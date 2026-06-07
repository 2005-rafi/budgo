import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:expense/models/reminder.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static void Function(NotificationResponse)? onActionTapped;

  void _handleNotificationResponse(NotificationResponse response) {
    if (onActionTapped != null) {
      onActionTapped!(response);
    }
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();
    
    String timeZoneName = 'UTC';
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      timeZoneName = tzInfo.identifier;
    } catch (_) {
      // Fallback to default UTC timezone if retrieval fails
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );


    // Create Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'budgo_reminders',
      'Budgo Reminders',
      description: 'This channel is used for Budgo reminders and alerts.',
      importance: Importance.high,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<bool> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'budgo_reminders',
        'Budgo Reminders',
        channelDescription: 'This channel is used for Budgo reminders and alerts.',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails notificationDetails = NotificationDetails(
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

  Future<bool> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String recurrence = 'none',
    RecurrenceRule? recurrenceRule,
    String? payload,
  }) async {
    try {
      tz.TZDateTime scheduledDateTime;
      final now = tz.TZDateTime.now(tz.local);
      final nowLocal = DateTime.now();

      if (recurrenceRule != null) {
        final next = recurrenceRule.nextOccurrenceAfter(nowLocal, scheduledTime);
        scheduledDateTime = tz.TZDateTime.from(next, tz.local);
      } else {
        if (recurrence == 'none' && scheduledTime.isBefore(nowLocal)) {
          return false;
        }
        final next = RecurrenceRule.computeLegacyNextOccurrence(scheduledTime, recurrence, nowLocal);
        scheduledDateTime = tz.TZDateTime.from(next, tz.local);
        if (scheduledDateTime.isBefore(now)) {
          return false;
        }
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'budgo_reminders',
        'Budgo Reminders',
        channelDescription: 'This channel is used for Budgo reminders and alerts.',
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'view',
            'View',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'mark_paid',
            'Mark as Paid',
          ),
          AndroidNotificationAction(
            'remind_later',
            'Remind Later',
          ),
        ],
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
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

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final actionId = response.actionId;
  final reminderId = response.payload;
  if (reminderId == null) return;

  if (actionId == 'mark_paid') {
    _handleBackgroundMarkPaid(reminderId);
  } else if (actionId == 'remind_later') {
    _handleBackgroundRemindLater(reminderId);
  }
}

Future<void> _handleBackgroundMarkPaid(String reminderId) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initialize();
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ReminderAdapter());
    }
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    final box = await Hive.openBox<Reminder>('reminders');
    final reminder = box.get(reminderId);
    if (reminder != null) {
      if (reminder.isRecurring && reminder.recurrenceType != 'none') {
        final now = DateTime.now();
        DateTime nextTime;
        if (reminder.recurrenceRule != null) {
          nextTime = reminder.recurrenceRule!.nextOccurrenceAfter(now, reminder.scheduledAt);
        } else {
          nextTime = RecurrenceRule.computeLegacyNextOccurrence(reminder.scheduledAt, reminder.recurrenceType, now);
        }
        reminder.scheduledAt = nextTime;
        reminder.paymentStatus = 'pending';
        reminder.state = 'active';
      } else {
        reminder.isActive = false;
        reminder.paymentStatus = 'completed';
      }
      await reminder.save();

      // Cancel current
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(reminder.notificationId);

      // Reschedule if recurring is still active
      if (reminder.isActive) {
        final service = NotificationService();
        await service.scheduleReminder(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.notificationBody,
          scheduledTime: reminder.scheduledAt,
          recurrence: reminder.recurrenceType,
          recurrenceRule: reminder.recurrenceRule,
          payload: reminder.id,
        );
      }
    }
  } catch (e) {
    debugPrint('Error marking paid in background: $e');
  }
}

Future<void> _handleBackgroundRemindLater(String reminderId) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initialize();
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ReminderAdapter());
    }
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    final box = await Hive.openBox<Reminder>('reminders');
    final reminder = box.get(reminderId);
    if (reminder != null) {
      final nextTime = DateTime.now().add(const Duration(hours: 6));
      reminder.scheduledAt = nextTime;
      await reminder.save();

      // Cancel current
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(reminder.notificationId);

      // Reschedule
      final service = NotificationService();
      await service.scheduleReminder(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.notificationBody,
        scheduledTime: nextTime,
        recurrence: reminder.recurrenceType,
        recurrenceRule: reminder.recurrenceRule,
        payload: reminder.id,
      );
    }
  } catch (e) {
    debugPrint('Error reminding later in background: $e');
  }
}

