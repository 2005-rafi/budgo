import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/widgets/common/app_transaction_tile.dart';
import 'package:expense/widgets/common/app_section_header.dart';
import 'package:expense/widgets/common/reminder_action_badge.dart';
import 'package:expense/widgets/forms/transaction_detail_sheet.dart';
import 'package:expense/widgets/confirmation_dialog.dart';
import 'package:expense/widgets/snackbar_feedback.dart';

class FutureExpensesScreen extends StatefulWidget {
  const FutureExpensesScreen({super.key});

  @override
  State<FutureExpensesScreen> createState() => _FutureExpensesScreenState();
}

class _FutureExpensesScreenState extends State<FutureExpensesScreen> {
  void _handleDelete(BuildContext context, FutureExpense item) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Planned Expense?',
      message: 'Are you sure you want to permanently delete this item? If purchased, this will also delete the recorded expense.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirm) {
      if (!context.mounted) return;
      try {
        await context.read<FutureExpensesProvider>().deleteFutureExpense(item);
        if (context.mounted) {
          SnackbarFeedback.showSuccess(context, 'Planned expense deleted.');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarFeedback.showError(context, 'Failed to delete planned expense: $e');
        }
      }
    }
  }

  Color? _getPriorityColor(int priority, ColorScheme colors) {
    if (priority == 2) return colors.error; // High
    if (priority == 1) return colors.primary; // Medium
    return null; // Low
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<FutureExpensesProvider>();
    final items = provider.items;

    final planned = items.where((e) => !e.isPurchased).toList();
    final purchased = items.where((e) => e.isPurchased).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Future Expenses'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: const [
          ReminderActionBadge(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No planned expenses',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Use the FAB on Home or Activity to plan expenses',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // Planned Section
                if (planned.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: AppSectionHeader(label: 'Planned'),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = planned[index];
                          final entry = PlannedEntry(
                            id: item.id,
                            date: item.dueDate ?? DateTime.now(),
                            amount: item.estimatedCost ?? 0,
                            displayName: item.title,
                            category: item.category,
                            priority: item.priority == 0
                                ? 'low'
                                : item.priority == 2
                                ? 'high'
                                : 'medium',
                            dueDate: item.dueDate,
                            rawFuture: item,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppTransactionTile(
                              title: item.title,
                              amount: item.estimatedCost ?? 0,
                              category: item.category,
                              date: item.dueDate ?? DateTime.now(),
                              isIncome: false,
                              isPending: false,
                              isPlanned: true,
                              priorityColor: _getPriorityColor(item.priority, colorScheme),
                              onTap: () => TransactionDetailSheet.show(context, entry),
                              onDelete: () => _handleDelete(context, item),
                            ),
                          );
                        },
                        childCount: planned.length,
                      ),
                    ),
                  ),
                ],

                // Purchased Section
                if (purchased.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: AppSectionHeader(label: 'Purchased'),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = purchased[index];
                          // Create double-wrapped adapters
                          final entry = PlannedEntry(
                            id: item.id,
                            date: item.dueDate ?? DateTime.now(),
                            amount: item.purchasedAmount ?? item.estimatedCost ?? 0,
                            displayName: item.title,
                            category: item.category,
                            priority: item.priority == 0
                                ? 'low'
                                : item.priority == 2
                                ? 'high'
                                : 'medium',
                            dueDate: item.dueDate,
                            rawFuture: item,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Opacity(
                              opacity: 0.6,
                              child: AppTransactionTile(
                                title: item.title,
                                amount: item.purchasedAmount ?? item.estimatedCost ?? 0,
                                category: item.category,
                                date: item.purchasedAt ?? item.dueDate ?? DateTime.now(),
                                isIncome: false,
                                isPending: false,
                                isPlanned: false, // Don't show planned badge since purchased
                                trailing: Icon(
                                  Icons.check_circle_outline,
                                  color: colorScheme.secondary,
                                  size: 20,
                                ),
                                onTap: () => TransactionDetailSheet.show(context, entry),
                                onDelete: () => _handleDelete(context, item),
                              ),
                            ),
                          );
                        },
                        childCount: purchased.length,
                      ),
                    ),
                  ),
                ],

                const SliverPadding(
                  padding: EdgeInsets.only(bottom: AppSpacing.bottomNavClear + AppSpacing.lg),
                ),
              ],
            ),
    );
  }
}
