import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/models/reminder.dart';

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
  });

  factory SmartNotificationTile.reminder({
    required Reminder reminder,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTap,
    VoidCallback? onMarkPaid,
  }) {
    final timeStr = DateFormat('MMM d, h:mm a').format(reminder.scheduledAt);
    final recurrenceLabel = reminder.isRecurring ? ' (${reminder.recurrenceType})' : '';
    return SmartNotificationTile._(
      type: SmartNotificationType.reminder,
      title: reminder.title,
      subtitle: '$timeStr$recurrenceLabel${reminder.notes != null && reminder.notes!.isNotEmpty ? '\n${reminder.notes}' : ''}',
      onTap: onTap,
      isSwitchActive: reminder.isActive,
      onSwitchChanged: onToggle,
      onMarkPaid: onMarkPaid,
      reminder: reminder,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Left Icon container
              if (type == SmartNotificationType.reminder && reminder != null) ...[
                GestureDetector(
                  onTap: reminder!.isActive ? onMarkPaid : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: !reminder!.isActive
                          ? colorScheme.surfaceContainer
                          : reminder!.paymentStatus == 'completed'
                              ? colorScheme.primaryContainer
                              : reminder!.paymentStatus == 'overdue'
                                  ? colorScheme.errorContainer.withValues(alpha: 0.15)
                                  : colorScheme.primaryContainer.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      !reminder!.isActive
                          ? Icons.notifications_off_outlined
                          : reminder!.paymentStatus == 'completed'
                              ? Icons.check_circle
                              : reminder!.paymentStatus == 'overdue'
                                  ? Icons.error_outline
                                  : Icons.circle_outlined,
                      color: !reminder!.isActive
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                          : reminder!.paymentStatus == 'completed'
                              ? colorScheme.primary
                              : reminder!.paymentStatus == 'overdue'
                                  ? colorScheme.error
                                  : colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: BudgoColors.warningColor(context).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_outlined,
                    color: BudgoColors.warningColor(context),
                    size: 20,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.md),

              // Text details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
              const SizedBox(width: AppSpacing.sm),

              // Action elements
              if (type == SmartNotificationType.reminder &&
                  isSwitchActive != null &&
                  onSwitchChanged != null)
                Switch(
                  value: isSwitchActive!,
                  onChanged: onSwitchChanged,
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
      ),
    );
  }
}

