import 'package:flutter/material.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';

/// Descriptor for rich dropdown items with optional icon and trailing balance/meta.
class BudgoDropdownItem<T> {
  final T value;
  final String label;
  final String? trailingText;
  final IconData? icon;
  final Color? iconColor;

  const BudgoDropdownItem({
    required this.value,
    required this.label,
    this.trailingText,
    this.icon,
    this.iconColor,
  });
}

/// Uniform Material 3 Expressive dropdown selector backed by [DropdownButtonFormField].
/// Supports either structured [options] or explicit [customItems] while preserving
/// exact form validation and tonal container consistency with [BudgoTextField].
class BudgoDropdownField<T> extends StatelessWidget {
  final T? value;
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final List<BudgoDropdownItem<T>>? options;
  final List<DropdownMenuItem<T>>? customItems;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final bool isDense;
  final Color? fillColor;

  const BudgoDropdownField({
    super.key,
    required this.value,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.options,
    this.customItems,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.isDense = false,
    this.fillColor,
  }) : assert(
          options != null || customItems != null,
          'Provide either options or customItems.',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool hasValue = customItems != null
        ? customItems!.any((item) => item.value == value)
        : (options?.any((opt) => opt.value == value) ?? false);

    final safeValue = hasValue
        ? value
        : (customItems != null
            ? (customItems!.isNotEmpty ? customItems!.first.value : null)
            : (options != null && options!.isNotEmpty
                ? options!.first.value
                : null));

    final List<DropdownMenuItem<T>> builtItems = customItems ??
        options!.map((opt) {
          final isSelected = opt.value == safeValue;
          return DropdownMenuItem<T>(
            value: opt.value,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  if (opt.icon != null) ...[
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (opt.iconColor ?? colorScheme.primary)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        opt.icon,
                        size: 18,
                        color: opt.iconColor ?? colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      opt.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (isDense
                              ? theme.textTheme.labelLarge
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (opt.trailingText != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.14)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        opt.trailingText!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  if (isSelected) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList();

    final selectedBuilder = options != null
        ? (BuildContext _) {
            return options!.map((opt) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (opt.icon != null) ...[
                    Icon(
                      opt.icon,
                      size: isDense ? 18 : 20,
                      color: opt.iconColor ?? colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      opt.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (isDense
                              ? theme.textTheme.labelLarge
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (opt.trailingText != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        opt.trailingText!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }).toList();
          }
        : null;

    return DropdownButtonFormField<T>(
      initialValue: safeValue,
      isExpanded: true,
      isDense: isDense,
      items: builtItems,
      selectedItemBuilder: selectedBuilder,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      menuMaxHeight: 320,
      focusColor: Colors.transparent,
      elevation: 3,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      dropdownColor: colorScheme.surfaceContainerHigh,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        filled: true,
        fillColor: fillColor ?? colorScheme.surfaceContainerLow,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isDense ? AppSpacing.md : AppSpacing.base,
          vertical: isDense ? AppSpacing.sm : AppSpacing.fieldGap,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
      ),
    );
  }
}

/// Uniform tap-to-open date/time selector matching [BudgoTextField] geometry.
class BudgoPickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData trailingIcon;

  const BudgoPickerField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailingIcon = Icons.keyboard_arrow_down_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadius.field);

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(trailingIcon, size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
