import 'package:hive/hive.dart';

class AppStateBox {
  static const String boxName = 'app_state';
  static const String kPendingResetKey = 'pending_reset';

  static Box get _box => Hive.box(boxName);

  static bool get isPendingReset => _box.get(kPendingResetKey, defaultValue: false) as bool;

  static Future<void> setPendingReset(bool val) async {
    await _box.put(kPendingResetKey, val);
  }
}
