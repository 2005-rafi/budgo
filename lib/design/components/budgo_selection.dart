import 'package:flutter/material.dart';
import 'package:expense/design/tokens/app_motion.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';

/// Descriptor for single or multi selection chips in [BudgoChoiceGroup] / [BudgoMultiChoiceGroup].
class BudgoChoiceOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
  final Color? accentColor;

  const BudgoChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.selectedIcon,
    this.accentColor,
  });
}

/// Uniform Material 3 Expressive capsule chip built on top of [ChoiceChip].
class BudgoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final IconData? selectedIcon;
  final Color? accentColor;
  final Widget? avatar;

  const BudgoChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.selectedIcon,
    this.accentColor,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = accentColor ?? colorScheme.primary;
    final effectiveIcon = selected ? (selectedIcon ?? icon) : icon;

    final resolvedAvatar = avatar ??
        (effectiveIcon != null
            ? Icon(
                effectiveIcon,
                size: 16,
                color: selected
                    ? (accentColor ?? colorScheme.onSecondaryContainer)
                    : colorScheme.onSurfaceVariant,
              )
            : null);

    return ChoiceChip(
      label: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
      avatar: resolvedAvatar,
      selected: selected,
      showCheckmark: resolvedAvatar == null,
      onSelected: onSelected,
      backgroundColor: colorScheme.surfaceContainerLow,
      selectedColor: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      side: BorderSide(
        color: selected
            ? activeColor.withValues(alpha: 0.4)
            : colorScheme.outlineVariant.withValues(alpha: 0.65),
        width: selected ? 1.2 : 1.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Backwards-compatible alias forwarding [AppFilterChip] calls into [BudgoChip].
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
    return BudgoChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      icon: icon,
    );
  }
}

/// Single-choice expressive chip group with optional collapsible "More / Less" toggle.
class BudgoChoiceGroup<T> extends StatefulWidget {
  final List<BudgoChoiceOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final int? maxVisibleCount;
  final bool allowHorizontalScroll;

  const BudgoChoiceGroup({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.maxVisibleCount,
    this.allowHorizontalScroll = false,
  });

  @override
  State<BudgoChoiceGroup<T>> createState() => _BudgoChoiceGroupState<T>();
}

class _BudgoChoiceGroupState<T> extends State<BudgoChoiceGroup<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.allowHorizontalScroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: widget.options.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: BudgoChip(
                label: opt.label,
                icon: opt.icon,
                selectedIcon: opt.selectedIcon,
                accentColor: opt.accentColor,
                selected: widget.selectedValue == opt.value,
                onSelected: (isSel) {
                  if (isSel) widget.onSelected(opt.value);
                },
              ),
            );
          }).toList(),
        ),
      );
    }

    final maxCap = widget.maxVisibleCount;
    final canExpand = maxCap != null && widget.options.length > maxCap;

    List<BudgoChoiceOption<T>> visible = !canExpand || _expanded
        ? widget.options
        : widget.options.take(maxCap).toList();

    if (canExpand &&
        !_expanded &&
        widget.selectedValue != null &&
        !visible.any((o) => o.value == widget.selectedValue)) {
      final selectedOpt = widget.options
          .where((o) => o.value == widget.selectedValue)
          .firstOrNull;
      if (selectedOpt != null) {
        visible = [...visible, selectedOpt];
      }
    }

    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.curveStandard,
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...visible.map((opt) {
            return BudgoChip(
              label: opt.label,
              icon: opt.icon,
              selectedIcon: opt.selectedIcon,
              accentColor: opt.accentColor,
              selected: widget.selectedValue == opt.value,
              onSelected: (isSel) {
                if (isSel) widget.onSelected(opt.value);
              },
            );
          }),
          if (canExpand)
            ActionChip(
              avatar: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              label: Text(
                _expanded ? 'Less' : 'More (${widget.options.length})',
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
        ],
      ),
    );
  }
}

/// Multi-select expressive chip group cleanly reusable in filter sheets.
class BudgoMultiChoiceGroup<T> extends StatelessWidget {
  final List<BudgoChoiceOption<T>> options;
  final Set<T> selectedValues;
  final ValueChanged<T> onToggle;

  const BudgoMultiChoiceGroup({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: options.map((opt) {
        final isSel = selectedValues.contains(opt.value);
        return BudgoChip(
          label: opt.label,
          icon: opt.icon,
          selectedIcon: opt.selectedIcon,
          accentColor: opt.accentColor,
          selected: isSel,
          onSelected: (_) => onToggle(opt.value),
        );
      }).toList(),
    );
  }
}

/// Uniform Material 3 Expressive segmented pill bar replacing duplicate
/// [SegmentedButton.styleFrom] blocks across screens & sheets.
class BudgoSegmentedControl<T> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool showSelectedIcon;

  const BudgoSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.showSelectedIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: segments,
        selected: {selected},
        onSelectionChanged: (next) {
          if (next.isNotEmpty) onSelected(next.first);
        },
        showSelectedIcon: showSelectedIcon,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.comfortable,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
    );
  }
}
