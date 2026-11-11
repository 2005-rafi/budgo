import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/currency/currency_formatter.dart';

/// Result returned by centralized input validation helpers.
class AmountValidationResult {
  final bool isValid;
  final int? paise;
  final String? errorMessage;

  const AmountValidationResult.valid(int this.paise)
      : isValid = true,
        errorMessage = null;

  const AmountValidationResult.invalid(String this.errorMessage)
      : isValid = false,
        paise = null;
}

/// Single source of truth for numeric, currency, and required-text validation
/// across forms, dialogs, and bottom sheets.
class InputValidators {
  InputValidators._();

  static AmountValidationResult validateAmount(
    String raw, {
    double maxRupees = AppConstants.kMaxAmountRupees,
    String fieldLabel = 'Amount',
    int? maxPaiseLimit,
    String? maxPaiseLimitLabel,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return AmountValidationResult.invalid('$fieldLabel is required');
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed <= 0) {
      return AmountValidationResult.invalid(
        'Enter a valid positive ${fieldLabel.toLowerCase()}',
      );
    }

    if (parsed > maxRupees) {
      final limitPaise = (maxRupees * 100).round();
      return AmountValidationResult.invalid(
        '$fieldLabel cannot exceed ${CurrencyFormatter.formatPaise(limitPaise)}',
      );
    }

    final parts = trimmed.split('.');
    if (parts.length > 1 && parts[1].length > 2) {
      return const AmountValidationResult.invalid(
        'Up to 2 decimal places allowed (e.g. 250.50)',
      );
    }

    final paise = (parsed * 100).round();
    if (paise <= 0) {
      return AmountValidationResult.invalid(
        '$fieldLabel must be at least ${MoneyFormatter.symbol}0.01',
      );
    }

    if (maxPaiseLimit != null && paise > maxPaiseLimit) {
      final capText = CurrencyFormatter.formatPaise(maxPaiseLimit);
      final target = maxPaiseLimitLabel ?? 'available limit';
      return AmountValidationResult.invalid(
        'Amount exceeds $target ($capText)',
      );
    }

    return AmountValidationResult.valid(paise);
  }

  static String? validateRequiredText(
    String? raw, {
    required String fieldLabel,
    int? maxLength,
  }) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$fieldLabel is required';
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return '$fieldLabel cannot exceed $maxLength characters';
    }
    return null;
  }
}

