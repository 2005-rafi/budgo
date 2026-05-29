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
}
