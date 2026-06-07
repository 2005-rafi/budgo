import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense/core/app_constants.dart';
import 'package:expense/core/safe_preferences.dart';
import 'package:expense/core/money.dart';

class AppPreferencesProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  bool _isBudgetModeEnabled;
  String _currencySymbol;

  bool get isBudgetModeEnabled => _isBudgetModeEnabled;
  String get currencySymbol => _currencySymbol;

  AppPreferencesProvider(this._prefs)
    : _isBudgetModeEnabled =
          SafePreferences.safeGetBool(
            _prefs,
            AppConstants.kBudgetModeKey,
            defaultValue: true,
          ) ??
          true,
      _currencySymbol = _prefs.getString(AppConstants.kCurrencySymbolKey) ?? '₹' {
    _updateMoneyFormatter();
  }

  void _updateMoneyFormatter() {
    MoneyFormatter.symbol = _currencySymbol;
    if (_currencySymbol == '₹') {
      MoneyFormatter.locale = 'en_IN';
    } else if (_currencySymbol == '€') {
      MoneyFormatter.locale = 'en_IE'; // Just to get standard EU formatting
    } else {
      MoneyFormatter.locale = 'en_US';
    }
  }

  Future<void> setBudgetMode(bool value) async {
    _isBudgetModeEnabled = value;
    await _prefs.setBool(AppConstants.kBudgetModeKey, value);
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    await _prefs.setString(AppConstants.kCurrencySymbolKey, symbol);
    _updateMoneyFormatter();
    notifyListeners();
  }
}
