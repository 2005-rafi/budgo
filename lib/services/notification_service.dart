import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';

/// Lightweight, isolate-safe snapshot of workspace branding used to segregate
/// and style scheduled OS notifications per workspace profile.
class WorkspaceNotificationMeta {
  final String workspaceId;
  final String workspaceName;
  final String workspaceTypeLabel;
  final int? colorValue;

  const WorkspaceNotificationMeta({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceTypeLabel,
    this.colorValue,
  });

  static String labelForType(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.personal:
        return 'Personal';
      case WorkspaceType.business:
        return 'Business';
      case WorkspaceType.trip:
        return 'Trip';
      case WorkspaceType.project:
        return 'Project';
      case WorkspaceType.savingsPool:
        return 'Savings Pool';
    }
  }

  factory WorkspaceNotificationMeta.fromWorkspace(Workspace ws) {
    return WorkspaceNotificationMeta(
      workspaceId: ws.id,
      workspaceName: ws.name,
      workspaceTypeLabel: labelForType(ws.type),
      colorValue: ws.colorValue,
    );
  }
}

/// Immutable representation of notification display strings tuned for
/// compact collapsed trays and detailed expanded ("Read more") dropdowns.
class ReminderNotificationContent {
  final String displayTitle;
  final String collapsedBody;
  final String expandedBody;
  final String subText;

  const ReminderNotificationContent({
    required this.displayTitle,
    required this.collapsedBody,
    required this.expandedBody,
    required this.subText,
  });
}

/// Pure formatting, recurrence, and action-calculation helpers for reminders.
/// Kept free of platform plugins so it runs in minimal-RAM isolates and tests.
class ReminderNotificationFormatter {
  ReminderNotificationFormatter._();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Lightweight date/time formatting avoiding heavy Intl locale init overhead.
  static String formatCompactScheduleTime(DateTime dt) {
    final month = _months[(dt.month - 1).clamp(0, 11)];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month, $hour12:$minuteStr $period';
  }

  static String recurrenceLabel(String recurrence, RecurrenceRule? rule) {
    final effectiveType = rule != null ? rule.type.name : recurrence;
    switch (effectiveType) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'One-time';
    }
  }

  /// Builds separate collapsed summary and rich expanded ("Read more") text,
  /// segregating titles and badges by [workspaceName] when provided.
  static ReminderNotificationContent buildContent({
    required String title,
    required String fallbackBody,
    DateTime? scheduledTime,
    String recurrence = 'none',
    RecurrenceRule? recurrenceRule,
    int? amount,
    String? category,
    String? notes,
    String? workspaceName,
    String? workspaceTypeLabel,
  }) {
    final trimmedWsName = workspaceName?.trim();
    final hasWorkspace = trimmedWsName != null && trimmedWsName.isNotEmpty;
    final trimmedWsType = workspaceTypeLabel?.trim();
    final trimmedCategory = category?.trim();
    final trimmedNotes = notes?.trim();
    final hasAmount = amount != null && amount > 0;
    final formattedAmount = hasAmount ? amount.format() : null;
    final cadence = recurrenceLabel(recurrence, recurrenceRule);
    final isRecurring = cadence != 'One-time';

    final displayTitle = hasWorkspace ? '[$trimmedWsName] $title' : title;

    // Compact header tag shown next to app name (Android subText / iOS subtitle)
    final subParts = <String>[
      if (hasWorkspace) trimmedWsName,
      if (trimmedCategory != null && trimmedCategory.isNotEmpty) trimmedCategory,
      if (isRecurring) cadence,
    ];
    final subText = subParts.isNotEmpty ? subParts.join(' • ') : 'Reminder';

    // Collapsed 1-line preview so tray stays neat without overflowing
    final collapsedParts = <String>[
      if (formattedAmount != null) formattedAmount,
      if (scheduledTime != null) formatCompactScheduleTime(scheduledTime),
      if (trimmedCategory != null && trimmedCategory.isNotEmpty) trimmedCategory,
    ];
    final String collapsedBody;
    if (collapsedParts.isNotEmpty) {
      collapsedBody = collapsedParts.join(' • ');
    } else {
      final firstLine = fallbackBody
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => 'Scheduled reminder');
      collapsedBody = firstLine;
    }

    // Detailed multiline body revealed when pulling down Android/iOS notification dropdown
    final expandedLines = <String>[];
    if (hasWorkspace) {
      final hasDistinctType = trimmedWsType != null &&
          trimmedWsType.isNotEmpty &&
          trimmedWsType.toLowerCase() != trimmedWsName.toLowerCase();
      expandedLines.add(
        hasDistinctType
            ? 'Workspace: $trimmedWsName ($trimmedWsType)'
            : 'Workspace: $trimmedWsName',
      );
    }
    if (formattedAmount != null) {
      expandedLines.add('Amount: $formattedAmount');
    }
    if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
      expandedLines.add('Category: $trimmedCategory');
    }
    if (scheduledTime != null) {
      expandedLines.add(
        'Due: ${formatCompactScheduleTime(scheduledTime)} ($cadence)',
      );
    } else if (isRecurring) {
      expandedLines.add('Repeats: $cadence');
    }
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      expandedLines.add('Notes: $trimmedNotes');
    }

    final expandedBody = expandedLines.isNotEmpty
        ? expandedLines.join('\n')
        : (fallbackBody.trim().isNotEmpty ? fallbackBody.trim() : collapsedBody);

    return ReminderNotificationContent(
      displayTitle: displayTitle,
      collapsedBody: collapsedBody,
      expandedBody: expandedBody,
      subText: subText,
    );
  }

  /// Maps reminder recurrence onto native OS periodic components so recurring
  /// schedules tick natively in OS RTC/UserNotifications even if app stays closed.
  static DateTimeComponents? matchComponentsFor(
    String recurrence,
    RecurrenceRule? rule,
    DateTime scheduledDate,
  ) {
    final effectiveType = rule != null ? rule.type.name : recurrence;
    switch (effectiveType) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'monthly':
        // Days 29-31 vary by month length; OS component matching can skip shorter
        // months like Feb, so only use native component match on days 1..28.
        return scheduledDate.day <= 28
            ? DateTimeComponents.dayOfMonthAndTime
            : null;
      default:
        return null;
    }
  }

  /// Computes next occurrence after skipping a recurring reminder cycle.
  static DateTime computeNextCycleAfterSkip(Reminder reminder, DateTime now) {
    final anchor = reminder.scheduledAt.isAfter(now) ? reminder.scheduledAt : now;
    final afterAnchor = anchor.add(const Duration(minutes: 1));
    final rule = reminder.recurrenceRule;
    if (rule != null) {
      return rule.nextOccurrenceAfter(afterAnchor, reminder.scheduledAt);
    }
    return RecurrenceRule.computeLegacyNextOccurrence(
      reminder.scheduledAt,
      reminder.recurrenceType,
      afterAnchor,
    );
  }

  /// Computes next occurrence after completing/paying a recurring reminder.
  static DateTime computeNextCycleAfterDone(Reminder reminder, DateTime now) {
    final rule = reminder.recurrenceRule;
    if (rule != null) {
      return rule.nextOccurrenceAfter(now, reminder.scheduledAt);
    }
    return RecurrenceRule.computeLegacyNextOccurrence(
      reminder.scheduledAt,
      reminder.recurrenceType,
      now,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Versioned channel ID so Android 8+ updates cleanly from high-priority alerts
  /// to quiet default reminder importance (standard notification, not an alarm).
  static const String kChannelId = 'budgo_reminders_v2';
  static String get kChannelName => '${AppBrand.appName} Reminders';
  static String get kChannelDescription =>
      'Scheduled financial reminders and bill nudges from ${AppBrand.appName}.';
  static const String kIosCategoryId = 'budgo_reminder_category';

  static const String kActionDone = 'mark_done';
  static const String kActionSkip = 'skip';
  static const String kActionCancel = 'cancel_reminder';

  // Legacy identifiers retained strictly for backward compatibility with
  // any notification already sitting in an OS tray during upgrade.
  static const String kLegacyActionMarkPaid = 'mark_paid';
  static const String kLegacyActionRemindLater = 'remind_later';

  static const Color kBrandGreen = Color(0xFF4CAF50);
  static const Color kCancelRed = Color(0xFFE53935);
  static const String kBackgroundActionPortName = 'budgo_notif_action_port';

  /// Returns an isolated Android channel ID for [workspaceId] so OS notification
  /// settings and grouping stay strictly separated across user workspaces.
  static String channelIdForWorkspace(String? workspaceId) {
    final trimmed = workspaceId?.trim() ?? '';
    if (trimmed.isEmpty) return kChannelId;
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'budgo_ws_${sanitized}_v1';
  }

  static String channelNameForWorkspace(String? workspaceName) {
    final trimmed = workspaceName?.trim() ?? '';
    if (trimmed.isEmpty) return kChannelName;
    return '$trimmed Reminders';
  }

  static String? groupKeyForWorkspace(String? workspaceId) {
    final trimmed = workspaceId?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return 'budgo_ws_group_$trimmed';
  }

  static String? iosThreadIdForWorkspace(String? workspaceId) {
    final trimmed = workspaceId?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return 'budgo_ws_thread_$trimmed';
  }

  /// Safely looks up [WorkspaceNotificationMeta] from Hive without requiring
  /// a Provider tree (used in headless background isolates & reconcilers).
  static Future<WorkspaceNotificationMeta?> resolveWorkspaceMetaFromHive(
    String workspaceId,
  ) async {
    final targetId =
        workspaceId.isEmpty ? AppConstants.kDefaultWorkspaceId : workspaceId;
    Box<Workspace>? wsBox;
    bool openedHere = false;
    try {
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(WorkspaceTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(WorkspaceAdapter());
      }
      if (Hive.isBoxOpen(AppConstants.kWorkspacesBox)) {
        wsBox = Hive.box<Workspace>(AppConstants.kWorkspacesBox);
      } else {
        wsBox = await Hive.openBox<Workspace>(AppConstants.kWorkspacesBox);
        openedHere = true;
      }
      final ws = wsBox.get(targetId);
      if (ws != null) {
        return WorkspaceNotificationMeta.fromWorkspace(ws);
      }
    } catch (_) {
      // Fallback safely to generic branding if workspace box is unavailable.
    } finally {
      if (openedHere && wsBox != null && wsBox.isOpen) {
        await wsBox.close();
      }
    }
    return null;
  }

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _timezoneInitialized = false;
  bool _pluginInitialized = false;

  static void Function(NotificationResponse)? onActionTapped;

  void _handleNotificationResponse(NotificationResponse response) {
    if (onActionTapped != null) {
      onActionTapped!(response);
    }
  }

  /// Initializes timezone database once per Dart isolate to minimize RAM/CPU cost.
  Future<void> _ensureTimezoneInitialized() async {
    if (_timezoneInitialized) return;
    tz.initializeTimeZones();

    String timeZoneName = 'UTC';
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      timeZoneName = tzInfo.identifier;
    } catch (_) {
      // Fallback to UTC if platform timezone lookup fails.
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    _timezoneInitialized = true;
  }

  InitializationSettings _buildInitializationSettings() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_budgo');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      defaultPresentSound: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          kIosCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(kActionDone, 'Done'),
            DarwinNotificationAction.plain(kActionSkip, 'Skip'),
            DarwinNotificationAction.plain(
              kActionCancel,
              'Cancel',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    return InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
  }

  Future<void> initialize() async {
    await _ensureTimezoneInitialized();

    if (!_pluginInitialized) {
      await _notificationsPlugin.initialize(
        _buildInitializationSettings(),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _pluginInitialized = true;
    }

    // Register standard non-alarm notification channel on Android 8+.
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      kChannelId,
      kChannelName,
      description: kChannelDescription,
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      final enabled = await androidImplementation.areNotificationsEnabled();
      if (enabled == false) {
        await androidImplementation.requestNotificationsPermission();
      }
    }
  }

  /// Lightweight plugin setup for headless background isolate notification actions.
  /// Deliberately avoids UI permission dialogs that require an active Activity.
  Future<void> initializeForBackground() async {
    await _ensureTimezoneInitialized();
    if (_pluginInitialized) return;

    await _notificationsPlugin.initialize(
      _buildInitializationSettings(),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _pluginInitialized = true;
  }

  /// Returns a pending notification launch action if app opened via notification tap.
  Future<NotificationResponse?> getLaunchNotificationResponse() async {
    try {
      final details =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse;
      }
    } catch (e) {
      debugPrint('Error reading launch notification details: $e');
    }
    return null;
  }

  Future<bool> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        kChannelId,
        kChannelName,
        channelDescription: kChannelDescription,
        icon: 'ic_stat_budgo',
        largeIcon: const DrawableResourceAndroidBitmap('budgo_logo'),
        color: kBrandGreen,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: '${AppBrand.appName} Alert',
        ),
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        subtitle: '${AppBrand.appName} Alert',
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
      return true;
    } catch (e) {
      debugPrint('Error showing immediate notification: $e');
      return false;
    }
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final canExact =
          await androidImplementation.canScheduleExactNotifications();
      if (canExact == false) {
        return AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<bool> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String recurrence = 'none',
    RecurrenceRule? recurrenceRule,
    String? payload,
    int? amount,
    String? category,
    String? notes,
    WorkspaceNotificationMeta? workspace,
  }) async {
    try {
      await _ensureTimezoneInitialized();

      tz.TZDateTime scheduledDateTime;
      final now = tz.TZDateTime.now(tz.local);
      final nowLocal = DateTime.now();

      if (recurrenceRule != null) {
        final next =
            recurrenceRule.nextOccurrenceAfter(nowLocal, scheduledTime);
        scheduledDateTime = tz.TZDateTime.from(next, tz.local);
      } else {
        if (recurrence == 'none' && scheduledTime.isBefore(nowLocal)) {
          return false;
        }
        final next = RecurrenceRule.computeLegacyNextOccurrence(
          scheduledTime,
          recurrence,
          nowLocal,
        );
        scheduledDateTime = tz.TZDateTime.from(next, tz.local);
        if (scheduledDateTime.isBefore(now)) {
          return false;
        }
      }

      final content = ReminderNotificationFormatter.buildContent(
        title: title,
        fallbackBody: body,
        scheduledTime: scheduledDateTime.toLocal(),
        recurrence: recurrence,
        recurrenceRule: recurrenceRule,
        amount: amount,
        category: category,
        notes: notes,
        workspaceName: workspace?.workspaceName,
        workspaceTypeLabel: workspace?.workspaceTypeLabel,
      );

      final resolvedChannelId = channelIdForWorkspace(workspace?.workspaceId);
      final resolvedChannelName =
          channelNameForWorkspace(workspace?.workspaceName);
      final resolvedChannelDesc = workspace != null
          ? 'Reminders for the ${workspace.workspaceName} workspace.'
          : kChannelDescription;
      final accentColor = workspace?.colorValue != null
          ? Color(workspace!.colorValue!)
          : kBrandGreen;

      if (workspace != null) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.createNotificationChannel(
          AndroidNotificationChannel(
            resolvedChannelId,
            resolvedChannelName,
            description: resolvedChannelDesc,
            importance: Importance.defaultImportance,
            enableVibration: true,
            playSound: true,
          ),
        );
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        resolvedChannelId,
        resolvedChannelName,
        channelDescription: resolvedChannelDesc,
        icon: 'ic_stat_budgo',
        largeIcon: const DrawableResourceAndroidBitmap('budgo_logo'),
        color: accentColor,
        subText: content.subText,
        groupKey: groupKeyForWorkspace(workspace?.workspaceId),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          content.expandedBody,
          contentTitle: content.displayTitle,
          summaryText: content.subText,
        ),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            kActionDone,
            'Done',
            titleColor: kBrandGreen,
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            kActionSkip,
            'Skip',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            kActionCancel,
            'Cancel',
            titleColor: kCancelRed,
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        subtitle: content.subText,
        threadIdentifier: iosThreadIdForWorkspace(workspace?.workspaceId),
        categoryIdentifier: kIosCategoryId,
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final String platformBody = defaultTargetPlatform == TargetPlatform.iOS
          ? content.expandedBody
          : content.collapsedBody;

      final matchComponents = ReminderNotificationFormatter.matchComponentsFor(
        recurrence,
        recurrenceRule,
        scheduledDateTime,
      );

      final scheduleMode = await _resolveAndroidScheduleMode();

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          content.displayTitle,
          platformBody,
          scheduledDateTime,
          notificationDetails,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: payload,
        );
      } on PlatformException catch (e) {
        if (e.code == 'exact_alarms_not_permitted' &&
            scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
          await _notificationsPlugin.zonedSchedule(
            id,
            content.displayTitle,
            platformBody,
            scheduledDateTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: matchComponents,
            payload: payload,
          );
        } else {
          rethrow;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return false;
    }
  }

  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}

/// Serializes headless Hive actions so rapid notification button taps never collide.
Future<void> _backgroundActionQueue = Future<void>.value();

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  final reminderId = response.payload;
  if (reminderId == null || actionId == null) return;

  // Fast-path: if main isolate is alive in memory, delegate straight to it so
  // live Hive box + ReminderProvider update atomically with zero lock races.
  final SendPort? mainPort = IsolateNameServer.lookupPortByName(
    NotificationService.kBackgroundActionPortName,
  );
  if (mainPort != null) {
    mainPort.send(<String, dynamic>{
      'actionId': actionId,
      'reminderId': reminderId,
      'notificationId': response.id,
    });
    return;
  }

  // Cold/terminated path: queue headless Hive mutation cleanly inside this isolate.
  _backgroundActionQueue = _backgroundActionQueue.then(
    (_) => _executeHeadlessBackgroundAction(actionId, reminderId, response.id),
  );
  await _backgroundActionQueue;
}

Future<void> _executeHeadlessBackgroundAction(
  String actionId,
  String reminderId,
  int? rawNotificationId,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  Box<Reminder>? box;
  bool openedHere = false;

  try {
    final service = NotificationService();
    await service.initializeForBackground();

    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ReminderAdapter());
    }
    if (!Hive.isBoxOpen(AppConstants.kRemindersBox)) {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      box = await Hive.openBox<Reminder>(AppConstants.kRemindersBox);
      openedHere = true;
    } else {
      box = Hive.box<Reminder>(AppConstants.kRemindersBox);
    }

    final reminder = box.get(reminderId);
    final plugin = FlutterLocalNotificationsPlugin();
    final cancelId = reminder?.notificationId ?? rawNotificationId;
    if (cancelId != null) {
      await plugin.cancel(cancelId);
    }

    if (reminder == null) return;

    final now = DateTime.now();
    final isRecurring =
        reminder.isRecurring && reminder.recurrenceType != 'none';

    if (actionId == NotificationService.kActionDone ||
        actionId == NotificationService.kLegacyActionMarkPaid) {
      if (isRecurring) {
        final nextTime =
            ReminderNotificationFormatter.computeNextCycleAfterDone(
          reminder,
          now,
        );
        reminder.scheduledAt = nextTime;
        reminder.paymentStatus = 'pending';
        reminder.isActive = true;
        reminder.state = 'active';
        reminder.failureReason = null;
        await reminder.save();

        await _rescheduleReminderFromHeadless(service, reminder);
      } else {
        reminder.isActive = false;
        reminder.paymentStatus = 'completed';
        reminder.state = 'active';
        reminder.failureReason = null;
        await reminder.save();
      }
    } else if (actionId == NotificationService.kActionSkip) {
      if (isRecurring) {
        final nextTime =
            ReminderNotificationFormatter.computeNextCycleAfterSkip(
          reminder,
          now,
        );
        reminder.scheduledAt = nextTime;
        reminder.paymentStatus = 'pending';
        reminder.isActive = true;
        reminder.state = 'active';
        reminder.failureReason = null;
        await reminder.save();

        await _rescheduleReminderFromHeadless(service, reminder);
      } else {
        reminder.isActive = false;
        reminder.paymentStatus = 'skipped';
        reminder.state = 'active';
        reminder.failureReason = null;
        await reminder.save();
      }
    } else if (actionId == NotificationService.kActionCancel) {
      reminder.isActive = false;
      reminder.paymentStatus = 'cancelled';
      reminder.state = 'active';
      reminder.failureReason = null;
      await reminder.save();
    } else if (actionId == NotificationService.kLegacyActionRemindLater) {
      final nextTime = now.add(const Duration(hours: 6));
      reminder.scheduledAt = nextTime;
      reminder.paymentStatus = 'pending';
      reminder.isActive = true;
      reminder.state = 'active';
      reminder.failureReason = null;
      await reminder.save();

      await _rescheduleReminderFromHeadless(service, reminder);
    }
  } catch (e) {
    debugPrint('Error processing background notification action: $e');
  } finally {
    if (openedHere && box != null && box.isOpen) {
      await box.close();
    }
  }
}

Future<void> _rescheduleReminderFromHeadless(
  NotificationService service,
  Reminder reminder,
) async {
  final workspaceMeta =
      await NotificationService.resolveWorkspaceMetaFromHive(
    reminder.workspaceId,
  );
  await service.scheduleReminder(
    id: reminder.notificationId,
    title: reminder.title,
    body: reminder.notificationBody,
    scheduledTime: reminder.scheduledAt,
    recurrence: reminder.recurrenceType,
    recurrenceRule: reminder.recurrenceRule,
    payload: reminder.id,
    amount: reminder.amount,
    category: reminder.category,
    notes: reminder.notes,
    workspace: workspaceMeta,
  );
}
