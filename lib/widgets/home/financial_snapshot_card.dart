import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/core/currency_formatter.dart';

class FinancialSnapshotCard extends StatelessWidget {
  final int balance;
  final int income;
  final int spent;
  final int? budgetLimit;
  final int? budgetRemaining;
  final double? budgetUsageRatio;
  final bool isBudgetEnabled;
  final VoidCallback? onTap;
  final VoidCallback onSetupBudget;

  const FinancialSnapshotCard({
    super.key,
    required this.balance,
    required this.income,
    required this.spent,
    required this.isBudgetEnabled,
    required this.onSetupBudget,
    this.budgetLimit,
    this.budgetRemaining,
    this.budgetUsageRatio,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: BudgoColors.heroCardSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Budget Info (if enabled)
              if (isBudgetEnabled) ...[
                _buildBudgetRow(context, colorScheme),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Row 2: Monthly Cashflow
              _buildCashflowRow(context, colorScheme),

              if (isBudgetEnabled && budgetLimit == null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: onSetupBudget,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Set a Budget'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetRow(BuildContext context, ColorScheme colorScheme) {
    final limit = budgetLimit ?? 0;
    final remaining = budgetRemaining ?? 0;
    final usage = (budgetUsageRatio ?? 0.0).clamp(0.0, 1.0);
    final isOver = remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BUDGET'.toUpperCase(),
              style: AppTextStyles.label(context).copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Limit: ${CurrencyFormatter.format(limit)}',
              style: AppTextStyles.label(
                context,
              ).copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              CurrencyFormatter.format(remaining),
              style: AppTextStyles.amountDisplay(context).copyWith(
                color: isOver ? colorScheme.error : colorScheme.onSurface,
              ),
            ),
            Text('Remaining', style: AppTextStyles.bodySecondary(context)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: usage,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              isOver ? colorScheme.error : colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashflowRow(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THIS MONTH'.toUpperCase(),
          style: AppTextStyles.label(context).copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricItem(
                label: 'Income',
                amount: income,
                color: colorScheme.primary,
              ),
            ),
            Container(
              height: 32,
              width: 1,
              color: colorScheme.outlineVariant,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            Expanded(
              child: _MetricItem(
                label: 'Spent',
                amount: spent,
                color: colorScheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          CurrencyFormatter.format(amount),
          style: AppTextStyles.title(
            context,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: AppTextStyles.bodySecondary(context)),
      ],
    );
  }
}
