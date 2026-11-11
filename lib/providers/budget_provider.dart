import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/repositories/budget_repository.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/services/alert_throttle_service.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/storage/app_state_box.dart';

import 'package:expense/models/budget.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';

/// Workspace-isolated Provider for managing budgets and spending limits.
class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repository;
  final AlertThrottleService _alertService;
  Budget? _active;
  IncomeProvider? _income;
  ExpensesProvider? _expenses;
  StreamSubscription<void>? _boxSubscription;

  String _activeWorkspaceId = AppStateBox.activeWorkspaceId;
  bool _isLoading = false;
  String? _errorMessage;
  int _cachedSpent = 0; // Paise
  int _cachedRemaining = 0; // Paise
  int _lastSeenExpensesVersion = -1;
  int _lastSeenIncomeTotal = -1;
  String _lastSeenIncomeWs = '';

  Budget? get activeBudget => _active;
  String get activeWorkspaceId => _activeWorkspaceId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get spentInPeriod => _cachedSpent;
  int get cachedSpent => _cachedSpent;
  int get cachedRemaining => _cachedRemaining;

  BudgetProvider(this._repository, this._alertService);

  String _normalizeWs(String workspaceId) =>
      workspaceId.isEmpty ? AppConstants.kDefaultWorkspaceId : workspaceId;

  Future<void> initialize({String? initialWorkspaceId}) async {
    if (initialWorkspaceId != null && initialWorkspaceId.isNotEmpty) {
      _activeWorkspaceId = _normalizeWs(initialWorkspaceId);
    }
    _boxSubscription ??= _repository.watch().listen((_) => load());
    await load();
  }

  /// Switches the active workspace scope cleanly and loads that workspace's isolated budget.
  Future<void> setActiveWorkspace(String workspaceId) async {
    final norm = _normalizeWs(workspaceId);
    if (_activeWorkspaceId == norm) return;
    _activeWorkspaceId = norm;
    await load();
  }

  void _onIncomeChanged() {
    final inc = _income;
    if (inc == null) return;
    if (inc.totalConfirmed != _lastSeenIncomeTotal ||
        inc.activeWorkspaceId != _lastSeenIncomeWs) {
      _lastSeenIncomeTotal = inc.totalConfirmed;
      _lastSeenIncomeWs = inc.activeWorkspaceId;
      _recomputeKPIs();
      notifyListeners();
    }
  }

  void _onExpensesChanged() {
    final exp = _expenses;
    if (exp == null) return;
    if (exp.dataVersion != _lastSeenExpensesVersion) {
      _lastSeenExpensesVersion = exp.dataVersion;
      _recomputeKPIs();
      notifyListeners();
    }
  }

  /// Injects [IncomeProvider] dependency and subscribes to income changes.
  void attachIncome(IncomeProvider income) {
    final changedInstance = !identical(_income, income);
    if (changedInstance) {
      _income?.removeListener(_onIncomeChanged);
      _income = income;
      income.addListener(_onIncomeChanged);
    }
    if (changedInstance ||
        income.totalConfirmed != _lastSeenIncomeTotal ||
        income.activeWorkspaceId != _lastSeenIncomeWs) {
      _lastSeenIncomeTotal = income.totalConfirmed;
      _lastSeenIncomeWs = income.activeWorkspaceId;
      _recomputeKPIs();
      notifyListeners();
    }
  }

  /// Injects [ExpensesProvider] dependency and triggers workspace-isolated spent recomputation.
  void attachExpenses(ExpensesProvider expenses) {
    final changedInstance = !identical(_expenses, expenses);
    if (changedInstance) {
      _expenses?.removeListener(_onExpensesChanged);
      _expenses = expenses;
      expenses.addListener(_onExpensesChanged);
    }
    if (changedInstance || expenses.dataVersion != _lastSeenExpensesVersion) {
      _lastSeenExpensesVersion = expenses.dataVersion;
      _recomputeKPIs();
      notifyListeners();
    }
  }

  /// Loads the active workspace's budget from repository and updates the spent cache.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _active = await _repository.getBudgetForWorkspace(_activeWorkspaceId);
      _recomputeKPIs();
      _errorMessage = null;
    } on StorageException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = AppErrorTranslator.translate(e).title;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recomputes spent total in active workspace & active budget period.
  void _recomputeKPIs() {
    final b = _active;
    final exp = _expenses;
    if (b == null || exp == null) {
      _cachedSpent = 0;
      _cachedRemaining = 0;
    } else {
      // Strictly query the active workspace's partition in ReportsDataService
      _cachedSpent = exp.totalForRange(
        b.startDate,
        b.endDate,
        workspaceId: _activeWorkspaceId,
      );
      _cachedRemaining = budget - _cachedSpent;
    }
    _checkBudgetAlert();
  }

  void _checkBudgetAlert() {
    final b = _active;
    final exp = _expenses;
    if (b == null || exp == null) return;

    final spent = _cachedSpent;
    final limit = budget;
    if (limit <= 0) return;

    final spentRatio = spent / limit;
    if (spentRatio >= AppConstants.kBudgetWarningThreshold) {
      if (_alertService.shouldFireBudgetAlert()) {
        final percentage = (spentRatio * 100).toStringAsFixed(0);
        final periodName = b.period;
        final notifId = 999900 + (_activeWorkspaceId.hashCode & 0xFF);

        unawaited(() async {
          try {
            await NotificationService().showImmediateNotification(
              id: notifId,
              title: 'Budget Alert',
              body: "You've used $percentage% of your $periodName budget",
            );
            _alertService.markBudgetAlertFired();
          } catch (_) {}
        }());
      }
    }
  }

  bool get hasBudget => _active != null && (_active!.limit > 0);

  int get baseBudget => _active?.limit ?? 0;

  /// Confirmed income contribution strictly scoped to the active workspace.
  int get confirmedIncomeContribution {
    final inc = _income;
    final b = _active;
    if (inc == null || b == null) return 0;

    if (b.period == AppConstants.kPeriodOverall) {
      return inc.totalConfirmed;
    }
    return inc.confirmedTotalBetween(
      b.startDate,
      b.endDate,
      workspaceId: _activeWorkspaceId,
    );
  }

  int get budget => baseBudget + confirmedIncomeContribution;

  Future<void> setBudget(int limit) async {
    final now = DateTime.now();
    final budget = Budget(
      id: 'overall_${now.millisecondsSinceEpoch}',
      limit: limit,
      period: AppConstants.kPeriodOverall,
      startDate: DateTime(2000, 1, 1),
      endDate: _endOfDay(DateTime(2100, 12, 31)),
      isActive: true,
      warningThreshold: AppConstants.kBudgetWarningThreshold,
      workspaceId: _activeWorkspaceId,
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  Future<void> setWeeklyBudget({
    required String id,
    required int limit,
    required DateTime weekStart,
    double warningThreshold = AppConstants.kBudgetWarningThreshold,
  }) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = _endOfDay(start.add(const Duration(days: 6)));
    final budget = Budget(
      id: id,
      limit: limit,
      period: AppConstants.kPeriodWeekly,
      startDate: start,
      endDate: end,
      isActive: true,
      warningThreshold: warningThreshold,
      workspaceId: _activeWorkspaceId,
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  Future<void> setMonthlyBudget({
    required String id,
    required int limit,
    required DateTime anyDayInMonth,
    double warningThreshold = AppConstants.kBudgetWarningThreshold,
  }) async {
    final start = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final nextMonth = (anyDayInMonth.month == 12)
        ? DateTime(anyDayInMonth.year + 1, 1, 1)
        : DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);
    final end = _endOfDay(nextMonth.subtract(const Duration(days: 1)));

    final budget = Budget(
      id: id,
      limit: limit,
      period: AppConstants.kPeriodMonthly,
      startDate: start,
      endDate: end,
      isActive: true,
      warningThreshold: warningThreshold,
      workspaceId: _activeWorkspaceId,
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  Future<void> setDailyBudget({
    required String id,
    required int limit,
    required DateTime date,
    double warningThreshold = AppConstants.kBudgetWarningThreshold,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = _endOfDay(start);

    final budget = Budget(
      id: id,
      limit: limit,
      period: AppConstants.kPeriodDaily,
      startDate: start,
      endDate: end,
      isActive: true,
      warningThreshold: warningThreshold,
      workspaceId: _activeWorkspaceId,
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  Future<void> setYearlyBudget({
    required String id,
    required int limit,
    required DateTime anyDayInYear,
    double warningThreshold = AppConstants.kBudgetWarningThreshold,
  }) async {
    final start = DateTime(anyDayInYear.year, 1, 1);
    final end = _endOfDay(DateTime(anyDayInYear.year, 12, 31));

    final budget = Budget(
      id: id,
      limit: limit,
      period: AppConstants.kPeriodYearly,
      startDate: start,
      endDate: end,
      isActive: true,
      warningThreshold: warningThreshold,
      workspaceId: _activeWorkspaceId,
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  Future<void> clearBudget() async {
    await AtomicWriter.instance.execute(() async {
      await _repository.clearBudgetForWorkspace(_activeWorkspaceId);
      _active = null;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  int spentInActivePeriod(ExpensesProvider expenses) => _cachedSpent;

  int remainingInActivePeriod(ExpensesProvider expenses) => _cachedRemaining;

  bool get isOverBudget => _cachedSpent >= budget;

  double usageRatio(ExpensesProvider expenses) {
    if (budget <= 0) return 0;
    return (_cachedSpent / budget).clamp(0.0, 1.0);
  }

  double get overBudgetRatio {
    if (budget <= 0) return 0;
    return _cachedSpent / budget;
  }

  bool isNearLimit(ExpensesProvider expenses) {
    final b = _active;
    if (b == null) return false;
    final r = overBudgetRatio;
    return r >= b.warningThreshold && r < 1;
  }

  bool isOverLimit(ExpensesProvider expenses) => overBudgetRatio >= 1;

  @override
  void dispose() {
    _boxSubscription?.cancel();
    _expenses?.removeListener(_onExpensesChanged);
    _income?.removeListener(_onIncomeChanged);
    super.dispose();
  }
}
