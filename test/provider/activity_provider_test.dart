import 'package:flutter_test/flutter_test.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/provider/activity_provider.dart';
import 'package:expense/services/activity_service.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/repositories/future_expense_repository.dart';
import 'package:expense/services/reports_data_service.dart';

class FakeExpenseRepository implements ExpenseRepository {
  final List<Expense> list = [];

  @override
  Future<List<Expense>> getAll() async => list;

  @override
  Future<List<Expense>> getAllExpenses() async => list;

  @override
  Stream<void> watch() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

class FakeIncomeRepository implements IncomeRepository {
  final List<Income> list = [];

  @override
  Future<List<Income>> getAll() async => list;

  @override
  Stream<void> watch() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

class FakeFutureExpenseRepository implements FutureExpenseRepository {
  final List<FutureExpense> list = [];

  @override
  Future<List<FutureExpense>> getAll() async => list;

  @override
  Stream<void> watch() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

void main() {
  test('ActivityProvider filters expenses, incomes, and planned correctly', () async {
    final expRepo = FakeExpenseRepository();
    final incRepo = FakeIncomeRepository();
    final futRepo = FakeFutureExpenseRepository();
    final reportService = ReportsDataService();

    final expensesProvider = ExpensesProvider(expRepo, reportService);
    final incomeProvider = IncomeProvider(incRepo);
    final futureExpensesProvider = FutureExpensesProvider(futRepo, expRepo);
    final activityService = ActivityService();

    final provider = ActivityProvider(
      service: activityService,
      expensesProvider: expensesProvider,
      incomeProvider: incomeProvider,
      futureExpensesProvider: futureExpensesProvider,
    );

    // Setup dates
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12, 0);
    final lastWeek = now.subtract(const Duration(days: 10));

    final e1 = Expense(productName: 'Lunch', amount: 15000, date: today, category: 'Food');
    final e2 = Expense(productName: 'Rent', amount: 1000000, date: lastWeek, category: 'Rent');
    
    expRepo.list.addAll([e1, e2]);
    await expensesProvider.load();

    // 1. Check Today timely filter
    final todayCriteria = const FilterCriteria(categories: {'Today'});
    final filteredToday = provider.filtered(expensesProvider.allExpenses, todayCriteria);
    expect(filteredToday.length, 1);
    expect(filteredToday.first.productName, 'Lunch');

    // 2. Check High Spend filter (should show at least top 5, or here all 2 since total is < 5)
    final highSpendCriteria = const FilterCriteria(categories: {'High Spend'});
    final filteredHigh = provider.filtered(expensesProvider.allExpenses, highSpendCriteria);
    // Since there are only 2 expenses, it should retain both because minimum is 5
    expect(filteredHigh.length, 2);
  });
}
