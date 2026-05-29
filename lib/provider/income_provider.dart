import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/core/app_exception.dart';
import 'package:expense/core/atomic_writer.dart';
import '../models/income.dart';

class IncomeProvider extends ChangeNotifier {
  final IncomeRepository _repository;
  final LinkedHashMap<String, Income> _itemMap = LinkedHashMap<String, Income>();
  // ignore: unused_field
  StreamSubscription<void>? _boxSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  int _cachedConfirmedTotal = 0;
  int _cachedAllTotal = 0;
  bool _skipNextWatch = false;

  UnmodifiableListView<Income> get items => UnmodifiableListView(_itemMap.values);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalConfirmed => _cachedConfirmedTotal;
  int get totalAll => _cachedAllTotal;

  IncomeProvider(this._repository);

  Future<void> initialize() async {
    _boxSubscription ??= _repository.watch().listen((_) {
      if (_skipNextWatch) {
        _skipNextWatch = false;
        return;
      }
      load();
    });
    await load();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _repository.getAll();
      _itemMap.clear();
      for (var item in list) {
        _itemMap[item.id] = item;
      }
      _recomputeCachedTotals();
      _errorMessage = null;
    } on StorageException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _recomputeCachedTotals() {
    int confirmedTotal = 0;
    int allTotal = 0;
    for (var item in _itemMap.values) {
      allTotal += item.amount;
      if (item.isConfirmed) {
        confirmedTotal += item.amount;
      }
    }
    _cachedConfirmedTotal = confirmedTotal;
    _cachedAllTotal = allTotal;
  }

  int confirmedTotalBetween(DateTime start, DateTime endInclusive) {
    return _itemMap.values
        .where((i) =>
            i.isConfirmed &&
            !i.date.isBefore(start) &&
            !i.date.isAfter(endInclusive))
        .fold<int>(0, (sum, i) => sum + i.amount);
  }

  int confirmedForMonth(DateTime date) {
    return _repository.confirmedForMonth(date);
  }

  Future<Income> addIncome(Income income) async {
    _skipNextWatch = true;
    await AtomicWriter.instance.execute(() async {
      await _repository.add(income);
      
      final list = _itemMap.values.toList();
      int idx = list.indexWhere((e) => e.date.isBefore(income.date));
      if (idx == -1) {
        list.add(income);
      } else {
        list.insert(idx, income);
      }
      _itemMap.clear();
      for (var item in list) {
        _itemMap[item.id] = item;
      }
      _recomputeCachedTotals();
    });
    notifyListeners();
    return income;
  }

  @Deprecated('Use addIncome instead')
  Future<void> addIncomeDraft(Income income) async {
    await addIncome(income);
  }

  Future<void> updateIncome(Income income) async {
    _skipNextWatch = true;
    await AtomicWriter.instance.execute(() async {
      if (income.isInBox) {
        await income.save();
        _itemMap[income.id] = income;
        _recomputeCachedTotals();
      }
    });
    notifyListeners();
  }

  Future<void> confirmIncome(Income income) async {
    await confirmSingle(income);
  }

  Future<void> confirmSingle(Income income) async {
    _skipNextWatch = true;
    await AtomicWriter.instance.execute(() async {
      await _repository.confirm(income);
      
      if (_itemMap.containsKey(income.id)) {
        final oldItem = _itemMap[income.id]!;
        if (!oldItem.isConfirmed) {
          income.isConfirmed = true;
          _itemMap[income.id] = income;
          _cachedConfirmedTotal += income.amount;
        }
      }
    });
    notifyListeners();
  }

  Future<void> deleteIncome(Income income) async {
    _skipNextWatch = true;
    await AtomicWriter.instance.execute(() async {
      await _repository.delete(income);
      
      if (_itemMap.containsKey(income.id)) {
        _itemMap.remove(income.id);
        _recomputeCachedTotals();
      }
    });
    notifyListeners();
  }
}
