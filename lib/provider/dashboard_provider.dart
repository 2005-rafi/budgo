import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:expense/models/view_models/dashboard_view_model.dart';
import 'package:expense/services/dashboard_service.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/provider/budget_provider.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;
  final ExpensesProvider _expensesProvider;
  final IncomeProvider _incomeProvider;
  final FutureExpensesProvider _futureExpensesProvider;
  final BudgetProvider _budgetProvider;
  Timer? _debounce;

  DashboardViewModel _viewModel = DashboardViewModel.empty();
  DashboardViewModel get viewModel => _viewModel;

  DashboardProvider({
    required DashboardService service,
    required ExpensesProvider expensesProvider,
    required IncomeProvider incomeProvider,
    required FutureExpensesProvider futureExpensesProvider,
    required BudgetProvider budgetProvider,
  }) : _service = service,
       _expensesProvider = expensesProvider,
       _incomeProvider = incomeProvider,
       _futureExpensesProvider = futureExpensesProvider,
       _budgetProvider = budgetProvider {
    _expensesProvider.addListener(_onDependencyChanged);
    _incomeProvider.addListener(_onDependencyChanged);
    _futureExpensesProvider.addListener(_onDependencyChanged);
    _budgetProvider.addListener(_onDependencyChanged);

    _update();
  }

  void _onDependencyChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 16), () {
      _update();
    });
  }

  Future<void> _update() async {
    final limit = _budgetProvider.activeBudget?.limit;
    final spent = _budgetProvider.cachedSpent;
    final ratio = (limit != null && limit > 0) ? spent / limit : null;

    _viewModel = await _service.buildViewModel(
      DateTime.now(),
      incomes: _incomeProvider.items,
      futureExpenses: _futureExpensesProvider.items,
      budgetLimit: limit,
      spentInActivePeriod: spent,
      budgetUsageRatio: ratio,
      isLoading:
          _expensesProvider.isLoading ||
          _incomeProvider.isLoading ||
          _futureExpensesProvider.isLoading,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _expensesProvider.removeListener(_onDependencyChanged);
    _incomeProvider.removeListener(_onDependencyChanged);
    _futureExpensesProvider.removeListener(_onDependencyChanged);
    _budgetProvider.removeListener(_onDependencyChanged);
    super.dispose();
  }
}
