import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/app_state_box.dart';
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
import 'package:expense/services/data_lifecycle_service.dart';
import 'package:expense/services/notification_service.dart';

class _RecordingNotificationService implements NotificationService {
  final List<int> cancelledIds = [];
  bool cancelledAll = false;

  @override
  Future<void> cancelReminder(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAllReminders() async {
    cancelledAll = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<Expense> expBox;
  late Box<Income> incBox;
  late Box<FutureExpense> futBox;
  late Box<Budget> budgetBox;
  late Box<Reminder> remBox;
  late Box<JobRecord> jobsBox;
  late Box<Workspace> wsBox;
  late Box<Account> accBox;
  late Box<Transfer> trfBox;
  late Box<TransferJournalEntry> journalBox;
  late Box<SavingsVault> vaultBox;
  late Box appStateBox;
  late _RecordingNotificationService notifSpy;
  late DataLifecycleService lifecycle;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('lifecycle_test');
    Hive.init(tempDir.path);

    void registerTyped<T>(TypeAdapter<T> adapter) {
      if (!Hive.isAdapterRegistered(adapter.typeId)) {
        Hive.registerAdapter<T>(adapter);
      }
    }

    registerTyped<Expense>(ExpenseAdapter());
    registerTyped<Income>(IncomeAdapter());
    registerTyped<FutureExpense>(FutureExpenseAdapter());
    registerTyped<Budget>(BudgetAdapter());
    registerTyped<Reminder>(ReminderAdapter());
    registerTyped<JobRecord>(JobRecordAdapter());
    registerTyped<WorkspaceType>(WorkspaceTypeAdapter());
    registerTyped<Workspace>(WorkspaceAdapter());
    registerTyped<AccountType>(AccountTypeAdapter());
    registerTyped<Account>(AccountAdapter());
    registerTyped<TransferStatus>(TransferStatusAdapter());
    registerTyped<Transfer>(TransferAdapter());
    registerTyped<TransferJournalPhase>(TransferJournalPhaseAdapter());
    registerTyped<TransferJournalEntry>(TransferJournalEntryAdapter());
    registerTyped<SavingsVault>(SavingsVaultAdapter());

    appStateBox = await Hive.openBox(AppStateBox.boxName);
    expBox = await Hive.openBox<Expense>('expenses');
    incBox = await Hive.openBox<Income>('incomes');
    futBox = await Hive.openBox<FutureExpense>('future_expenses');
    budgetBox = await Hive.openBox<Budget>('budgets');
    remBox = await Hive.openBox<Reminder>('reminders');
    jobsBox = await Hive.openBox<JobRecord>('jobs');
    wsBox = await Hive.openBox<Workspace>('workspaces');
    accBox = await Hive.openBox<Account>('accounts');
    trfBox = await Hive.openBox<Transfer>('transfers');
    journalBox = await Hive.openBox<TransferJournalEntry>('transfer_journal');
    vaultBox = await Hive.openBox<SavingsVault>('savings_vaults');

    notifSpy = _RecordingNotificationService();
    lifecycle = DataLifecycleService(
      expensesBox: expBox,
      incomesBox: incBox,
      futureBox: futBox,
      budgetsBox: budgetBox,
      remindersBox: remBox,
      jobsBox: jobsBox,
      workspacesBox: wsBox,
      accountsBox: accBox,
      transfersBox: trfBox,
      transferJournalBox: journalBox,
      vaultsBox: vaultBox,
      appStateBox: appStateBox,
      notificationService: notifSpy,
    );

    final now = DateTime.now();
    await wsBox.put(AppConstants.kDefaultWorkspaceId, Workspace(
      id: AppConstants.kDefaultWorkspaceId,
      name: 'Personal',
      type: WorkspaceType.personal,
      currency: '₹',
      createdAt: now,
      iconCodePoint: 0xe491,
      colorValue: 0xFF2196F3,
      isDefault: true,
    ));
    await wsBox.put('ws_trip', Workspace(
      id: 'ws_trip',
      name: 'Goa Trip',
      type: WorkspaceType.trip,
      currency: '₹',
      createdAt: now,
      iconCodePoint: 0xe539,
      colorValue: 0xFFFF9800,
    ));

    // Seed Accounts
    await accBox.put('acc_p_cash', Account(
      id: 'acc_p_cash',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'Cash Wallet',
      type: AccountType.cash,
      balancePaise: 500000,
      iconCodePoint: 0,
      colorValue: 0,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ));
    await accBox.put('acc_t_cash', Account(
      id: 'acc_t_cash',
      workspaceId: 'ws_trip',
      name: 'Trip Cash',
      type: AccountType.cash,
      balancePaise: 250000,
      iconCodePoint: 0,
      colorValue: 0,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ));

    // Seed old + new expenses in both workspaces
    await expBox.addAll([
      Expense(
        productName: 'Personal Old',
        amount: 10000,
        category: 'Food',
        date: now.subtract(const Duration(days: 400)),
        workspaceId: AppConstants.kDefaultWorkspaceId,
      ),
      Expense(
        productName: 'Trip Old',
        amount: 20000,
        category: 'Travel',
        date: now.subtract(const Duration(days: 400)),
        workspaceId: 'ws_trip',
      ),
      Expense(
        productName: 'Trip Recent',
        amount: 30000,
        category: 'Food',
        date: now,
        workspaceId: 'ws_trip',
      ),
    ]);

    await incBox.addAll([
      Income(
        id: 'inc_p',
        source: 'Salary',
        amount: 5000000,
        date: now,
        isConfirmed: true,
        workspaceId: AppConstants.kDefaultWorkspaceId,
      ),
      Income(
        id: 'inc_t',
        source: 'Trip Refund',
        amount: 50000,
        date: now,
        workspaceId: 'ws_trip',
      ),
    ]);

    await budgetBox.put(
      AppConstants.budgetKeyForWorkspace(AppConstants.kDefaultWorkspaceId),
      Budget(
        id: 'b_p',
        limit: 1000000,
        period: 'monthly',
        startDate: now,
        endDate: now,
        workspaceId: AppConstants.kDefaultWorkspaceId,
      ),
    );
    await budgetBox.put(
      AppConstants.budgetKeyForWorkspace('ws_trip'),
      Budget(
        id: 'b_t',
        limit: 300000,
        period: 'monthly',
        startDate: now,
        endDate: now,
        workspaceId: 'ws_trip',
      ),
    );

    final remP = Reminder(
      id: 'rem_p',
      title: 'Rent',
      scheduledAt: now.add(const Duration(days: 1)),
      workspaceId: AppConstants.kDefaultWorkspaceId,
    );
    final remT = Reminder(
      id: 'rem_t',
      title: 'Hotel Deposit',
      scheduledAt: now.add(const Duration(days: 1)),
      workspaceId: 'ws_trip',
    );
    await remBox.put(remP.id, remP);
    await remBox.put(remT.id, remT);

    await vaultBox.put('v_p', SavingsVault(
      id: 'v_p',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      parentAccountId: 'acc_p_cash',
      name: 'Emergency',
      targetPaise: 100000,
      iconCodePoint: 0,
      colorValue: 0,
      createdAt: now,
      updatedAt: now,
    ));
    await vaultBox.put('v_t', SavingsVault(
      id: 'v_t',
      workspaceId: 'ws_trip',
      parentAccountId: 'acc_t_cash',
      name: 'Flights Fund',
      targetPaise: 50000,
      iconCodePoint: 0,
      colorValue: 0,
      createdAt: now,
      updatedAt: now,
    ));

    // One intra-trip transfer & one cross-workspace transfer Personal -> Trip
    await trfBox.put('trf_intra_trip', Transfer(
      id: 'trf_intra_trip',
      sourceAccountId: 'acc_t_cash',
      destinationAccountId: 'acc_t_bank',
      sourceWorkspaceId: 'ws_trip',
      destinationWorkspaceId: 'ws_trip',
      amountPaise: 10000,
      date: now,
      status: TransferStatus.completed,
    ));
    await trfBox.put('trf_cross', Transfer(
      id: 'trf_cross',
      sourceAccountId: 'acc_p_cash',
      destinationAccountId: 'acc_t_cash',
      sourceWorkspaceId: AppConstants.kDefaultWorkspaceId,
      destinationWorkspaceId: 'ws_trip',
      amountPaise: 50000,
      date: now,
      status: TransferStatus.completed,
    ));
    await journalBox.put('j_intra', TransferJournalEntry(
      transferId: 'trf_intra_trip',
      sourceAccountId: 'acc_t_cash',
      destinationAccountId: 'acc_t_bank',
      amountPaise: 10000,
      sourceOriginalBalance: 250000,
      destOriginalBalance: 0,
      phase: TransferJournalPhase.destinationCredited,
      timestamp: now,
    ));
    await journalBox.put('j_cross', TransferJournalEntry(
      transferId: 'trf_cross',
      sourceAccountId: 'acc_p_cash',
      destinationAccountId: 'acc_t_cash',
      amountPaise: 50000,
      sourceOriginalBalance: 500000,
      destOriginalBalance: 250000,
      phase: TransferJournalPhase.destinationCredited,
      timestamp: now,
    ));
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('archiveExpenses isolates strictly to targeted workspace without touching sibling workspaces', () async {
    final archivedCount = await lifecycle.archiveExpenses(
      workspaceIds: {'ws_trip'},
      olderThanMonths: 12,
    );

    expect(archivedCount, 1);

    final tripOld = expBox.values.firstWhere((e) => e.productName == 'Trip Old');
    final personalOld = expBox.values.firstWhere((e) => e.productName == 'Personal Old');

    expect(tripOld.isArchived, isTrue);
    expect(personalOld.isArchived, isFalse); // Untouched!
  });

  test('clearWorkspaceData cascades across child boxes & cancels targeted OS alarms while preserving Personal & cross-transfers', () async {
    final summary = await lifecycle.clearWorkspaceData(
      workspaceIds: {'ws_trip'},
      deleteSecondaryWorkspaces: true,
    );

    expect(summary.expensesAffected, 2);
    expect(summary.incomesAffected, 1);
    expect(summary.remindersCancelled, 1);
    expect(summary.vaultsDeleted, 1);
    expect(summary.workspacesDeleted, 1);
    expect(summary.transfersDeleted, 1); // Only intra-trip deleted!

    // Targeted reminder OS alarm was cancelled, NOT all reminders
    expect(notifSpy.cancelledAll, isFalse);
    expect(notifSpy.cancelledIds, [remBox.get('rem_t')?.notificationId ?? ('rem_t'.hashCode & 0x7FFFFFFF)]);

    // Secondary workspace & child records completely gone
    expect(wsBox.containsKey('ws_trip'), isFalse);
    expect(expBox.values.any((e) => e.workspaceId == 'ws_trip'), isFalse);
    expect(incBox.values.any((i) => i.workspaceId == 'ws_trip'), isFalse);
    expect(vaultBox.containsKey('v_t'), isFalse);
    expect(budgetBox.containsKey(AppConstants.budgetKeyForWorkspace('ws_trip')), isFalse);

    // Personal workspace + child records + surviving cross-workspace transfer preserved!
    expect(wsBox.containsKey(AppConstants.kDefaultWorkspaceId), isTrue);
    expect(expBox.values.where((e) => e.workspaceId == AppConstants.kDefaultWorkspaceId).length, 1);
    expect(incBox.values.where((i) => i.workspaceId == AppConstants.kDefaultWorkspaceId).length, 1);
    expect(vaultBox.containsKey('v_p'), isTrue);
    expect(accBox.get('acc_p_cash')?.balancePaise, 500000);
    expect(trfBox.containsKey('trf_intra_trip'), isFalse);
    expect(trfBox.containsKey('trf_cross'), isTrue);
    expect(journalBox.containsKey('j_cross'), isTrue);
  });

  test('factoryResetAllData wipes all 11 boxes, cancels all OS notifications, re-seeds default triad, and respects category opt-in', () async {
    await appStateBox.put(AppConstants.kUserCategoriesKey, '[{"custom":"data"}]');

    await lifecycle.factoryResetAllData(resetCategories: false);

    expect(notifSpy.cancelledAll, isTrue);
    expect(expBox.isEmpty, isTrue);
    expect(incBox.isEmpty, isTrue);
    expect(futBox.isEmpty, isTrue);
    expect(budgetBox.isEmpty, isTrue);
    expect(remBox.isEmpty, isTrue);
    expect(trfBox.isEmpty, isTrue);
    expect(journalBox.isEmpty, isTrue);
    expect(vaultBox.isEmpty, isTrue);
    expect(wsBox.length, 1);
    expect(wsBox.get(AppConstants.kDefaultWorkspaceId)?.name, 'Personal');
    // Triad seeded cleanly with zero balance
    expect(accBox.length, 3);
    expect(accBox.values.every((a) => a.balancePaise == 0), isTrue);
    // Opt-in category preservation respected
    expect(appStateBox.get(AppConstants.kUserCategoriesKey), isNotNull);

    // Now simulate crash recovery when resetCategories == true
    await AppStateBox.setPendingLifecycleOp({
      'type': 'factory_reset',
      'resetCategories': true,
    });
    final resumed = await lifecycle.resumePendingOperationIfNeeded();
    expect(resumed, isTrue);
    expect(AppStateBox.pendingLifecycleOp, isNull);
    expect(appStateBox.get(AppConstants.kUserCategoriesKey), isNull);
  });
}
