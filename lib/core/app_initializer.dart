import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense/core/app_constants.dart';
import 'package:expense/core/app_readiness_notifier.dart';
import 'package:expense/core/app_state_box.dart';
import 'package:expense/core/hive_migration.dart';
import 'package:expense/core/job_reconciler.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/job_record.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/provider/budget_provider.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/services/notification_service.dart';

class AppInitializer {
  static Future<SharedPreferences> preInit() async {
    WidgetsFlutterBinding.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Register adapters
    _registerAdapters();

    // Open boxes with migration
    await _openBoxes();

    // Run startup reconciliation
    await JobReconciler.reconcile();

    return prefs;
  }

  static void _registerAdapters() {
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(IncomeAdapter());
    Hive.registerAdapter(FutureExpenseAdapter());
    Hive.registerAdapter(BudgetAdapter());
    Hive.registerAdapter(ReminderAdapter());
    Hive.registerAdapter(JobRecordAdapter());
  }

  static Future<void> _openBoxes() async {
    await Future.wait([
      HiveMigration.openBoxWithMigration<Expense>(
        boxName: AppConstants.kExpensesBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 50,
      ),
      HiveMigration.openBoxWithMigration<Budget>(
        boxName: AppConstants.kBudgetsBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 5,
      ),
      HiveMigration.openGenericBoxWithMigration(boxName: AppStateBox.boxName),
      HiveMigration.openBoxWithMigration<Income>(
        boxName: AppConstants.kIncomesBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 20,
      ),
      HiveMigration.openBoxWithMigration<FutureExpense>(
        boxName: AppConstants.kFutureExpensesBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 50,
      ),
      HiveMigration.openBoxWithMigration<Reminder>(
        boxName: 'reminders',
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 50,
      ),
      HiveMigration.openBoxWithMigration<JobRecord>(
        boxName: 'jobs',
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 10,
      ),
    ]);
  }

  static Future<void> postInit({
    required ExpensesProvider expensesProvider,
    required BudgetProvider budgetProvider,
    required IncomeProvider incomeProvider,
    required FutureExpensesProvider futureExpensesProvider,
    required ReminderProvider reminderProvider,
    required AppReadinessNotifier appReadiness,
  }) async {
    // 1. Recovery if pending reset
    if (AppStateBox.isPendingReset) {
      await _handlePendingReset(expensesProvider, budgetProvider);
    }

    // 2. Deferred rebuilds & Critical Initializations
    await Future.wait([
      expensesProvider.initialize(),
      budgetProvider.initialize(),
    ]);
    await expensesProvider.deferredRebuild();

    // 3. Services
    final notificationService = NotificationService();
    await notificationService.initialize();

    // 4. Initialize Reminder Provider
    await reminderProvider.initialize();

    // 5. Reminders reconciliation
    await _reconcileReminders(reminderProvider);

    // 6. Initialize other Phase 2 providers
    await Future.wait([
      incomeProvider.initialize(),
      futureExpensesProvider.initialize(),
    ]);

    // 7. Reschedule
    await reminderProvider.rescheduleRecurringReminders();

    // 8. Done
    appReadiness.markReady();
  }

  static Future<void> _handlePendingReset(
    ExpensesProvider expensesProvider,
    BudgetProvider budgetProvider,
  ) async {
    await Hive.box<Expense>(AppConstants.kExpensesBox).clear();
    await Hive.box<Income>(AppConstants.kIncomesBox).clear();
    final futureBox = Hive.box<FutureExpense>(AppConstants.kFutureExpensesBox);

    for (final item in futureBox.values) {
      if (item.isPurchased) {
        item.isPurchased = false;
        item.linkedExpenseKey = null;
        item.purchasedAmount = null;
        item.purchasedAt = null;
        await item.save();
      }
    }

    await Hive.box<Reminder>('reminders').clear();
    await AppStateBox.setPendingReset(false);
    await Future.wait([expensesProvider.load(), budgetProvider.load()]);
  }

  static Future<void> _reconcileReminders(
    ReminderProvider reminderProvider,
  ) async {
    final schedulingReminders = reminderProvider.items
        .where((r) => r.state == 'scheduling')
        .toList();
    if (schedulingReminders.isNotEmpty) {
      await JobReconciler.reconcileReminders(schedulingReminders);
      await reminderProvider.load();
    }
  }
}
