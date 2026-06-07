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
