import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/design/components/budgo_feedback.dart';

class PayYourselfFirstCard extends StatefulWidget {
  const PayYourselfFirstCard({super.key});

  @override
  State<PayYourselfFirstCard> createState() => _PayYourselfFirstCardState();
}

class _PayYourselfFirstCardState extends State<PayYourselfFirstCard> {
  final Set<String> _dismissedIncomeIds = {};
  bool _isAllocating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final incomeProvider = context.watch<IncomeProvider>();
    final vaultProvider = context.watch<SavingsVaultProvider>();

    final activeVaults = vaultProvider.activeVaults;
    if (activeVaults.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    // Look for confirmed salary income in current month
    final recentSalary = incomeProvider.items.firstWhereOrNull((i) {
      if (!i.isConfirmed) return false;
      if (_dismissedIncomeIds.contains(i.id)) return false;
      final isSalarySource = i.source.toLowerCase().contains('salary');
      final isThisMonth = i.date.year == now.year && i.date.month == now.month;
      return isSalarySource && isThisMonth;
    });

    if (recentSalary == null) return const SizedBox.shrink();

    // Default allocation suggestion: 10% of salary or remaining target of highest priority vault
    final priorityVault = activeVaults.first;
    final suggestedAllocationPaise = (recentSalary.amount * 0.10).round();
    final allocationPaise = suggestedAllocationPaise > 0
        ? (suggestedAllocationPaise > priorityVault.remainingPaise && priorityVault.remainingPaise > 0
            ? priorityVault.remainingPaise
            : suggestedAllocationPaise)
        : 100000; // 1,000 INR default

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.savings_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Pay Yourself First',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _dismissedIncomeIds.add(recentSalary.id);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Salary confirmed! Secure ${CurrencyFormatter.format(allocationPaise)} into your "${priorityVault.name}" before spending.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dismissedIncomeIds.add(recentSalary.id);
                    });
                  },
                  child: const Text('Later'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton.tonal(
                  onPressed: _isAllocating
                      ? null
                      : () async {
                          setState(() => _isAllocating = true);
                          try {
                            final success = await vaultProvider.deposit(
                              priorityVault.id,
                              allocationPaise,
                            );
                            if (!context.mounted) return;
                            if (success) {
                              SnackbarFeedback.showSuccess(
                                context,
                                'Locked ${CurrencyFormatter.format(allocationPaise)} into ${priorityVault.name}!',
                              );
                              setState(() {
                                _dismissedIncomeIds.add(recentSalary.id);
                              });
                            } else {
                              SnackbarFeedback.showError(
                                context,
                                vaultProvider.lastError ??
                                    vaultProvider.errorMessage ??
                                    'Could not allocate funds to ${priorityVault.name}.',
                                operation: FeedbackOperation.depositVault,
                              );
                            }
                          } finally {
                            if (context.mounted) setState(() => _isAllocating = false);
                          }
                        },
                  child: _isAllocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Reserve ${CurrencyFormatter.format(allocationPaise)}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
