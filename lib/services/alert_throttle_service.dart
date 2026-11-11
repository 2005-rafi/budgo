import 'package:shared_preferences/shared_preferences.dart';

class AlertThrottleService {
  SharedPreferences? _prefs;

  AlertThrottleService([this._prefs]);

  void attachPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

  bool shouldFireBudgetAlert() {
    final prefs = _prefs;
    if (prefs == null) return false;
    final lastFiredDay = prefs.getInt('kLastBudgetAlertDay') ?? 0;
    final today = DateTime.now().difference(DateTime(2000, 1, 1)).inDays;
    return today > lastFiredDay;
  }

  void markBudgetAlertFired() {
    final prefs = _prefs;
    if (prefs == null) return;
    final today = DateTime.now().difference(DateTime(2000, 1, 1)).inDays;
    prefs.setInt('kLastBudgetAlertDay', today);
  }
}
