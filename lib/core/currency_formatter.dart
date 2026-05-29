import 'package:expense/core/money.dart';

class CurrencyFormatter {
  /// Formats an amount in paise (minor units) as a currency string.
  static String format(int paise) {
    return paise.format();
  }
}

