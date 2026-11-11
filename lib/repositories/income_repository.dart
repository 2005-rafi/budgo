import 'package:hive/hive.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/income.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/constants/app_constants.dart';

/// Repository interface for managing [Income] records.
abstract class IncomeRepository {
  /// Retrieves all incomes, sorted by date in descending order.
  /// Throws [StorageException] if retrieval fails.
  Future<List<Income>> getAll();

  /// Adds a new income record.
  /// Rounds the amount to 2 decimal places before saving to avoid precision errors.
  /// Throws [StorageException] if the write operation fails.
  Future<void> add(Income income);

  /// Confirms a pending income record.
  /// Marks [income.isConfirmed] as true and saves.
  /// Throws [StorageException] if the record is not in the box or saving fails.
  Future<void> confirm(Income income);

  /// Deletes an income record.
  /// Does nothing if the record is not in the box.
  /// Throws [StorageException] if deletion fails.
  Future<void> delete(Income income);

  /// Calculates the sum of confirmed income amounts.
  int confirmedTotal(List<Income> incomes);

  /// Retrieves the confirmed income total for a specific month.
  int confirmedForMonth(DateTime date);

  /// Emits a stream of void events whenever the box changes.
  Stream<void> watch();
}

/// Hive implementation of [IncomeRepository].
class HiveIncomeRepository implements IncomeRepository {
  final Box<Income>? _injectedBox;

  HiveIncomeRepository([this._injectedBox]);

  Box<Income> get _box =>
      _injectedBox ?? Hive.box<Income>(AppConstants.kIncomesBox);

  @override
  Stream<void> watch() => _box.watch();

  // Partitioned by workspaceId -> (monthKey -> confirmedPaise)
  final Map<String, Map<int, int>> _confirmedMonthTotalsByWs = {};
  bool _isTotalsInitialized = false;

  String _normWs(String workspaceId) =>
      workspaceId.isEmpty ? AppConstants.kDefaultWorkspaceId : workspaceId;

  void _ensureTotalsInitialized() {
    if (_isTotalsInitialized) return;
    _confirmedMonthTotalsByWs.clear();
    for (final income in _box.values) {
      if (income.isConfirmed) {
        final ws = _normWs(income.workspaceId);
        final monthKey = income.date.year * 100 + income.date.month;
        final wsMap = _confirmedMonthTotalsByWs.putIfAbsent(ws, () => {});
        wsMap[monthKey] = (wsMap[monthKey] ?? 0) + income.amount;
      }
    }
    _isTotalsInitialized = true;
  }

  @override
  int confirmedForMonth(DateTime date) {
    _ensureTotalsInitialized();
    final monthKey = date.year * 100 + date.month;
    int total = 0;
    for (final wsMap in _confirmedMonthTotalsByWs.values) {
      total += wsMap[monthKey] ?? 0;
    }
    return total;
  }

  /// Workspace-isolated monthly confirmed income lookup (O(1) hash hit).
  int confirmedForMonthInWorkspace(DateTime date, String workspaceId) {
    _ensureTotalsInitialized();
    final monthKey = date.year * 100 + date.month;
    return _confirmedMonthTotalsByWs[_normWs(workspaceId)]?[monthKey] ?? 0;
  }

  @override
  Future<List<Income>> getAll() async {
    try {
      final list = _box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      _isTotalsInitialized = false;
      _ensureTotalsInitialized();
      return list;
    } catch (e) {
      throw StorageException('Failed to read incomes: $e');
    }
  }

  @override
  Future<void> add(Income income) async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.add(income);
        await _box.flush();
        _ensureTotalsInitialized();
        if (income.isConfirmed) {
          final ws = _normWs(income.workspaceId);
          final monthKey = income.date.year * 100 + income.date.month;
          final wsMap = _confirmedMonthTotalsByWs.putIfAbsent(ws, () => {});
          wsMap[monthKey] = (wsMap[monthKey] ?? 0) + income.amount;
        }
      } catch (e) {
        throw StorageException('Failed to add income: $e');
      }
    });
  }

  @override
  Future<void> confirm(Income income) async {
    await AtomicWriter.instance.execute(() async {
      try {
        final wasConfirmed = income.isConfirmed;
        income.isConfirmed = true;
        await income.save();
        await _box.flush();

        if (!wasConfirmed) {
          _ensureTotalsInitialized();
          final ws = _normWs(income.workspaceId);
          final monthKey = income.date.year * 100 + income.date.month;
          final wsMap = _confirmedMonthTotalsByWs.putIfAbsent(ws, () => {});
          wsMap[monthKey] = (wsMap[monthKey] ?? 0) + income.amount;
        }
      } catch (e) {
        throw StorageException('Failed to confirm income: $e');
      }
    });
  }

  @override
  Future<void> delete(Income income) async {
    await AtomicWriter.instance.execute(() async {
      try {
        final isConfirmed = income.isConfirmed;
        final amount = income.amount;
        final date = income.date;
        final ws = _normWs(income.workspaceId);

        await income.delete();
        await _box.flush();

        if (isConfirmed) {
          _ensureTotalsInitialized();
          final monthKey = date.year * 100 + date.month;
          final wsMap = _confirmedMonthTotalsByWs[ws];
          if (wsMap != null) {
            final next = (wsMap[monthKey] ?? 0) - amount;
            if (next <= 0) {
              wsMap.remove(monthKey);
            } else {
              wsMap[monthKey] = next;
            }
          }
        }
      } catch (e) {
        throw StorageException('Failed to delete income: $e');
      }
    });
  }

  @override
  int confirmedTotal(List<Income> incomes) {
    return incomes
        .where((i) => i.isConfirmed)
        .fold<int>(0, (sum, i) => sum + i.amount);
  }
}
