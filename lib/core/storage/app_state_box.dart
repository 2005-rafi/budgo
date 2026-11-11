import 'dart:convert';
import 'package:hive/hive.dart';

class AppStateBox {
  static const String boxName = 'app_state';
  static const String kPendingResetKey = 'pending_reset';
  static const String kPendingLifecycleOpKey = 'pending_lifecycle_op';
  static const String kActiveWorkspaceIdKey = 'active_workspace_id';

  static Box get _box => Hive.box(boxName);

  static bool get isPendingReset {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return (_box.get(kPendingResetKey, defaultValue: false) as bool) ||
            pendingLifecycleOp != null;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> setPendingReset(bool val) async {
    if (Hive.isBoxOpen(boxName)) {
      await _box.put(kPendingResetKey, val);
      await _box.flush();
    }
  }

  /// Stores a crash-recovery descriptor (`type`: `'factory_reset'` | `'workspace_wipe'`,
  /// `workspaceIds`: `List<String>`, `deleteSecondaryWorkspaces`: `bool`,
  /// `resetCategories`: `bool`) so interrupted mass deletes resume idempotently.
  static Map<String, dynamic>? get pendingLifecycleOp {
    try {
      if (!Hive.isBoxOpen(boxName)) return null;
      final raw = _box.get(kPendingLifecycleOpKey);
      if (raw is String && raw.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> setPendingLifecycleOp(Map<String, dynamic>? op) async {
    if (!Hive.isBoxOpen(boxName)) return;
    if (op == null) {
      await _box.delete(kPendingLifecycleOpKey);
    } else {
      await _box.put(kPendingLifecycleOpKey, jsonEncode(op));
    }
    await _box.flush();
  }

  static String get activeWorkspaceId {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return _box.get(kActiveWorkspaceIdKey, defaultValue: 'default_personal') as String;
      }
    } catch (_) {}
    return 'default_personal';
  }

  static Future<void> setActiveWorkspaceId(String id) async {
    if (Hive.isBoxOpen(boxName)) {
      await _box.put(kActiveWorkspaceIdKey, id);
      await _box.flush();
    }
  }
}
