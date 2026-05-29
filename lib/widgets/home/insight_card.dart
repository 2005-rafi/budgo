import 'package:flutter/material.dart';
import 'package:expense/models/view_models/insight_model.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';


class InsightCard extends StatelessWidget {
  final InsightModel insight;

  const InsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWarning = insight.type == 'warning';
    
    final background = isWarning
        ? BudgoColors.insightWarningBackground(context)
        : BudgoColors.insightNeutralBackground(context);

    final textColor = isWarning
        ? BudgoColors.insightWarningText(context)
        : colorScheme.onSurface;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: InkWell(
        onTap: () {
          // Open detail dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(insight.title),
              content: Text(insight.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 200.0,
          height: 80.0,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: isWarning
                      ? colorScheme.error.withValues(alpha: 0.12)
                      : colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  insight.icon,
                  size: 16.0,
                  color: isWarning ? colorScheme.error : colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      insight.title,
                      style: AppTextStyles.label(context).copyWith(
                        color: isWarning ? textColor : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      insight.message,
                      style: AppTextStyles.bodySecondary(context).copyWith(
                        color: textColor.withValues(alpha: 0.85),
                        fontSize: 12.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
