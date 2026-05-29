import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:expense/core/app_constants.dart';
import 'package:expense/repositories/budget_repository.dart';
import 'package:expense/core/app_exception.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/services/alert_throttle_service.dart';
import 'package:expense/core/atomic_writer.dart';

import '../models/budget.dart';
import 'expenses_provider.dart';
import 'income_provider.dart';

/// Provider for managing state related to budgets and matching spending limits.
class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repository;
  final AlertThrottleService _alertService;
  Budget? _active;
  IncomeProvider? _income;
  ExpensesProvider? _expenses;
  StreamSubscription<void>? _boxSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  int _cachedSpent = 0; // Paise
  int _cachedRemaining = 0; // Paise
  int _lastSeenExpensesVersion = -1;

  Budget? get activeBudget => _active;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get spentInPeriod => _cachedSpent;
  int get cachedSpent => _cachedSpent;
  int get cachedRemaining => _cachedRemaining;

  BudgetProvider(this._repository, this._alertService);

  Future<void> initialize() async {
    _boxSubscription = _repository.watch().listen((_) => load());
    await load();
  }

  /// Injects [IncomeProvider] dependency.
  void attachIncome(IncomeProvider income) {
    _income = income;
    _recomputeKPIs();
    notifyListeners();
  }

  /// Injects [ExpensesProvider] dependency and triggers spent recomputation.
  void attachExpenses(ExpensesProvider expenses) {
    _expenses = expenses;
    if (expenses.dataVersion != _lastSeenExpensesVersion) {
      _lastSeenExpensesVersion = expenses.dataVersion;
      _recomputeKPIs();
      notifyListeners();
    }
  }

  /// Loads the active budget from repository and updates the spent cache.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _active = await _repository.getActiveBudget();
      _recomputeKPIs();
      _errorMessage = null;
    } on StorageException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recomputes spent total in active budget period and stores it.
  void _recomputeKPIs() {
    final b = _active;
    final exp = _expenses;
    if (b == null || exp == null) {
      _cachedSpent = 0;
      _cachedRemaining = 0;
    } else {
      // O(1)/O(days_in_month) lookup instead of full linear scan
      _cachedSpent = exp.totalForRange(b.startDate, b.endDate);
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

        unawaited(() async {
          try {
            await NotificationService().showImmediateNotification(
              id: 999999, // Reserved ID for budget alerts
              title: 'Budget Alert',
              body: "You've used $percentage% of your $periodName budget",
            );
            _alertService.markBudgetAlertFired();
          } catch (_) {}
        }());
      }
    }
  }

  /// Checks if an active budget exists with a positive limit.
  bool get hasBudget => _active != null && (_active!.limit > 0);

  /// Base budget set by user (stored in Hive).
  int get baseBudget => _active?.limit ?? 0;

  /// Confirmed income contribution (overall = all-time; weekly/monthly = within active range).
  int get confirmedIncomeContribution {
    final inc = _income;
    final b = _active;
    if (inc == null || b == null) return 0;

    if (b.period == AppConstants.kPeriodOverall) {
      return inc.totalConfirmed;
    }
    return inc.confirmedTotalBetween(b.startDate, b.endDate);
  }

  /// Combined total budget (base budget plus confirmed income contribution).
  int get budget => baseBudget + confirmedIncomeContribution;

  /// Sets an overall budget with boundaries spanning standard epoch dates.
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
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  /// Sets a weekly budget, rounding boundaries to include full calendar days.
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
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  /// Sets a monthly budget, rounding boundaries to include full calendar days.
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
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  /// Sets a daily budget, rounding boundaries to include full calendar days.
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
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  /// Sets a yearly budget, rounding boundaries to include full calendar days.
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
    );
    await AtomicWriter.instance.execute(() async {
      await _repository.saveActiveBudget(budget);
      _active = budget;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  /// Normalizes period end dates to be inclusive of the full calendar day (23:59:59.999).
  /// This ensures transactions made late on the final day are captured.
  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Clears/deletes the active budget.
  Future<void> clearBudget() async {
    await AtomicWriter.instance.execute(() async {
      await _repository.clearActiveBudget();
      _active = null;
      _recomputeKPIs();
    });
    notifyListeners();
  }

  /// Helper to return cached spending total.
  int spentInActivePeriod(ExpensesProvider expenses) {
    return _cachedSpent;
  }

  /// Helper to return remaining budget allowance.
  int remainingInActivePeriod(ExpensesProvider expenses) {
    return _cachedRemaining;
  }

  bool get isOverBudget => _cachedSpent >= budget;

  /// Helper to calculate current usage ratio (spent divided by budget).
  double usageRatio(ExpensesProvider expenses) {
    if (budget <= 0) return 0;
    return (_cachedSpent / budget).clamp(0.0, 1.0);
  }

  double get overBudgetRatio {
    if (budget <= 0) return 0;
    return _cachedSpent / budget;
  }

  /// Returns true if usage ratio is near the configured warning threshold.
  bool isNearLimit(ExpensesProvider expenses) {
    final b = _active;
    if (b == null) return false;
    final r = overBudgetRatio;
    return r >= b.warningThreshold && r < 1;
  }

  /// Returns true if spending has exceeded the total budget.
  bool isOverLimit(ExpensesProvider expenses) => overBudgetRatio >= 1;

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }
}
