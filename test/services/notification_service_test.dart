import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/services/notification_service.dart';

void main() {
  group('ReminderNotificationFormatter', () {
    test('builds single-line collapsed summary and rich expandable dropdown body', () {
      final due = DateTime(2026, 11, 15, 9, 30);
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        dayOfMonth: 15,
        time: const TimeOfDay(hour: 9, minute: 30),
      );

      final content = ReminderNotificationFormatter.buildContent(
        title: 'Electricity Bill',
        fallbackBody: 'Pay BESCOM online',
        scheduledTime: due,
        recurrence: 'monthly',
        recurrenceRule: rule,
        amount: 150000, // ₹1,500.00
        category: 'Bills',
        notes: 'Use autopay or UPI before evening',
      );

      expect(content.collapsedBody.contains('\n'), isFalse);
      expect(content.collapsedBody, contains('15 Nov, 9:30 AM'));
      expect(content.collapsedBody, contains('Bills'));
      expect(content.collapsedBody, contains('1,500'));

      expect(content.expandedBody, contains('Amount: '));
      expect(content.expandedBody, contains('Category: Bills'));
      expect(content.expandedBody, contains('Due: 15 Nov, 9:30 AM (Monthly)'));
      expect(
        content.expandedBody,
        contains('Notes: Use autopay or UPI before evening'),
      );
      expect(content.subText, 'Bills • Monthly');
    });

    test('falls back cleanly when optional metadata is missing', () {
      final content = ReminderNotificationFormatter.buildContent(
        title: 'Quick Reminder',
        fallbackBody: 'Line one\nLine two detail',
      );

      expect(content.collapsedBody, 'Line one');
      expect(content.expandedBody, 'Line one\nLine two detail');
      expect(content.subText, 'Reminder');
    });

    test('maps recurrence types to OS-level DateTimeComponents safely', () {
      expect(
        ReminderNotificationFormatter.matchComponentsFor(
          'daily',
          null,
          DateTime(2026, 11, 10, 8, 0),
        ),
        DateTimeComponents.time,
      );

      expect(
        ReminderNotificationFormatter.matchComponentsFor(
          'weekly',
          null,
          DateTime(2026, 11, 10, 8, 0),
        ),
        DateTimeComponents.dayOfWeekAndTime,
      );

      expect(
        ReminderNotificationFormatter.matchComponentsFor(
          'monthly',
          null,
          DateTime(2026, 11, 15, 8, 0),
        ),
        DateTimeComponents.dayOfMonthAndTime,
      );

      // Days 29-31 return null so short months (e.g., Feb) never silently skip.
      expect(
        ReminderNotificationFormatter.matchComponentsFor(
          'monthly',
          null,
          DateTime(2026, 1, 31, 8, 0),
        ),
        isNull,
      );

      expect(
        ReminderNotificationFormatter.matchComponentsFor(
          'none',
          null,
          DateTime(2026, 11, 15, 8, 0),
        ),
        isNull,
      );

      final ruleOverride = RecurrenceRule(
        type: RecurrenceType.weekly,
        weekday: DateTime.friday,
        time: const TimeOfDay(hour: 18, minute: 0),
      );
      expect(
        ReminderNotificationFormatter.matchComponentsFor(
          'none',
          ruleOverride,
          DateTime(2026, 11, 13, 18, 0),
        ),
        DateTimeComponents.dayOfWeekAndTime,
      );
    });

    test('computeNextCycleAfterSkip jumps forward even when tapped before due time', () {
      final scheduled = DateTime(2026, 11, 15, 9, 0);
      final nowBefore = DateTime(2026, 11, 15, 8, 30);
      final reminder = Reminder(
        id: 'skip-early',
        title: 'Daily Standup Savings',
        scheduledAt: scheduled,
        isRecurring: true,
        recurrenceType: 'daily',
      )..recurrenceRule = RecurrenceRule(
          type: RecurrenceType.daily,
          time: const TimeOfDay(hour: 9, minute: 0),
        );

      final nextAfterEarlySkip =
          ReminderNotificationFormatter.computeNextCycleAfterSkip(
        reminder,
        nowBefore,
      );
      expect(nextAfterEarlySkip, DateTime(2026, 11, 16, 9, 0));

      final nowLate = DateTime(2026, 11, 17, 10, 0);
      final nextAfterLateSkip =
          ReminderNotificationFormatter.computeNextCycleAfterSkip(
        reminder,
        nowLate,
      );
      expect(nextAfterLateSkip, DateTime(2026, 11, 18, 9, 0));
    });
  });

  group('NotificationService configuration invariants', () {
    test('builds workspace-segregated titles, subtitles, channels, groups, and threads', () {
      final due = DateTime(2026, 11, 20, 10, 0);
      final content = ReminderNotificationFormatter.buildContent(
        title: 'Vendor Payout',
        fallbackBody: 'Transfer invoice #42',
        scheduledTime: due,
        recurrence: 'monthly',
        amount: 250000,
        category: 'Bills',
        workspaceName: 'Acme Corp',
        workspaceTypeLabel: 'Business',
      );

      expect(content.displayTitle, '[Acme Corp] Vendor Payout');
      expect(content.subText, 'Acme Corp • Bills • Monthly');
      expect(content.expandedBody, startsWith('Workspace: Acme Corp (Business)'));

      expect(
        NotificationService.channelIdForWorkspace('ws_123'),
        'budgo_ws_ws_123_v1',
      );
      expect(
        NotificationService.channelNameForWorkspace('Goa Trip'),
        'Goa Trip Reminders',
      );
      expect(
        NotificationService.groupKeyForWorkspace('ws_123'),
        'budgo_ws_group_ws_123',
      );
      expect(
        NotificationService.iosThreadIdForWorkspace('ws_123'),
        'budgo_ws_thread_ws_123',
      );
    });

    test('uses non-alarm versioned channel and minimal 3 action IDs', () {
      expect(NotificationService.kChannelId, 'budgo_reminders_v2');
      expect(NotificationService.kIosCategoryId, 'budgo_reminder_category');
      expect(NotificationService.kActionDone, 'mark_done');
      expect(NotificationService.kActionSkip, 'skip');
      expect(NotificationService.kActionCancel, 'cancel_reminder');
      expect(NotificationService.kLegacyActionMarkPaid, 'mark_paid');
      expect(NotificationService.kLegacyActionRemindLater, 'remind_later');
      expect(
        NotificationService.kBackgroundActionPortName,
        'budgo_notif_action_port',
      );
    });
  });
}

