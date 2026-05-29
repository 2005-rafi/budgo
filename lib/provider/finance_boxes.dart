import 'package:hive/hive.dart';
import 'package:expense/core/app_constants.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../models/future_expense.dart';
import '../models/budget.dart';
import '../models/job_record.dart';

class FinanceBoxes {
  static const String expensesBoxName = AppConstants.kExpensesBox;
  static const String incomesBoxName = AppConstants.kIncomesBox;
  static const String futureExpensesBoxName = AppConstants.kFutureExpensesBox;
  static const String budgetsBoxName = AppConstants.kBudgetsBox;
  static const String remindersBoxName = 'reminders';
  static const String jobsBoxName = 'jobs';
  static const String appStateBoxName = 'app_state';

  static const List<String> allBoxNames = [
    expensesBoxName,
    incomesBoxName,
    futureExpensesBoxName,
    budgetsBoxName,
    remindersBoxName,
    jobsBoxName,
    appStateBoxName,
  ];

  static Box<Expense> get expenses => Hive.box<Expense>(expensesBoxName);
  static Box<Income> get incomes => Hive.box<Income>(incomesBoxName);
  static Box<FutureExpense> get futureExpenses =>
      Hive.box<FutureExpense>(futureExpensesBoxName);
  static Box<Budget> get budgets => Hive.box<Budget>(budgetsBoxName);
  static Box<JobRecord> get jobs => Hive.box<JobRecord>(jobsBoxName);

  static const String activeBudgetKey = AppConstants.kActiveBudgetKey;
}
