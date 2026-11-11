import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/view_models/dashboard_view_model.dart';
import 'package:expense/services/dashboard_service.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/future_expenses_provider.dart';
import 'package:expense/providers/budget_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/services/safe_to_spend_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;
  final ExpensesProvider _expensesProvider;
  final IncomeProvider _incomeProvider;
  final FutureExpensesProvider _futureExpensesProvider;
  final BudgetProvider _budgetProvider;
  final AppPreferencesProvider _appPreferencesProvider;
  final AccountProvider? _accountProvider;
  final TransferProvider? _transferProvider;
  final WorkspaceProvider? _workspaceProvider;
  final SavingsVaultProvider? _savingsVaultProvider;
  final ReminderProvider? _reminderProvider;
  Timer? _debounce;

  DashboardViewModel _viewModel = DashboardViewModel.empty();
  DashboardViewModel get viewModel => _viewModel;

  DashboardProvider({
    required DashboardService service,
    required ExpensesProvider expensesProvider,
    required IncomeProvider incomeProvider,
    required FutureExpensesProvider futureExpensesProvider,
    required BudgetProvider budgetProvider,
    required AppPreferencesProvider appPreferencesProvider,
    AccountProvider? accountProvider,
    TransferProvider? transferProvider,
    WorkspaceProvider? workspaceProvider,
    SavingsVaultProvider? savingsVaultProvider,
    ReminderProvider? reminderProvider,
  }) : _service = service,
       _expensesProvider = expensesProvider,
       _incomeProvider = incomeProvider,
       _futureExpensesProvider = futureExpensesProvider,
       _budgetProvider = budgetProvider,
       _appPreferencesProvider = appPreferencesProvider,
       _accountProvider = accountProvider,
       _transferProvider = transferProvider,
       _workspaceProvider = workspaceProvider,
       _savingsVaultProvider = savingsVaultProvider,
       _reminderProvider = reminderProvider {
    _expensesProvider.addListener(_onDependencyChanged);
    _incomeProvider.addListener(_onDependencyChanged);
    _futureExpensesProvider.addListener(_onDependencyChanged);
    _budgetProvider.addListener(_onDependencyChanged);
    _appPreferencesProvider.addListener(_onDependencyChanged);
    _accountProvider?.addListener(_onDependencyChanged);
    _transferProvider?.addListener(_onDependencyChanged);
    _workspaceProvider?.addListener(_onDependencyChanged);
    _savingsVaultProvider?.addListener(_onDependencyChanged);
    _reminderProvider?.addListener(_onDependencyChanged);

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

    final activeWsId = _workspaceProvider?.activeWorkspaceId ?? AppConstants.kDefaultWorkspaceId;
    final totalBalance = _accountProvider?.activeWorkspaceBalancePaise ??
        (_workspaceProvider?.activeWorkspace?.initialBalance ?? 0);

    final transfers = _transferProvider?.transfers ?? [];
    final accountNames = <String, String>{
      for (final a in _accountProvider?.allAccounts ?? const []) a.id: a.name,
    };
    final workspaceNames = <String, String>{
      for (final w in _workspaceProvider?.workspaces ?? const []) w.id: w.name,
    };

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final totalAllocatedInVaults = _savingsVaultProvider?.totalAllocatedPaise ?? 0;
    final totalLiquidAssets = _accountProvider?.activeWorkspaceLiquidPaise ?? 0;
    final unallocatedLiquid = (totalLiquidAssets - totalAllocatedInVaults).clamp(0, 1 << 62);

    final confirmedIncomeMonth = _incomeProvider.items
        .where((i) => i.isConfirmed && i.date.year == now.year && i.date.month == now.month)
        .fold<int>(0, (sum, i) => sum + i.amount);

    final pendingRemindersMonthPaise =
        (_reminderProvider?.allItems ?? const <Reminder>[])
            .where((r) {
          final rWsId = r.workspaceId.isEmpty
              ? AppConstants.kDefaultWorkspaceId
              : r.workspaceId;
          return rWsId == activeWsId &&
              r.isActive &&
              r.paymentStatus != 'completed' &&
              r.paymentStatus != 'skipped' &&
              r.paymentStatus != 'cancelled' &&
              r.amount != null &&
              r.amount! > 0 &&
              !r.scheduledAt.isBefore(startOfToday) &&
              !r.scheduledAt.isAfter(endOfMonth);
        })
        .fold<int>(0, (sum, r) => sum + r.amount!);

    final effectiveBudgetLimit = _appPreferencesProvider.isBudgetModeEnabled ? limit : null;

    final safeToSpend = SafeToSpendService.compute(
      now: now,
      budgetLimitPaise: effectiveBudgetLimit,
      spentThisMonthPaise: spent,
      liquidUnallocatedPaise: unallocatedLiquid,
      confirmedIncomeThisMonthPaise: confirmedIncomeMonth,
      pendingRemindersPaise: pendingRemindersMonthPaise,
      totalVaultsAllocatedPaise: totalAllocatedInVaults,
    );

    _viewModel = await _service.buildViewModel(
      now,
      incomes: _incomeProvider.items,
      futureExpenses: _futureExpensesProvider.items,
      transfers: transfers,
      activeWorkspaceId: activeWsId,
      totalBalance: totalBalance,
      safeToSpend: safeToSpend,
      totalVaultsAllocated: totalAllocatedInVaults,
      accountNames: accountNames,
      workspaceNames: workspaceNames,
      budgetLimit: limit,
      spentInActivePeriod: spent,
      budgetUsageRatio: ratio,
      isMonthlyRefreshEnabled: _appPreferencesProvider.isMonthlyRefreshEnabled,
      isLoading:
          _expensesProvider.isLoading ||
          _incomeProvider.isLoading ||
          _futureExpensesProvider.isLoading ||
          (_accountProvider?.isLoading ?? false) ||
          (_transferProvider?.isLoading ?? false) ||
          (_savingsVaultProvider?.isLoading ?? false),
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
    _appPreferencesProvider.removeListener(_onDependencyChanged);
    _accountProvider?.removeListener(_onDependencyChanged);
    _transferProvider?.removeListener(_onDependencyChanged);
    _workspaceProvider?.removeListener(_onDependencyChanged);
    _savingsVaultProvider?.removeListener(_onDependencyChanged);
    _reminderProvider?.removeListener(_onDependencyChanged);
    super.dispose();
  }
}
