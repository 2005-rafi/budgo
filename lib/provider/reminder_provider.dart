import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/reminder.dart';
import '../repositories/reminder_repository.dart';
import '../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderRepository _repository;
  final NotificationService _notificationService;
  final LinkedHashMap<String, Reminder> _itemMap =
      LinkedHashMap<String, Reminder>();
  StreamSubscription<void>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;
  bool _skipNextWatch = false;

  ReminderProvider(this._repository, [NotificationService? notificationService])
    : _notificationService = notificationService ?? NotificationService();

  UnmodifiableListView<Reminder> get items =>
      UnmodifiableListView(_itemMap.values);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _subscription ??= _repository.watch().listen((_) {
      if (_skipNextWatch) {
        _skipNextWatch = false;
        return;
      }
      load();
    });
    await load();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final list = await _repository.getAll();
      final now = DateTime.now();
      bool changed = false;
      _itemMap.clear();
      for (var reminder in list) {
        if (reminder.isActive &&
            reminder.paymentStatus == 'pending' &&
            reminder.scheduledAt.isBefore(now)) {
          reminder.paymentStatus = 'overdue';
          await _repository.update(reminder);
          changed = true;
        }
        _itemMap[reminder.id] = reminder;
      }
      if (changed) {
        final updatedList = await _repository.getAll();
        _itemMap.clear();
        for (var reminder in updatedList) {
          _itemMap[reminder.id] = reminder;
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load reminders: $e';
    }
    _isLoading = false;
    notifyListeners();
  }


  Future<bool> addReminder(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      DateTime scheduledTime = reminder.scheduledAt;
      if (reminder.isActive && scheduledTime.isBefore(DateTime.now())) {
        if (reminder.recurrenceRule != null ||
            reminder.recurrenceType != 'none') {
          scheduledTime = _computeNextOccurrence(
            scheduledTime,
            reminder.recurrenceRule,
            reminder.recurrenceType,
          );
          reminder.scheduledAt = scheduledTime;
        }
      }

      // Task 3-7: Two-phase commit
      // Step 1: Write to box with 'scheduling' state
      reminder.state = 'scheduling';
      _skipNextWatch = true;
      await _repository.add(reminder);

      final list = _itemMap.values.toList();
      int idx = list.indexWhere(
        (e) => e.scheduledAt.isAfter(reminder.scheduledAt),
      );
      if (idx == -1) {
        list.add(reminder);
      } else {
        list.insert(idx, reminder);
      }
      _itemMap.clear();
      for (var item in list) {
        _itemMap[item.id] = item;
      }

      bool scheduleSuccess = true;
      // Step 2: Register with OS
      if (reminder.isActive) {
        if (reminder.recurrenceRule != null ||
            reminder.recurrenceType != 'none' ||
            !scheduledTime.isBefore(DateTime.now())) {
          final success = await _notificationService.scheduleReminder(
            id: reminder.notificationId,
            title: reminder.title,
            body: reminder.notificationBody,
            scheduledTime: scheduledTime,
            recurrence: reminder.recurrenceType,
            recurrenceRule: reminder.recurrenceRule,
            payload: reminder.id,
          );


          scheduleSuccess = success;

          // Step 3: Flip state based on success
          if (success) {
            reminder.state = 'active';
            reminder.failureReason = null;
          } else {
            reminder.state = 'failed';
            reminder.failureReason = 'Failed to schedule with OS';
          }
          _skipNextWatch = true;
          await _repository.update(reminder);
        } else {
          reminder.state = 'active';
          _skipNextWatch = true;
          await _repository.update(reminder);
        }
      } else {
        reminder.state =
            'active'; // Inactive reminders are considered 'active' in DB state
        _skipNextWatch = true;
        await _repository.update(reminder);
      }

      return scheduleSuccess;
    } catch (e) {
      _errorMessage = 'Failed to add reminder: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateReminder(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      DateTime scheduledTime = reminder.scheduledAt;
      if (reminder.isActive && scheduledTime.isBefore(DateTime.now())) {
        if (reminder.recurrenceRule != null ||
            reminder.recurrenceType != 'none') {
          scheduledTime = _computeNextOccurrence(
            scheduledTime,
            reminder.recurrenceRule,
            reminder.recurrenceType,
          );
          reminder.scheduledAt = scheduledTime;
        }
      }

      // Step 1: Write to database with 'scheduling' state
      reminder.state = 'scheduling';
      _skipNextWatch = true;
      await _repository.update(reminder);

      final list = _itemMap.values.toList();
      final idx = list.indexWhere((e) => e.id == reminder.id);
      if (idx != -1) {
        list[idx] = reminder;
      } else {
        list.add(reminder);
      }
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      _itemMap.clear();
      for (var item in list) {
        _itemMap[item.id] = item;
      }

      // Cancel old system notification first
      await _notificationService.cancelReminder(reminder.notificationId);

      bool scheduleSuccess = true;
      // Step 2: Register new with OS if active
      if (reminder.isActive) {
        if (reminder.recurrenceRule != null ||
            reminder.recurrenceType != 'none' ||
            !scheduledTime.isBefore(DateTime.now())) {
          final success = await _notificationService.scheduleReminder(
            id: reminder.notificationId,
            title: reminder.title,
            body: reminder.notificationBody,
            scheduledTime: scheduledTime,
            recurrence: reminder.recurrenceType,
            recurrenceRule: reminder.recurrenceRule,
            payload: reminder.id,
          );


          scheduleSuccess = success;

          // Step 3: Flip state based on success
          if (success) {
            reminder.state = 'active';
            reminder.failureReason = null;
          } else {
            reminder.state = 'failed';
            reminder.failureReason = 'Failed to schedule with OS';
          }
          _skipNextWatch = true;
          await _repository.update(reminder);
        } else {
          reminder.state = 'active';
          _skipNextWatch = true;
          await _repository.update(reminder);
        }
      } else {
        reminder.state = 'active';
        _skipNextWatch = true;
        await _repository.update(reminder);
      }

      return scheduleSuccess;
    } catch (e) {
      _errorMessage = 'Failed to update reminder: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteReminder(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _notificationService.cancelReminder(reminder.notificationId);
      _skipNextWatch = true;
      await _repository.delete(reminder);
      _itemMap.remove(reminder.id);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete reminder: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleActive(Reminder reminder) async {
    _errorMessage = null;
    final originalState = reminder.isActive;
    final originalScheduledTime = reminder.scheduledAt;
    final originalDbState = reminder.state;

    // 1. Calculate new state
    bool newState = !originalState;
    DateTime scheduledTime = originalScheduledTime;

    if (newState && scheduledTime.isBefore(DateTime.now())) {
      if (reminder.recurrenceRule != null ||
          reminder.recurrenceType != 'none') {
        scheduledTime = _computeNextOccurrence(
          scheduledTime,
          reminder.recurrenceRule,
          reminder.recurrenceType,
        );
      } else {
        newState = false; // Cannot activate past one-time reminder
      }
    }

    // 2. Persistent update (Hive) - Step 1 of 2PC
    try {
      _skipNextWatch = true;
      reminder.isActive = newState;
      reminder.scheduledAt = scheduledTime;
      if (newState) {
        reminder.state = 'scheduling';
      }
      await _repository.update(reminder);
    } catch (e) {
      // Rollback memory if persistence fails
      reminder.isActive = originalState;
      reminder.scheduledAt = originalScheduledTime;
      reminder.state = originalDbState;
      _errorMessage = 'Failed to update reminder: $e';
      notifyListeners();
      return false;
    }

    // 3. Side-effect update (System Notification) - Step 2 of 2PC
    try {
      bool success = true;
      if (newState) {
        success = await _notificationService.scheduleReminder(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.notificationBody,
          scheduledTime: scheduledTime,
          recurrence: reminder.recurrenceType,
          recurrenceRule: reminder.recurrenceRule,
          payload: reminder.id,
        );

      } else {
        await _notificationService.cancelReminder(reminder.notificationId);
      }

      // Step 3 of 2PC: Flip state
      if (success) {
        reminder.state = 'active';
        reminder.failureReason = null;
      } else {
        reminder.state = 'failed';
        reminder.failureReason = 'Failed to schedule with OS';
      }
      _skipNextWatch = true;
      await _repository.update(reminder);

      _itemMap[reminder.id] = reminder;
      notifyListeners();
      return true;
    } catch (e) {
      // 4. Rollback Hive if Notification fails
      try {
        reminder.isActive = originalState;
        reminder.scheduledAt = originalScheduledTime;
        reminder.state = 'failed';
        reminder.failureReason = e.toString();
        _skipNextWatch = true;
        await _repository.update(reminder);
      } catch (_) {}

      _errorMessage = 'Failed to schedule notification: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsPaid(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (reminder.isRecurring && reminder.recurrenceType != 'none') {
        final nextTime = _computeNextOccurrence(
          reminder.scheduledAt,
          reminder.recurrenceRule,
          reminder.recurrenceType,
        );
        reminder.scheduledAt = nextTime;
        reminder.paymentStatus = 'pending';
        reminder.state = 'active';
        
        _skipNextWatch = true;
        await _repository.update(reminder);
        
        await _notificationService.cancelReminder(reminder.notificationId);
        await _notificationService.scheduleReminder(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.notificationBody,
          scheduledTime: nextTime,
          recurrence: reminder.recurrenceType,
          recurrenceRule: reminder.recurrenceRule,
          payload: reminder.id,
        );
      } else {
        reminder.isActive = false;
        reminder.paymentStatus = 'completed';
        
        _skipNextWatch = true;
        await _repository.update(reminder);
        await _notificationService.cancelReminder(reminder.notificationId);
      }
      await load();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to mark reminder as paid: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> remindLater(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final nextTime = DateTime.now().add(const Duration(hours: 6));
      reminder.scheduledAt = nextTime;
      reminder.paymentStatus = 'pending';
      
      _skipNextWatch = true;
      await _repository.update(reminder);
      
      await _notificationService.cancelReminder(reminder.notificationId);
      await _notificationService.scheduleReminder(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.notificationBody,
        scheduledTime: nextTime,
        recurrence: reminder.recurrenceType,
        recurrenceRule: reminder.recurrenceRule,
        payload: reminder.id,
      );
      
      await load();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to postpone reminder: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> rescheduleRecurringReminders() async {
    _errorMessage = null;
    try {
      final all = _itemMap.values.toList();
      final now = DateTime.now();
      for (var reminder in all) {
        if (reminder.isActive &&
            (reminder.recurrenceRule != null ||
                reminder.recurrenceType != 'none') &&
            reminder.scheduledAt.isBefore(now)) {
          final nextTime = _computeNextOccurrence(
            reminder.scheduledAt,
            reminder.recurrenceRule,
            reminder.recurrenceType,
          );
          reminder.scheduledAt = nextTime;
          _skipNextWatch = true;
          await _repository.update(reminder);
          await _notificationService.scheduleReminder(
            id: reminder.notificationId,
            title: reminder.title,
            body: reminder.notificationBody,
            scheduledTime: nextTime,
            recurrence: reminder.recurrenceType,
            recurrenceRule: reminder.recurrenceRule,
            payload: reminder.id,
          );

        }
      }
    } catch (e) {
      _errorMessage = 'Failed to reschedule reminders: $e';
    } finally {
      notifyListeners();
    }
  }

  DateTime _computeNextOccurrence(
    DateTime scheduledAt,
    RecurrenceRule? rule,
    String legacyType,
  ) {
    final now = DateTime.now();
    if (rule != null) {
      return rule.nextOccurrenceAfter(now, scheduledAt);
    } else {
      return RecurrenceRule.computeLegacyNextOccurrence(scheduledAt, legacyType, now);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
