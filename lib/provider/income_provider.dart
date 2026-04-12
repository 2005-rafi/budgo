import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/income.dart';
import 'finance_boxes.dart';

class IncomeProvider extends ChangeNotifier {
  List<Income> _items = [];
  StreamSubscription<BoxEvent>? _sub;

  List<Income> get items => List.unmodifiable(_items);

  double get totalConfirmed =>
      _items.where((i) => i.isConfirmed).fold<double>(0, (sum, i) => sum + i.amount);

  double get totalAll =>
      _items.fold<double>(0, (sum, i) => sum + i.amount);

  IncomeProvider() {
    _sub = FinanceBoxes.incomes.watch().listen((_) => load());
  }

  Future<void> load() async {
    _items = FinanceBoxes.incomes.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  double confirmedTotalBetween(DateTime start, DateTime endInclusive) {
    return _items
        .where((i) =>
            i.isConfirmed &&
            !i.date.isBefore(start) &&
            !i.date.isAfter(endInclusive))
        .fold<double>(0, (sum, i) => sum + i.amount);
  }

  Future<void> addIncomeDraft(Income income) async {
    final draft = Income(
      id: income.id,
      source: income.source,
      amount: income.amount,
      date: income.date,
      description: income.description,
      isConfirmed: false,
    );
    await FinanceBoxes.incomes.add(draft);
    await load();
  }

  Future<void> confirmIncome(Income income) async {
    income.isConfirmed = true;
    await income.save();
    await load();
  }

  Future<void> deleteIncome(Income income) async {
    await income.delete();
    await load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
