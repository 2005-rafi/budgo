import 'package:intl/intl.dart';

typedef Money = int;

class MoneyFormatter {
  static String symbol = '₹';
  static String locale = 'en_IN';

  static NumberFormat get formatter => NumberFormat.currency(
        locale: locale,
        symbol: symbol,
        decimalDigits: 2,
      );

  static NumberFormat get compactFormatter => NumberFormat.compactCurrency(
        locale: locale,
        symbol: symbol,
        decimalDigits: 1,
      );
}

extension MoneyExtension on Money {
  double get toDouble => this / 100.0;

  String format() {
    return MoneyFormatter.formatter.format(toDouble);
  }

  String formatCompact() {
    return MoneyFormatter.compactFormatter.format(toDouble);
  }
}

/// Centralized currency formatting utility respecting dynamic [MoneyFormatter.symbol].
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats an amount in paise (minor units) as standard currency (e.g. ₹10,000.00).
  static String format(int paise) => paise.format();

  /// Alias for formatting paise amounts.
  static String formatPaise(int paise) => format(paise);

  static String _cleanDecimals(double val) {
    var str = val.toStringAsFixed(2);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }

  /// Compact notation for large numbers respecting the active currency symbol
  /// (e.g. ₹12.5 L, ₹1.5 Cr or $1.5 L when user selects $).
  static String formatCompact(int paise) {
    final absPaise = paise.abs();
    final sign = paise < 0 ? '-' : '';
    final sym = MoneyFormatter.symbol;
    // Under 1 Lakh (< 1,00,000 units = 10,000,000 minor units)
    if (absPaise < 10000000) {
      return '$sign$sym${_cleanDecimals(absPaise / 100.0)}';
    }
    // Between 1 Lakh and 1 Crore
    if (absPaise < 1000000000) {
      return '$sign$sym${_cleanDecimals(absPaise / 10000000.0)} L';
    }
    // 1 Crore and above
    return '$sign$sym${_cleanDecimals(absPaise / 1000000000.0)} Cr';
  }

  /// Smart formatting: uses compact notation above [compactThresholdPaise].
  static String formatSmart(int paise, {int compactThresholdPaise = 100000000}) {
    if (paise.abs() >= compactThresholdPaise) {
      return formatCompact(paise);
    }
    return format(paise);
  }
}

