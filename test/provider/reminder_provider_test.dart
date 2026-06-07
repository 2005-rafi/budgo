import 'package:flutter_test/flutter_test.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
class FakeReminderRepository implements ReminderRepository {
  final List<Reminder> _reminders = [];

  @override
  Future<void> add(Reminder reminder) async {
    _reminders.add(reminder);
  }

  @override
  Future<void> delete(Reminder reminder) async {
    _reminders.removeWhere((r) => r.id == reminder.id);
  }

  @override
  Future<List<Reminder>> getAll() async => List.of(_reminders);

  @override
  Future<void> update(Reminder reminder) async {
    final idx = _reminders.indexWhere((r) => r.id == reminder.id);
    if (idx != -1) _reminders[idx] = reminder;
  }

  @override
  Stream<void> watch() async* {
    // No-op stream for testing.
  }

  @override
  Future<void> toggleActive(Reminder reminder) async {
    final idx = _reminders.indexWhere((r) => r.id == reminder.id);
    if (idx != -1) {
      _reminders[idx].isActive = !_reminders[idx].isActive;
    }
  }
}

class FakeNotificationService implements NotificationService {
  final List<int> cancelled = [];
  final List<int> scheduled = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String recurrence = 'none',
    RecurrenceRule? recurrenceRule,
    String? payload,
  }) async {
    scheduled.add(id);
    return true;
  }

  @override
  Future<void> cancelReminder(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> cancelAllReminders() async {}

  @override
  Future<List<PendingNotificationRequest>> getPendingReminders() async => [];

  @override
  Future<bool> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    return true;
  }
}

void main() {
  test('addReminder schedules notification and adds to list', () async {
    final repo = FakeReminderRepository();
    final notif = FakeNotificationService();
    final provider = ReminderProvider(repo, notif);
    final reminder = Reminder(
      id: '1',
      title: 'Test',
      notes: null,
      scheduledAt: DateTime.now().add(const Duration(minutes: 1)),
      isRecurring: false,
      recurrenceType: 'none',
      isActive: true,
    );
    final result = await provider.addReminder(reminder);
    expect(result, true);
    expect(provider.items.length, 1);
    expect(provider.items.first.id, '1');
  });

  test('deleteReminder cancels notification and removes from list', () async {
    final repo = FakeReminderRepository();
    final notif = FakeNotificationService();
    final provider = ReminderProvider(repo, notif);
    final reminder = Reminder(
      id: '2',
      title: 'Del',
      notes: null,
      scheduledAt: DateTime.now().add(const Duration(minutes: 2)),
      isRecurring: false,
      recurrenceType: 'none',
      isActive: true,
    );
    await provider.addReminder(reminder);
    expect(provider.items.length, 1);
    final delResult = await provider.deleteReminder(reminder);
    expect(delResult, true);
    expect(provider.items.length, 0);
  });

  test('toggleActive updates active state and schedules/cancels notification', () async {
    final repo = FakeReminderRepository();
    final notif = FakeNotificationService();
    final provider = ReminderProvider(repo, notif);
    final reminder = Reminder(
      id: '3',
      title: 'Toggle',
      notes: null,
      scheduledAt: DateTime.now().add(const Duration(minutes: 1)),
      isRecurring: false,
      recurrenceType: 'none',
      isActive: false,
    );
    await provider.addReminder(reminder);
    expect(provider.items.first.isActive, false);
    await provider.toggleActive(reminder);
    expect(provider.items.first.isActive, true);
  });

  test('markAsPaid updates non-recurring reminder to completed and inactive', () async {
    final repo = FakeReminderRepository();
    final notif = FakeNotificationService();
    final provider = ReminderProvider(repo, notif);
    final reminder = Reminder(
      id: '4',
      title: 'One-time',
      scheduledAt: DateTime.now().add(const Duration(minutes: 10)),
      isRecurring: false,
      recurrenceType: 'none',
      isActive: true,
      paymentStatus: 'pending',
    );
    await provider.addReminder(reminder);
    expect(provider.items.first.paymentStatus, 'pending');
    expect(provider.items.first.isActive, true);

    final result = await provider.markAsPaid(reminder);
    expect(result, true);
    expect(provider.items.first.paymentStatus, 'completed');
    expect(provider.items.first.isActive, false);
    expect(notif.cancelled.contains(reminder.notificationId), true);
  });

  test('markAsPaid updates recurring reminder to next occurrence and pending status', () async {
    final repo = FakeReminderRepository();
    final notif = FakeNotificationService();
    final provider = ReminderProvider(repo, notif);
    final baseTime = DateTime(2026, 5, 30, 9, 0);
    final reminder = Reminder(
      id: '5',
      title: 'Recurring',
      scheduledAt: baseTime,
      isRecurring: true,
      recurrenceType: 'daily',
      isActive: true,
      paymentStatus: 'pending',
    );
    await provider.addReminder(reminder);

    final result = await provider.markAsPaid(reminder);
    expect(result, true);
    expect(provider.items.first.paymentStatus, 'pending');
    expect(provider.items.first.isActive, true);
    
    DateTime expectedNext = baseTime;
    final now = DateTime.now();
    while (expectedNext.isBefore(now)) {
      expectedNext = expectedNext.add(const Duration(days: 1));
    }
    
    expect(provider.items.first.scheduledAt, expectedNext);
    expect(notif.cancelled.contains(reminder.notificationId), true);
    expect(notif.scheduled.contains(reminder.notificationId), true);
  });

  test('remindLater postpones reminder by 6 hours', () async {
    final repo = FakeReminderRepository();
    final notif = FakeNotificationService();
    final provider = ReminderProvider(repo, notif);
    final reminder = Reminder(
      id: '6',
      title: 'Postpone',
      scheduledAt: DateTime.now().add(const Duration(minutes: 10)),
      isRecurring: false,
      recurrenceType: 'none',
      isActive: true,
      paymentStatus: 'pending',
    );
    await provider.addReminder(reminder);

    final originalTime = reminder.scheduledAt;
    final result = await provider.remindLater(reminder);
    expect(result, true);
    expect(provider.items.first.paymentStatus, 'pending');
    expect(provider.items.first.isActive, true);
    expect(provider.items.first.scheduledAt.isAfter(originalTime), true);
    expect(notif.cancelled.contains(reminder.notificationId), true);
    expect(notif.scheduled.contains(reminder.notificationId), true);
  });
}
