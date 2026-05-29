import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';

/// Expert-grade Hive migration handler
/// Gracefully handles data type mismatches when upgrading from double → int for Money type
class HiveMigration {
  /// Opens a Hive box with automatic recovery for type mismatches.
  /// If deserialization fails due to type casting (e.g., double → int),
  /// clears the box and retries. This is idempotent and safe.
  static Future<Box<T>> openBoxWithMigration<T>({
    required String boxName,
    required bool Function(int entries, int deletedEntries) compactionStrategy,
  }) async {
    try {
      return await Hive.openBox<T>(
        boxName,
        compactionStrategy: compactionStrategy,
      );
    } catch (e) {
      // Detect type casting errors (double → int mismatch)
      if (e.toString().contains('is not a subtype of type') ||
          e.toString().contains('type cast')) {
        debugPrint(
          'HiveMigration: Type mismatch in box "$boxName": $e\n'
          'Clearing box and retrying...',
        );

        try {
          // Close any existing box reference first
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).close();
          }

          // Add small delay to ensure file handles are released
          await Future.delayed(const Duration(milliseconds: 100));

          // Attempt to delete the box from disk
          // Ignore file not found errors as they're expected in some cases
          try {
            await Hive.deleteBoxFromDisk(boxName);
            debugPrint('HiveMigration: Deleted corrupted box "$boxName"');
          } on FileSystemException catch (fsError) {
            // File doesn't exist or is locked - this is OK, continue
            debugPrint(
              'HiveMigration: Box "$boxName" file cleanup note: ${fsError.message}\n'
              'Proceeding with retry anyway...',
            );
          }

          // Add another delay before retrying
          await Future.delayed(const Duration(milliseconds: 50));

          // Retry opening the box (now empty or fresh)
          return await Hive.openBox<T>(
            boxName,
            compactionStrategy: compactionStrategy,
          );
        } catch (retryError) {
          debugPrint(
            'HiveMigration: Failed to recover box "$boxName": $retryError',
          );
          rethrow;
        }
      } else {
        // Re-throw if not a type casting error
        rethrow;
      }
    }
  }

  /// Opens a generic (untyped) Hive box with the same migration logic
  static Future<Box> openGenericBoxWithMigration({
    required String boxName,
  }) async {
    try {
      return await Hive.openBox(boxName);
    } catch (e) {
      if (e.toString().contains('is not a subtype of type') ||
          e.toString().contains('type cast')) {
        debugPrint(
          'HiveMigration: Type mismatch in generic box "$boxName": $e\n'
          'Clearing box and retrying...',
        );

        try {
          // Close any existing box reference first
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).close();
          }

          // Add small delay to ensure file handles are released
          await Future.delayed(const Duration(milliseconds: 100));

          // Attempt to delete the box from disk
          try {
            await Hive.deleteBoxFromDisk(boxName);
            debugPrint(
              'HiveMigration: Deleted corrupted generic box "$boxName"',
            );
          } on FileSystemException catch (fsError) {
            // File doesn't exist or is locked - this is OK, continue
            debugPrint(
              'HiveMigration: Generic box "$boxName" file cleanup note: ${fsError.message}\n'
              'Proceeding with retry anyway...',
            );
          }

          // Add another delay before retrying
          await Future.delayed(const Duration(milliseconds: 50));

          return await Hive.openBox(boxName);
        } catch (retryError) {
          debugPrint(
            'HiveMigration: Failed to recover generic box "$boxName": $retryError',
          );
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }
}
