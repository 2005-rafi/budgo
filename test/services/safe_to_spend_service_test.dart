import 'package:flutter_test/flutter_test.dart';
import 'package:expense/services/safe_to_spend_service.dart';

void main() {
  group('SafeToSpendService Tests', () {
    test('Zero-division elimination: on day 31 of 31 daysRemaining is at least 1', () {
      final now = DateTime(2026, 1, 31); // January has 31 days
      final result = SafeToSpendService.compute(
        now: now,
        budgetLimitPaise: 3100000, // ₹31,000
        spentThisMonthPaise: 3000000, // ₹30,000
        liquidUnallocatedPaise: 1000000,
        confirmedIncomeThisMonthPaise: 5000000,
      );

      expect(result.daysRemaining, equals(1));
      expect(result.dailyAllowancePaise, equals(100000)); // ₹1,000 for the last day
      expect(result.status, equals(SafeToSpendStatus.healthy));
    });

    test('Constrains spending by physical unallocated liquid funds when lower than budget', () {
      final now = DateTime(2026, 10, 1);
      // User has a ₹30,000 budget, but only ₹5,000 in physical liquid bank balance!
      final result = SafeToSpendService.compute(
        now: now,
        budgetLimitPaise: 3000000, // ₹30,000
        spentThisMonthPaise: 0,
        liquidUnallocatedPaise: 500000, // ₹5,000 actual cash
        confirmedIncomeThisMonthPaise: 500000,
      );

      // Must be capped by ₹5,000, NOT ₹30,000!
      // In October (31 days), ₹5,000 / 31 days = ₹161 / day (< ₹200 -> tight pace)
      expect(result.effectiveDiscretionaryPaise, equals(500000));
      expect(result.dailyAllowancePaise, equals(500000 ~/ 31));
      expect(result.status, equals(SafeToSpendStatus.tight));
    });

    test('Honest deficit reporting when spending exceeds budget without crashing', () {
      final now = DateTime(2026, 5, 20); // 12 days remaining
      final result = SafeToSpendService.compute(
        now: now,
        budgetLimitPaise: 2000000, // ₹20,000 budget
        spentThisMonthPaise: 2500000, // ₹25,000 spent (over by ₹5,000)
        liquidUnallocatedPaise: 1000000,
        confirmedIncomeThisMonthPaise: 3000000,
      );

      expect(result.isDeficit, isTrue);
      expect(result.dailyAllowancePaise, equals(0));
      expect(result.deficitPaise, equals(500000)); // ₹5,000 deficit
    });

    test('Unbudgeted fallback: calculates safe daily spend from confirmed income minus spent', () {
      final now = DateTime(2026, 6, 11); // June has 30 days -> 20 days remaining
      final result = SafeToSpendService.compute(
        now: now,
        budgetLimitPaise: null, // No budget mode
        spentThisMonthPaise: 1000000, // ₹10,000 spent
        liquidUnallocatedPaise: 4000000, // ₹40,000 liquid
        confirmedIncomeThisMonthPaise: 5000000, // ₹50,000 income
        pendingRemindersPaise: 500000, // ₹5,000 upcoming bills
      );

      // Remaining discretionary = 50k - 10k - 5k = 35k.
      // Capped by liquid (40k) -> 35k.
      // Days remaining: 30 - 11 + 1 = 20 days.
      // Daily allowance: 3,500,000 ~/ 20 = 175,000 paise (₹1,750/day).
      expect(result.daysRemaining, equals(20));
      expect(result.dailyAllowancePaise, equals(175000));
      expect(result.isHealthy, isTrue);
    });

    test('Zero-expense unbudgeted scenario matches ₹1,000 / 21 days = ₹47.61 with full derivation metadata', () {
      final now = DateTime(2026, 11, 10); // November has 30 days -> 21 days remaining (10..30)
      final result = SafeToSpendService.compute(
        now: now,
        budgetLimitPaise: null,
        spentThisMonthPaise: 0,
        liquidUnallocatedPaise: 100000, // ₹1,000.00
        confirmedIncomeThisMonthPaise: 100000, // ₹1,000.00
      );

      expect(result.daysInMonth, equals(30));
      expect(result.currentDay, equals(10));
      expect(result.daysRemaining, equals(21));
      expect(result.isBudgetedMode, isFalse);
      expect(result.dailyAllowancePaise, equals(4761)); // ₹47.61 / day
      expect(result.status, equals(SafeToSpendStatus.tight));
      expect(result.effectiveDiscretionaryPaise, equals(100000));
      expect(result.wasCappedByLiquidBalance, isFalse);
    });
  });
}

