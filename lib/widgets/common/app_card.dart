import 'package:flutter/material.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool elevated;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.elevated = false,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.base),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: cardContent,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: cardContent,
    );
  }
}
