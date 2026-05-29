import 'package:flutter/material.dart';
import 'package:expense/core/app_motion.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/widgets/common/app_card.dart';

class ChartPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? keyFinding;
  final Widget chart;
  final String? comparisonLabel;
  final List<Widget>? actions;

  const ChartPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.keyFinding,
    required this.chart,
    this.comparisonLabel,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Semantics(
      label: '$title: ${keyFinding ?? subtitle}',
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),

              // Key-finding chip
              if (keyFinding != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    keyFinding!,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Chart child with 7-1 · AnimatedSwitcher
              AnimatedSwitcher(
                duration: AppMotion.standard,
                child: SizedBox(
                  key: ValueKey(chart.hashCode),
                  child: chart,
                ),
              ),

              if (comparisonLabel != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      comparisonLabel!.startsWith('↑')
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 16,
                      color: comparisonLabel!.startsWith('↑')
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      comparisonLabel!,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
