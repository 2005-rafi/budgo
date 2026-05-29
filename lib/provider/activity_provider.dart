import 'package:expense/models/filter_criteria.dart';
import 'package:flutter/foundation.dart';
import 'package:expense/models/view_models/activity_view_model.dart';
import 'package:expense/services/activity_service.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/models/expense.dart';

class ActivityProvider extends ChangeNotifier {
  final ActivityService _service;
  final ExpensesProvider _expensesProvider;
  final IncomeProvider _incomeProvider;
  final FutureExpensesProvider _futureExpensesProvider;

  ActivityService get service => _service;
  bool get isLoading =>
      _expensesProvider.isLoading ||
      _incomeProvider.isLoading ||
      _futureExpensesProvider.isLoading;

  FilterCriteria _criteria = const FilterCriteria();
  FilterCriteria get criteria => _criteria;

  ActivityViewModel _viewModel = ActivityViewModel.empty();
  ActivityViewModel get viewModel => _viewModel;

  ActivityProvider({
    required ActivityService service,
    required ExpensesProvider expensesProvider,
    required IncomeProvider incomeProvider,
    required FutureExpensesProvider futureExpensesProvider,
  }) : _service = service,
       _expensesProvider = expensesProvider,
       _incomeProvider = incomeProvider,
       _futureExpensesProvider = futureExpensesProvider {
    _expensesProvider.addListener(_onDependencyChanged);
    _incomeProvider.addListener(_onDependencyChanged);
    _futureExpensesProvider.addListener(_onDependencyChanged);

    _update();
  }

  void setFilter(FilterCriteria criteria) {
    _criteria = criteria;
    _update();
  }

  void _onDependencyChanged() {
    _update();
  }

  int _firstIndexLessThanOrEqual(List<Expense> list, DateTime targetEnd) {
    int lo = 0;
    int hi = list.length;
    while (lo < hi) {
      int mid = lo + ((hi - lo) >> 1);
      if (!list[mid].date.isAfter(targetEnd)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  int _firstIndexLessThan(List<Expense> list, DateTime targetStart) {
    int lo = 0;
    int hi = list.length;
    while (lo < hi) {
      int mid = lo + ((hi - lo) >> 1);
      if (list[mid].date.isBefore(targetStart)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// Filters expenses locally without affecting the global ExpensesProvider state.
  List<Expense> filtered(List<Expense> expenses, FilterCriteria criteria) {
    if (expenses.isEmpty) return [];

    List<Expense> result = expenses;

    // 1. O(log N) Time filtering for Dates/DateRanges using Binary Search (since expenses is sorted descending)
    if (criteria.date != null) {
      final d = criteria.date!;
      final startOfDay = DateTime(d.year, d.month, d.day);
      final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);

      final startIdx = _firstIndexLessThanOrEqual(result, endOfDay);
      final endIdx = _firstIndexLessThan(result, startOfDay);
      result = result.sublist(startIdx, endIdx);
    } else if (criteria.dateRange != null) {
      final range = criteria.dateRange!;
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

      final startIdx = _firstIndexLessThanOrEqual(result, end);
      final endIdx = _firstIndexLessThan(result, start);
      result = result.sublist(startIdx, endIdx);
    } else if (criteria.categories.contains('This Week')) {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);

      final endIdx = _firstIndexLessThan(result, startOfWeek);
      result = result.sublist(0, endIdx);
    } else if (criteria.categories.contains('This Month')) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final endIdx = _firstIndexLessThan(result, startOfMonth);
      result = result.sublist(0, endIdx);
    } else if (criteria.categories.contains('Today')) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final startIdx = _firstIndexLessThanOrEqual(result, todayEnd);
      final endIdx = _firstIndexLessThan(result, todayStart);
      result = result.sublist(startIdx, endIdx);
    }

    // 2. O(K) Category / Query filtering on the sliced sublist
    final hasSearchQuery = criteria.searchQuery.isNotEmpty;
    
    // Extract row 1 category selection:
    final row1Categories = {'Rent', 'Food', 'Entertainment', 'Shopping', 'Travel', 'Lend/Borrow', 'Other'};
    final activeRow1Categories = criteria.categories.intersection(row1Categories);

    final hasCategoryFilter = activeRow1Categories.isNotEmpty;
    final mappedCategoryFilters = activeRow1Categories.map((c) => c == 'Lend/Borrow' ? 'Lend' : c).toSet();

    final hasHighSpend = criteria.categories.contains('High Spend');

    if (hasSearchQuery || hasCategoryFilter || hasHighSpend) {
      final query = hasSearchQuery ? criteria.searchQuery.toLowerCase() : '';

      List<Expense> filteredPass = [];
      for (final e in result) {
        if (hasCategoryFilter && !mappedCategoryFilters.contains(e.category)) {
          continue;
        }
        if (hasSearchQuery &&
            !e.productName.toLowerCase().contains(query) &&
            !e.category.toLowerCase().contains(query)) {
          continue;
        }
        filteredPass.add(e);
      }
      result = filteredPass;

      if (hasHighSpend && result.isNotEmpty) {
        final sortedAmounts = result.map((e) => e.amount).toList()..sort();
        final threshold = sortedAmounts[(sortedAmounts.length * 0.9).floor()];
        result = result.where((e) => e.amount >= threshold).toList();
      }
    }

    return result;
  }

  void _update() {
    final filteredExpenses = filtered(_expensesProvider.allExpenses, _criteria);

    final groups = _service.buildTimeline(
      filteredExpenses: filteredExpenses,
      allIncomes: _incomeProvider.items,
      allFutureExpenses: _futureExpensesProvider.items,
      criteria: _criteria,
    );

    _viewModel = ActivityViewModel(
      groups: groups,
      activeFilter: _criteria,
      hasMore: _expensesProvider.hasMore,
      isLoading:
          _expensesProvider.isLoading ||
          _incomeProvider.isLoading ||
          _futureExpensesProvider.isLoading,
      errorMessage:
          _expensesProvider.errorMessage ??
          _incomeProvider.errorMessage ??
          _futureExpensesProvider.errorMessage,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _expensesProvider.removeListener(_onDependencyChanged);
    _incomeProvider.removeListener(_onDependencyChanged);
    _futureExpensesProvider.removeListener(_onDependencyChanged);
    super.dispose();
  }
}
