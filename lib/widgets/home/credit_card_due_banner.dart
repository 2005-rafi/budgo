import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/widgets/sheets/credit_card_settlement_sheet.dart';

class CreditCardDueBanner extends StatelessWidget {
  const CreditCardDueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrivacyMode = context.watch<AppPreferencesProvider>().isPrivacyModeEnabled;

    return Consumer<AccountProvider>(
      builder: (context, accProvider, _) {
        final cardsWithDebt = accProvider.activeCreditCardsWithDebt;
        if (cardsWithDebt.isEmpty) return const SizedBox.shrink();

        final card = cardsWithDebt.first;
        final debtPaise = card.balancePaise.abs();

        final debtText = isPrivacyMode
            ? '${MoneyFormatter.symbol} ••••'
            : CurrencyFormatter.format(debtPaise);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.credit_card_outlined,
                  color: Colors.amber.shade900,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      Text(
                        '$debtText outstanding',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => CreditCardSettlementSheet.show(context, card),
                  child: const Text('Pay Now'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
