import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/initialization/app_readiness_notifier.dart';
import 'package:expense/core/initialization/job_reconciler.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/core/storage/hive_migration.dart';
import 'package:expense/core/storage/migrations/multi_profile_migration.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/job_record.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_journal_entry.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/providers/budget_provider.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/future_expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/providers/theme_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/services/alert_throttle_service.dart';
import 'package:expense/services/data_lifecycle_service.dart';
import 'package:expense/services/notification_service.dart';

class AppInitializer {
  static Future<void>? _activeBoot;
  static bool _hivePathInitialized = false;

  /// Phased, non-blocking startup sequence executed after Frame #1 renders the Splash Screen.
  /// Drives user-friendly progress messages, yields between I/O stages for 60/120fps
  /// smoothness, isolates non-fatal OS notification/timezone failures, and converts critical
  /// errors into actionable recovery guidance instead of crashing or hanging.
  static Future<void> boot({
    required AppReadinessNotifier appReadiness,
    required ExpensesProvider expensesProvider,
    required BudgetProvider budgetProvider,
    required IncomeProvider incomeProvider,
    required FutureExpensesProvider futureExpensesProvider,
    required ReminderProvider reminderProvider,
    WorkspaceProvider? workspaceProvider,
    AccountProvider? accountProvider,
    TransferProvider? transferProvider,
    SavingsVaultProvider? savingsVaultProvider,
    ThemeProvider? themeProvider,
    AppPreferencesProvider? appPrefsProvider,
    CategoryProvider? categoryProvider,
    AlertThrottleService? alertThrottleService,
    DataLifecycleService? lifecycleService,
    Future<SharedPreferences> Function()? initStorageHook,
    Future<void> Function()? initHiveHook,
    Future<void> Function()? initNotificationsHook,
  }) {
    if (_activeBoot != null) return _activeBoot!;

    final future = _executeBoot(
      appReadiness: appReadiness,
      expensesProvider: expensesProvider,
      budgetProvider: budgetProvider,
      incomeProvider: incomeProvider,
      futureExpensesProvider: futureExpensesProvider,
      reminderProvider: reminderProvider,
      workspaceProvider: workspaceProvider,
      accountProvider: accountProvider,
      transferProvider: transferProvider,
      savingsVaultProvider: savingsVaultProvider,
      themeProvider: themeProvider,
      appPrefsProvider: appPrefsProvider,
      categoryProvider: categoryProvider,
      alertThrottleService: alertThrottleService,
      lifecycleService: lifecycleService,
      initStorageHook: initStorageHook,
      initHiveHook: initHiveHook,
      initNotificationsHook: initNotificationsHook,
    );

    _activeBoot = future.whenComplete(() => _activeBoot = null);
    return _activeBoot!;
  }

  static Future<void> _executeBoot({
    required AppReadinessNotifier appReadiness,
    required ExpensesProvider expensesProvider,
    required BudgetProvider budgetProvider,
    required IncomeProvider incomeProvider,
    required FutureExpensesProvider futureExpensesProvider,
    required ReminderProvider reminderProvider,
    WorkspaceProvider? workspaceProvider,
    AccountProvider? accountProvider,
    TransferProvider? transferProvider,
    SavingsVaultProvider? savingsVaultProvider,
    ThemeProvider? themeProvider,
    AppPreferencesProvider? appPrefsProvider,
    CategoryProvider? categoryProvider,
    AlertThrottleService? alertThrottleService,
    DataLifecycleService? lifecycleService,
    Future<SharedPreferences> Function()? initStorageHook,
    Future<void> Function()? initHiveHook,
    Future<void> Function()? initNotificationsHook,
  }) async {
    try {
      // Stage 1: Preferences & Theme Warm-up
      appReadiness.updateProgress(0.12, 'Warming up your workspace');
      await Future.delayed(Duration.zero);

      final prefs = await (initStorageHook?.call() ?? SharedPreferences.getInstance())
          .timeout(const Duration(seconds: 10));
      alertThrottleService?.attachPrefs(prefs);
      appPrefsProvider?.attachPrefs(prefs);
      await themeProvider?.loadPreferences(prefs);

      // Stage 2: Local Ledger Storage & Schema Registration
      appReadiness.updateProgress(0.32, 'Opening your secure ledger');
      await Future.delayed(Duration.zero);

      if (initHiveHook != null) {
        await initHiveHook();
      } else {
        if (!_hivePathInitialized) {
          final dir = await getApplicationDocumentsDirectory()
              .timeout(const Duration(seconds: 10));
          Hive.init(dir.path);
          _hivePathInitialized = true;
        }
        _registerAdapters();
        await _openBoxes().timeout(const Duration(seconds: 20));
      }

      if (Hive.isBoxOpen(AppStateBox.boxName)) {
        categoryProvider?.attachBox(Hive.box(AppStateBox.boxName));
      }

      // Stage 3: Integrity, Migrations & Recovery
      appReadiness.updateProgress(0.50, 'Verifying financial records');
      await Future.delayed(Duration.zero);

      await MultiProfileMigration.runIfNeeded();
      await JobReconciler.reconcile();

      if (AppStateBox.isPendingReset || AppStateBox.pendingLifecycleOp != null) {
        await _handlePendingReset(
          expensesProvider,
          budgetProvider,
          lifecycleService: lifecycleService,
        );
      }

      // Stage 4: Financial Profiles, Accounts & Vaults
      appReadiness.updateProgress(0.68, 'Preparing your financial assistant');
      await Future.delayed(Duration.zero);

      if (workspaceProvider != null) {
        await workspaceProvider.initialize();
      }
      final activeWsId = workspaceProvider?.activeWorkspaceId;

      if (accountProvider != null) {
        await accountProvider.initialize(initialWorkspaceId: activeWsId);
        if (workspaceProvider != null) {
          for (final ws in workspaceProvider.workspaces) {
            await accountProvider.ensureStandardAccountsForWorkspace(ws.id);
          }
        }
      }
      if (transferProvider != null) {
        await transferProvider.initialize(initialWorkspaceId: activeWsId);
      }
      if (savingsVaultProvider != null) {
        await savingsVaultProvider.initialize(initialWorkspaceId: activeWsId);
      }

      // Stage 5: Expenses, Budgets & Analytics Cube
      appReadiness.updateProgress(0.84, 'Calculating balances & insights');
      await Future.delayed(Duration.zero);

      if (activeWsId != null) {
        expensesProvider.setActiveWorkspace(activeWsId);
      }
      await Future.wait([
        expensesProvider.initialize(),
        budgetProvider.initialize(initialWorkspaceId: activeWsId),
        incomeProvider.initialize(initialWorkspaceId: activeWsId),
        futureExpensesProvider.initialize(initialWorkspaceId: activeWsId),
      ]);
      await expensesProvider.deferredRebuild();

      // Stage 6: OS Notifications, Timezone & Reminders (Non-fatal isolation)
      appReadiness.updateProgress(0.95, 'Syncing smart bill alerts');
      await Future.delayed(Duration.zero);

      try {
        await (initNotificationsHook?.call() ?? NotificationService().initialize())
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('AppInitializer: Notification OS init degraded safely: $e');
        appReadiness.addWarning('Bill notification service deferred.');
      }

      try {
        await reminderProvider.initialize(initialWorkspaceId: activeWsId);
        await _reconcileReminders(reminderProvider);
        await reminderProvider
            .rescheduleRecurringReminders()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('AppInitializer: Reminder rescheduling deferred cleanly: $e');
        appReadiness.addWarning('Reminder rescheduling deferred.');
      }

      // Stage 7: Complete
      appReadiness.markReady();
    } catch (e, st) {
      debugPrint('AppInitializer.boot critical failure: $e\n$st');
      final friendly = AppErrorTranslator.translate(
        e,
        operation: FeedbackOperation.appStartup,
      );
      appReadiness.markFailed(
        title: friendly.title,
        guidance: friendly.guidance ??
            'Your saved local financial records remain safe. Please retry startup or close and reopen ${AppBrand.appName}.',
      );
    }
  }

  /// Legacy synchronous pre-init preserved for backwards compatibility in integration harnesses.
  static Future<SharedPreferences> preInit() async {
    WidgetsFlutterBinding.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    if (!_hivePathInitialized) {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      _hivePathInitialized = true;
    }

    _registerAdapters();
    await _openBoxes();
    await MultiProfileMigration.runIfNeeded();
    await JobReconciler.reconcile();

    return prefs;
  }

  static void _reg<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  static void _registerAdapters() {
    _reg<Expense>(ExpenseAdapter());
    _reg<Income>(IncomeAdapter());
    _reg<FutureExpense>(FutureExpenseAdapter());
    _reg<Budget>(BudgetAdapter());
    _reg<Reminder>(ReminderAdapter());
    _reg<JobRecord>(JobRecordAdapter());
    _reg<WorkspaceType>(WorkspaceTypeAdapter());
    _reg<Workspace>(WorkspaceAdapter());
    _reg<AccountType>(AccountTypeAdapter());
    _reg<Account>(AccountAdapter());
    _reg<TransferStatus>(TransferStatusAdapter());
    _reg<Transfer>(TransferAdapter());
    _reg<TransferJournalPhase>(TransferJournalPhaseAdapter());
    _reg<TransferJournalEntry>(TransferJournalEntryAdapter());
    _reg<SavingsVault>(SavingsVaultAdapter());
  }

  static Future<void> _openBoxes() async {
    await Future.wait([
      HiveMigration.openBoxWithMigration<Expense>(
        boxName: AppConstants.kExpensesBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 50,
      ),
      HiveMigration.openBoxWithMigration<Budget>(
        boxName: AppConstants.kBudgetsBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 25,
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
        boxName: AppConstants.kRemindersBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 50,
      ),
      HiveMigration.openBoxWithMigration<JobRecord>(
        boxName: AppConstants.kJobsBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 20,
      ),
      HiveMigration.openBoxWithMigration<Workspace>(
        boxName: AppConstants.kWorkspacesBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 10,
      ),
      HiveMigration.openBoxWithMigration<Account>(
        boxName: AppConstants.kAccountsBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 20,
      ),
      HiveMigration.openBoxWithMigration<Transfer>(
        boxName: AppConstants.kTransfersBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 50,
      ),
      HiveMigration.openBoxWithMigration<TransferJournalEntry>(
        boxName: AppConstants.kTransferJournalBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 10,
      ),
      HiveMigration.openBoxWithMigration<SavingsVault>(
        boxName: AppConstants.kVaultsBox,
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 10,
      ),
    ]);
  }

  /// Legacy post-init preserved for tests/callers invoking [preInit] + [postInit].
  static Future<void> postInit({
    required ExpensesProvider expensesProvider,
    required BudgetProvider budgetProvider,
    required IncomeProvider incomeProvider,
    required FutureExpensesProvider futureExpensesProvider,
    required ReminderProvider reminderProvider,
    required AppReadinessNotifier appReadiness,
    WorkspaceProvider? workspaceProvider,
    AccountProvider? accountProvider,
    TransferProvider? transferProvider,
    SavingsVaultProvider? savingsVaultProvider,
    DataLifecycleService? lifecycleService,
  }) async {
    try {
      if (AppStateBox.isPendingReset || AppStateBox.pendingLifecycleOp != null) {
        await _handlePendingReset(
          expensesProvider,
          budgetProvider,
          lifecycleService: lifecycleService,
        );
      }

      if (workspaceProvider != null) {
        await workspaceProvider.initialize();
      }
      final activeWsId = workspaceProvider?.activeWorkspaceId;

      if (accountProvider != null) {
        await accountProvider.initialize(initialWorkspaceId: activeWsId);
        if (workspaceProvider != null) {
          for (final ws in workspaceProvider.workspaces) {
            await accountProvider.ensureStandardAccountsForWorkspace(ws.id);
          }
        }
      }
      if (transferProvider != null) {
        await transferProvider.initialize(initialWorkspaceId: activeWsId);
      }
      if (savingsVaultProvider != null) {
        await savingsVaultProvider.initialize(initialWorkspaceId: activeWsId);
      }

      if (activeWsId != null) {
        expensesProvider.setActiveWorkspace(activeWsId);
      }
      await Future.wait([
        expensesProvider.initialize(),
        budgetProvider.initialize(initialWorkspaceId: activeWsId),
      ]);
      await expensesProvider.deferredRebuild();

      try {
        await NotificationService()
            .initialize()
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('AppInitializer.postInit notification deferred: $e');
      }

      await reminderProvider.initialize(initialWorkspaceId: activeWsId);
      await _reconcileReminders(reminderProvider);

      await Future.wait([
        incomeProvider.initialize(initialWorkspaceId: activeWsId),
        futureExpensesProvider.initialize(initialWorkspaceId: activeWsId),
      ]);

      try {
        await reminderProvider
            .rescheduleRecurringReminders()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('AppInitializer.postInit reschedule deferred: $e');
      }

      appReadiness.markReady();
    } catch (e) {
      final friendly = AppErrorTranslator.translate(
        e,
        operation: FeedbackOperation.appStartup,
      );
      appReadiness.markFailed(
        title: friendly.title,
        guidance: friendly.guidance ??
            'Please retry startup or close and reopen ${AppBrand.appName} cleanly.',
      );
    }
  }

  static Future<void> _handlePendingReset(
    ExpensesProvider expensesProvider,
    BudgetProvider budgetProvider, {
    DataLifecycleService? lifecycleService,
  }) async {
    final service = lifecycleService ?? DataLifecycleService();
    await service.resumePendingOperationIfNeeded();
    await Future.wait([expensesProvider.load(), budgetProvider.load()]);
  }

  static Future<void> _reconcileReminders(
    ReminderProvider reminderProvider,
  ) async {
    final schedulingReminders = reminderProvider.allItems
        .where((r) => r.state == 'scheduling')
        .toList();
    if (schedulingReminders.isNotEmpty) {
      await JobReconciler.reconcileReminders(schedulingReminders);
      await reminderProvider.load();
    }
  }
}
