import 'package:flutter/material.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/widgets/common/app_section_header.dart';
import 'package:expense/widgets/forms/transaction_bottom_sheet.dart';
import 'package:expense/widgets/forms/reminder_bottom_sheet.dart';
import 'package:expense/widgets/forms/budget_setup_sheet.dart';
import 'package:expense/widgets/forms/export_bottom_sheet.dart';

class AppQuickActionsSheet extends StatelessWidget {
  const AppQuickActionsSheet({super.key});

  static void show(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => const AppQuickActionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.72,
      ),
      padding: const EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.base,
        bottom: AppSpacing.lg,
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
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Title & Description Headers
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select a task',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Options List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppSectionHeader(label: 'Transactions'),
                  _AppActionCard(
                    title: 'Add Expense',
                    description: 'Record an expense',
                    icon: Icons.receipt_outlined,
                    isPrimary: true,
                    onTap: () {
                      Navigator.pop(context);
                      TransactionBottomSheet.show(context, mode: TransactionMode.expense);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AppActionCard(
                    title: 'Add Income',
                    description: 'Record income',
                    icon: Icons.trending_up,
                    isPrimary: true,
                    onTap: () {
                      Navigator.pop(context);
                      TransactionBottomSheet.show(context, mode: TransactionMode.income);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const AppSectionHeader(label: 'Tools'),
                  _AppActionCard(
                    title: 'Reminder',
                    description: 'Set reminders',
                    icon: Icons.notifications_active_outlined,
                    isPrimary: false,
                    onTap: () {
                      Navigator.pop(context);
                      ReminderBottomSheet.show(context);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AppActionCard(
                    title: 'Budget Goal',
                    description: 'Configure limits',
                    icon: Icons.track_changes,
                    isPrimary: false,
                    onTap: () {
                      Navigator.pop(context);
                      BudgetSetupSheet.show(context);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AppActionCard(
                    title: 'Export',
                    description: 'Export reports',
                    icon: Icons.download_outlined,
                    isPrimary: false,
                    onTap: () {
                      Navigator.pop(context);
                      ExportBottomSheet.show(context);
                    },
                  ),
                  // Safe area space padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _AppActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final leadingBg = isPrimary ? colorScheme.primaryContainer : colorScheme.secondaryContainer;
    final leadingFg = isPrimary ? colorScheme.onPrimaryContainer : colorScheme.onSecondaryContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: leadingBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 24,
                color: leadingFg,
              ),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
