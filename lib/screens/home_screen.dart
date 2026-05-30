import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/provider/app_preferences_provider.dart';
import 'package:expense/provider/dashboard_provider.dart';
import 'package:expense/provider/app_navigation_provider.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/models/view_models/dashboard_view_model.dart';

import 'package:expense/widgets/common/app_budget_card.dart';
import 'package:expense/widgets/common/app_section_header.dart';
import 'package:expense/widgets/common/app_card.dart';
import 'package:expense/widgets/common/reminder_action_badge.dart';
import 'package:expense/widgets/forms/transaction_bottom_sheet.dart';
import 'package:expense/widgets/forms/budget_setup_sheet.dart';
import 'package:expense/widgets/home/recent_activity_list.dart';

import 'package:expense/widgets/confirmation_dialog.dart';
import 'package:expense/widgets/snackbar_feedback.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOrphanedPurchases();
    });
  }

  void _checkOrphanedPurchases() {
    if (!mounted) return;
    final wishlistProvider = context.read<FutureExpensesProvider>();
    if (wishlistProvider.orphanedItem != null) {
      final item = wishlistProvider.orphanedItem!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Incomplete Purchase Found'),
          content: Text(
            'Found an incomplete purchase for "${item.title}". Would you like to complete it or discard the expense?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<FutureExpensesProvider>().resolveOrphan(false);
              },
              child: const Text('Discard Expense'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<FutureExpensesProvider>().resolveOrphan(true);
              },
              child: const Text('Complete Purchase'),
            ),
          ],
        ),
      );
    }
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  void _handleDelete(BuildContext context, TransactionEntry entry) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Transaction?',
      message: 'Are you sure you want to permanently delete this record?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirm) {
      if (!context.mounted) return;
      try {
        if (entry is ExpenseEntry) {
          await context.read<ExpensesProvider>().deleteExpense(
            entry.rawExpense,
          );
        } else if (entry is IncomeEntry) {
          await context.read<IncomeProvider>().deleteIncome(entry.rawIncome);
        } else if (entry is PlannedEntry) {
          await context.read<FutureExpensesProvider>().deleteFutureExpense(
            entry.rawFuture,
          );
        }
        if (context.mounted) {
          SnackbarFeedback.showSuccess(
            context,
            'Transaction deleted successfully.',
          );
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarFeedback.showError(
            context,
            'Failed to delete transaction: $e',
          );
        }
      }
    }
  }

  void _handleConfirm(BuildContext context, IncomeEntry entry) async {
    try {
      await context.read<IncomeProvider>().confirmSingle(entry.rawIncome);
      if (context.mounted) {
        SnackbarFeedback.showSuccess(context, 'Income confirmed.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarFeedback.showError(context, 'Failed to confirm income: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBudgetEnabled = context.watch<AppPreferencesProvider>().isBudgetModeEnabled;

    return Scaffold(
      body: Selector<DashboardProvider, bool>(
        selector: (_, p) => p.viewModel.isLoading && p.viewModel.recentTransactions.isEmpty,
        builder: (context, isLoadingInitial, _) {
          if (isLoadingInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          return Selector<DashboardProvider, bool>(
            selector: (_, p) => p.viewModel.recentTransactions.isEmpty,
            builder: (context, isEmpty, _) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Zone 1 — Sticky App Bar
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: colorScheme.surface,
                    title: Text(
                      'Budgo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    actions: const [
                      ReminderActionBadge(),
                      SizedBox(width: AppSpacing.sm),
                    ],
                  ),

                  // Zone 2 — Header Greeting
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingText(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Your Finances',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Zone 3 — AppBudgetCard
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base,
                      AppSpacing.base,
                      AppSpacing.base,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Selector<DashboardProvider, DashboardViewModel>(
                        selector: (_, p) => p.viewModel,
                        builder: (context, vm, _) {
                          return AppBudgetCard(
                            budgetLimit: vm.budgetLimit,
                            spent: vm.spentThisMonth,
                            income: vm.incomeThisMonth,
                            isBudgetEnabled: isBudgetEnabled,
                            balance: vm.cashflowBalance,
                            onSetBudget: () {
                              if (isBudgetEnabled) {
                                BudgetSetupSheet.show(context);
                              } else {
                                context.read<AppNavigationProvider>().setIndex(2); // Go to Reports tab
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Zone 3.5 — Overdue Reminders Banner
                  SliverToBoxAdapter(
                    child: Consumer<ReminderProvider>(
                      builder: (context, reminderProvider, child) {
                        final overdue = reminderProvider.items
                            .where((r) => r.isActive && r.paymentStatus == 'overdue')
                            .toList();
                        if (overdue.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.base,
                            AppSpacing.md,
                            AppSpacing.base,
                            0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Overdue Bills (${overdue.length})',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onErrorContainer,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ...overdue.map((reminder) {
                                  final amountText = reminder.amount != null
                                      ? ' • ₹ ${(reminder.amount! / 100.0).toStringAsFixed(2)}'
                                      : '';
                                  return Card(
                                    elevation: 0,
                                    color: Theme.of(context).colorScheme.surface,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  reminder.title,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Due ${DateFormat('MMM d, y h:mm a').format(reminder.scheduledAt)}$amountText',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          IconButton.filledTonal(
                                            onPressed: () async {
                                              final success = await reminderProvider.markAsPaid(reminder);
                                              if (success && context.mounted) {
                                                SnackbarFeedback.showSuccess(context, 'Marked as paid');
                                              }
                                            },
                                            icon: const Icon(Icons.check, size: 18),
                                            tooltip: 'Mark Paid',
                                            style: IconButton.styleFrom(
                                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                          IconButton.filledTonal(
                                            onPressed: () async {
                                              final success = await reminderProvider.remindLater(reminder);
                                              if (success && context.mounted) {
                                                SnackbarFeedback.showSuccess(context, 'Postponed by 6 hours');
                                              }
                                            },
                                            icon: const Icon(Icons.snooze, size: 18),
                                            tooltip: 'Remind Later',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),


                  // Zone 4 — Onboarding or Recent Activity
                  if (isEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppCard(
                              onTap: () {
                                if (isBudgetEnabled) {
                                  BudgetSetupSheet.show(context);
                                } else {
                                  context.read<AppNavigationProvider>().setIndex(2); // Reports tab
                                }
                              },
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Icon(
                                      isBudgetEnabled ? Icons.track_changes : Icons.analytics,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.base),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isBudgetEnabled ? 'Set a Budget' : 'View Reports',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          isBudgetEnabled
                                              ? 'Plan your spending limits'
                                              : 'Check your spending insights',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppCard(
                              onTap: () {
                                Navigator.pushNamed(context, '/income');
                              },
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Icon(Icons.add_chart, color: colorScheme.primary),
                                  ),
                                  const SizedBox(width: AppSpacing.base),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Add Income',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Record your earnings',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppCard(
                              onTap: () {
                                TransactionBottomSheet.show(
                                  context,
                                  mode: TransactionMode.expense,
                                );
                              },
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Icon(Icons.shopping_bag_outlined, color: colorScheme.primary),
                                  ),
                                  const SizedBox(width: AppSpacing.base),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Track Expense',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Log a recent purchase',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    SliverToBoxAdapter(
                      child: AppSectionHeader(
                        label: 'Recent Activity',
                        trailingLabel: 'See All',
                        onTrailingTap: () {
                          context.read<AppNavigationProvider>().setIndex(1); // Activity tab
                        },
                      ),
                    ),
                    Selector<DashboardProvider, List<TransactionEntry>>(
                      selector: (_, p) => p.viewModel.recentTransactions,
                      builder: (context, transactions, _) {
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                          sliver: SliverToBoxAdapter(
                            child: RecentActivityList(
                              transactions: transactions,
                              onDelete: (entry) => _handleDelete(context, entry),
                              onConfirm: (entry) => _handleConfirm(context, entry),
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // Safe bottom padding clearance
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xl),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
