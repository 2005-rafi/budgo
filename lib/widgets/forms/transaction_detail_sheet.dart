import 'package:expense/models/future_expense.dart';
import 'package:expense/core/atomic_writer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/core/currency_formatter.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/widgets/snackbar_feedback.dart';
import 'package:expense/core/money.dart';
import 'package:expense/widgets/forms/transaction_bottom_sheet.dart';
import 'package:expense/widgets/forms/wishlist_item_sheet.dart';
import 'package:expense/core/app_constants.dart';

class TransactionDetailSheet extends StatefulWidget {
  final TransactionEntry entry;

  const TransactionDetailSheet({super.key, required this.entry});

  static void show(BuildContext context, TransactionEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailSheet(entry: entry),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  final _purchaseAmountController = TextEditingController();
  bool _showPurchaseInput = false;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    final val = widget.entry.amount / 100.0;
    _purchaseAmountController.text = val % 1 == 0
        ? val.toInt().toString()
        : val.toString();
  }

  @override
  void dispose() {
    _purchaseAmountController.dispose();
    super.dispose();
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'travel':
        return Icons.directions_car_outlined;
      case 'bills':
        return Icons.receipt_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'income':
        return Icons.arrow_downward_outlined;
      default:
        return Icons.attach_money_outlined;
    }
  }

  void _edit() {
    Navigator.pop(context); // close detail sheet
    final entry = widget.entry;
    if (entry is ExpenseEntry) {
      TransactionBottomSheet.show(
        context,
        mode: TransactionMode.expense,
        existingExpense: entry.rawExpense,
      );
    } else if (entry is IncomeEntry) {
      TransactionBottomSheet.show(
        context,
        mode: TransactionMode.income,
        existingIncome: entry.rawIncome,
      );
    } else if (entry is PlannedEntry) {
      WishlistItemSheet.show(context, existingItem: entry.rawFuture);
    }
  }

  void _delete() async {
    final colorScheme = Theme.of(context).colorScheme;
    final entry = widget.entry;

    // Check for linked future expense
    FutureExpense? linkedFuture;
    if (entry is ExpenseEntry && entry.rawExpense.key != null) {
      linkedFuture = context
          .read<FutureExpensesProvider>()
          .getLinkedFutureExpense(entry.rawExpense.key as int);
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to permanently delete this record?',
            ),
            if (linkedFuture != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: colorScheme.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'This expense is linked to a planned item. Deleting it will also reset the planned item to "unpurchased".',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isActionInProgress = true);
      try {
        if (entry is ExpenseEntry) {
          final provider = context.read<ExpensesProvider>();
          final futureProvider = context.read<FutureExpensesProvider>();

          await AtomicWriter.instance.execute(() async {
            if (linkedFuture != null) {
              await futureProvider.unpurchase(linkedFuture);
            }
            await provider.deleteExpense(entry.rawExpense);
          });
        } else if (entry is IncomeEntry) {
          final provider = context.read<IncomeProvider>();
          await provider.deleteIncome(entry.rawIncome);
        } else if (entry is PlannedEntry) {
          final provider = context.read<FutureExpensesProvider>();
          await provider.deleteFutureExpense(entry.rawFuture);
        }
        if (mounted) {
          Navigator.pop(context);
          SnackbarFeedback.showSuccess(context, 'Transaction deleted');
        }
      } catch (e) {
        if (mounted) {
          SnackbarFeedback.showError(context, 'Deletion failed: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isActionInProgress = false);
        }
      }
    }
  }

  void _confirmIncome() async {
    final entry = widget.entry;
    if (entry is IncomeEntry) {
      setState(() => _isActionInProgress = true);
      try {
        final provider = context.read<IncomeProvider>();
        await provider.confirmSingle(entry.rawIncome);
        if (mounted) {
          Navigator.pop(context);
          SnackbarFeedback.showSuccess(context, 'Income confirmed');
        }
      } catch (e) {
        if (mounted) {
          SnackbarFeedback.showError(context, 'Failed to confirm income: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isActionInProgress = false);
        }
      }
    }
  }

  void _purchasePlanned() async {
    final entry = widget.entry;
    if (entry is PlannedEntry) {
      final amountText = _purchaseAmountController.text.trim();
      final amountRupees = double.tryParse(amountText);
      if (amountRupees == null || amountRupees <= 0) {
        SnackbarFeedback.showError(context, 'Please enter a valid amount');
        return;
      }
      final amount = (amountRupees * 100).round();
      if (amount > AppConstants.kMaxAmount) {
        SnackbarFeedback.showError(context, 'Amount cannot exceed ${MoneyFormatter.symbol}10,00,000');
        return;
      }
      final parts = amountText.split('.');
      if (parts.length > 1 && parts[1].length > 2) {
        SnackbarFeedback.showError(context, 'Up to 2 decimal places allowed');
        return;
      }
      setState(() => _isActionInProgress = true);
      try {
        final provider = context.read<FutureExpensesProvider>();
        await provider.purchase(entry.rawFuture, amount: amount);
        if (mounted) {
          Navigator.pop(context);
          SnackbarFeedback.showSuccess(context, 'Item marked as purchased');
        }
      } catch (e) {
        if (mounted) SnackbarFeedback.showError(context, 'Purchase failed: $e');
      } finally {
        if (mounted) setState(() => _isActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = widget.entry is IncomeEntry;
    final isPlanned = widget.entry is PlannedEntry;

    Color iconCircleBg;
    Color iconColor;

    if (isIncome) {
      iconCircleBg = BudgoColors.incomeIconCircle(context);
      iconColor = BudgoColors.incomeIconColor(context);
    } else if (isPlanned) {
      iconCircleBg = colorScheme.surfaceContainerHigh;
      iconColor = colorScheme.primary;
    } else {
      iconCircleBg = BudgoColors.categoryIconCircle(context);
      iconColor = BudgoColors.categoryIconColor(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: BudgoColors.bottomSheetSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Large Category Icon Circle
          Center(
            child: Container(
              width: 56.0,
              height: 56.0,
              decoration: BoxDecoration(
                color: iconCircleBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward
                    : _categoryIcon(widget.entry.category),
                size: 28.0,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            widget.entry.displayName,
            style: AppTextStyles.headline(
              context,
            ).copyWith(fontWeight: FontWeight.bold, fontSize: 22.0),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),

          // Amount
          Text(
            isIncome
                ? '+${CurrencyFormatter.format(widget.entry.amount)}'
                : isPlanned
                ? 'Est. ${CurrencyFormatter.format(widget.entry.amount)}'
                : '-${CurrencyFormatter.format(widget.entry.amount)}',
            style: isIncome
                ? AppTextStyles.amountDisplay(
                    context,
                  ).copyWith(color: BudgoColors.incomeColor(context))
                : AppTextStyles.amountDisplay(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),

          // Details Block
          Card(
            color: colorScheme.surfaceContainerLow,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Date',
                    DateFormat('MMMM d, yyyy').format(widget.entry.date),
                  ),
                  const Divider(height: AppSpacing.lg),
                  _buildDetailRow('Category', widget.entry.category),
                  if (widget.entry.notes != null &&
                      widget.entry.notes!.isNotEmpty) ...[
                    const Divider(height: AppSpacing.lg),
                    _buildDetailRow('Notes', widget.entry.notes!),
                  ],
                  if (isIncome) ...[
                    const Divider(height: AppSpacing.lg),
                    _buildDetailRow(
                      'Status',
                      (widget.entry as IncomeEntry).isConfirmed
                          ? 'Confirmed'
                          : 'Pending Confirmation',
                    ),
                  ],
                  if (isPlanned) ...[
                    const Divider(height: AppSpacing.lg),
                    _buildDetailRow(
                      'Priority',
                      (widget.entry as PlannedEntry).priority.toUpperCase(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Action Buttons
          if (_showPurchaseInput && isPlanned) ...[
            TextFormField(
              controller: _purchaseAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Actual Paid Amount (${MoneyFormatter.symbol})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showPurchaseInput = false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _isActionInProgress ? null : _purchasePlanned,
                    child: _isActionInProgress
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm Purchase'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isActionInProgress ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),
            if (isIncome && !(widget.entry as IncomeEntry).isConfirmed) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _isActionInProgress ? null : _confirmIncome,
                icon: const Icon(Icons.check),
                label: const Text('Confirm Income'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                ),
              ),
            ],
            if (isPlanned) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => setState(() => _showPurchaseInput = true),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Mark as Purchased'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySecondary(context)),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body(
              context,
            ).copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
