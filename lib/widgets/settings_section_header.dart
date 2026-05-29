import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_text_styles.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.lg,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall(context).copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
