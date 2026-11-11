import 'package:flutter/material.dart';
import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/design/tokens/app_motion.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/design/tokens/app_text_styles.dart';
import 'package:expense/design/components/budgo_button.dart';
import 'package:expense/design/components/budgo_pressable.dart';

/// Model representing a single button cell in the layered action matrix.
class BudgoActionCell {
  final String label;
  final VoidCallback onPressed;
  final BudgoButtonVariant variant;
  final IconData? icon;

  const BudgoActionCell({
    required this.label,
    required this.onPressed,
    this.variant = BudgoButtonVariant.primary,
    this.icon,
  });
}

/// Borderless layered action matrix for multi-action dialogs.
/// Formatted cleanly without table borders in a 3-tier hierarchy:
/// - Level 1: Primary actions (e.g. Mark as Paid | Skip Cycle)
/// - Level 2: Secondary / destructive actions (e.g. Delete | Edit)
/// - Level 3: Cancel / dismiss action (expanded to match full width of above levels)
class BudgoLayeredActionLayout extends StatelessWidget {
  final List<BudgoActionCell> level1;
  final List<BudgoActionCell> level2;
  final BudgoActionCell level3;

  const BudgoLayeredActionLayout({
    super.key,
    required this.level1,
    required this.level2,
    required this.level3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (level1.isNotEmpty) ...[
          Row(
            children: [
              for (int i = 0; i < level1.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: BudgoButton(
                    label: level1[i].label,
                    icon: level1[i].icon,
                    variant: level1[i].variant,
                    height: 42,
                    expanded: true,
                    onPressed: level1[i].onPressed,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (level2.isNotEmpty) ...[
          Row(
            children: [
              for (int i = 0; i < level2.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: BudgoButton(
                    label: level2[i].label,
                    icon: level2[i].icon,
                    variant: level2[i].variant,
                    height: 42,
                    expanded: true,
                    onPressed: level2[i].onPressed,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        BudgoButton(
          label: level3.label,
          icon: level3.icon,
          variant: level3.variant,
          height: 42,
          expanded: true,
          onPressed: level3.onPressed,
        ),
      ],
    );
  }
}

/// Material 3 Expressive Action Dialog wrapping content and a [BudgoLayeredActionLayout].
class BudgoActionDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final BudgoLayeredActionLayout actions;

  const BudgoActionDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    required BudgoLayeredActionLayout actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => BudgoActionDialog(
        title: title,
        message: message,
        content: content,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: AppTextStyles.titleMedium(context).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null && message!.isNotEmpty)
              Text(
                message!,
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (content != null) ...[
              if (message != null) const SizedBox(height: AppSpacing.md),
              content!,
            ],
            const SizedBox(height: AppSpacing.lg),
            actions,
          ],
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      buttonPadding: EdgeInsets.zero,
    );
  }
}

/// Unified Material 3 Expressive confirmation modal dialog.
class ConfirmationDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            BudgoButton(
              label: cancelLabel,
              variant: BudgoButtonVariant.text,
              expanded: false,
              height: 44,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            BudgoButton(
              label: confirmLabel,
              variant: isDestructive
                  ? BudgoButtonVariant.destructive
                  : BudgoButtonVariant.primary,
              expanded: false,
              height: 44,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

typedef BudgoConfirmDialog = ConfirmationDialog;

class AppExitDialog extends StatelessWidget {
  const AppExitDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Exit Dialog',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: AppMotion.standard,
      pageBuilder: (context, anim1, anim2) => const AppExitDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: AppMotion.curveExpressive,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.errorContainer,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: colorScheme.onErrorContainer,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Exit ${AppBrand.appName}?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Are you sure you want to close the app? Any unsaved changes might be lost.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: BudgoPressable(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Stay Back',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: BudgoPressable(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Center(
                        child: Text(
                          'Quit App',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onError,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
