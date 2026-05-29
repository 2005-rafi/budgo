import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/currency_formatter.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/widgets/common/app_transaction_tile.dart';
import 'package:expense/widgets/common/app_section_header.dart';
import 'package:expense/widgets/common/app_card.dart';
import 'package:expense/widgets/common/reminder_action_badge.dart';
import 'package:expense/widgets/forms/transaction_detail_sheet.dart';
import 'package:expense/widgets/confirmation_dialog.dart';
import 'package:expense/widgets/snackbar_feedback.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  void _handleDelete(BuildContext context, Income income) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Income?',
      message: 'Are you sure you want to permanently delete this income entry?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirm) {
      if (!context.mounted) return;
      try {
        await context.read<IncomeProvider>().deleteIncome(income);
        if (context.mounted) {
          SnackbarFeedback.showSuccess(context, 'Income entry deleted.');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarFeedback.showError(context, 'Failed to delete income: $e');
        }
      }
    }
  }

  void _handleConfirm(BuildContext context, Income income) async {
    try {
      await context.read<IncomeProvider>().confirmSingle(income);
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
    final incomeProvider = context.watch<IncomeProvider>();
    final incomes = incomeProvider.items;

    // Calculate Summary Values
    int confirmedTotal = 0;
    int allTotal = 0;
    int pendingCount = 0;

    final List<Income> pendingIncomes = [];
    final List<Income> confirmedIncomes = [];

    for (final inc in incomes) {
      allTotal += inc.amount;
      if (inc.isConfirmed) {
        confirmedTotal += inc.amount;
        confirmedIncomes.add(inc);
      } else {
        pendingCount++;
        pendingIncomes.add(inc);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: const [
          ReminderActionBadge(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: incomes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_chart_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No income recorded',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Use the FAB on Home or Activity to add income',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // Summary KPI Bar
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  sliver: SliverToBoxAdapter(
                    child: AppCard(
                      elevated: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Confirmed',
                                CurrencyFormatter.format(confirmedTotal),
                                colorScheme.secondary,
                              ),
                            ),
                            Container(
                              width: 0.5,
                              height: 36,
                              color: colorScheme.outlineVariant,
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'All Entries',
                                CurrencyFormatter.format(allTotal),
                                colorScheme.onSurface,
                              ),
                            ),
                            Container(
                              width: 0.5,
                              height: 36,
                              color: colorScheme.outlineVariant,
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Pending',
                                '$pendingCount entries',
                                colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Pending Section
                if (pendingIncomes.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: AppSectionHeader(label: 'Pending Confirmation'),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final inc = pendingIncomes[index];
                          // Build an adapter entry for detail sheets
                          final entry = IncomeEntry(
                            id: inc.id,
                            date: inc.date,
                            amount: inc.amount,
                            displayName: inc.source,
                            category: 'Income',
                            isConfirmed: false,
                            rawIncome: inc,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppTransactionTile(
                              title: inc.source,
                              amount: inc.amount,
                              category: 'Income',
                              date: inc.date,
                              isIncome: true,
                              isPending: true,
                              isPlanned: false,
                              onTap: () => TransactionDetailSheet.show(context, entry),
                              onDelete: () => _handleDelete(context, inc),
                              onConfirm: () => _handleConfirm(context, inc),
                            ),
                          );
                        },
                        childCount: pendingIncomes.length,
                      ),
                    ),
                  ),
                ],

                // Confirmed Section
                if (confirmedIncomes.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: AppSectionHeader(label: 'Confirmed Income'),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final inc = confirmedIncomes[index];
                          final entry = IncomeEntry(
                            id: inc.id,
                            date: inc.date,
                            amount: inc.amount,
                            displayName: inc.source,
                            category: 'Income',
                            isConfirmed: true,
                            rawIncome: inc,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppTransactionTile(
                              title: inc.source,
                              amount: inc.amount,
                              category: 'Income',
                              date: inc.date,
                              isIncome: true,
                              isPending: false,
                              isPlanned: false,
                              onTap: () => TransactionDetailSheet.show(context, entry),
                              onDelete: () => _handleDelete(context, inc),
                            ),
                          );
                        },
                        childCount: confirmedIncomes.length,
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

  Widget _buildSummaryItem(BuildContext context, String label, String value, Color valueColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
