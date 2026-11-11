import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expense/core/constants/app_input_limits.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/design/theme/app_theme_extensions.dart';
import 'package:expense/design/tokens/app_motion.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/design/tokens/app_text_styles.dart';

/// Dynamic tabular character counter with limit warning threshold and policy rule hint.
class BudgoCharacterCounter extends StatelessWidget {
  final int currentCount;
  final int maxCount;
  final String? ruleHint;
  final bool showRuleHint;

  const BudgoCharacterCounter({
    super.key,
    required this.currentCount,
    required this.maxCount,
    this.ruleHint,
    this.showRuleHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAtLimit = currentCount >= maxCount;
    final isNearLimit = currentCount >= (maxCount * 0.85).floor();

    final badgeColor = isAtLimit
        ? colorScheme.error
        : (isNearLimit ? Colors.amber.shade700 : colorScheme.onSurfaceVariant);

    final badgeBackground = isAtLimit
        ? colorScheme.errorContainer.withValues(alpha: 0.5)
        : (isNearLimit
            ? Colors.amber.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHigh.withValues(alpha: 0.5));

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: (showRuleHint && ruleHint != null && ruleHint!.isNotEmpty)
                ? Text(
                    ruleHint!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isAtLimit ? colorScheme.error : colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '$currentCount / $maxCount',
              style: theme.textTheme.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: isNearLimit ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated inline validation or status helper strip.
class BudgoValidationText extends StatelessWidget {
  final String? message;
  final bool isError;

  const BudgoValidationText({
    super.key,
    this.message,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    final show = message != null && message!.isNotEmpty;
    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.curveStandard,
      child: show
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                    color: isError
                        ? BudgoColors.budgetOver(context)
                        : BudgoColors.warningColor(context),
                    size: 14,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      message!,
                      style: AppTextStyles.labelSmall(context).copyWith(
                        color: isError
                            ? BudgoColors.budgetOver(context)
                            : BudgoColors.warningColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// Uniform Material 3 Expressive text field wrapped around [TextFormField].
class BudgoTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? prefix;
  final String? prefixText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final bool readOnly;
  final bool enabled;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final BudgoInputPolicy? inputPolicy;
  final bool showCounter;

  const BudgoTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.prefixText,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.inputPolicy,
    this.showCounter = true,
  });

  @override
  State<BudgoTextField> createState() => _BudgoTextFieldState();
}

class _BudgoTextFieldState extends State<BudgoTextField> {
  late int _currentLength;

  @override
  void initState() {
    super.initState();
    _currentLength = widget.controller?.text.characters.length ?? 0;
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(BudgoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
      _currentLength = widget.controller?.text.characters.length ?? 0;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final len = widget.controller?.text.characters.length ?? 0;
    if (_currentLength != len) {
      setState(() {
        _currentLength = len;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveMax = widget.maxLength ?? widget.inputPolicy?.maxLength;
    final effectiveFormatters = <TextInputFormatter>[
      if (widget.inputPolicy != null) ...widget.inputPolicy!.formatters,
      if (widget.inputFormatters != null) ...widget.inputFormatters!,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          inputFormatters: effectiveFormatters.isNotEmpty ? effectiveFormatters : null,
          validator: widget.validator,
          onChanged: (val) {
            if (widget.controller == null) {
              setState(() {
                _currentLength = val.characters.length;
              });
            }
            widget.onChanged?.call(val);
          },
          onFieldSubmitted: widget.onSubmitted,
          maxLength: effectiveMax,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          autofocus: widget.autofocus,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          textAlign: widget.textAlign,
          style: widget.textStyle ??
              theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            helperText: widget.showCounter && effectiveMax != null ? null : widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 20) : null,
            prefix: widget.prefix,
            prefixText: widget.prefixText,
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: widget.readOnly
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
                : colorScheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.fieldGap,
            ),
            counter: const SizedBox.shrink(),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              borderSide: BorderSide(color: colorScheme.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              borderSide: BorderSide(color: colorScheme.error, width: 1.8),
            ),
          ),
        ),
        if (widget.showCounter && effectiveMax != null)
          BudgoCharacterCounter(
            currentCount: _currentLength,
            maxCount: effectiveMax,
            ruleHint: widget.inputPolicy?.ruleHint ?? widget.helperText,
          ),
      ],
    );
  }
}

/// Uniform monetary input field dynamically bound to [MoneyFormatter.symbol].
class BudgoAmountField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool readOnly;
  final List<int>? quickPresetsPaise;
  final void Function(int paise)? onPresetSelected;
  final bool showFullBalanceAction;
  final VoidCallback? onFullBalanceTap;

  const BudgoAmountField({
    super.key,
    this.controller,
    this.label = 'Amount',
    this.hint = '0.00',
    this.helperText,
    this.errorText,
    this.validator,
    this.onChanged,
    this.autofocus = false,
    this.readOnly = false,
    this.quickPresetsPaise,
    this.onPresetSelected,
    this.showFullBalanceAction = false,
    this.onFullBalanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final symbol = MoneyFormatter.symbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BudgoTextField(
          controller: controller,
          label: '$label ($symbol)',
          hint: hint,
          helperText: helperText,
          errorText: errorText,
          autofocus: autofocus,
          readOnly: readOnly,
          maxLength: AppInputLimits.amountInputMaxChars,
          showCounter: false,
          inputFormatters: AppInputLimits.decimalAmountFormatters,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
          onChanged: onChanged,
          textStyle: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          prefix: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Text(
              symbol,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        if ((quickPresetsPaise != null && quickPresetsPaise!.isNotEmpty) ||
            showFullBalanceAction) ...[
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (quickPresetsPaise != null)
                  ...quickPresetsPaise!.map(
                    (paise) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ActionChip(
                        label: Text('+${CurrencyFormatter.formatCompact(paise)}'),
                        onPressed: onPresetSelected == null
                            ? null
                            : () => onPresetSelected!(paise),
                      ),
                    ),
                  ),
                if (showFullBalanceAction)
                  ActionChip(
                    avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                    label: const Text('Full Balance'),
                    onPressed: onFullBalanceTap,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Stadium capsule search input with instant animated clear button.
class BudgoSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCleared;

  const BudgoSearchField({
    super.key,
    required this.controller,
    this.hint = 'Search...',
    required this.onChanged,
    this.onCleared,
  });

  @override
  State<BudgoSearchField> createState() => _BudgoSearchFieldState();
}

class _BudgoSearchFieldState extends State<BudgoSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(covariant BudgoSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChange);
      widget.controller.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      maxLength: AppInputLimits.searchQueryMax,
      inputFormatters: [
        LengthLimitingTextInputFormatter(AppInputLimits.searchQueryMax),
      ],
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        counter: const SizedBox.shrink(),
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                  widget.onCleared?.call();
                },
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
    );
  }
}
