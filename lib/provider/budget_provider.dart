import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/budget.dart';
import 'expenses_provider.dart';
import 'finance_boxes.dart';
import 'income_provider.dart';

class BudgetProvider extends ChangeNotifier {
  Budget? _active;
  IncomeProvider? _income;
  StreamSubscription<BoxEvent>? _sub;

  Budget? get activeBudget => _active;

  BudgetProvider() {
    _sub = FinanceBoxes.budgets.watch().listen((_) => load());
  }

  // Inject IncomeProvider using ChangeNotifierProxyProvider (see main.dart section)
  void attachIncome(IncomeProvider income) {
    _income = income;
    notifyListeners();
  }

  Future<void> load() async {
    _active = FinanceBoxes.budgets.get(FinanceBoxes.activeBudgetKey);
    notifyListeners();
  }

  bool get hasBudget => _active != null && (_active!.limit > 0);

  /// Base budget set by user (stored in Hive).
  double get baseBudget => _active?.limit ?? 0.0;

  /// Confirmed income contribution (overall = all-time; weekly/monthly = within active range).
  double get confirmedIncomeContribution {
    final inc = _income;
    final b = _active;
    if (inc == null || b == null) return 0.0;

    if (b.period == 'overall') {
      return inc.totalConfirmed;
    }
    return inc.confirmedTotalBetween(b.startDate, b.endDate);
  }

  /// This is what Home screen should show as "Budget".
  double get budget => baseBudget + confirmedIncomeContribution;

  /// Compatibility method (your Home budget dialog uses this).
  Future<void> setBudget(double limit) async {
    final now = DateTime.now();
    final budget = Budget(
      id: 'overall_${now.millisecondsSinceEpoch}',
      limit: limit,
      period: 'overall',
      startDate: DateTime(2000, 1, 1),
      endDate: DateTime(2100, 12, 31, 23, 59, 59),
      isActive: true,
      warningThreshold: 0.9,
    );
    await FinanceBoxes.budgets.put(FinanceBoxes.activeBudgetKey, budget);
    await load();
  }

  Future<void> setWeeklyBudget({
    required String id,
    required double limit,
    required DateTime weekStart,
    double warningThreshold = 0.9,
  }) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final budget = Budget(
      id: id,
      limit: limit,
      period: 'weekly',
      startDate: start,
      endDate: end,
      isActive: true,
      warningThreshold: warningThreshold,
    );
    await FinanceBoxes.budgets.put(FinanceBoxes.activeBudgetKey, budget);
    await load();
  }

  Future<void> setMonthlyBudget({
    required String id,
    required double limit,
    required DateTime anyDayInMonth,
    double warningThreshold = 0.9,
  }) async {
    final start = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final nextMonth = (anyDayInMonth.month == 12)
        ? DateTime(anyDayInMonth.year + 1, 1, 1)
        : DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);
    final end = nextMonth.subtract(const Duration(seconds: 1));

    final budget = Budget(
      id: id,
      limit: limit,
      period: 'monthly',
      startDate: start,
      endDate: end,
      isActive: true,
      warningThreshold: warningThreshold,
    );
    await FinanceBoxes.budgets.put(FinanceBoxes.activeBudgetKey, budget);
    await load();
  }

  Future<void> clearBudget() async {
    await FinanceBoxes.budgets.delete(FinanceBoxes.activeBudgetKey);
    await load();
  }

  double spentInActivePeriod(ExpensesProvider expenses) {
    final b = _active;
    if (b == null) return 0;
    return expenses.totalBetween(b.startDate, b.endDate);
  }

  double remainingInActivePeriod(ExpensesProvider expenses) {
    final b = _active;
    if (b == null) return 0;
    return budget - spentInActivePeriod(expenses);
  }

  double usageRatio(ExpensesProvider expenses) {
    final b = _active;
    if (b == null || budget <= 0) return 0;
    return (spentInActivePeriod(expenses) / budget).clamp(0, 10);
  }

  bool isNearLimit(ExpensesProvider expenses) {
    final b = _active;
    if (b == null) return false;
    final r = usageRatio(expenses);
    return r >= b.warningThreshold && r < 1;
  }

  bool isOverLimit(ExpensesProvider expenses) => usageRatio(expenses) >= 1;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
