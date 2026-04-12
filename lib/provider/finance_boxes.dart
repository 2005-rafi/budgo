import 'package:hive/hive.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../models/future_expense.dart';
import '../models/budget.dart';

class FinanceBoxes {
  static const String expensesBoxName = 'expenses';
  static const String incomesBoxName = 'incomes';
  static const String futureExpensesBoxName = 'future_expenses';
  static const String budgetsBoxName = 'budgets';

  static Box<Expense> get expenses => Hive.box<Expense>(expensesBoxName);
  static Box<Income> get incomes => Hive.box<Income>(incomesBoxName);
  static Box<FutureExpense> get futureExpenses =>
      Hive.box<FutureExpense>(futureExpensesBoxName);
  static Box<Budget> get budgets => Hive.box<Budget>(budgetsBoxName);

  static const String activeBudgetKey = 'active_budget';
}
