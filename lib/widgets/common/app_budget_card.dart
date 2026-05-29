import 'package:flutter/material.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_motion.dart';
import 'package:expense/core/currency_formatter.dart';

class AppBudgetCard extends StatelessWidget {
  final int? budgetLimit;
  final int spent;
  final int income;
  final bool isBudgetEnabled;
  final int? balance;
  final VoidCallback? onSetBudget;

  const AppBudgetCard({
    super.key,
    required this.budgetLimit,
    required this.spent,
    required this.income,
    this.isBudgetEnabled = true,
    this.balance,
    this.onSetBudget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Case 1: Budget mode is disabled (off)
    if (!isBudgetEnabled) {
      final Color cardBackground = colorScheme.surfaceContainerLow;
      final Color dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.5);

      return Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Income',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      CurrencyFormatter.format(income),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 0.5,
                height: 48,
                color: dividerColor,
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Spent',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      CurrencyFormatter.format(spent),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Case 2: No budget limit is set (and budget is enabled)
    if (budgetLimit == null || budgetLimit == 0) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: InkWell(
          onTap: onSetBudget,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Center(
            child: FilledButton.tonal(
              onPressed: onSetBudget,
              child: const Text('Set Budget'),
            ),
          ),
        ),
      );
    }

    final limit = budgetLimit!;
    final remaining = limit - spent;
    final isOver = remaining < 0;
    final double usageRatio = (spent / limit).clamp(0.0, 1.0);

    // Color definitions based on state
    final Color cardBackground = isOver ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final Color onCardColor = isOver ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;
    final Color remainingTextColor = isOver ? colorScheme.error : onCardColor;
    final Color progressColor = isOver ? colorScheme.error : colorScheme.primary;
    final Color progressTrackColor = (isOver ? colorScheme.error : colorScheme.primary).withValues(alpha: 0.2);
    final Color dividerColor = onCardColor.withValues(alpha: 0.2);

    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.curveStandard,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Header Label
            Text(
              'Budget',
              style: theme.textTheme.labelLarge?.copyWith(
                color: onCardColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Row 2: Headline Limit Value
            Text(
              CurrencyFormatter.format(limit),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onCardColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Row 3: Progress Bar
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: usageRatio),
              duration: AppMotion.enter,
              curve: AppMotion.curveStandard,
              builder: (context, value, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: progressTrackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xs),

            // Row 4: Remaining / Spent Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOver
                      ? 'Over Budget by ${CurrencyFormatter.format(remaining.abs())}'
                      : 'Remaining ${CurrencyFormatter.format(remaining)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: remainingTextColor,
                    fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '${(usageRatio * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onCardColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, thickness: 0.5, color: dividerColor),
            const SizedBox(height: AppSpacing.md),

            // Row 5: Footer split (Income & Spent)
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onCardColor.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          CurrencyFormatter.format(income),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onCardColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 0.5,
                    color: dividerColor,
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onCardColor.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          CurrencyFormatter.format(spent),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onCardColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
