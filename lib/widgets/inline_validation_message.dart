import 'package:flutter/material.dart';
import 'package:expense/core/app_durations.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';

class InlineValidationMessage extends StatelessWidget {
  final String? message;
  final bool isError;

  const InlineValidationMessage({
    super.key,
    this.message,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    final show = message != null && message!.isNotEmpty;

    return AnimatedSize(
      duration: AppDurations.fast,
      curve: Curves.easeInOut,
      child: show
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.info_outline,
                    color: isError
                        ? BudgoColors.expenseColor(context)
                        : BudgoColors.warningColor(context),
                    size: 14,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      message!,
                      style: AppTextStyles.labelSmall(context).copyWith(
                        color: isError
                            ? BudgoColors.expenseColor(context)
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
