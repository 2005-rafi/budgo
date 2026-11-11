import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/models/income.dart';

class IncomeProvider extends ChangeNotifier {
  final IncomeRepository _repository;
  final LinkedHashMap<String, Income> _itemMap = LinkedHashMap<String, Income>();
  // ignore: unused_field
  StreamSubscription<void>? _boxSubscription;

  bool _isLoading = false;
  String _activeWorkspaceId = 'default_personal';
  String? _errorMessage;
  int _cachedConfirmedTotal = 0;
  int _cachedAllTotal = 0;
  bool _skipNextWatch = false;

  String _normWs(String ws) => ws.isEmpty ? 'default_personal' : ws;

  UnmodifiableListView<Income> get items => UnmodifiableListView(
        _itemMap.values.where((i) => _normWs(i.workspaceId) == _activeWorkspaceId),
      );
  UnmodifiableListView<Income> get allIncomes => UnmodifiableListView(_itemMap.values);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalConfirmed => _cachedConfirmedTotal;
  int get totalAll => _cachedAllTotal;
  String get activeWorkspaceId => _activeWorkspaceId;

  IncomeProvider(this._repository);

  void setActiveWorkspace(String workspaceId) {
    final norm = _normWs(workspaceId);
    if (_activeWorkspaceId == norm) return;
    _activeWorkspaceId = norm;
    _recomputeCachedTotals();
    notifyListeners();
  }

  Future<void> initialize({String? initialWorkspaceId}) async {
    if (initialWorkspaceId != null && initialWorkspaceId.isNotEmpty) {
      _activeWorkspaceId = _normWs(initialWorkspaceId);
    }
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
      _errorMessage = AppErrorTranslator.translate(e).title;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _recomputeCachedTotals() {
    int confirmedTotal = 0;
    int allTotal = 0;
    for (var item in _itemMap.values) {
      if (_normWs(item.workspaceId) == _activeWorkspaceId) {
        allTotal += item.amount;
        if (item.isConfirmed) {
          confirmedTotal += item.amount;
        }
      }
    }
    _cachedConfirmedTotal = confirmedTotal;
    _cachedAllTotal = allTotal;
  }

  int confirmedTotalBetween(
    DateTime start,
    DateTime endInclusive, {
    String? workspaceId,
  }) {
    final targetWs = workspaceId != null && workspaceId.isNotEmpty
        ? _normWs(workspaceId)
        : _activeWorkspaceId;
    return _itemMap.values
        .where((i) =>
            _normWs(i.workspaceId) == targetWs &&
            i.isConfirmed &&
            !i.date.isBefore(start) &&
            !i.date.isAfter(endInclusive))
        .fold<int>(0, (sum, i) => sum + i.amount);
  }

  int confirmedForMonth(DateTime date, {String? workspaceId}) {
    final targetWs = workspaceId != null && workspaceId.isNotEmpty
        ? _normWs(workspaceId)
        : _activeWorkspaceId;
    if (_repository is HiveIncomeRepository) {
      return _repository.confirmedForMonthInWorkspace(date, targetWs);
    }
    return _itemMap.values
        .where((i) =>
            _normWs(i.workspaceId) == targetWs &&
            i.isConfirmed &&
            i.date.year == date.year &&
            i.date.month == date.month)
        .fold<int>(0, (sum, i) => sum + i.amount);
  }

  Future<Income> addIncome(Income income) async {
    _skipNextWatch = true;
    if (income.workspaceId.isEmpty) {
      income.workspaceId = _activeWorkspaceId;
    }
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
          if (_normWs(income.workspaceId) == _activeWorkspaceId) {
            _cachedConfirmedTotal += income.amount;
          }
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
