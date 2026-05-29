import 'package:hive/hive.dart';
import '../core/app_constants.dart';
import '../core/app_exception.dart';
import '../models/budget.dart';
import '../core/atomic_writer.dart';

/// Repository interface for managing [Budget] records.
abstract class BudgetRepository {
  /// Retrieves the active budget from storage.
  /// Returns `null` if no active budget is configured.
  /// Throws [StorageException] if retrieval fails.
  Future<Budget?> getActiveBudget();

  /// Saves or overwrites the active budget in storage.
  /// Rounds the budget limit to 2 decimal places before saving to avoid precision errors.
  /// Throws [StorageException] if the write operation fails.
  Future<void> saveActiveBudget(Budget budget);

  /// Clears/deletes the active budget from storage.
  /// Throws [StorageException] if clearing fails.
  Future<void> clearActiveBudget();

  /// Emits a stream of void events whenever the box changes.
  Stream<void> watch();
}

/// Hive implementation of [BudgetRepository].
class HiveBudgetRepository implements BudgetRepository {
  final Box<Budget> _box;

  HiveBudgetRepository(this._box);

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<Budget?> getActiveBudget() async {
    try {
      return _box.get(AppConstants.kActiveBudgetKey);
    } catch (e) {
      throw StorageException('Failed to read active budget: $e');
    }
  }

  @override
  Future<void> saveActiveBudget(Budget budget) async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.put(AppConstants.kActiveBudgetKey, budget);
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to save active budget: $e');
      }
    });
  }

  @override
  Future<void> clearActiveBudget() async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.delete(AppConstants.kActiveBudgetKey);
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to clear active budget: $e');
      }
    });
  }
}
