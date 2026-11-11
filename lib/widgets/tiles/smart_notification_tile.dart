import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/workspace.dart';

enum SmartNotificationType { reminder, budgetAlert }

class SmartNotificationTile extends StatelessWidget {
  final SmartNotificationType type;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool? isSwitchActive;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback? onDismiss;
  final VoidCallback? onMarkPaid;
  final Reminder? reminder;
  final Workspace? workspace;

  const SmartNotificationTile._({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isSwitchActive,
    this.onSwitchChanged,
    this.onDismiss,
    this.onMarkPaid,
    this.reminder,
    this.workspace,
  });

  factory SmartNotificationTile.reminder({
    required Reminder reminder,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTap,
    VoidCallback? onMarkPaid,
    Workspace? workspace,
  }) {
    final timeStr = DateFormat('MMM d, h:mm a').format(reminder.scheduledAt);
    final recurrenceLabel = reminder.isRecurring ? ' (${reminder.recurrenceType})' : '';
    final statusSuffix = switch (reminder.paymentStatus) {
      'completed' when !reminder.isActive => ' • Done',
      'skipped' when !reminder.isActive => ' • Skipped',
      'cancelled' when !reminder.isActive => ' • Cancelled',
      'overdue' when reminder.isActive => ' • Overdue',
      _ => '',
    };
    return SmartNotificationTile._(
      type: SmartNotificationType.reminder,
      title: reminder.title,
      subtitle: '$timeStr$recurrenceLabel$statusSuffix${reminder.notes != null && reminder.notes!.isNotEmpty ? '\n${reminder.notes}' : ''}',
      onTap: onTap,
      isSwitchActive: reminder.isActive,
      onSwitchChanged: onToggle,
      onMarkPaid: onMarkPaid,
      reminder: reminder,
      workspace: workspace,
    );
  }

  factory SmartNotificationTile.budgetAlert({
    required String title,
    required String message,
    required VoidCallback onTap,
    required VoidCallback onDismiss,
  }) {
    return SmartNotificationTile._(
      type: SmartNotificationType.budgetAlert,
      title: title,
      subtitle: message,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Row(
          children: [
            // Left Action / Icon button (Independent 44x44 touch target)
            if (type == SmartNotificationType.reminder && reminder != null) ...[
              Tooltip(
                message: !reminder!.isActive
                    ? 'Reactivate reminder'
                    : reminder!.paymentStatus == 'completed'
                        ? 'Reopen reminder'
                        : 'Mark as paid',
                child: BudgoPressable(
                  onTap: onMarkPaid,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !reminder!.isActive
                            ? colorScheme.surfaceContainer
                            : reminder!.paymentStatus == 'completed'
                                ? colorScheme.primary
                                : reminder!.paymentStatus == 'overdue'
                                    ? colorScheme.errorContainer.withValues(alpha: 0.15)
                                    : Colors.transparent,
                        border: Border.all(
                          color: !reminder!.isActive
                              ? colorScheme.outline.withValues(alpha: 0.45)
                              : reminder!.paymentStatus == 'completed'
                                  ? colorScheme.primary
                                  : reminder!.paymentStatus == 'overdue'
                                      ? colorScheme.error
                                      : colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        !reminder!.isActive
                            ? (reminder!.paymentStatus == 'completed'
                                ? Icons.check
                                : reminder!.paymentStatus == 'skipped'
                                    ? Icons.skip_next
                                    : reminder!.paymentStatus == 'cancelled'
                                        ? Icons.close
                                        : Icons.notifications_off_outlined)
                            : reminder!.paymentStatus == 'completed'
                                ? Icons.check
                                : reminder!.paymentStatus == 'overdue'
                                    ? Icons.priority_high
                                    : null,
                        color: !reminder!.isActive
                            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                            : reminder!.paymentStatus == 'completed'
                                ? colorScheme.onPrimary
                                : reminder!.paymentStatus == 'overdue'
                                    ? colorScheme.error
                                    : Colors.transparent,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: BudgoColors.warningColor(context).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_outlined,
                    color: BudgoColors.warningColor(context),
                    size: 18,
                  ),
                ),
              ),
            ],

            // Text details (Wrapped in InkWell for editing / management)
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTextStyles.bodyMedium(context).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (workspace != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Color(workspace!.colorValue)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    WorkspaceIcons.forType(workspace!.type),
                                    size: 11,
                                    color: Color(workspace!.colorValue),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    workspace!.name,
                                    style: AppTextStyles.labelSmall(context)
                                        .copyWith(
                                      color: Color(workspace!.colorValue),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),

            // Action elements (Switch / Dismiss)
            if (type == SmartNotificationType.reminder &&
                isSwitchActive != null &&
                onSwitchChanged != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: BudgoSwitch(
                  value: isSwitchActive!,
                  onChanged: onSwitchChanged,
                ),
              )
            else if (type == SmartNotificationType.budgetAlert && onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onDismiss,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

