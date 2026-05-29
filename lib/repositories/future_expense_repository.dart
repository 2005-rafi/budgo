import 'package:hive/hive.dart';
import '../core/app_exception.dart';
import '../models/future_expense.dart';

/// Repository interface for managing planned/wishlist [FutureExpense] records.
abstract class FutureExpenseRepository {
  /// Retrieves all future expenses, sorted by priority (1=highest) ascending,
  /// then by due date ascending, and finally alphabetically by title.
  /// Throws [StorageException] if retrieval fails.
  Future<List<FutureExpense>> getAll();

  /// Adds a new planned expense to storage.
  /// Rounds any estimated cost or purchased amount to 2 decimal places before saving.
  /// Throws [StorageException] if the write operation fails.
  Future<void> add(FutureExpense item);

  /// Updates an existing planned expense record.
  /// Rounds estimated cost and purchased amount to 2 decimal places before saving.
  /// Throws [StorageException] if the item is not persistent in the box or saving fails.
  Future<void> update(FutureExpense item);

  /// Deletes a planned expense from storage.
  /// Does nothing if the item is not in the box.
  /// Throws [StorageException] if deletion fails.
  Future<void> delete(FutureExpense item);

  /// Resets the purchase status and links of all purchased wishlist items.
  /// Sets `isPurchased = false`, `linkedExpenseKey = null`, `purchasedAmount = null`, and `purchasedAt = null`.
  /// Used to sync the wishlist after resetting all expenses in Settings.
  /// Throws [StorageException] if saving changes fails.
  Future<void> resetAllLinkedStates();

  /// Emits a stream of void events whenever the box changes.
  Stream<void> watch();
}

/// Hive implementation of [FutureExpenseRepository].
class HiveFutureExpenseRepository implements FutureExpenseRepository {
  Box<FutureExpense> get _box => Hive.box<FutureExpense>('future_expenses');

  HiveFutureExpenseRepository();

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<List<FutureExpense>> getAll() async {
    try {
      final list = _box.values.toList();
      list.sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        if (p != 0) return p;

        final ad = a.dueDate ?? DateTime(9999);
        final bd = b.dueDate ?? DateTime(9999);
        final d = ad.compareTo(bd);
        if (d != 0) return d;

        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      return list;
    } catch (e) {
      throw StorageException('Failed to read future expenses: $e');
    }
  }

  @override
  Future<void> add(FutureExpense item) async {
    try {
      await _box.add(item);
      await _box.flush();
    } catch (e) {
      throw StorageException('Failed to add future expense: $e');
    }
  }

  @override
  Future<void> update(FutureExpense item) async {
    try {
      if (item.isInBox) {
        await item.save();
        await _box.flush();
      } else {
        throw StorageException('Item is not in the box to be updated.');
      }
    } catch (e) {
      throw StorageException('Failed to update future expense: $e');
    }
  }

  @override
  Future<void> delete(FutureExpense item) async {
    try {
      if (item.isInBox) {
        await item.delete();
        await _box.flush();
      }
    } catch (e) {
      throw StorageException('Failed to delete future expense: $e');
    }
  }

  @override
  Future<void> resetAllLinkedStates() async {
    try {
      bool modified = false;
      for (final item in _box.values) {
        if (item.isPurchased) {
          item.isPurchased = false;
          item.linkedExpenseKey = null;
          item.purchasedAmount = null;
          item.purchasedAt = null;
          await item.save();
          modified = true;
        }
      }
      if (modified) {
        await _box.flush();
      }
    } catch (e) {
      throw StorageException('Failed to reset linked states: $e');
    }
  }
}
