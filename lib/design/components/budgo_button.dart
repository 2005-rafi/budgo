import 'package:flutter/material.dart';
import 'package:expense/design/tokens/app_radius.dart';

enum BudgoButtonVariant { primary, tonal, outlined, destructive, text }

/// Uniform Material 3 Expressive capsule button handling primary, tonal,
/// outlined, destructive, and inline loading states from one point of control.
class BudgoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BudgoButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final double height;

  const BudgoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BudgoButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    this.height = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveOnPressed = isLoading ? null : onPressed;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.full),
    );

    final spinnerColor = switch (variant) {
      BudgoButtonVariant.primary => colorScheme.onPrimary,
      BudgoButtonVariant.destructive => colorScheme.onError,
      BudgoButtonVariant.tonal => colorScheme.onSecondaryContainer,
      BudgoButtonVariant.outlined || BudgoButtonVariant.text => colorScheme.primary,
    };

    final Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final Widget button = switch (variant) {
      BudgoButtonVariant.primary => FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height),
            shape: shape,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      BudgoButtonVariant.tonal => FilledButton.tonal(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height),
            shape: shape,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      BudgoButtonVariant.destructive => FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            minimumSize: Size(expanded ? double.infinity : 0, height),
            shape: shape,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      BudgoButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height),
            shape: shape,
            side: BorderSide(color: colorScheme.outlineVariant),
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      BudgoButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, height - 6),
            shape: shape,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
