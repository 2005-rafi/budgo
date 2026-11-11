import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderRepository _repository;
  final NotificationService _notificationService;
  final LinkedHashMap<String, Reminder> _itemMap =
      LinkedHashMap<String, Reminder>();
  StreamSubscription<void>? _subscription;
  String _activeWorkspaceId = AppConstants.kDefaultWorkspaceId;
  bool _isLoading = false;
  String? _errorMessage;
  Object? _lastError;
  bool _skipNextWatch = false;

  /// Optional resolver injected from root wiring so notifications inherit live
  /// workspace name, type label, and accent color across isolates/workloads.
  WorkspaceNotificationMeta? Function(String workspaceId)? workspaceResolver;

  ReminderProvider(this._repository, [NotificationService? notificationService])
    : _notificationService = notificationService ?? NotificationService();

  String _normalizeWorkspaceId(String workspaceId) =>
      workspaceId.isEmpty ? AppConstants.kDefaultWorkspaceId : workspaceId;

  String get activeWorkspaceId => _activeWorkspaceId;

  /// Reminders isolated strictly to the active workspace.
  UnmodifiableListView<Reminder> get items => UnmodifiableListView(
        _itemMap.values.where(
          (r) => _normalizeWorkspaceId(r.workspaceId) == _activeWorkspaceId,
        ),
      );

  /// Complete global reminder ledger across all workspaces (used for triage,
  /// notification dispatch, and optional "All Workspaces" view).
  UnmodifiableListView<Reminder> get allItems =>
      UnmodifiableListView(_itemMap.values);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Object? get lastError => _lastError;

  void _setError(Object error, [FeedbackOperation? op]) {
    _lastError = error;
    _errorMessage = AppErrorTranslator.translate(error, operation: op).title;
  }

  Future<void> initialize({String? initialWorkspaceId}) async {
    if (initialWorkspaceId != null && initialWorkspaceId.isNotEmpty) {
      _activeWorkspaceId = _normalizeWorkspaceId(initialWorkspaceId);
    }
    _subscription ??= _repository.watch().listen((_) {
      if (_skipNextWatch) {
        _skipNextWatch = false;
        return;
      }
      load();
    });
    await load();
  }

  void setActiveWorkspace(String workspaceId) {
    final normalized = _normalizeWorkspaceId(workspaceId);
    if (_activeWorkspaceId == normalized) return;
    _activeWorkspaceId = normalized;
    notifyListeners();
  }

  /// Re-schedules active pending OS alarms for [workspaceId] so renamed or
  /// restyled workspaces immediately update tray notifications.
  Future<void> syncWorkspaceNotificationStyles(String workspaceId) async {
    final normalized = _normalizeWorkspaceId(workspaceId);
    final now = DateTime.now();
    for (final reminder in _itemMap.values) {
      if (_normalizeWorkspaceId(reminder.workspaceId) != normalized) continue;
      if (!reminder.isActive) continue;
      final isFutureOrRecurring =
          reminder.isRecurring ||
          reminder.recurrenceType != 'none' ||
          reminder.scheduledAt.isAfter(now);
      if (!isFutureOrRecurring) continue;
      await _notificationService.cancelReminder(reminder.notificationId);
      await _scheduleForReminder(reminder, reminder.scheduledAt);
    }
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
      _lastError = null;
    } catch (e) {
      _setError(e);
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
          final success = await _scheduleForReminder(reminder, scheduledTime);


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

      if (!scheduleSuccess) {
        _setError(
          PermissionException(
            'Could not schedule OS notification reminder.',
            guidance:
                'Enable Notifications & Alarms permission for ${AppBrand.appName} in system Settings.',
          ),
        );
      }
      return scheduleSuccess;
    } catch (e) {
      _setError(e, FeedbackOperation.saveReminder);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateReminder(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    _lastError = null;
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
      if (reminder.isActive) {
        reminder.paymentStatus = 'pending';
      }
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
          final success = await _scheduleForReminder(reminder, scheduledTime);


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

      if (!scheduleSuccess) {
        _setError(
          PermissionException(
            'Could not schedule OS notification reminder.',
            guidance:
                'Enable Notifications & Alarms permission for ${AppBrand.appName} in system Settings.',
          ),
        );
      }
      return scheduleSuccess;
    } catch (e) {
      _setError(e, FeedbackOperation.saveReminder);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteReminder(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    _lastError = null;
    notifyListeners();
    try {
      await _notificationService.cancelReminder(reminder.notificationId);
      _skipNextWatch = true;
      await _repository.delete(reminder);
      _itemMap.remove(reminder.id);
      return true;
    } catch (e) {
      _setError(e, FeedbackOperation.deleteReminder);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleActive(Reminder reminder) async {
    _errorMessage = null;
    _lastError = null;
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
        _setError(
          ValidationException(
            'This one-time reminder is already in the past.',
            guidance: 'Edit the reminder to select an upcoming date and time.',
          ),
        );
        notifyListeners();
        return false;
      }
    }

    // 2. Persistent update (Hive) - Step 1 of 2PC
    try {
      _skipNextWatch = true;
      reminder.isActive = newState;
      reminder.scheduledAt = scheduledTime;
      if (newState) {
        reminder.paymentStatus = 'pending';
        reminder.state = 'scheduling';
      }
      await _repository.update(reminder);
    } catch (e) {
      // Rollback memory if persistence fails
      reminder.isActive = originalState;
      reminder.scheduledAt = originalScheduledTime;
      reminder.state = originalDbState;
      _setError(e, FeedbackOperation.toggleReminder);
      notifyListeners();
      return false;
    }

    // 3. Side-effect update (System Notification) - Step 2 of 2PC
    try {
      bool success = true;
      if (newState) {
        success = await _scheduleForReminder(reminder, scheduledTime);
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
        _setError(
          PermissionException(
            'Notification permission is disabled.',
            guidance: 'Allow Notifications & Alarms in system Settings to activate alerts.',
          ),
        );
      }
      _skipNextWatch = true;
      await _repository.update(reminder);

      _itemMap[reminder.id] = reminder;
      notifyListeners();
      return success;
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

      _setError(e, FeedbackOperation.toggleReminder);
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
        await _scheduleForReminder(reminder, nextTime);
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
      _setError(e, FeedbackOperation.toggleReminder);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggles the completion state of a reminder:
  /// - If already completed, reopens it as active and pending.
  /// - If pending/active, marks it as paid.
  Future<bool> togglePaymentStatus(Reminder reminder) async {
    if (reminder.paymentStatus == 'completed') {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      try {
        reminder.paymentStatus = 'pending';
        reminder.isActive = true;
        reminder.state = 'active';
        _skipNextWatch = true;
        await _repository.update(reminder);
        await _scheduleForReminder(reminder, reminder.scheduledAt);
        await load();
        return true;
      } catch (e) {
        _setError(e, FeedbackOperation.toggleReminder);
        return false;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      return markAsPaid(reminder);
    }
  }

  /// Skips the current notification occurrence cleanly:
  /// - Recurring: jumps strictly past max(now, scheduledAt) to the next cycle.
  /// - One-time: marks skipped and cancels OS alarm without deleting the entry.
  Future<bool> skipReminder(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    _lastError = null;
    notifyListeners();
    try {
      await _notificationService.cancelReminder(reminder.notificationId);
      if (reminder.isRecurring && reminder.recurrenceType != 'none') {
        final nextTime = ReminderNotificationFormatter.computeNextCycleAfterSkip(
          reminder,
          DateTime.now(),
        );
        reminder.scheduledAt = nextTime;
        reminder.isActive = true;
        reminder.paymentStatus = 'pending';
        reminder.state = 'active';
        reminder.failureReason = null;

        _skipNextWatch = true;
        await _repository.update(reminder);
        await _scheduleForReminder(reminder, nextTime);
      } else {
        reminder.isActive = false;
        reminder.paymentStatus = 'skipped';
        reminder.state = 'active';
        reminder.failureReason = null;

        _skipNextWatch = true;
        await _repository.update(reminder);
      }
      await load();
      return true;
    } catch (e) {
      _setError(e, FeedbackOperation.toggleReminder);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancels an active reminder directly from a notification action button.
  Future<bool> cancelReminderFromNotification(Reminder reminder) async {
    _isLoading = true;
    _errorMessage = null;
    _lastError = null;
    notifyListeners();
    try {
      await _notificationService.cancelReminder(reminder.notificationId);
      reminder.isActive = false;
      reminder.paymentStatus = 'cancelled';
      reminder.state = 'active';
      reminder.failureReason = null;

      _skipNextWatch = true;
      await _repository.update(reminder);
      await load();
      return true;
    } catch (e) {
      _setError(e, FeedbackOperation.toggleReminder);
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
      reminder.isActive = true;
      reminder.state = 'active';
      
      _skipNextWatch = true;
      await _repository.update(reminder);
      
      await _notificationService.cancelReminder(reminder.notificationId);
      await _scheduleForReminder(reminder, nextTime);
      
      await load();
      return true;
    } catch (e) {
      _setError(e, FeedbackOperation.toggleReminder);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rescheduleRecurringReminders() async {
    _errorMessage = null;
    _lastError = null;
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
          await _scheduleForReminder(reminder, nextTime);
        }
      }
    } catch (e) {
      _setError(e, FeedbackOperation.saveReminder);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _scheduleForReminder(
    Reminder reminder,
    DateTime scheduledTime,
  ) {
    final wsId = _normalizeWorkspaceId(reminder.workspaceId);
    final workspaceMeta = workspaceResolver?.call(wsId);
    return _notificationService.scheduleReminder(
      id: reminder.notificationId,
      title: reminder.title,
      body: reminder.notificationBody,
      scheduledTime: scheduledTime,
      recurrence: reminder.recurrenceType,
      recurrenceRule: reminder.recurrenceRule,
      payload: reminder.id,
      amount: reminder.amount,
      category: reminder.category,
      notes: reminder.notes,
      workspace: workspaceMeta,
    );
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
