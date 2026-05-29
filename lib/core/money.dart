import 'package:intl/intl.dart';

typedef Money = int;

extension MoneyExtension on Money {
  double get toDouble => this / 100.0;

  String format() {
    return _formatter.format(toDouble);
  }

  String formatCompact() {
    return _compactFormatter.format(toDouble);
  }
}

final NumberFormat _formatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

final NumberFormat _compactFormatter = NumberFormat.compactCurrency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 1,
);
