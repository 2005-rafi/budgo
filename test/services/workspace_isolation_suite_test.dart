import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/job_record.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/providers/activity_provider.dart';
import 'package:expense/providers/budget_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/future_expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/reports_provider.dart';
import 'package:expense/repositories/budget_repository.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/repositories/future_expense_repository.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/services/activity_service.dart';
import 'package:expense/services/alert_throttle_service.dart';
import 'package:expense/services/dashboard_service.dart';
import 'package:expense/services/insight_engine_service.dart';
import 'package:expense/services/reports_data_service.dart';

class _MemReminderRepo implements ReminderRepository {
  final List<Reminder> items = [];
  @override
  Future<void> add(Reminder r) async => items.add(r);
  @override
  Future<void> delete(Reminder r) async => items.removeWhere((x) => x.id == r.id);
  @override
  Future<List<Reminder>> getAll() async => List.of(items);
  @override
  Future<void> toggleActive(Reminder r) async => r.isActive = !r.isActive;
  @override
  Future<void> update(Reminder r) async {}
  @override
  Stream<void> watch() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<Expense> expBox;
  late Box<Income> incBox;
  late Box<Budget> budgetBox;
  late Box<FutureExpense> futBox;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ws_iso_suite');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(ExpenseAdapter().typeId)) Hive.registerAdapter(ExpenseAdapter());
    if (!Hive.isAdapterRegistered(IncomeAdapter().typeId)) Hive.registerAdapter(IncomeAdapter());
    if (!Hive.isAdapterRegistered(FutureExpenseAdapter().typeId)) Hive.registerAdapter(FutureExpenseAdapter());
    if (!Hive.isAdapterRegistered(BudgetAdapter().typeId)) Hive.registerAdapter(BudgetAdapter());
    if (!Hive.isAdapterRegistered(ReminderAdapter().typeId)) Hive.registerAdapter(ReminderAdapter());
    if (!Hive.isAdapterRegistered(JobRecordAdapter().typeId)) Hive.registerAdapter(JobRecordAdapter());

    await Hive.openBox(AppStateBox.boxName);
    await Hive.openBox<JobRecord>(AppConstants.kJobsBox);
    expBox = await Hive.openBox<Expense>(AppConstants.kExpensesBox);
    incBox = await Hive.openBox<Income>(AppConstants.kIncomesBox);
    budgetBox = await Hive.openBox<Budget>(AppConstants.kBudgetsBox);
    futBox = await Hive.openBox<FutureExpense>(AppConstants.kFutureExpensesBox);

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('ReportsDataService, ReportsProvider, ExpensesProvider & ActivityProvider strictly isolate workspaces', () async {
    final reportsService = ReportsDataService();
    final expRepo = HiveExpenseRepository(expBox);
    final incRepo = HiveIncomeRepository(incBox);
    final futRepo = HiveFutureExpenseRepository(futBox);

    final expProvider = ExpensesProvider(expRepo, reportsService);
    final incProvider = IncomeProvider(incRepo);
    final futProvider = FutureExpensesProvider(futRepo, expRepo);
    final reportsProvider = ReportsProvider(service: reportsService);
    final activityProvider = ActivityProvider(
      service: ActivityService(),
      expensesProvider: expProvider,
      incomeProvider: incProvider,
      futureExpensesProvider: futProvider,
    );

    final now = DateTime.now();
    await expProvider.addExpense(Expense(
      productName: 'Personal Coffee',
      amount: 15000, // ₹150
      category: 'Food',
      date: now,
      paymentMethod: 'UPI',
      workspaceId: AppConstants.kDefaultWorkspaceId,
    ));
    await expProvider.addExpense(Expense(
      productName: 'Business Flight',
      amount: 500000, // ₹5,000
      category: 'Travel',
      date: now,
      paymentMethod: 'Bank',
      workspaceId: 'ws_work',
    ));

    // Confirm initial Personal scope has ZERO Business leakage
    reportsProvider.initialize(expProvider.allExpenses, activeWorkspaceId: AppConstants.kDefaultWorkspaceId);
    await Future.delayed(const Duration(milliseconds: 80));

    expect(expProvider.totalSpent, 15000);
    expect(expProvider.currentMonthDailyTotals.values.fold<int>(0, (a, b) => a + b), 15000);
    expect(reportsProvider.viewModel?.totalSpent, 15000);
    expect(reportsProvider.viewModel?.transactionCount, 1);
    expect(activityProvider.filtered(expProvider.activeWorkspaceExpenses, const FilterCriteria()).length, 1);

    // Switch active workspace -> Business (ws_work)
    expProvider.setActiveWorkspace('ws_work');
    reportsProvider.setActiveWorkspace('ws_work');
    await Future.delayed(const Duration(milliseconds: 80));

    expect(expProvider.totalSpent, 500000);
    expect(reportsProvider.viewModel?.totalSpent, 500000);
    expect(reportsProvider.viewModel?.topCategory, 'Travel');

    // Filter Reports by 'Bank' (previously missing in UI!)
    reportsProvider.setPaymentMethod('Bank');
    expect(reportsProvider.viewModel?.transactionCount, 1);
    expect(reportsProvider.viewModel?.totalSpent, 500000);

    // Mutate non-active workspace (add Personal expense while Work is active)
    await expProvider.addExpense(Expense(
      productName: 'Personal Dinner',
      amount: 45000,
      category: 'Food',
      date: now,
      paymentMethod: 'Cash',
      workspaceId: AppConstants.kDefaultWorkspaceId,
    ));

    // Active workspace ('ws_work') must stay completely unaffected!
    expect(expProvider.totalSpent, 500000);
    expect(reportsProvider.viewModel?.totalSpent, 500000);

    // Switch back to Personal -> sees both Personal items (15k + 45k = 60k)
    reportsProvider.setPaymentMethod(null);
    expProvider.setActiveWorkspace(AppConstants.kDefaultWorkspaceId);
    reportsProvider.setActiveWorkspace(AppConstants.kDefaultWorkspaceId);
    await Future.delayed(const Duration(milliseconds: 80));

    expect(expProvider.totalSpent, 60000);
    expect(reportsProvider.viewModel?.totalSpent, 60000);
    expect(reportsProvider.viewModel?.transactionCount, 2);
  });

  test('Budgets, Incomes, Planned Wishlist, Insights & Dashboard respect strict per-workspace isolation', () async {
    final reportsService = ReportsDataService();
    final expRepo = HiveExpenseRepository(expBox);
    final incRepo = HiveIncomeRepository(incBox);
    final budgetRepo = HiveBudgetRepository(budgetBox);
    final futRepo = HiveFutureExpenseRepository(futBox);
    final remRepo = _MemReminderRepo();

    // Seed reminder strictly in 'ws_work'
    remRepo.items.add(Reminder(
      id: 'rem_work_only',
      title: 'Server Renewal',
      scheduledAt: DateTime.now().add(const Duration(hours: 12)),
      workspaceId: 'ws_work',
    ));

    final expProvider = ExpensesProvider(expRepo, reportsService);
    final incProvider = IncomeProvider(incRepo);
    final budgetProvider = BudgetProvider(budgetRepo, AlertThrottleService(prefs));
    final futProvider = FutureExpensesProvider(futRepo, expRepo);

    budgetProvider.attachExpenses(expProvider);
    budgetProvider.attachIncome(incProvider);
    futProvider.attachExpenses(expProvider);

    await expProvider.initialize();
    await incProvider.initialize();
    await budgetProvider.initialize(initialWorkspaceId: AppConstants.kDefaultWorkspaceId);
    await futProvider.initialize(initialWorkspaceId: AppConstants.kDefaultWorkspaceId);

    // 1. Set Budget & Income in Personal
    final now = DateTime.now();
    await budgetProvider.setMonthlyBudget(id: 'b_pers', limit: 100000, anyDayInMonth: now);
    await incProvider.addIncome(Income(
      id: 'inc_pers',
      source: 'Salary',
      amount: 200000,
      date: now,
      isConfirmed: true,
      workspaceId: AppConstants.kDefaultWorkspaceId,
    ));

    // 2. Switch to 'ws_work' and set independent budget + income + planned item
    expProvider.setActiveWorkspace('ws_work');
    incProvider.setActiveWorkspace('ws_work');
    await budgetProvider.setActiveWorkspace('ws_work');
    futProvider.setActiveWorkspace('ws_work');

    expect(budgetProvider.activeBudget, isNull); // Personal's budget must NOT leak into Work!
    expect(incProvider.totalConfirmed, 0);

    await budgetProvider.setMonthlyBudget(id: 'b_work', limit: 500000, anyDayInMonth: now);
    await incProvider.addIncome(Income(
      id: 'inc_work',
      source: 'Retainer',
      amount: 300000,
      date: now,
      isConfirmed: true,
      workspaceId: 'ws_work',
    ));

    await futProvider.addFutureExpense(FutureExpense(
      id: 'fut_work',
      title: 'Mac Mini',
      estimatedCost: 6000000,
      category: 'Other',
      workspaceId: 'ws_work',
    ));
    expect(futProvider.items.length, 1);

    // Purchase planned item inside 'ws_work' -> created Expense must carry 'ws_work'
    await futProvider.purchase(futProvider.items.first, amount: 5500000);
    await expProvider.deferredRebuild();

    expect(expProvider.totalSpent, 5500000);
    expect(budgetProvider.cachedSpent, 5500000);
    expect(budgetProvider.confirmedIncomeContribution, 300000);

    // 3. Switch back to Personal -> must still have Personal's budget (100k limit + 200k inc) and ZERO spent!
    expProvider.setActiveWorkspace(AppConstants.kDefaultWorkspaceId);
    incProvider.setActiveWorkspace(AppConstants.kDefaultWorkspaceId);
    await budgetProvider.setActiveWorkspace(AppConstants.kDefaultWorkspaceId);
    futProvider.setActiveWorkspace(AppConstants.kDefaultWorkspaceId);

    expect(budgetProvider.baseBudget, 100000);
    expect(budgetProvider.confirmedIncomeContribution, 200000);
    expect(budgetProvider.cachedSpent, 0);
    expect(futProvider.items, isEmpty);

    // 4. Verify DashboardService & InsightEngineService isolate Personal vs Work
    final insightService = InsightEngineService(
      reminderRepo: remRepo,
      reportsDataService: reportsService,
    );
    final dashService = DashboardService(
      reportsDataService: reportsService,
      insightEngineService: insightService,
    );

    final personalDash = await dashService.buildViewModel(
      now,
      incomes: incProvider.items,
      futureExpenses: futProvider.items,
      activeWorkspaceId: AppConstants.kDefaultWorkspaceId,
      budgetLimit: budgetProvider.budget,
      spentInActivePeriod: budgetProvider.cachedSpent,
      budgetUsageRatio: 0.0,
      isMonthlyRefreshEnabled: true,
    );
    expect(personalDash.spentThisMonth, 0);
    expect(personalDash.insights.any((i) => i.message.contains('Server Renewal')), isFalse);
  });
}
