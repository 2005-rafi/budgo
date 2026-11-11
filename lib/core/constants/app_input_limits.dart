import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:expense/models/workspace_type.dart';

/// Centralized length limits, safety barriers, and policies for all input fields.
class AppInputLimits {
  const AppInputLimits._();

  static const int workspaceNameMax = 20;
  static const int categoryNameMax = 16;
  static const int vaultNameMax = 24;
  static const int reminderTitleMax = 36;
  static const int reminderNotesMax = 140;
  static const int transactionTitleMax = 40;
  static const int wishlistTitleMax = 40;
  static const int wishlistNotesMax = 160;
  static const int transferNoteMax = 80;
  static const int searchQueryMax = 50;
  static const int amountInputMaxChars = 11;
  static const int resetConfirmMax = 5;

  /// Shared decimal money input barrier (up to 8 integer digits + optional 2 decimals).
  static List<TextInputFormatter> get decimalAmountFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,8}(\.\d{0,2})?$')),
        LengthLimitingTextInputFormatter(amountInputMaxChars),
      ];
}

/// Governance policy configuring formatting rules, safety barriers, and helper hints.
class BudgoInputPolicy {
  final int maxLength;
  final bool allowSpaces;
  final bool allowNewlines;
  final bool allowLeadingFormulaChars;
  final String? ruleHint;

  const BudgoInputPolicy({
    required this.maxLength,
    this.allowSpaces = true,
    this.allowNewlines = false,
    this.allowLeadingFormulaChars = false,
    this.ruleHint,
  });

  /// Workspace Name: max 20 graphemes, strictly no spaces allowed.
  static const BudgoInputPolicy workspaceName = BudgoInputPolicy(
    maxLength: AppInputLimits.workspaceNameMax,
    allowSpaces: false,
    allowNewlines: false,
    allowLeadingFormulaChars: false,
    ruleHint: 'Up to 20 characters · No spaces allowed',
  );

  /// Category Name: max 16 graphemes.
  static const BudgoInputPolicy categoryName = BudgoInputPolicy(
    maxLength: AppInputLimits.categoryNameMax,
    allowSpaces: true,
    allowNewlines: false,
    ruleHint: 'Up to 16 characters for category tag',
  );

  /// Savings Vault Name: max 24 graphemes.
  static const BudgoInputPolicy vaultName = BudgoInputPolicy(
    maxLength: AppInputLimits.vaultNameMax,
    allowSpaces: true,
    allowNewlines: false,
    ruleHint: 'Up to 24 characters for vault target',
  );

  /// Reminder Title: max 36 graphemes.
  static const BudgoInputPolicy reminderTitle = BudgoInputPolicy(
    maxLength: AppInputLimits.reminderTitleMax,
    allowSpaces: true,
    allowNewlines: false,
    ruleHint: 'Up to 36 characters for reminder title',
  );

  /// Reminder Notes: max 140 graphemes (multiline).
  static const BudgoInputPolicy reminderNotes = BudgoInputPolicy(
    maxLength: AppInputLimits.reminderNotesMax,
    allowSpaces: true,
    allowNewlines: true,
    ruleHint: 'Up to 140 characters for notes or biller info',
  );

  /// Transaction Title: max 40 graphemes.
  static const BudgoInputPolicy transactionTitle = BudgoInputPolicy(
    maxLength: AppInputLimits.transactionTitleMax,
    allowSpaces: true,
    allowNewlines: false,
    ruleHint: 'Up to 40 characters for title',
  );

  /// Wishlist Item Title: max 40 graphemes.
  static const BudgoInputPolicy wishlistTitle = BudgoInputPolicy(
    maxLength: AppInputLimits.wishlistTitleMax,
    allowSpaces: true,
    allowNewlines: false,
    ruleHint: 'Up to 40 characters for item name',
  );

  /// Wishlist Notes: max 160 graphemes (multiline).
  static const BudgoInputPolicy wishlistNotes = BudgoInputPolicy(
    maxLength: AppInputLimits.wishlistNotesMax,
    allowSpaces: true,
    allowNewlines: true,
    ruleHint: 'Up to 160 characters for purchase context',
  );

  /// Self Transfer Note: max 80 graphemes.
  static const BudgoInputPolicy transferNote = BudgoInputPolicy(
    maxLength: AppInputLimits.transferNoteMax,
    allowSpaces: true,
    allowNewlines: false,
    ruleHint: 'Up to 80 characters for transfer reason',
  );

  /// Factory Reset Confirmation: exactly 5 characters ('RESET').
  static const BudgoInputPolicy resetConfirm = BudgoInputPolicy(
    maxLength: AppInputLimits.resetConfirmMax,
    allowSpaces: false,
    allowNewlines: false,
    ruleHint: 'Type "RESET" to confirm wipe',
  );

  /// Generates a TextInputFormatter list applying this policy's rules.
  List<TextInputFormatter> get formatters => [
        BudgoTextSafetyFormatter(policy: this),
      ];
}

/// Unicode grapheme-aware TextInputFormatter that enforces length and filters disallowed characters.
class BudgoTextSafetyFormatter extends TextInputFormatter {
  final BudgoInputPolicy policy;

  const BudgoTextSafetyFormatter({required this.policy});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // Disallow spaces if configured (rejects space bar and strips spaces from paste)
    if (!policy.allowSpaces && text.contains(' ')) {
      text = text.replaceAll(' ', '');
    }

    // Disallow newlines if single line
    if (!policy.allowNewlines && (text.contains('\n') || text.contains('\r'))) {
      text = text.replaceAll('\r', '').replaceAll('\n', ' ');
    }

    // Formula injection barrier (=, +, -, @ at index 0)
    if (!policy.allowLeadingFormulaChars && text.isNotEmpty) {
      final first = text.characters.first;
      if (first == '=' || first == '+' || first == '-' || first == '@') {
        text = text.substring(first.length);
      }
    }

    // Unicode grapheme cluster length clamping
    final characters = text.characters;
    if (characters.length > policy.maxLength) {
      text = characters.take(policy.maxLength).toString();
    }

    final selectionOffset = (newValue.selection.baseOffset <= text.length)
        ? (newValue.selection.baseOffset < 0 ? text.length : newValue.selection.baseOffset)
        : text.length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}

/// Dynamic guiding prompts that replace static and passive "e.g." placeholders.
class BudgoInputGuidance {
  const BudgoInputGuidance._();

  /// Guiding hint for Workspace Name based on selected WorkspaceType.
  static String workspaceHint(WorkspaceType type) {
    return switch (type) {
      WorkspaceType.personal => 'Name your personal financial profile',
      WorkspaceType.business => 'Name your business or client account',
      WorkspaceType.trip => 'Name your vacation or travel budget',
      WorkspaceType.project => 'Name your venture or project ledger',
      WorkspaceType.savingsPool => 'Name your collective or group savings pool',
    };
  }

  /// Guiding hint for Expense Title based on selected Category.
  static String expenseHint(String? category) {
    if (category == null || category.isEmpty) {
      return 'What was this expense for?';
    }
    return switch (category.toLowerCase()) {
      'food' || 'dining' => 'What meal, dining, or groceries did you purchase?',
      'travel' || 'transport' => 'Where did you commute or travel?',
      'bills' || 'utilities' => 'Which utility or recurring bill was paid?',
      'shopping' => 'What item or product did you purchase?',
      'entertainment' => 'What event, movie, or service was this for?',
      'health' || 'medical' => 'What medicine, doctor, or care service was this?',
      'lend' || 'loan' => 'Who did you lend funds or pay on behalf of?',
      _ => 'What was this expense for?',
    };
  }

  /// Guiding hint for Income Source based on selected Source.
  static String incomeHint(String? source) {
    if (source == null || source.isEmpty) {
      return 'Where did this income arrive from?';
    }
    return switch (source.toLowerCase()) {
      'salary' => 'Enter employer, company, or organization name',
      'freelance' => 'Enter client, gig, or invoice title',
      'gift' => 'Enter sender or special occasion details',
      'investment' => 'Enter asset, dividend, or payout description',
      _ => 'Where did this income arrive from?',
    };
  }

  /// Guiding hint for Reminder Title based on recurrence.
  static String reminderHint(bool isRecurring) {
    return isRecurring
        ? 'Name your recurring bill or subscription'
        : 'Name your upcoming payment or one-time bill';
  }

  /// Guiding hint for Savings Vault Name based on locked state.
  static String vaultHint(bool isLocked) {
    return isLocked
        ? 'Name your locked savings goal'
        : 'Name your flexible savings envelope';
  }

  /// Guiding hint for Cross-Workspace or Inter-Account Transfer.
  static String transferHint({String? destinationName}) {
    if (destinationName != null && destinationName.isNotEmpty) {
      return 'Enter purpose for moving funds to $destinationName';
    }
    return 'Enter reason or purpose for transferring funds';
  }

  /// Guiding hint for Planned Wishlist item.
  static String wishlistHint() {
    return 'Name your desired item or future purchase';
  }
}
