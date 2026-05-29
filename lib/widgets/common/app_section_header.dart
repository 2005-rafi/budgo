import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';

class AppSectionHeader extends StatelessWidget {
  final String label;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const AppSectionHeader({
    super.key,
    required this.label,
    this.trailingLabel,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      margin: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingLabel != null)
            TextButton(
              onPressed: onTrailingTap,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                trailingLabel!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
