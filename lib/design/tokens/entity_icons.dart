import 'package:flutter/material.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/workspace_type.dart';

/// Centralized visual identity (icons and accent colors) for [AccountType].
class AccountIcons {
  AccountIcons._();

  static IconData forType(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.bankAccount:
        return Icons.account_balance_rounded;
      case AccountType.upi:
        return Icons.qr_code_rounded;
      case AccountType.creditCard:
        return Icons.credit_card_rounded;
      case AccountType.savings:
        return Icons.savings_rounded;
      case AccountType.other:
        return Icons.account_balance_wallet_rounded;
    }
  }

  static Color defaultColorForType(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return const Color(0xFF4CAF50);
      case AccountType.bankAccount:
        return const Color(0xFF1976D2);
      case AccountType.upi:
        return const Color(0xFF9C27B0);
      case AccountType.creditCard:
        return const Color(0xFFE65100);
      case AccountType.savings:
        return const Color(0xFF009688);
      case AccountType.other:
        return const Color(0xFF607D8B);
    }
  }
}

/// Centralized icon and color mapping for [WorkspaceType].
class WorkspaceIcons {
  WorkspaceIcons._();

  static IconData forType(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.personal:
        return Icons.person_rounded;
      case WorkspaceType.business:
        return Icons.business_center_rounded;
      case WorkspaceType.trip:
        return Icons.flight_takeoff_rounded;
      case WorkspaceType.project:
        return Icons.folder_special_rounded;
      case WorkspaceType.savingsPool:
        return Icons.savings_rounded;
    }
  }

  static Color defaultColorForType(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.personal:
        return const Color(0xFF2196F3);
      case WorkspaceType.business:
        return const Color(0xFF607D8B);
      case WorkspaceType.trip:
        return const Color(0xFFFF9800);
      case WorkspaceType.project:
        return const Color(0xFF9C27B0);
      case WorkspaceType.savingsPool:
        return const Color(0xFF4CAF50);
    }
  }
}

