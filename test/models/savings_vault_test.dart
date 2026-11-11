import 'package:flutter_test/flutter_test.dart';
import 'package:expense/models/savings_vault.dart';

void main() {
  group('SavingsVault Model Tests', () {
    test('computes progressRatio, remainingPaise, and isGoalReached accurately', () {
      final vault = SavingsVault(
        id: 'vault_1',
        workspaceId: 'default_personal',
        parentAccountId: 'acc_bank',
        name: 'Emergency Fund',
        targetPaise: 5000000, // ₹50,000
        currentPaise: 1000000, // ₹10,000
        iconCodePoint: 0xe571,
        colorValue: 0xFF4CAF50,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(vault.progressRatio, equals(0.20));
      expect(vault.remainingPaise, equals(4000000));
      expect(vault.isGoalReached, isFalse);

      final completedVault = vault.copyWith(currentPaise: 5000000);
      expect(completedVault.progressRatio, equals(1.0));
      expect(completedVault.remainingPaise, equals(0));
      expect(completedVault.isGoalReached, isTrue);

      final overfundedVault = vault.copyWith(currentPaise: 6000000);
      expect(overfundedVault.progressRatio, equals(1.0)); // Clamped to 1.0
      expect(overfundedVault.remainingPaise, equals(0));
      expect(overfundedVault.isGoalReached, isTrue);
    });

    test('handles zero or negative target gracefully without divide-by-zero', () {
      final vault = SavingsVault(
        id: 'vault_zero',
        workspaceId: 'default_personal',
        parentAccountId: 'acc_bank',
        name: 'Open Pool',
        targetPaise: 0,
        currentPaise: 50000,
        iconCodePoint: 0xe571,
        colorValue: 0xFF4CAF50,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(vault.progressRatio, equals(1.0));
      expect(vault.remainingPaise, equals(0));
      expect(vault.isGoalReached, isFalse);
    });
  });
}

