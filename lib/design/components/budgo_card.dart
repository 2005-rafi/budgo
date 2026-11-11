import 'package:flutter/material.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';

/// Unified Material 3 Expressive surface card.
class BudgoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool elevated;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? border;
  final double borderRadius;

  const BudgoCard({
    super.key,
    required this.child,
    this.padding,
    this.elevated = false,
    this.onTap,
    this.color,
    this.border,
    this.borderRadius = AppRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);

    Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.base),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: cardContent,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? colorScheme.surfaceContainerLow,
        borderRadius: radius,
        border: border != null ? Border.fromBorderSide(border!) : null,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: cardContent,
    );
  }
}

/// Alias preserving backwards-compatible name [AppCard] mapped to [BudgoCard].
typedef AppCard = BudgoCard;

/// Standardized section header with optional right-aligned action link.
class BudgoSectionHeader extends StatelessWidget {
  final String label;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final EdgeInsetsGeometry? padding;

  const BudgoSectionHeader({
    super.key,
    required this.label,
    this.trailingLabel,
    this.onTrailingTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.base),
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
                fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Alias preserving backwards-compatible name [AppSectionHeader].
typedef AppSectionHeader = BudgoSectionHeader;
