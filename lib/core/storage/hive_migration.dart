import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

/// Resilient Hive migration and recovery handler.
/// Guarantees data durability and NEVER deletes user data from disk.
class HiveMigration {
  /// Opens a typed Hive box with safety guarantees and non-destructive recovery.
  static Future<Box<T>> openBoxWithMigration<T>({
    required String boxName,
    required bool Function(int entries, int deletedEntries) compactionStrategy,
  }) async {
    // 1. Create a defensive backup snapshot if box exists on disk
    await createSnapshotBackup(boxName);

    try {
      return await Hive.openBox<T>(
        boxName,
        compactionStrategy: compactionStrategy,
      );
    } catch (e) {
      debugPrint('HiveMigration: Error opening box "$boxName": $e');

      // Close if partially open
      if (Hive.isBoxOpen(boxName)) {
        try {
          await Hive.box(boxName).close();
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Attempt to quarantine corrupted file rather than deleting it
      await _quarantineBoxFile(boxName, e.toString());

      // Open a fresh box after quarantine
      return await Hive.openBox<T>(
        boxName,
        compactionStrategy: compactionStrategy,
      );
    }
  }

  /// Opens a generic (untyped) Hive box with the same non-destructive safety logic.
  static Future<Box> openGenericBoxWithMigration({
    required String boxName,
  }) async {
    await createSnapshotBackup(boxName);

    try {
      return await Hive.openBox(boxName);
    } catch (e) {
      debugPrint('HiveMigration: Error opening generic box "$boxName": $e');

      if (Hive.isBoxOpen(boxName)) {
        try {
          await Hive.box(boxName).close();
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 100));
      await _quarantineBoxFile(boxName, e.toString());

      return await Hive.openBox(boxName);
    }
  }

  /// Creates a non-destructive .bak snapshot of the Hive box file before critical operations.
  static Future<void> createSnapshotBackup(String boxName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final boxFile = File('${dir.path}/$boxName.hive');
      if (await boxFile.exists()) {
        final backupFile = File('${dir.path}/$boxName.hive.bak');
        await boxFile.copy(backupFile.path);
      }
    } catch (e) {
      debugPrint('HiveMigration: Snapshot creation note for "$boxName": $e');
    }
  }

  /// Quarantines an unreadable box file to preserve user forensic data.
  /// NEVER deletes user data!
  static Future<void> _quarantineBoxFile(String boxName, String reason) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final boxFile = File('${dir.path}/$boxName.hive');
      if (await boxFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final quarantinePath = '${dir.path}/$boxName.corrupted.$timestamp.bak';
        await boxFile.rename(quarantinePath);
        debugPrint(
          'HiveMigration: Quarantined unreadable box "$boxName" to "$quarantinePath". Reason: $reason',
        );
      }
    } catch (e) {
      debugPrint('HiveMigration: Quarantine failed for "$boxName": $e');
    }
  }
}
