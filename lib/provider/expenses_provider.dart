import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';
import 'finance_boxes.dart';

class ExpensesProvider extends ChangeNotifier {
  List<Expense> _items = [];
  StreamSubscription<BoxEvent>? _sub;

  List<Expense> get items => List.unmodifiable(_items);

  double get total =>
      _items.fold<double>(0, (sum, e) => sum + e.amount);

  ExpensesProvider() {
    _sub = FinanceBoxes.expenses.watch().listen((_) => load());
  }

  Future<void> load() async {
    _items = FinanceBoxes.expenses.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await FinanceBoxes.expenses.add(expense);
    // load() will be triggered by watch(), but calling it is fine too.
    await load();
  }

  Future<void> updateExpense(Expense expense) async {
    await expense.save();
    await load();
  }

  Future<void> deleteExpense(Expense expense) async {
    await expense.delete();
    await load();
  }

  double totalBetween(DateTime start, DateTime endInclusive) {
    return _items
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(endInclusive))
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
