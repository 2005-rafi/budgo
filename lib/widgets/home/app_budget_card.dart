import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/services/safe_to_spend_service.dart';
import 'package:expense/widgets/sheets/safe_to_spend_derivation_sheet.dart';

class AppBudgetCard extends StatefulWidget {
  final int? budgetLimit;
  final int spent;
  final int income;
  final bool isBudgetEnabled;
  final int? balance;
  final SafeToSpendResult? safeToSpend;
  final int totalVaultsAllocated;
  final VoidCallback? onSetBudget;

  const AppBudgetCard({
    super.key,
    required this.budgetLimit,
    required this.spent,
    required this.income,
    this.isBudgetEnabled = true,
    this.balance,
    this.safeToSpend,
    this.totalVaultsAllocated = 0,
    this.onSetBudget,
  });

  @override
  State<AppBudgetCard> createState() => _AppBudgetCardState();
}

class _AppBudgetCardState extends State<AppBudgetCard> {
  bool _showFullPrecision = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPrivacyMode = context.watch<AppPreferencesProvider>().isPrivacyModeEnabled;

    final int currentBalance = widget.balance ?? (widget.income - widget.spent);
    final bool hasBudget = widget.isBudgetEnabled && widget.budgetLimit != null && widget.budgetLimit! > 0;
    final int limit = widget.budgetLimit ?? 0;
    final int remaining = limit - widget.spent;
    final bool isOver = hasBudget && remaining < 0;
    final double usageRatio = hasBudget ? (widget.spent / limit).clamp(0.0, 1.0) : 0.0;

    // Card background & color tokens
    final Color cardBackground = isOver
        ? colorScheme.errorContainer.withValues(alpha: 0.7)
        : colorScheme.surfaceContainerLow;
    final Color dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.4);

    // Balance text calculation with smart scaling
    final String balanceText;
    if (isPrivacyMode) {
      balanceText = '${MoneyFormatter.symbol} ••••••';
    } else if (_showFullPrecision) {
      balanceText = CurrencyFormatter.format(currentBalance);
    } else {
      balanceText = CurrencyFormatter.formatSmart(currentBalance);
    }

    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.curveStandard,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Tier 1: GPay Hero Total Balance & Safe-to-Spend Pill ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Balance',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          if (!isPrivacyMode) {
                            setState(() {
                              _showFullPrecision = !_showFullPrecision;
                            });
                          }
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.fast,
                            curve: AppMotion.curveStandard,
                            style: (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
                              color: currentBalance < 0
                                  ? colorScheme.error
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              letterSpacing: isPrivacyMode ? 2.0 : -0.5,
                            ),
                            child: Text(balanceText),
                          ),
                        ),
                      ),
                      if (widget.totalVaultsAllocated > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${CurrencyFormatter.format(widget.totalVaultsAllocated)} saved in vaults',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.safeToSpend != null && !isPrivacyMode) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _buildSafeToSpendBadge(context, widget.safeToSpend!),
                ],
              ],
            ),

            // --- Tier 2: Budget Progress (when enabled) ---
            if (widget.isBudgetEnabled) ...[
              const SizedBox(height: AppSpacing.sm),
              if (hasBudget) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: usageRatio),
                  duration: AppMotion.enter,
                  curve: AppMotion.curveStandard,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: (isOver ? colorScheme.error : colorScheme.primary)
                            .withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOver ? colorScheme.error : colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isOver
                          ? 'Over budget by ${CurrencyFormatter.format(remaining.abs())}'
                          : 'Remaining: ${CurrencyFormatter.format(remaining)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOver ? colorScheme.error : colorScheme.onSurfaceVariant,
                        fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '${(usageRatio * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Budget enabled but no limit configured yet
                InkWell(
                  onTap: widget.onSetBudget,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'No budget limit set',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Set Budget',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, thickness: 0.5, color: dividerColor),
            const SizedBox(height: AppSpacing.sm),

            // --- Tier 3: Subtotal Split (Total Income vs Total Spent) ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Income',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isPrivacyMode
                              ? '${MoneyFormatter.symbol} ••••'
                              : CurrencyFormatter.format(widget.income),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 36,
                  color: dividerColor,
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Spent',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isPrivacyMode
                              ? '${MoneyFormatter.symbol} ••••'
                              : CurrencyFormatter.format(widget.spent),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeToSpendBadge(BuildContext context, SafeToSpendResult sts) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color badgeColor;
    final Color textColor;
    final String label;
    final String sublabel;

    if (sts.isDeficit) {
      badgeColor = colorScheme.errorContainer;
      textColor = colorScheme.onErrorContainer;
      label = sts.deficitPaise > 0
          ? 'Deficit: ${CurrencyFormatter.format(sts.deficitPaise)}'
          : '${CurrencyFormatter.format(0)} / day';
      sublabel = sts.isBudgetedMode ? 'Over budget' : 'Over limit';
    } else if (sts.isTight) {
      badgeColor = Colors.amber.withValues(alpha: 0.18);
      textColor = Colors.amber.shade900;
      label = '${CurrencyFormatter.format(sts.dailyAllowancePaise)} / day';
      sublabel = 'Tight limit';
    } else {
      badgeColor = colorScheme.secondaryContainer.withValues(alpha: 0.7);
      textColor = colorScheme.onSecondaryContainer;
      label = '${CurrencyFormatter.format(sts.dailyAllowancePaise)} / day';
      sublabel = 'Safe to spend';
    }

    return Semantics(
      button: true,
      label: 'Explain daily spend calculation',
      child: BudgoPressable(
        key: const ValueKey('safe_to_spend_badge'),
        onTap: () => SafeToSpendDerivationSheet.show(
          context,
          result: sts,
          onSetBudget: widget.onSetBudget,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sublabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: textColor.withValues(alpha: 0.85),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 11,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
