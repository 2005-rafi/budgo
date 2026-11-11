import 'package:flutter_test/flutter_test.dart';
import 'package:expense/core/currency/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests (Universal Scaling)', () {
    test('format standard paise currency', () {
      expect(CurrencyFormatter.format(0), '₹0.00');
      expect(CurrencyFormatter.format(100), '₹1.00');
      expect(CurrencyFormatter.format(100000), '₹1,000.00');
      expect(CurrencyFormatter.format(1000000), '₹10,000.00');
    });

    test('formatCompact Indian notation for small, lakh, and crore values', () {
      // Below 1 Lakh (< 100,000 Rupees = 10,000,000 paise)
      expect(CurrencyFormatter.formatCompact(0), '₹0');
      expect(CurrencyFormatter.formatCompact(500000), '₹5000');
      expect(CurrencyFormatter.formatCompact(5000000), '₹50000');

      // Between 1 Lakh and 1 Crore
      expect(CurrencyFormatter.formatCompact(10000000), '₹1 L');
      expect(CurrencyFormatter.formatCompact(12500000), '₹1.25 L');
      expect(CurrencyFormatter.formatCompact(99900000), '₹9.99 L');

      // 1 Crore and above
      expect(CurrencyFormatter.formatCompact(1000000000), '₹1 Cr');
      expect(CurrencyFormatter.formatCompact(1500000000), '₹1.5 Cr');
      expect(CurrencyFormatter.formatCompact(100000000000), '₹100 Cr');
    });

    test('formatSmart switches automatically at 10 Lakhs threshold', () {
      // 5 Lakhs -> standard
      expect(CurrencyFormatter.formatSmart(50000000), contains('₹5,00,000.00'));
      // 15 Lakhs -> compact
      expect(CurrencyFormatter.formatSmart(150000000), '₹15 L');
      // 1.5 Crores -> compact
      expect(CurrencyFormatter.formatSmart(1500000000), '₹1.5 Cr');
    });

    test('format handles negative balances properly', () {
      expect(CurrencyFormatter.format(-50000), '-₹500.00');
      expect(CurrencyFormatter.formatCompact(-1500000000), '-₹1.5 Cr');
    });
  });
}
