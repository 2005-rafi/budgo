import 'package:flutter_test/flutter_test.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';

void main() {
  group('Account Signed Net Equity Invariants (TEST-SIGN-01, TEST-SIGN-02)', () {
    test('Asset account natural state is >= 0', () {
      final cashAccount = Account(
        id: 'acc_cash_1',
        workspaceId: 'default_personal',
        name: 'Cash Wallet',
        type: AccountType.cash,
        balancePaise: 500000, // ₹5,000
        iconCodePoint: 0xef63,
        colorValue: 0xFF4CAF50,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(cashAccount.isCredit, isFalse);
      expect(cashAccount.balancePaise, 500000);
      expect(cashAccount.availableCreditPaise, 500000);
      expect(cashAccount.outstandingDebtPaise, 0);
    });

    test('Credit Card natural state is <= 0 under Signed Net Equity', () {
      final ccAccount = Account(
        id: 'acc_cc_1',
        workspaceId: 'default_personal',
        name: 'HDFC Credit Card',
        type: AccountType.creditCard,
        balancePaise: -1500000, // -₹15,000 outstanding debt
        creditLimitPaise: 10000000, // ₹1,00,000 credit limit
        iconCodePoint: 0xe040,
        colorValue: 0xFF1976D2,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(ccAccount.isCredit, isTrue);
      expect(ccAccount.balancePaise, -1500000);
      // Outstanding debt in positive paise
      expect(ccAccount.outstandingDebtPaise, 1500000);
      // Available credit = creditLimitPaise + balancePaise = 100k - 15k = 85k
      expect(ccAccount.availableCreditPaise, 8500000);
    });

    test('Universal Net Worth is algebraic sum without conditional branching', () {
      final bank = Account(
        id: '1',
        workspaceId: 'w',
        name: 'Bank',
        type: AccountType.bankAccount,
        balancePaise: 4500000, // ₹45,000
        iconCodePoint: 0,
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cash = Account(
        id: '2',
        workspaceId: 'w',
        name: 'Cash',
        type: AccountType.cash,
        balancePaise: 500000, // ₹5,000
        iconCodePoint: 0,
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cc = Account(
        id: '3',
        workspaceId: 'w',
        name: 'CC',
        type: AccountType.creditCard,
        balancePaise: -1000000, // -₹10,000 debt
        creditLimitPaise: 5000000,
        iconCodePoint: 0,
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final accounts = [bank, cash, cc];
      // Sum = 45k + 5k - 10k = 40k
      final netWorthPaise = accounts.fold<int>(0, (sum, a) => sum + a.balancePaise);
      expect(netWorthPaise, 4000000); // Exactly ₹40,000
    });
  });
}

