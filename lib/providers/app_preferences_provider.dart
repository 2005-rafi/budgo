import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/safe_preferences.dart';
import 'package:expense/core/currency/currency_formatter.dart';

class AppPreferencesProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isBudgetModeEnabled;
  bool _isMonthlyRefreshEnabled;
  bool _isPrivacyModeEnabled;
  String _currencySymbol;
  String _defaultPaymentMethod;

  bool get isBudgetModeEnabled => _isBudgetModeEnabled;
  bool get isMonthlyRefreshEnabled => _isMonthlyRefreshEnabled;
  bool get isPrivacyModeEnabled => _isPrivacyModeEnabled;
  String get currencySymbol => _currencySymbol;
  String get defaultPaymentMethod => _defaultPaymentMethod;

  AppPreferencesProvider([SharedPreferences? prefs])
    : _prefs = prefs,
      _isBudgetModeEnabled = true,
      _isMonthlyRefreshEnabled = true,
      _isPrivacyModeEnabled = false,
      _currencySymbol = '₹',
      _defaultPaymentMethod = 'UPI' {
    if (prefs != null) {
      _readFromPrefs(prefs);
    } else {
      _updateMoneyFormatter();
    }
  }

  void attachPrefs(SharedPreferences prefs) {
    _prefs = prefs;
    _readFromPrefs(prefs);
    notifyListeners();
  }

  void _readFromPrefs(SharedPreferences prefs) {
    _isBudgetModeEnabled =
        SafePreferences.safeGetBool(
          prefs,
          AppConstants.kBudgetModeKey,
          defaultValue: true,
        ) ??
        true;
    _isMonthlyRefreshEnabled =
        SafePreferences.safeGetBool(
          prefs,
          AppConstants.kMonthlyRefreshKey,
          defaultValue: true,
        ) ??
        true;
    _isPrivacyModeEnabled =
        SafePreferences.safeGetBool(
          prefs,
          AppConstants.kPrivacyModeKey,
          defaultValue: false,
        ) ??
        false;
    _defaultPaymentMethod =
        prefs.getString(AppConstants.kDefaultPaymentMethodKey) ?? 'UPI';
    _currencySymbol =
        prefs.getString(AppConstants.kCurrencySymbolKey) ?? '₹';
    _updateMoneyFormatter();
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  void _updateMoneyFormatter() {
    MoneyFormatter.symbol = _currencySymbol;
    if (_currencySymbol == '₹') {
      MoneyFormatter.locale = 'en_IN';
    } else if (_currencySymbol == '€') {
      MoneyFormatter.locale = 'en_IE';
    } else {
      MoneyFormatter.locale = 'en_US';
    }
  }

  Future<void> setDefaultPaymentMethod(String method) async {
    _defaultPaymentMethod = method;
    final prefs = await _ensurePrefs();
    await prefs.setString(AppConstants.kDefaultPaymentMethodKey, method);
    notifyListeners();
  }

  Future<void> setBudgetMode(bool value) async {
    _isBudgetModeEnabled = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(AppConstants.kBudgetModeKey, value);
    notifyListeners();
  }

  Future<void> setPrivacyMode(bool value) async {
    _isPrivacyModeEnabled = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(AppConstants.kPrivacyModeKey, value);
    notifyListeners();
  }

  Future<void> setMonthlyRefresh(bool value) async {
    _isMonthlyRefreshEnabled = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(AppConstants.kMonthlyRefreshKey, value);
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await _ensurePrefs();
    await prefs.setString(AppConstants.kCurrencySymbolKey, symbol);
    _updateMoneyFormatter();
    notifyListeners();
  }
}
