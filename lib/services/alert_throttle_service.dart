import 'package:shared_preferences/shared_preferences.dart';

class AlertThrottleService {
  final SharedPreferences _prefs;

  AlertThrottleService(this._prefs);

  bool shouldFireBudgetAlert() {
    final lastFiredDay = _prefs.getInt('kLastBudgetAlertDay') ?? 0;
    final today = DateTime.now().difference(DateTime(2000, 1, 1)).inDays;
    return today > lastFiredDay;
  }

  void markBudgetAlertFired() {
    final today = DateTime.now().difference(DateTime(2000, 1, 1)).inDays;
    _prefs.setInt('kLastBudgetAlertDay', today);
  }
}
