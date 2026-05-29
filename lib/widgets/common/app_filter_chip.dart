import 'package:flutter/material.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_motion.dart';

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fillColor = selected
        ? colorScheme.secondaryContainer
        : Colors.transparent;

    final textColor = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    final borderSide = selected
        ? BorderSide.none
        : BorderSide(color: colorScheme.outline, width: 1.0);

    return InkWell(
      onTap: () => onSelected(!selected),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curveStandard,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
