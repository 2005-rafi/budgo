import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/storage/finance_boxes.dart';
import 'package:expense/design/tokens/entity_icons.dart';
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
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/services/storage_info_service.dart';

class DataOperationSummary {
  final int expensesAffected;
  final int incomesAffected;
  final int remindersCancelled;
  final int transfersDeleted;
  final int vaultsDeleted;
  final int accountsResetOrDeleted;
  final int budgetsDeleted;
  final int futureExpensesDeleted;
  final int workspacesDeleted;

  const DataOperationSummary({
    this.expensesAffected = 0,
    this.incomesAffected = 0,
    this.remindersCancelled = 0,
    this.transfersDeleted = 0,
    this.vaultsDeleted = 0,
    this.accountsResetOrDeleted = 0,
    this.budgetsDeleted = 0,
    this.futureExpensesDeleted = 0,
    this.workspacesDeleted = 0,
  });

  int get totalRecordsAffected =>
      expensesAffected +
      incomesAffected +
      remindersCancelled +
      transfersDeleted +
      vaultsDeleted +
      accountsResetOrDeleted +
      budgetsDeleted +
      futureExpensesDeleted +
      workspacesDeleted;
}

/// Centralized ACID DBMS Lifecycle Coordinator handling:
/// 1. Workspace-isolated batch archival
/// 2. Scoped workspace wipe / cascade deletion (preserving cross-workspace integrity)
/// 3. Crash-safe factory reset + OS alarm cancellation + Hive disk compaction.
class DataLifecycleService {
  final Box<Expense>? _injectedExpensesBox;
  final Box<Income>? _injectedIncomesBox;
  final Box<FutureExpense>? _injectedFutureBox;
  final Box<Budget>? _injectedBudgetsBox;
  final Box<Reminder>? _injectedRemindersBox;
  final Box<JobRecord>? _injectedJobsBox;
  final Box<Workspace>? _injectedWorkspacesBox;
  final Box<Account>? _injectedAccountsBox;
  final Box<Transfer>? _injectedTransfersBox;
  final Box<TransferJournalEntry>? _injectedTransferJournalBox;
  final Box<SavingsVault>? _injectedVaultsBox;
  final Box? _injectedAppStateBox;
  final NotificationService _notificationService;

  Box<Expense> get _expensesBox => _injectedExpensesBox ?? FinanceBoxes.expenses;
  Box<Income> get _incomesBox => _injectedIncomesBox ?? FinanceBoxes.incomes;
  Box<FutureExpense> get _futureBox => _injectedFutureBox ?? FinanceBoxes.futureExpenses;
  Box<Budget> get _budgetsBox => _injectedBudgetsBox ?? FinanceBoxes.budgets;
  Box<Reminder> get _remindersBox => _injectedRemindersBox ?? FinanceBoxes.reminders;
  Box<JobRecord> get _jobsBox => _injectedJobsBox ?? FinanceBoxes.jobs;
  Box<Workspace> get _workspacesBox => _injectedWorkspacesBox ?? FinanceBoxes.workspaces;
  Box<Account> get _accountsBox => _injectedAccountsBox ?? FinanceBoxes.accounts;
  Box<Transfer> get _transfersBox => _injectedTransfersBox ?? FinanceBoxes.transfers;
  Box<TransferJournalEntry> get _transferJournalBox => _injectedTransferJournalBox ?? FinanceBoxes.transferJournal;
  Box<SavingsVault> get _vaultsBox => _injectedVaultsBox ?? FinanceBoxes.vaults;
  Box get _appStateBox => _injectedAppStateBox ?? Hive.box(AppStateBox.boxName);

  DataLifecycleService({
    Box<Expense>? expensesBox,
    Box<Income>? incomesBox,
    Box<FutureExpense>? futureBox,
    Box<Budget>? budgetsBox,
    Box<Reminder>? remindersBox,
    Box<JobRecord>? jobsBox,
    Box<Workspace>? workspacesBox,
    Box<Account>? accountsBox,
    Box<Transfer>? transfersBox,
    Box<TransferJournalEntry>? transferJournalBox,
    Box<SavingsVault>? vaultsBox,
    Box? appStateBox,
    NotificationService? notificationService,
  })  : _injectedExpensesBox = expensesBox,
        _injectedIncomesBox = incomesBox,
        _injectedFutureBox = futureBox,
        _injectedBudgetsBox = budgetsBox,
        _injectedRemindersBox = remindersBox,
        _injectedJobsBox = jobsBox,
        _injectedWorkspacesBox = workspacesBox,
        _injectedAccountsBox = accountsBox,
        _injectedTransfersBox = transfersBox,
        _injectedTransferJournalBox = transferJournalBox,
        _injectedVaultsBox = vaultsBox,
        _injectedAppStateBox = appStateBox,
        _notificationService = notificationService ?? NotificationService();

  static String _normWs(String? wsId) =>
      (wsId == null || wsId.isEmpty) ? AppConstants.kDefaultWorkspaceId : wsId;

  Future<void> _batchDeleteKeys(
    Box box,
    List<dynamic> keys, {
    int chunkSize = AppConstants.kDbBatchChunkSize,
    void Function(double)? onChunkProgress,
  }) async {
    if (keys.isEmpty) return;
    for (int i = 0; i < keys.length; i += chunkSize) {
      final end = min(i + chunkSize, keys.length);
      await box.deleteAll(keys.sublist(i, end));
      onChunkProgress?.call(end / keys.length);
      await Future.delayed(Duration.zero);
    }
    await box.flush();
    if (keys.length >= 100) {
      await box.compact();
    }
  }

  /// Archives non-archived expenses belonging strictly to [workspaceIds] older
  /// than [olderThanMonths], using batched `putAll` writes + compaction.
  Future<int> archiveExpenses({
    required Set<String> workspaceIds,
    required int olderThanMonths,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final normTargets = workspaceIds.map(_normWs).toSet();
    if (normTargets.isEmpty) {
      onProgress?.call(1.0);
      return 0;
    }

    final cutoff = DateTime.now().subtract(Duration(days: 30 * olderThanMonths));

    return await AtomicWriter.instance.execute(() async {
      final matches = <dynamic, Expense>{};
      for (final entry in _expensesBox.toMap().entries) {
        final e = entry.value;
        if (!e.isArchived &&
            e.date.isBefore(cutoff) &&
            normTargets.contains(_normWs(e.workspaceId))) {
          matches[entry.key] = e;
        }
      }

      final total = matches.length;
      if (total == 0) {
        onProgress?.call(1.0);
        return 0;
      }

      final keys = matches.keys.toList();
      int archivedCount = 0;
      const chunkSize = AppConstants.kDbBatchChunkSize;

      for (int i = 0; i < total; i += chunkSize) {
        if (isCancelled?.call() == true) break;
        final end = min(i + chunkSize, total);
        final chunkMap = <dynamic, Expense>{};
        for (int j = i; j < end; j++) {
          final k = keys[j];
          final exp = matches[k]!;
          exp.isArchived = true;
          chunkMap[k] = exp;
        }
        await _expensesBox.putAll(chunkMap);
        archivedCount += chunkMap.length;
        onProgress?.call(archivedCount / total);
        await Future.delayed(Duration.zero);
      }

      await _expensesBox.flush();
      if (archivedCount >= 200) {
        await _expensesBox.compact();
      }
      StorageInfoService.invalidate();
      return archivedCount;
    });
  }

  /// Wipes ALL records strictly scoped to [workspaceIds] across every Hive box,
  /// cancelling targeted OS notifications cleanly while keeping sibling workspaces intact.
  ///
  /// Cross-workspace transfers touching a surviving workspace are preserved to maintain
  /// audit integrity for the surviving workspace's balance/ledger.
  Future<DataOperationSummary> clearWorkspaceData({
    required Set<String> workspaceIds,
    bool deleteSecondaryWorkspaces = false,
    void Function(double progress)? onProgress,
  }) async {
    final targets = workspaceIds.map(_normWs).toSet();
    if (targets.isEmpty) {
      onProgress?.call(1.0);
      return const DataOperationSummary();
    }

    return await AtomicWriter.instance.execute(() async {
      await _writePendingOp({
        'type': 'workspace_wipe',
        'workspaceIds': targets.toList(),
        'deleteSecondaryWorkspaces': deleteSecondaryWorkspaces,
      });

      onProgress?.call(0.05);

      // 1. Expenses
      final expKeys = <dynamic>[];
      for (final entry in _expensesBox.toMap().entries) {
        if (targets.contains(_normWs(entry.value.workspaceId))) {
          expKeys.add(entry.key);
        }
      }
      await _batchDeleteKeys(_expensesBox, expKeys);
      onProgress?.call(0.20);

      // 2. Incomes
      final incKeys = <dynamic>[];
      for (final entry in _incomesBox.toMap().entries) {
        if (targets.contains(_normWs(entry.value.workspaceId))) {
          incKeys.add(entry.key);
        }
      }
      await _batchDeleteKeys(_incomesBox, incKeys);
      onProgress?.call(0.35);

      // 3. Future Expenses (Wishlist)
      final futKeys = <dynamic>[];
      for (final entry in _futureBox.toMap().entries) {
        if (targets.contains(_normWs(entry.value.workspaceId))) {
          futKeys.add(entry.key);
        }
      }
      await _batchDeleteKeys(_futureBox, futKeys);
      onProgress?.call(0.45);

      // 4. Reminders + Cancel targeted OS alarms cleanly!
      final remKeys = <dynamic>[];
      for (final entry in _remindersBox.toMap().entries) {
        if (targets.contains(_normWs(entry.value.workspaceId))) {
          try {
            await _notificationService.cancelReminder(entry.value.notificationId);
          } catch (_) {}
          remKeys.add(entry.key);
        }
      }
      await _batchDeleteKeys(_remindersBox, remKeys);
      onProgress?.call(0.55);

      // 5. Budgets (remove both scoped key & legacy active_budget if default wiped)
      final budgetKeys = <dynamic>[];
      for (final entry in _budgetsBox.toMap().entries) {
        if (targets.contains(_normWs(entry.value.workspaceId))) {
          budgetKeys.add(entry.key);
        }
      }
      if (targets.contains(AppConstants.kDefaultWorkspaceId) &&
          _budgetsBox.containsKey(AppConstants.kActiveBudgetKey) &&
          !budgetKeys.contains(AppConstants.kActiveBudgetKey)) {
        budgetKeys.add(AppConstants.kActiveBudgetKey);
      }
      await _batchDeleteKeys(_budgetsBox, budgetKeys);
      onProgress?.call(0.65);

      // 6. Savings Vaults
      final vaultKeys = <dynamic>[];
      for (final entry in _vaultsBox.toMap().entries) {
        if (targets.contains(_normWs(entry.value.workspaceId))) {
          vaultKeys.add(entry.key);
        }
      }
      await _batchDeleteKeys(_vaultsBox, vaultKeys);
      onProgress?.call(0.72);

      // 7. Intra-workspace Transfers + Journal Entries (Preserve cross-workspace transfers
      // if the counterparty workspace survives!)
      final transferIdsToDelete = <String>{};
      final transferKeysToDelete = <dynamic>[];
      for (final entry in _transfersBox.toMap().entries) {
        final t = entry.value;
        final srcTargeted = targets.contains(_normWs(t.sourceWorkspaceId));
        final dstTargeted = targets.contains(_normWs(t.destinationWorkspaceId));
        if (srcTargeted && dstTargeted) {
          transferKeysToDelete.add(entry.key);
          transferIdsToDelete.add(t.id);
        }
      }
      if (transferIdsToDelete.isNotEmpty) {
        final journalKeys = <dynamic>[];
        for (final entry in _transferJournalBox.toMap().entries) {
          if (transferIdsToDelete.contains(entry.value.transferId)) {
            journalKeys.add(entry.key);
          }
        }
        await _batchDeleteKeys(_transferJournalBox, journalKeys);
      }
      await _batchDeleteKeys(_transfersBox, transferKeysToDelete);
      onProgress?.call(0.80);

      // 8. Accounts & Workspaces
      int accountsAffected = 0;
      int workspacesDeleted = 0;
      final now = DateTime.now();

      final accountsToDelete = <dynamic>[];
      final accountsToZero = <dynamic, Account>{};

      for (final entry in _accountsBox.toMap().entries) {
        final acc = entry.value;
        final wsId = _normWs(acc.workspaceId);
        if (!targets.contains(wsId)) continue;

        final willDeleteWs =
            deleteSecondaryWorkspaces && wsId != AppConstants.kDefaultWorkspaceId;
        if (willDeleteWs) {
          accountsToDelete.add(entry.key);
        } else {
          acc.balancePaise = 0;
          acc.updatedAt = now;
          accountsToZero[entry.key] = acc;
        }
      }

      if (accountsToDelete.isNotEmpty) {
        await _batchDeleteKeys(_accountsBox, accountsToDelete);
        accountsAffected += accountsToDelete.length;
      }
      if (accountsToZero.isNotEmpty) {
        await _accountsBox.putAll(accountsToZero);
        await _accountsBox.flush();
        accountsAffected += accountsToZero.length;
      }

      if (deleteSecondaryWorkspaces) {
        final wsKeysToDelete = <dynamic>[];
        for (final entry in _workspacesBox.toMap().entries) {
          final w = entry.value;
          if (!w.isDefault &&
              w.id != AppConstants.kDefaultWorkspaceId &&
              targets.contains(_normWs(w.id))) {
            wsKeysToDelete.add(entry.key);
          }
        }
        await _batchDeleteKeys(_workspacesBox, wsKeysToDelete);
        workspacesDeleted = wsKeysToDelete.length;
      }

      onProgress?.call(0.95);
      await _clearPendingOp();
      StorageInfoService.invalidate();
      onProgress?.call(1.0);

      return DataOperationSummary(
        expensesAffected: expKeys.length,
        incomesAffected: incKeys.length,
        remindersCancelled: remKeys.length,
        transfersDeleted: transferKeysToDelete.length,
        vaultsDeleted: vaultKeys.length,
        accountsResetOrDeleted: accountsAffected,
        budgetsDeleted: budgetKeys.length,
        futureExpensesDeleted: futKeys.length,
        workspacesDeleted: workspacesDeleted,
      );
    });
  }

  /// Complete ACID factory wipe of all 11 entity boxes, cancels all OS notifications,
  /// compacts physical storage, and re-seeds clean Default Personal triad accounts.
  Future<void> factoryResetAllData({
    bool resetCategories = false,
    void Function(double progress)? onProgress,
  }) async {
    await AtomicWriter.instance.execute(() async {
      await _writePendingOp({
        'type': 'factory_reset',
        'resetCategories': resetCategories,
      });

      onProgress?.call(0.05);

      try {
        await _notificationService.cancelAllReminders();
      } catch (e) {
        debugPrint('DataLifecycleService: OS notification wipe warning: $e');
      }

      final boxesToClear = <Box>[
        _expensesBox,
        _incomesBox,
        _futureBox,
        _budgetsBox,
        _remindersBox,
        _jobsBox,
        _transfersBox,
        _transferJournalBox,
        _vaultsBox,
        _accountsBox,
        _workspacesBox,
      ];

      for (int i = 0; i < boxesToClear.length; i++) {
        final box = boxesToClear[i];
        if (box.isNotEmpty) {
          await box.clear();
          await box.flush();
          await box.compact();
        }
        onProgress?.call(0.10 + (0.75 * ((i + 1) / boxesToClear.length)));
        await Future.delayed(Duration.zero);
      }

      if (resetCategories) {
        await _appStateBox.delete(AppConstants.kUserCategoriesKey);
      }

      // Re-seed clean Personal workspace + 3 standard zero-balance accounts
      final now = DateTime.now();
      final defaultWs = Workspace(
        id: AppConstants.kDefaultWorkspaceId,
        name: 'Personal',
        type: WorkspaceType.personal,
        currency: '₹',
        initialBalance: 0,
        createdAt: now,
        iconCodePoint: WorkspaceIcons.forType(WorkspaceType.personal).codePoint,
        colorValue: WorkspaceIcons.defaultColorForType(WorkspaceType.personal).toARGB32(),
        isDefault: true,
      );
      await _workspacesBox.put(defaultWs.id, defaultWs);
      await _workspacesBox.flush();

      await _accountsBox.putAll({
        AppConstants.kCashAccountId: Account(
          id: AppConstants.kCashAccountId,
          workspaceId: AppConstants.kDefaultWorkspaceId,
          name: 'Cash Wallet',
          type: AccountType.cash,
          balancePaise: 0,
          iconCodePoint: AccountIcons.forType(AccountType.cash).codePoint,
          colorValue: AccountIcons.defaultColorForType(AccountType.cash).toARGB32(),
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
        AppConstants.kBankAccountId: Account(
          id: AppConstants.kBankAccountId,
          workspaceId: AppConstants.kDefaultWorkspaceId,
          name: 'Bank Account',
          type: AccountType.bankAccount,
          balancePaise: 0,
          iconCodePoint: AccountIcons.forType(AccountType.bankAccount).codePoint,
          colorValue: AccountIcons.defaultColorForType(AccountType.bankAccount).toARGB32(),
          isDefault: false,
          createdAt: now.add(const Duration(milliseconds: 1)),
          updatedAt: now,
        ),
        AppConstants.kUpiAccountId: Account(
          id: AppConstants.kUpiAccountId,
          workspaceId: AppConstants.kDefaultWorkspaceId,
          name: 'UPI / GPay',
          type: AccountType.upi,
          balancePaise: 0,
          iconCodePoint: AccountIcons.forType(AccountType.upi).codePoint,
          colorValue: AccountIcons.defaultColorForType(AccountType.upi).toARGB32(),
          isDefault: false,
          createdAt: now.add(const Duration(milliseconds: 2)),
          updatedAt: now,
        ),
      });
      await _accountsBox.flush();

      await _appStateBox.put(
        AppStateBox.kActiveWorkspaceIdKey,
        AppConstants.kDefaultWorkspaceId,
      );
      await _clearPendingOp();
      StorageInfoService.invalidate();
      onProgress?.call(1.0);
    });
  }

  /// Runs compact() across every financial box to reclaim append-log fragmentation.
  Future<void> compactAllBoxes() async {
    await AtomicWriter.instance.execute(() async {
      final boxes = <Box>[
        _expensesBox,
        _incomesBox,
        _futureBox,
        _budgetsBox,
        _remindersBox,
        _jobsBox,
        _transfersBox,
        _transferJournalBox,
        _vaultsBox,
        _accountsBox,
        _workspacesBox,
      ];
      for (final box in boxes) {
        await box.flush();
        await box.compact();
      }
      StorageInfoService.invalidate();
    });
  }

  /// Resumes any interrupted mass delete / reset on cold startup cleanly.
  Future<bool> resumePendingOperationIfNeeded() async {
    final op = AppStateBox.pendingLifecycleOp;
    final legacyPending =
        _appStateBox.get(AppStateBox.kPendingResetKey, defaultValue: false) == true;

    if (op == null && !legacyPending) return false;

    if (legacyPending && op == null) {
      await factoryResetAllData();
      return true;
    }

    final type = op!['type'] as String?;
    if (type == 'factory_reset') {
      await factoryResetAllData(
        resetCategories: op['resetCategories'] == true,
      );
      return true;
    } else if (type == 'workspace_wipe') {
      final wsList =
          (op['workspaceIds'] as List?)?.map((e) => e.toString()).toSet() ?? {};
      final deleteSecondary = op['deleteSecondaryWorkspaces'] == true;
      await clearWorkspaceData(
        workspaceIds: wsList,
        deleteSecondaryWorkspaces: deleteSecondary,
      );
      return true;
    }

    await _clearPendingOp();
    return false;
  }

  Future<void> _writePendingOp(Map<String, dynamic> op) async {
    await AppStateBox.setPendingReset(true);
    await AppStateBox.setPendingLifecycleOp(op);
  }

  Future<void> _clearPendingOp() async {
    await AppStateBox.setPendingLifecycleOp(null);
    await AppStateBox.setPendingReset(false);
  }
}
