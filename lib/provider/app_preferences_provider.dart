import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense/core/app_constants.dart';
import 'package:expense/core/safe_preferences.dart';

class AppPreferencesProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  bool _isBudgetModeEnabled;

  bool get isBudgetModeEnabled => _isBudgetModeEnabled;

  AppPreferencesProvider(this._prefs)
    : _isBudgetModeEnabled =
          SafePreferences.safeGetBool(
            _prefs,
            AppConstants.kBudgetModeKey,
            defaultValue: true,
          ) ??
          true;

  Future<void> setBudgetMode(bool value) async {
    _isBudgetModeEnabled = value;
    await _prefs.setBool(AppConstants.kBudgetModeKey, value);
    notifyListeners();
  }
}
