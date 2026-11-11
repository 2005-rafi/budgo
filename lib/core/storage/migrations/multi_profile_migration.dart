import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:expense/design/tokens/entity_icons.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/storage/hive_migration.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/core/storage/finance_boxes.dart';

class MultiProfileMigration {
  static const String kMigrationKey = 'v2_multi_profile_complete';
  static const String kDefaultWorkspaceId = AppConstants.kDefaultWorkspaceId;
  static const String kCashAccountId = AppConstants.kCashAccountId;
  static const String kBankAccountId = AppConstants.kBankAccountId;
  static const String kUpiAccountId = AppConstants.kUpiAccountId;

  static Future<void> runIfNeeded() async {
    final appState = Hive.box(AppStateBox.boxName);
    if (appState.get(kMigrationKey, defaultValue: false) == true) {
      return;
    }

    debugPrint('MultiProfileMigration: Beginning non-destructive migration...');

    // 1. Snapshot backups of all boxes
    for (final boxName in FinanceBoxes.allBoxNames) {
      await HiveMigration.createSnapshotBackup(boxName);
    }

    await AtomicWriter.instance.execute(() async {
      final workspaceBox = Hive.box<Workspace>(AppConstants.kWorkspacesBox);
      final accountBox = Hive.box<Account>(AppConstants.kAccountsBox);
      final expenseBox = Hive.box<Expense>(AppConstants.kExpensesBox);
      final incomeBox = Hive.box<Income>(AppConstants.kIncomesBox);
      final budgetBox = Hive.box<Budget>(AppConstants.kBudgetsBox);
      final futureExpenseBox = Hive.box<FutureExpense>(AppConstants.kFutureExpensesBox);
      final reminderBox = Hive.box<Reminder>(AppConstants.kRemindersBox);

      final now = DateTime.now();

      // 2. Ensure Default Workspace exists
      if (!workspaceBox.containsKey(kDefaultWorkspaceId)) {
        final defaultWorkspace = Workspace(
          id: kDefaultWorkspaceId,
          name: 'Personal',
          type: WorkspaceType.personal,
          currency: '₹',
          initialBalance: 0,
          createdAt: DateTime(2024, 1, 1),
          iconCodePoint: WorkspaceIcons.forType(WorkspaceType.personal).codePoint,
          colorValue: WorkspaceIcons.defaultColorForType(WorkspaceType.personal).toARGB32(),
          isDefault: true,
        );
        await workspaceBox.put(kDefaultWorkspaceId, defaultWorkspace);
      }

      // 3. Ensure Default Accounts exist
      Account? cashAccount = accountBox.get(kCashAccountId);
      if (cashAccount == null) {
        cashAccount = Account(
          id: kCashAccountId,
          workspaceId: kDefaultWorkspaceId,
          name: 'Cash Wallet',
          type: AccountType.cash,
          balancePaise: 0,
          iconCodePoint: AccountIcons.forType(AccountType.cash).codePoint,
          colorValue: AccountIcons.defaultColorForType(AccountType.cash).toARGB32(),
          isDefault: true,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: now,
        );
        await accountBox.put(kCashAccountId, cashAccount);
      }

      Account? bankAccount = accountBox.get(kBankAccountId);
      if (bankAccount == null) {
        bankAccount = Account(
          id: kBankAccountId,
          workspaceId: kDefaultWorkspaceId,
          name: 'Bank Account',
          type: AccountType.bankAccount,
          balancePaise: 0,
          iconCodePoint: AccountIcons.forType(AccountType.bankAccount).codePoint,
          colorValue: AccountIcons.defaultColorForType(AccountType.bankAccount).toARGB32(),
          isDefault: false,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: now,
        );
        await accountBox.put(kBankAccountId, bankAccount);
      }

      Account? upiAccount = accountBox.get(kUpiAccountId);
      if (upiAccount == null) {
        upiAccount = Account(
          id: kUpiAccountId,
          workspaceId: kDefaultWorkspaceId,
          name: 'UPI / GPay',
          type: AccountType.upi,
          balancePaise: 0,
          iconCodePoint: AccountIcons.forType(AccountType.upi).codePoint,
          colorValue: AccountIcons.defaultColorForType(AccountType.upi).toARGB32(),
          isDefault: false,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: now,
        );
        await accountBox.put(kUpiAccountId, upiAccount);
      }

      // 4. Backfill Expenses
      for (final exp in expenseBox.values) {
        bool changed = false;
        if (exp.workspaceId.isEmpty || exp.workspaceId == 'default_personal') {
          exp.workspaceId = kDefaultWorkspaceId;
          changed = true;
        }
        if (exp.accountId.isEmpty || exp.accountId == 'acc_default_cash') {
          if (exp.paymentMethod.toLowerCase().contains('upi')) {
            exp.accountId = kUpiAccountId;
          } else {
            exp.accountId = kCashAccountId;
          }
          changed = true;
        }
        if (changed) {
          await exp.save();
        }
      }

      // 5. Backfill Incomes & Calculate Historical Confirmed Total
      int bankIncomePaise = 0;
      for (final inc in incomeBox.values) {
        bool changed = false;
        if (inc.workspaceId.isEmpty || inc.workspaceId == 'default_personal') {
          inc.workspaceId = kDefaultWorkspaceId;
          changed = true;
        }
        if (inc.accountId.isEmpty || inc.accountId == 'acc_default_bank') {
          inc.accountId = kBankAccountId;
          changed = true;
        }
        if (inc.isConfirmed) {
          bankIncomePaise += inc.amount;
        }
        if (changed) {
          await inc.save();
        }
      }

      // 6. Backfill Budgets
      for (final b in budgetBox.values) {
        if (b.workspaceId.isEmpty || b.workspaceId == 'default_personal') {
          b.workspaceId = kDefaultWorkspaceId;
          await b.save();
        }
      }

      // 7. Backfill Future Expenses
      for (final fe in futureExpenseBox.values) {
        if (fe.workspaceId.isEmpty || fe.workspaceId == 'default_personal') {
          fe.workspaceId = kDefaultWorkspaceId;
          await fe.save();
        }
      }

      // 8. Backfill Reminders
      for (final r in reminderBox.values) {
        if (r.workspaceId.isEmpty || r.workspaceId == 'default_personal') {
          r.workspaceId = kDefaultWorkspaceId;
          await r.save();
        }
      }

      // 9. Initialize Bank balance with historical confirmed income if account is newly initialized
      if (bankAccount.balancePaise == 0 && bankIncomePaise > 0) {
        bankAccount.balancePaise = bankIncomePaise;
        await bankAccount.save();
      }

      // 10. Mark migration complete and set active workspace
      await AppStateBox.setActiveWorkspaceId(kDefaultWorkspaceId);
      await appState.put(kMigrationKey, true);

      // 11. Flush all modified boxes
      await Future.wait([
        workspaceBox.flush(),
        accountBox.flush(),
        expenseBox.flush(),
        incomeBox.flush(),
        budgetBox.flush(),
        futureExpenseBox.flush(),
        reminderBox.flush(),
        appState.flush(),
      ]);

      debugPrint('MultiProfileMigration: Migration completed successfully.');
    });
  }
}

