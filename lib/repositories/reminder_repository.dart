import 'package:hive/hive.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/constants/app_constants.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> getAll();
  Future<void> add(Reminder reminder);
  Future<void> update(Reminder reminder);
  Future<void> delete(Reminder reminder);
  Future<void> toggleActive(Reminder reminder);
  Stream<void> watch();
}

class HiveReminderRepository implements ReminderRepository {
  final Box<Reminder>? _injectedBox;

  HiveReminderRepository([this._injectedBox]);

  Box<Reminder> get _box =>
      _injectedBox ?? Hive.box<Reminder>(AppConstants.kRemindersBox);

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<List<Reminder>> getAll() async {
    try {
      final list = _box.values.toList();
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return list;
    } catch (e) {
      throw StorageException('Failed to read reminders: $e');
    }
  }

  @override
  Future<void> add(Reminder reminder) async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.put(reminder.id, reminder);
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to add reminder: $e');
      }
    });
  }

  @override
  Future<void> update(Reminder reminder) async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.put(reminder.id, reminder);
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to update reminder: $e');
      }
    });
  }

  @override
  Future<void> delete(Reminder reminder) async {
    await AtomicWriter.instance.execute(() async {
      try {
        await _box.delete(reminder.id);
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to delete reminder: $e');
      }
    });
  }

  @override
  Future<void> toggleActive(Reminder reminder) async {
    await AtomicWriter.instance.execute(() async {
      try {
        reminder.isActive = !reminder.isActive;
        await reminder.save();
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to toggle reminder status: $e');
      }
    });
  }
}
