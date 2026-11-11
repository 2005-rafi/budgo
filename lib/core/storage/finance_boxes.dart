import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';

import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/job_record.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_journal_entry.dart';

class FinanceBoxes {
  static const String expensesBoxName = AppConstants.kExpensesBox;
  static const String incomesBoxName = AppConstants.kIncomesBox;
  static const String futureExpensesBoxName = AppConstants.kFutureExpensesBox;
  static const String budgetsBoxName = AppConstants.kBudgetsBox;
  static const String remindersBoxName = AppConstants.kRemindersBox;
  static const String jobsBoxName = AppConstants.kJobsBox;
  static const String appStateBoxName = AppConstants.kAppStateBox;
  static const String workspacesBoxName = AppConstants.kWorkspacesBox;
  static const String accountsBoxName = AppConstants.kAccountsBox;
  static const String transfersBoxName = AppConstants.kTransfersBox;
  static const String transferJournalBoxName = AppConstants.kTransferJournalBox;
  static const String vaultsBoxName = AppConstants.kVaultsBox;

  static const List<String> allBoxNames = [
    expensesBoxName,
    incomesBoxName,
    futureExpensesBoxName,
    budgetsBoxName,
    remindersBoxName,
    jobsBoxName,
    appStateBoxName,
    workspacesBoxName,
    accountsBoxName,
    transfersBoxName,
    transferJournalBoxName,
    vaultsBoxName,
  ];

  static Box<Expense> get expenses => Hive.box<Expense>(expensesBoxName);
  static Box<Income> get incomes => Hive.box<Income>(incomesBoxName);
  static Box<FutureExpense> get futureExpenses =>
      Hive.box<FutureExpense>(futureExpensesBoxName);
  static Box<Budget> get budgets => Hive.box<Budget>(budgetsBoxName);
  static Box<Reminder> get reminders => Hive.box<Reminder>(remindersBoxName);
  static Box<JobRecord> get jobs => Hive.box<JobRecord>(jobsBoxName);
  static Box<Workspace> get workspaces => Hive.box<Workspace>(workspacesBoxName);
  static Box<Account> get accounts => Hive.box<Account>(accountsBoxName);
  static Box<Transfer> get transfers => Hive.box<Transfer>(transfersBoxName);
  static Box<TransferJournalEntry> get transferJournal =>
      Hive.box<TransferJournalEntry>(transferJournalBoxName);
  static Box<SavingsVault> get vaults => Hive.box<SavingsVault>(vaultsBoxName);

  static const String activeBudgetKey = AppConstants.kActiveBudgetKey;
  static const String activeWorkspaceIdKey = AppConstants.kActiveWorkspaceIdKey;
}
