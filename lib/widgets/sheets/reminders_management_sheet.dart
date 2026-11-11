import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/widgets/tiles/smart_notification_tile.dart';
import 'package:expense/widgets/sheets/reminder_bottom_sheet.dart';

class RemindersManagementSheet extends StatefulWidget {
  const RemindersManagementSheet({super.key});

  static void show(BuildContext context) {
    BudgoBottomSheet.show(
      context,
      builder: (context) => const RemindersManagementSheet(),
    );
  }

  @override
  State<RemindersManagementSheet> createState() =>
      _RemindersManagementSheetState();
}

class _RemindersManagementSheetState extends State<RemindersManagementSheet> {
  bool _showAllWorkspaces = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReminderProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    WorkspaceProvider? wsProvider;
    try {
      wsProvider = context.watch<WorkspaceProvider>();
    } on ProviderNotFoundException {
      wsProvider = null;
    }

    final workspaces = wsProvider?.workspaces ?? const <Workspace>[];
    final activeWorkspace = wsProvider?.activeWorkspace;
    final hasMultipleWorkspaces = workspaces.length > 1;
    final displayedReminders =
        (_showAllWorkspaces && hasMultipleWorkspaces)
            ? provider.allItems
            : provider.items;

    final String subtitleText;
    if (!hasMultipleWorkspaces || activeWorkspace == null) {
      subtitleText = 'Isolated per active workspace';
    } else if (_showAllWorkspaces) {
      subtitleText = 'Showing all ${workspaces.length} workspaces';
    } else {
      subtitleText = 'Workspace: ${activeWorkspace.name}';
    }

    return BudgoBottomSheet(
      title: 'Bill Reminders',
      subtitle: subtitleText,
      contentPadding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.base + bottomInset,
        left: AppSpacing.base,
        right: AppSpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasMultipleWorkspaces) ...[
            BudgoSegmentedControl<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(activeWorkspace?.name ?? 'This Workspace'),
                ),
                const ButtonSegment<bool>(
                  value: true,
                  label: Text('All Workspaces'),
                ),
              ],
              selected: _showAllWorkspaces,
              onSelected: (val) => setState(() => _showAllWorkspaces = val),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedReminders.isEmpty
                    ? Center(
                        child: EmptyStatePlaceholder(
                          icon: Icons.notifications_none,
                          title: 'No reminders set',
                          message: activeWorkspace != null && !_showAllWorkspaces
                              ? 'Add reminders for ${activeWorkspace.name} to get notified before bills are due.'
                              : 'Add reminders to get notified before bills are due.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: displayedReminders.length,
                        itemBuilder: (context, index) {
                          final reminder = displayedReminders[index];
                          final reminderWorkspace = workspaces.firstWhereOrNull(
                            (w) => w.id == reminder.workspaceId,
                          );
                           return Dismissible(
                            key: Key(reminder.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              color: colorScheme.error,
                              child: Icon(
                                Icons.delete,
                                color: colorScheme.onError,
                              ),
                            ),
                            onDismissed: (direction) async {
                              final success = await provider.deleteReminder(reminder);
                              if (!success && context.mounted) {
                                SnackbarFeedback.showError(
                                  context,
                                  provider.lastError ?? provider.errorMessage ?? 'Unable to delete reminder.',
                                  operation: FeedbackOperation.deleteReminder,
                                );
                              } else if (success && context.mounted) {
                                SnackbarFeedback.showSuccess(context, 'Reminder deleted');
                              }
                            },
                            child: SmartNotificationTile.reminder(
                              reminder: reminder,
                              workspace: reminderWorkspace,
                              onToggle: (_) async {
                                final success = await provider.toggleActive(reminder);
                                if (!success && context.mounted) {
                                  SnackbarFeedback.showError(
                                    context,
                                    provider.lastError ?? provider.errorMessage ?? 'Unable to toggle reminder.',
                                    operation: FeedbackOperation.toggleReminder,
                                  );
                                }
                              },
                              onMarkPaid: () async {
                                if (!reminder.isActive) {
                                  final success =
                                      await provider.toggleActive(reminder);
                                  if (success && context.mounted) {
                                    SnackbarFeedback.showSuccess(
                                      context,
                                      '${reminder.title} reactivated',
                                    );
                                  }
                                  return;
                                }
                                if (reminder.paymentStatus == 'completed') {
                                  final success = await provider
                                      .togglePaymentStatus(reminder);
                                  if (success && context.mounted) {
                                    SnackbarFeedback.showInfo(
                                      context,
                                      '${reminder.title} reopened as pending',
                                    );
                                  }
                                  return;
                                }
                                final wasRecurring = reminder.isRecurring &&
                                    reminder.recurrenceType != 'none';
                                final success =
                                    await provider.markAsPaid(reminder);
                                if (success && context.mounted) {
                                  HapticFeedback.lightImpact();
                                  if (wasRecurring) {
                                    final nextFormatted = DateFormat(
                                      'MMM d, h:mm a',
                                    ).format(reminder.scheduledAt);
                                    SnackbarFeedback.showSuccess(
                                      context,
                                      '${reminder.title} marked as paid for today! Next: $nextFormatted',
                                    );
                                  } else {
                                    SnackbarFeedback.showSuccess(
                                      context,
                                      '${reminder.title} marked as paid',
                                    );
                                  }
                                } else if (!success && context.mounted) {
                                  SnackbarFeedback.showError(
                                    context,
                                    provider.lastError ??
                                        provider.errorMessage ??
                                        'Unable to mark reminder as paid.',
                                    operation: FeedbackOperation.toggleReminder,
                                  );
                                }
                              },
                              onTap: () {
                                BudgoActionDialog.show(
                                  context,
                                  title: 'Manage Reminder',
                                  message: 'What would you like to do with "${reminder.title}"?',
                                  actions: BudgoLayeredActionLayout(
                                    level1: [
                                      if (reminder.isActive &&
                                          reminder.paymentStatus != 'completed')
                                        BudgoActionCell(
                                          label: 'Mark as Paid',
                                          variant: BudgoButtonVariant.primary,
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            final wasRecurring =
                                                reminder.isRecurring &&
                                                    reminder.recurrenceType != 'none';
                                            final success = await provider.markAsPaid(reminder);
                                            if (success && context.mounted) {
                                              HapticFeedback.lightImpact();
                                              if (wasRecurring) {
                                                final nextFormatted = DateFormat(
                                                  'MMM d, h:mm a',
                                                ).format(reminder.scheduledAt);
                                                SnackbarFeedback.showSuccess(
                                                  context,
                                                  '${reminder.title} marked as paid for today! Next: $nextFormatted',
                                                );
                                              } else {
                                                SnackbarFeedback.showSuccess(
                                                  context,
                                                  '${reminder.title} marked as paid',
                                                );
                                              }
                                            }
                                          },
                                        )
                                      else if (reminder.paymentStatus == 'completed')
                                        BudgoActionCell(
                                          label: 'Reopen',
                                          variant: BudgoButtonVariant.tonal,
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            final success =
                                                await provider.togglePaymentStatus(reminder);
                                            if (success && context.mounted) {
                                              SnackbarFeedback.showInfo(
                                                context,
                                                '${reminder.title} reopened as pending',
                                              );
                                            }
                                          },
                                        ),
                                      if (reminder.isRecurring && reminder.isActive)
                                        BudgoActionCell(
                                          label: 'Skip Cycle',
                                          variant: BudgoButtonVariant.tonal,
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            final success =
                                                await provider.skipReminder(reminder);
                                            if (success && context.mounted) {
                                              final nextFormatted = DateFormat(
                                                'MMM d, h:mm a',
                                              ).format(reminder.scheduledAt);
                                              SnackbarFeedback.showInfo(
                                                context,
                                                'Skipped cycle. Next: $nextFormatted',
                                              );
                                            }
                                          },
                                        ),
                                    ],
                                    level2: [
                                      BudgoActionCell(
                                        label: 'Delete',
                                        variant: BudgoButtonVariant.destructive,
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final success =
                                              await provider.deleteReminder(reminder);
                                          if (success) {
                                            if (context.mounted) {
                                              SnackbarFeedback.showSuccess(
                                                context,
                                                'Reminder deleted',
                                              );
                                            }
                                          } else {
                                            if (context.mounted) {
                                              SnackbarFeedback.showError(
                                                context,
                                                provider.lastError ??
                                                    provider.errorMessage ??
                                                    'Unable to delete reminder.',
                                                operation:
                                                    FeedbackOperation.deleteReminder,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      BudgoActionCell(
                                        label: 'Edit',
                                        variant: BudgoButtonVariant.tonal,
                                        onPressed: () {
                                          Navigator.pop(context);
                                          ReminderBottomSheet.show(
                                            context,
                                            existingReminder: reminder,
                                          );
                                        },
                                      ),
                                    ],
                                    level3: BudgoActionCell(
                                      label: 'Cancel',
                                      variant: BudgoButtonVariant.text,
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: BudgoButton(
              label: 'Add Reminder',
              icon: Icons.add,
              onPressed: () => ReminderBottomSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }
}
