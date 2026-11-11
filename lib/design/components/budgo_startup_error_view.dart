import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/design/components/budgo_button.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/design/tokens/app_text_styles.dart';

/// Branded, plain-English crash/startup failure recovery view preventing infinite
/// spinners or unstyled developer crash screens.
class BudgoStartupErrorView extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onCloseApp;
  final bool isRetrying;

  const BudgoStartupErrorView({
    super.key,
    this.title,
    this.message =
        'Something unexpected interrupted initialization. Your saved local financial records remain safe. Please retry opening your workspace or close and reopen the app.',
    this.onRetry,
    this.onCloseApp,
    this.isRetrying = false,
  });

  static Future<void> defaultCloseApp() async {
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
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
                      color: colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      size: 32,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title ?? 'Unable to finish starting ${AppBrand.appName}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMedium(context).copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (onRetry != null) ...[
                    BudgoButton(
                      label: 'Retry Startup',
                      icon: Icons.refresh_rounded,
                      isLoading: isRetrying,
                      onPressed: isRetrying ? null : onRetry,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  BudgoButton(
                    label: 'Close App',
                    icon: Icons.power_settings_new_rounded,
                    variant: onRetry != null
                        ? BudgoButtonVariant.outlined
                        : BudgoButtonVariant.destructive,
                    onPressed: isRetrying
                        ? null
                        : (onCloseApp ?? defaultCloseApp),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

