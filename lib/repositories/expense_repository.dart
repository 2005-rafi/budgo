import 'dart:math';
import 'package:hive/hive.dart';
import '../core/app_exception.dart';
import '../models/expense.dart';
import '../core/atomic_writer.dart';

/// Repository interface for managing [Expense] records.
abstract class ExpenseRepository {
  /// Retrieves all non-archived expenses, sorted by date in descending order.
  /// Throws [StorageException] if the retrieval fails.
  Future<List<Expense>> getAll();

  /// Retrieves expenses within a date range (inclusive), sorted by date descending.
  Future<List<Expense>> getRange(DateTime from, DateTime to);

  /// Retrieves all expenses (including archived ones), sorted by date in descending order.
  /// Throws [StorageException] if the retrieval fails.
  Future<List<Expense>> getAllExpenses();

  /// Retrieves all archived expenses, sorted by date in descending order.
  /// Throws [StorageException] if the retrieval fails.
  Future<List<Expense>> getArchived();

  /// Soft archives all expenses older than the specified date.
  /// Throws [StorageException] if the archive operation fails.
  Future<void> archiveOlderThan(DateTime date);

  /// Adds a new expense record to storage.
  /// Rounds the amount to 2 decimal places before saving to avoid precision errors.
  /// Returns the assigned integer key.
  /// Throws [StorageException] if the write operation fails.
  Future<int> add(Expense expense);

  /// Updates an existing expense record at the given [key].
  /// Rounds the amount to 2 decimal places before saving.
  /// Throws [StorageException] if the update fails.
  Future<void> update(int key, Expense expense);

  /// Deletes an expense record at the given [key].
  /// Does nothing if the key does not exist.
  /// Throws [StorageException] if the delete fails.
  Future<void> delete(int key);

  /// Clears all expense records from storage.
  /// Throws [StorageException] if the operation fails.
  Future<void> deleteAll();

  /// Calculates the sum of expense amounts between [start] and [end] (inclusive).
  int totalBetween(List<Expense> expenses, DateTime start, DateTime end);

  /// Emits a stream of void events whenever the box changes.
  Stream<void> watch();

  /// Retrieves a page of non-archived expenses.
  Future<List<Expense>> getPage(int offset, int limit);
}

/// Hive implementation of [ExpenseRepository].
class HiveExpenseRepository implements ExpenseRepository {
  final Box<Expense> _box;

  HiveExpenseRepository(this._box);

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<List<Expense>> getPage(int offset, int limit) async {
    try {
      final list = _box.values.where((e) => e.isArchived != true).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      if (offset >= list.length) return [];
      return list.sublist(offset, min(offset + limit, list.length));
    } catch (e) {
      throw StorageException('Failed to read page: $e');
    }
  }

  @override
  Future<List<Expense>> getAll() async {
    try {
      final list = _box.values.where((e) => e.isArchived != true).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      throw StorageException('Failed to read expenses: $e');
    }
  }

  @override
  Future<List<Expense>> getRange(DateTime from, DateTime to) async {
    try {
      final start = DateTime(from.year, from.month, from.day);
      final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
      final list = _box.values
          .where((e) => !e.isArchived && !e.date.isBefore(start) && !e.date.isAfter(end))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      throw StorageException('Failed to read expense range: $e');
    }
  }

  @override
  Future<List<Expense>> getAllExpenses() async {
    try {
      final list = _box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      throw StorageException('Failed to read all expenses: $e');
    }
  }

  @override
  Future<List<Expense>> getArchived() async {
    try {
      final list = _box.values.where((e) => e.isArchived == true).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      throw StorageException('Failed to read archived expenses: $e');
    }
  }

  @override
  Future<void> archiveOlderThan(DateTime date) async {
    await AtomicWriter.instance.execute(() async {
      try {
        bool modified = false;
        for (var expense in _box.values) {
          if (expense.date.isBefore(date) && expense.isArchived != true) {
            expense.isArchived = true;
            await expense.save();
            modified = true;
          }
        }
        if (modified) {
          await _box.flush();
        }
      } catch (e) {
        throw StorageException('Failed to archive expenses: $e');
      }
    });
  }

  @override
  Future<int> add(Expense expense) async {
    return await AtomicWriter.instance.execute(() async {
      try {
        final key = await _box.add(expense);
        await _box.flush();
        return key;
      } catch (e) {
        throw StorageException('Failed to add expense: $e');
      }
    });
  }

  @override
  Future<void> update(int key, Expense expense) async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.put(key, expense);
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to update expense: $e');
      }
    });
  }

  @override
  Future<void> delete(int key) async {
    await AtomicWriter.instance.execute(() async {
      try {
        if (_box.containsKey(key)) {
          await _box.delete(key);
          await _box.flush();
        }
      } catch (e) {
        throw StorageException('Failed to delete expense: $e');
      }
    });
  }

  @override
  Future<void> deleteAll() async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.clear();
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to clear expenses: $e');
      }
    });
  }

  @override
  int totalBetween(List<Expense> expenses, DateTime start, DateTime end) {
    return expenses
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .fold<int>(0, (sum, e) => sum + e.amount);
  }
}
