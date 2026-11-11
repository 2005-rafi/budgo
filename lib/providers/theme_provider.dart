import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense/design/theme/app_theme.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/safe_preferences.dart';

enum ThemeContrast {
  low,
  medium,
  high,
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeContrast _contrast = ThemeContrast.low;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  ThemeContrast get contrast => _contrast;

  final materialTheme = MaterialTheme(Typography.material2021().englishLike);

  ThemeData get lightTheme {
    switch (_contrast) {
      case ThemeContrast.low:
        return materialTheme.light();
      case ThemeContrast.medium:
        return materialTheme.lightMediumContrast();
      case ThemeContrast.high:
        return materialTheme.lightHighContrast();
    }
  }

  ThemeData get darkTheme {
    switch (_contrast) {
      case ThemeContrast.low:
        return materialTheme.dark();
      case ThemeContrast.medium:
        return materialTheme.darkMediumContrast();
      case ThemeContrast.high:
        return materialTheme.darkHighContrast();
    }
  }

  ThemeProvider({bool autoLoadPrefs = false}) {
    if (autoLoadPrefs) {
      loadPreferences();
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemeToPrefs();
    notifyListeners();
  }

  void setContrast(ThemeContrast value) {
    if (_contrast != value) {
      _contrast = value;
      _saveContrastToPrefs();
      notifyListeners();
    }
  }

  Future<void> loadPreferences([SharedPreferences? providedPrefs]) async {
    try {
      final prefs = providedPrefs ?? await SharedPreferences.getInstance();
      final modeStr = SafePreferences.safeGetString(
        prefs,
        AppConstants.kThemeModeKey,
        defaultValue: null,
      );

      if (modeStr != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => ThemeMode.system,
        );
      }

      final contrastStr = SafePreferences.safeGetString(
        prefs,
        AppConstants.kThemeContrastKey,
        defaultValue: null,
      );

      if (contrastStr != null) {
        _contrast = ThemeContrast.values.firstWhere(
          (c) => c.name == contrastStr,
          orElse: () => ThemeContrast.low,
        );
      }

      notifyListeners();
    } catch (_) {}
  }

  void _saveThemeToPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(AppConstants.kThemeModeKey, _themeMode.name);
  }

  void _saveContrastToPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(AppConstants.kThemeContrastKey, _contrast.name);
  }
}
