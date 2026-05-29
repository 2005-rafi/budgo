import 'package:flutter/material.dart';
import 'package:expense/core/app_durations.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/currency_formatter.dart';

class SmartKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget rightWidget;

  const SmartKpiCard._({
    required this.icon,
    required this.label,
    required this.rightWidget,
  });

  factory SmartKpiCard.topCategory({
    required String category,
    required int amount,
  }) {
    return SmartKpiCard._(
      icon: Icons.category_outlined,
      label: 'Top Category',
      rightWidget: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                category.isNotEmpty ? category : 'None',
                style: AppTextStyles.titleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: amount.toDouble()),
                duration: AppDurations.slow,
                builder: (context, value, child) {
                  return Text(
                    CurrencyFormatter.format(value.round()),
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  factory SmartKpiCard.avgDailySpend({
    required double avgAmount,
  }) {
    return SmartKpiCard._(
      icon: Icons.today_outlined,
      label: 'Daily Average',
      rightWidget: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: avgAmount),
                duration: AppDurations.slow,
                builder: (context, value, child) {
                  return Text(
                    CurrencyFormatter.format(value.round()),
                    style: AppTextStyles.amountLarge(context),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                'this month',
                style: AppTextStyles.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  factory SmartKpiCard.savingsRate({
    required double income,
    required double spent,
  }) {
    final rate = income > 0 ? (((income - spent) / income) * 100).clamp(0.0, 100.0) : 0.0;
    
    return SmartKpiCard._(
      icon: Icons.savings_outlined,
      label: 'Savings Rate',
      rightWidget: Builder(
        builder: (context) {
          if (income <= 0) {
            return const SizedBox.shrink();
          }
          final colorScheme = Theme.of(context).colorScheme;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: rate),
                duration: AppDurations.slow,
                builder: (context, value, child) {
                  return Text(
                    '${value.toStringAsFixed(0)}%',
                    style: AppTextStyles.amountLarge(context),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                'of confirmed income',
                style: AppTextStyles.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Left Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 24,
                color: colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Right Content
          rightWidget,
        ],
      ),
    );
  }
}
