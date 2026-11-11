import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/services/safe_to_spend_service.dart';

/// Interactive educational breakdown bottom sheet showing the exact,
/// plain-English arithmetic derivation behind the Safe-to-Spend daily limit.
class SafeToSpendDerivationSheet extends StatelessWidget {
  final SafeToSpendResult result;
  final VoidCallback? onSetBudget;

  const SafeToSpendDerivationSheet({
    super.key,
    required this.result,
    this.onSetBudget,
  });

  static Future<void> show(
    BuildContext context, {
    required SafeToSpendResult result,
    VoidCallback? onSetBudget,
  }) {
    return BudgoBottomSheet.show(
      context,
      builder: (_) => SafeToSpendDerivationSheet(
        result: result,
        onSetBudget: onSetBudget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final monthShort = DateFormat('MMM').format(now);
    final sym = MoneyFormatter.symbol;

    final int startingPool = result.isBudgetedMode
        ? (result.budgetLimitPaise ?? 0)
        : result.confirmedIncomeThisMonthPaise;

    final String statusTitle;
    final String statusSubtitle;
    final Color accentBg;
    final Color accentFg;
    final IconData statusIcon;

    if (result.isDeficit) {
      statusTitle = result.deficitPaise > 0
          ? 'Deficit: ${CurrencyFormatter.format(result.deficitPaise)}'
          : '${CurrencyFormatter.format(0)} / day';
      statusSubtitle = 'Over safe spending limit';
      accentBg = colorScheme.errorContainer;
      accentFg = colorScheme.onErrorContainer;
      statusIcon = Icons.warning_amber_rounded;
    } else if (result.isTight) {
      statusTitle = '${CurrencyFormatter.format(result.dailyAllowancePaise)} / day';
      statusSubtitle = 'Tight daily limit (below ${CurrencyFormatter.format(20000)}/day)';
      accentBg = Colors.amber.withValues(alpha: 0.18);
      accentFg = Colors.amber.shade900;
      statusIcon = Icons.speed_rounded;
    } else {
      statusTitle = '${CurrencyFormatter.format(result.dailyAllowancePaise)} / day';
      statusSubtitle = 'Healthy daily spend allowance';
      accentBg = colorScheme.secondaryContainer.withValues(alpha: 0.85);
      accentFg = colorScheme.onSecondaryContainer;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    final exactRupees = result.exactDailyPaise / 100.0;
    final conservativeTotal = result.dailyAllowancePaise * result.daysRemaining;
    final dayWord = result.daysRemaining == 1 ? 'day' : 'days';

    return BudgoBottomSheet(
      title: 'How Daily Safe-to-Spend Works',
      subtitle: result.isBudgetedMode
          ? 'Based on your active monthly budget'
          : 'Based on your $monthName income (no budget limit set)',
      icon: Icons.calculate_outlined,
      footer: Row(
        children: [
          if (!result.isBudgetedMode && onSetBudget != null) ...[
            Expanded(
              child: BudgoButton(
                label: 'Set Budget',
                variant: BudgoButtonVariant.tonal,
                onPressed: () {
                  Navigator.pop(context);
                  onSetBudget?.call();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: BudgoButton(
              label: 'Got It',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero summary card
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: accentFg, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: accentFg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accentFg.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Plain-English misconception clarifier
            BudgoCard(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      result.spentThisMonthPaise == 0 && !result.isDeficit
                          ? 'This is your daily spending limit for the rest of $monthName — not an expense average. Even with ${CurrencyFormatter.format(0)} spent, it shows how much you can safely spend each day so your remaining money lasts all ${result.daysRemaining} $dayWord.'
                          : 'This is the maximum amount you can safely spend per day from today ($monthShort ${result.currentDay}) through $monthShort ${result.daysInMonth} without exceeding your remaining balance or reserves.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            const BudgoSectionHeader(label: 'Step-by-Step Derivation'),
            BudgoCard(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MathRow(
                    step: '1',
                    label: result.isBudgetedMode
                        ? 'Monthly Budget Limit'
                        : 'Confirmed Income ($monthName)',
                    value: CurrencyFormatter.format(startingPool),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MathRow(
                    step: '2',
                    label: 'Minus Already Spent ($monthName)',
                    value: '− ${CurrencyFormatter.format(result.spentThisMonthPaise)}',
                    valueColor: result.spentThisMonthPaise > 0
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  if (!result.isBudgetedMode && result.pendingRemindersPaise > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _MathRow(
                      step: '3',
                      label: 'Minus Upcoming Bills This Month',
                      value: '− ${CurrencyFormatter.format(result.pendingRemindersPaise)}',
                      valueColor: colorScheme.error,
                    ),
                  ],
                  if (result.totalVaultsAllocatedPaise > 0 ||
                      result.wasCappedByLiquidBalance) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _MathRow(
                      step: (!result.isBudgetedMode &&
                              result.pendingRemindersPaise > 0)
                          ? '4'
                          : '3',
                      label: result.wasCappedByLiquidBalance
                          ? 'Capped to Free Cash & Bank Pool'
                          : 'Savings Vaults Excluded (Protected)',
                      value: result.wasCappedByLiquidBalance
                          ? CurrencyFormatter.format(result.liquidUnallocatedPaise)
                          : '${CurrencyFormatter.format(result.totalVaultsAllocatedPaise)} safe',
                      valueColor: colorScheme.secondary,
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Divider(height: 1),
                  ),
                  _MathRow(
                    label: 'Money Available for Rest of $monthName',
                    value: CurrencyFormatter.format(result.effectiveDiscretionaryPaise),
                    isEmphasized: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MathRow(
                    label: 'Days Left ($monthShort ${result.currentDay} – $monthShort ${result.daysInMonth})',
                    value: '${result.daysRemaining} $dayWord',
                    isEmphasized: true,
                  ),
                  if (!result.isDeficit) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Formula',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${CurrencyFormatter.format(result.effectiveDiscretionaryPaise)} ÷ ${result.daysRemaining} $dayWord = '
                            '$sym${exactRupees.toStringAsFixed(3)} → ${CurrencyFormatter.format(result.dailyAllowancePaise)} / day',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rounded down to the nearest unit so ${result.daysRemaining} × ${CurrencyFormatter.format(result.dailyAllowancePaise)} = ${CurrencyFormatter.format(conservativeTotal)} never exceeds ${CurrencyFormatter.format(result.effectiveDiscretionaryPaise)}.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Simple threshold reference
            Text(
              'Status Guide: ${CurrencyFormatter.format(20000)}+/day = Comfortable • Under ${CurrencyFormatter.format(20000)}/day = Tight limit • ${CurrencyFormatter.format(0)} or less = Over limit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MathRow extends StatelessWidget {
  final String? step;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isEmphasized;

  const _MathRow({
    this.step,
    required this.label,
    required this.value,
    this.valueColor,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (step != null) ...[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              step!,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isEmphasized
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
              fontWeight: isEmphasized ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: (isEmphasized
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodySmall)
              ?.copyWith(
            color: valueColor ?? colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

