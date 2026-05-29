import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/widgets/smart_notification_tile.dart';
import 'package:expense/widgets/forms/reminder_bottom_sheet.dart';
import 'package:expense/widgets/empty_state_placeholder.dart';
import 'package:expense/widgets/snackbar_feedback.dart';

class RemindersManagementSheet extends StatelessWidget {
  const RemindersManagementSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RemindersManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReminderProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Bill Reminders',
            style: AppTextStyles.headline(context).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.items.isEmpty
                    ? const Center(
                        child: EmptyStatePlaceholder(
                          icon: Icons.notifications_none,
                          title: 'No reminders set',
                          message: 'Add reminders to get notified before bills are due.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.items.length,
                        itemBuilder: (context, index) {
                          final reminder = provider.items[index];
                           return Dismissible(
                            key: Key(reminder.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              color: colorScheme.error,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (direction) async {
                              final success = await provider.deleteReminder(reminder);
                              if (!success && context.mounted) {
                                SnackbarFeedback.showError(
                                  context,
                                  provider.errorMessage ?? 'Failed to delete reminder',
                                );
                              } else if (success && context.mounted) {
                                SnackbarFeedback.showSuccess(context, 'Reminder deleted');
                              }
                            },
                            child: SmartNotificationTile.reminder(
                              reminder: reminder,
                              onToggle: (_) async {
                                final success = await provider.toggleActive(reminder);
                                if (!success && context.mounted) {
                                  SnackbarFeedback.showError(
                                    context,
                                    provider.errorMessage ?? 'Failed to toggle reminder status',
                                  );
                                }
                              },
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Manage Reminder'),
                                    content: Text('What would you like to do with "${reminder.title}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          ReminderBottomSheet.show(context, existingReminder: reminder);
                                        },
                                        child: const Text('Edit'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          final success = await provider.deleteReminder(reminder);
                                          if (success) {
                                            if (context.mounted) {
                                              SnackbarFeedback.showSuccess(context, 'Reminder deleted');
                                            }
                                          } else {
                                            if (context.mounted) {
                                              SnackbarFeedback.showError(
                                                context,
                                                provider.errorMessage ?? 'Failed to delete reminder',
                                              );
                                            }
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: colorScheme.error,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
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
            child: FilledButton.icon(
              onPressed: () => ReminderBottomSheet.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Reminder'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
