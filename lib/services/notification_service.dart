import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:expense/models/reminder.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

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
      await androidImplementation.requestExactAlarmsPermission();
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
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Determine the matchComponents for repeating scheduled notifications
      DateTimeComponents? matchComponents;
      final recRuleType = recurrenceRule?.type ?? _recurrenceTypeFromString(recurrence);
      if (recRuleType == RecurrenceType.daily) {
        matchComponents = DateTimeComponents.time;
      } else if (recRuleType == RecurrenceType.weekly) {
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      } else if (recRuleType == RecurrenceType.monthly) {
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
      }

      try {
        if (matchComponents == null) {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDateTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } else {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDateTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: matchComponents,
          );
        }
      } catch (e) {
        // Fallback to inexact scheduling if exact alarms are not permitted (Android 14+)
        if (matchComponents == null) {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDateTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } else {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDateTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: matchComponents,
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return false;
    }
  }

  RecurrenceType _recurrenceTypeFromString(String recurrence) {
    switch (recurrence) {
      case 'daily':
        return RecurrenceType.daily;
      case 'weekly':
        return RecurrenceType.weekly;
      case 'monthly':
        return RecurrenceType.monthly;
      default:
        return RecurrenceType.none;
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
