import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';

enum AppSettingsTileType {
  toggle,
  navigation,
  action,
  info,
  segmented,
}

class AppSettingsTile extends StatelessWidget {
  final AppSettingsTileType type;
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final String? trailingValue;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? segmentedWidget;

  const AppSettingsTile({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailingValue,
    this.value = false,
    this.onChanged,
    this.onTap,
    this.destructive = false,
    this.segmentedWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: destructive ? colorScheme.error : colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    // Construct leading widget
    Widget? leadingWidget;
    if (leadingIcon != null) {
      leadingWidget = Icon(
        leadingIcon,
        color: destructive ? colorScheme.error : colorScheme.onSurfaceVariant,
        size: 24,
      );
    }

    // Construct trailing widget based on type
    Widget? trailingWidget;
    switch (type) {
      case AppSettingsTileType.toggle:
        trailingWidget = Switch(
          value: value,
          onChanged: onChanged,
        );
        break;
      case AppSettingsTileType.navigation:
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingValue != null)
              Text(
                trailingValue!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        );
        break;
      case AppSettingsTileType.info:
        if (trailingValue != null) {
          trailingWidget = Text(
            trailingValue!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          );
        }
        break;
      case AppSettingsTileType.action:
      case AppSettingsTileType.segmented:
        // No trailing widget in root row list tile
        break;
    }

    // List tile padding and minHeight
    final double minHeight = (type == AppSettingsTileType.segmented || type == AppSettingsTileType.action) ? 64 : 56;
    final EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.base,
      vertical: AppSpacing.sm,
    );

    // Build row body
    Widget rowBody = Row(
      children: [
        if (leadingWidget != null) ...[
          leadingWidget,
          const SizedBox(width: AppSpacing.base),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: titleStyle),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: subtitleStyle),
              ],
            ],
          ),
        ),
        if (trailingWidget != null) ...[
          const SizedBox(width: AppSpacing.base),
          trailingWidget,
        ],
      ],
    );

    if (type == AppSettingsTileType.segmented && segmentedWidget != null) {
      rowBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rowBody,
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: segmentedWidget!,
          ),
        ],
      );
    }

    Widget content = InkWell(
      onTap: (type == AppSettingsTileType.toggle || type == AppSettingsTileType.segmented) ? null : onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: padding,
          child: rowBody,
        ),
      ),
    );

    // Destructive background tint
    if (destructive) {
      content = Container(
        color: colorScheme.errorContainer.withValues(alpha: 0.15),
        child: content,
      );
    }

    return content;
  }
}
