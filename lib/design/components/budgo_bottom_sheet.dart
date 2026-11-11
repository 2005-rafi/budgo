import 'package:flutter/material.dart';
import 'package:expense/design/theme/app_theme_extensions.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/design/tokens/app_text_styles.dart';

/// Unified Material 3 Expressive modal bottom sheet container enforcing coherent
/// drag handle geometry, tonal surface, keyboard inset clearance, header chrome,
/// and optional pinned footer CTA.
class BudgoBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;
  final Widget? footer;
  final double maxHeightFactor;
  final EdgeInsetsGeometry contentPadding;
  final bool useSafeArea;

  const BudgoBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    required this.child,
    this.footer,
    this.maxHeightFactor = 0.88,
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppSpacing.sheetPadding,
      AppSpacing.md,
      AppSpacing.sheetPadding,
      AppSpacing.sheetPadding,
    ),
    this.useSafeArea = true,
  });

  /// Helper opening any modal sheet using standardized transparent barrier +
  /// keyboard-aware scroll physics.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = useSafeArea ? MediaQuery.viewPaddingOf(context).bottom : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: BoxDecoration(
          color: BudgoColors.bottomSheetSurface(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: contentPadding.add(
          EdgeInsets.only(bottom: safeBottom > 0 ? safeBottom * 0.5 : 0.0),
        ),
        constraints: BoxConstraints(
          maxHeight: screenHeight * maxHeightFactor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle Pill
            Center(
              child: Container(
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: AppSpacing.base),
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (iconColor ?? colorScheme.primary)
                            .withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: iconColor ?? colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ) ??
                              AppTextStyles.headline(context),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ) ??
                                AppTextStyles.bodySecondary(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Flexible(child: child),
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.md),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Alias preserving backwards-compatible name [AppBottomSheetContainer].
typedef AppBottomSheetContainer = BudgoBottomSheet;
