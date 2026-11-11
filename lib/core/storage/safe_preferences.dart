import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Safe SharedPreferences wrapper that handles type mismatches gracefully
/// When data types change (e.g., bool → String), automatically recovers
class SafePreferences {
  /// Safely retrieves a String, handles type mismatches by returning null
  static String? safeGetString(
    SharedPreferences prefs,
    String key, {
    String? defaultValue,
  }) {
    try {
      return prefs.getString(key) ?? defaultValue;
    } catch (e) {
      if (e.toString().contains('is not a subtype of type')) {
        debugPrint(
          'SafePreferences: Type mismatch for key "$key" (expected String): $e\n'
          'Clearing key and returning default...',
        );
        // Clear the incompatible value
        try {
          prefs.remove(key);
        } catch (clearError) {
          debugPrint(
            'SafePreferences: Failed to clear key "$key": $clearError',
          );
        }
        return defaultValue;
      }
      // Re-throw if not a type mismatch
      rethrow;
    }
  }

  /// Safely retrieves a boolean, handles type mismatches by returning null
  static bool? safeGetBool(
    SharedPreferences prefs,
    String key, {
    bool? defaultValue,
  }) {
    try {
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      if (e.toString().contains('is not a subtype of type')) {
        debugPrint(
          'SafePreferences: Type mismatch for key "$key" (expected bool): $e\n'
          'Clearing key and returning default...',
        );
        // Clear the incompatible value
        try {
          prefs.remove(key);
        } catch (clearError) {
          debugPrint(
            'SafePreferences: Failed to clear key "$key": $clearError',
          );
        }
        return defaultValue;
      }
      // Re-throw if not a type mismatch
      rethrow;
    }
  }

  /// Safely retrieves an integer, handles type mismatches by returning null
  static int? safeGetInt(
    SharedPreferences prefs,
    String key, {
    int? defaultValue,
  }) {
    try {
      return prefs.getInt(key) ?? defaultValue;
    } catch (e) {
      if (e.toString().contains('is not a subtype of type')) {
        debugPrint(
          'SafePreferences: Type mismatch for key "$key" (expected int): $e\n'
          'Clearing key and returning default...',
        );
        try {
          prefs.remove(key);
        } catch (clearError) {
          debugPrint(
            'SafePreferences: Failed to clear key "$key": $clearError',
          );
        }
        return defaultValue;
      }
      rethrow;
    }
  }

  /// Safely retrieves a double, handles type mismatches by returning null
  static double? safeGetDouble(
    SharedPreferences prefs,
    String key, {
    double? defaultValue,
  }) {
    try {
      return prefs.getDouble(key) ?? defaultValue;
    } catch (e) {
      if (e.toString().contains('is not a subtype of type')) {
        debugPrint(
          'SafePreferences: Type mismatch for key "$key" (expected double): $e\n'
          'Clearing key and returning default...',
        );
        try {
          prefs.remove(key);
        } catch (clearError) {
          debugPrint(
            'SafePreferences: Failed to clear key "$key": $clearError',
          );
        }
        return defaultValue;
      }
      rethrow;
    }
  }
}
