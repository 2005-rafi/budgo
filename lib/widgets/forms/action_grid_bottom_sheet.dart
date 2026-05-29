import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/widgets/forms/transaction_bottom_sheet.dart';
import 'package:expense/widgets/forms/reminder_bottom_sheet.dart';
import 'package:expense/widgets/forms/budget_setup_sheet.dart';
import 'package:expense/widgets/forms/export_bottom_sheet.dart';

class ActionGridBottomSheet extends StatelessWidget {
  const ActionGridBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ActionGridBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: BudgoColors.bottomSheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Quick Actions',
            style: AppTextStyles.headline(context).copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select a tool or transaction flow',
            style: AppTextStyles.bodySecondary(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Scrollable Area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Group 1: Transactions ---
                  _buildSectionHeader(context, 'Transaction Actions'),
                  _ActionTile(
                    icon: Icons.receipt_outlined,
                    title: 'Add Expense',
                    subtitle: 'Record a new spending entry',
                    iconBgColor: colorScheme.errorContainer,
                    iconColor: colorScheme.onErrorContainer,
                    onTap: () {
                      Navigator.pop(context);
                      TransactionBottomSheet.show(context, mode: TransactionMode.expense);
                    },
                  ),
                  _ActionTile(
                    icon: Icons.trending_up,
                    title: 'Add Income',
                    subtitle: 'Record a credit amount or deposit',
                    iconBgColor: colorScheme.tertiaryContainer,
                    iconColor: colorScheme.onTertiaryContainer,
                    onTap: () {
                      Navigator.pop(context);
                      TransactionBottomSheet.show(context, mode: TransactionMode.income);
                    },
                  ),
                  
                  const SizedBox(height: AppSpacing.md),

                  // --- Group 2: Productivity ---
                  _buildSectionHeader(context, 'Productivity Tools'),
                  _ActionTile(
                    icon: Icons.alarm_outlined,
                    title: 'Reminder',
                    subtitle: 'Set up alerts for future bills',
                    iconBgColor: colorScheme.primaryContainer,
                    iconColor: colorScheme.onPrimaryContainer,
                    onTap: () {
                      Navigator.pop(context);
                      ReminderBottomSheet.show(context);
                    },
                  ),
                  _ActionTile(
                    icon: Icons.savings_outlined,
                    title: 'Budget Goal',
                    subtitle: 'Configure daily, weekly, monthly, or yearly limits',
                    iconBgColor: colorScheme.primaryContainer,
                    iconColor: colorScheme.onPrimaryContainer,
                    onTap: () {
                      Navigator.pop(context);
                      BudgetSetupSheet.show(context);
                    },
                  ),
                  _ActionTile(
                    icon: Icons.download_outlined,
                    title: 'Export Summary',
                    subtitle: 'Download PDF or CSV reports for archiving',
                    iconBgColor: colorScheme.secondaryContainer,
                    iconColor: colorScheme.onSecondaryContainer,
                    onTap: () {
                      Navigator.pop(context);
                      ExportBottomSheet.show(context);
                    },
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.label(context).copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }


}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Icon Background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.base),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
