import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/expense.dart';
import '../models/future_expense.dart';
import 'expenses_provider.dart';
import 'finance_boxes.dart';

class FutureExpensesProvider extends ChangeNotifier {
  List<FutureExpense> _items = [];
  StreamSubscription<BoxEvent>? _sub;

  ExpensesProvider? _expensesProvider;

  FutureExpensesProvider() {
    _sub = FinanceBoxes.futureExpenses.watch().listen((_) => load());
  }

  void attachExpenses(ExpensesProvider expensesProvider) {
    _expensesProvider = expensesProvider;
  }

  List<FutureExpense> get items => List.unmodifiable(_items);

  List<FutureExpense> get planned =>
      _items.where((e) => !e.isPurchased).toList()..sort(_wishlistSort);

  List<FutureExpense> get purchased =>
      _items.where((e) => e.isPurchased).toList()..sort(_wishlistSort);

  double get totalPlannedEstimated =>
      planned.fold<double>(0, (sum, e) => sum + (e.estimatedCost ?? 0));

  Future<void> load() async {
    _items = FinanceBoxes.futureExpenses.values.toList()..sort(_wishlistSort);
    notifyListeners();
  }

  Future<void> addFutureExpense(FutureExpense item) async {
    await FinanceBoxes.futureExpenses.add(item);
    await load();
  }

  /// Converts a wishlist item into a real Expense and marks as purchased.
  /// - Creates an Expense only once (uses linkedExpenseKey).
  Future<void> purchase(
    FutureExpense item, {
    required double amount,
    DateTime? purchasedAt,
  }) async {
    // Already linked -> do not duplicate
    if (item.linkedExpenseKey != null) {
      item.isPurchased = true;
      item.purchasedAmount = amount;
      item.purchasedAt = purchasedAt ?? DateTime.now();
      await item.save();
      await load();
      return;
    }

    final expense = Expense(
      productName: item.title,
      amount: amount,
      category: item.category,
      date: purchasedAt ?? DateTime.now(),
    );

    // Add to expenses box and store returned key in FutureExpense
    final int expenseKey = await FinanceBoxes.expenses.add(expense); // returns int key [web:458][web:454]

    item.isPurchased = true;
    item.linkedExpenseKey = expenseKey;
    item.purchasedAmount = amount;
    item.purchasedAt = purchasedAt ?? DateTime.now();

    await item.save();
    await load();

    // Optional: refresh expenses provider (if you also show via provider list)
    await _expensesProvider?.load();
  }

  /// Optional: Undo purchase (also deletes linked Expense to keep data consistent).
  Future<void> undoPurchase(FutureExpense item) async {
    final key = item.linkedExpenseKey;
    if (key != null) {
      await FinanceBoxes.expenses.delete(key);
    }

    item.isPurchased = false;
    item.linkedExpenseKey = null;
    item.purchasedAmount = null;
    item.purchasedAt = null;

    await item.save();
    await load();
    await _expensesProvider?.load();
  }

  Future<void> deleteFutureExpense(FutureExpense item) async {
    await item.delete();
    await load();
  }

  static int _wishlistSort(FutureExpense a, FutureExpense b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;

    final ad = a.dueDate ?? DateTime(9999);
    final bd = b.dueDate ?? DateTime(9999);
    final d = ad.compareTo(bd);
    if (d != 0) return d;

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
