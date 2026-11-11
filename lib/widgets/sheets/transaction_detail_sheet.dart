import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/registries/category_registry.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/future_expenses_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/widgets/sheets/transaction_bottom_sheet.dart';
import 'package:expense/widgets/sheets/wishlist_item_sheet.dart';

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

  void _edit() {
    final entry = widget.entry;
    if (entry is TransferEntry) {
      SnackbarFeedback.showInfo(
        context,
        'Transfers are permanent ledger entries. Use "Reverse" to roll back.',
      );
      return;
    }
    Navigator.pop(context); // close detail sheet
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

    final isTransfer = entry is TransferEntry;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTransfer ? 'Reverse Transfer?' : 'Delete Transaction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTransfer
                  ? 'Are you sure you want to reverse this transfer? Funds will be deducted from the receiving account and credited back to the source.'
                  : 'Are you sure you want to permanently delete this record?',
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
          BudgoButton(
            label: 'Cancel',
            variant: BudgoButtonVariant.text,
            expanded: false,
            height: 42,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BudgoButton(
            label: isTransfer ? 'Reverse' : 'Delete',
            variant: BudgoButtonVariant.destructive,
            expanded: false,
            height: 42,
            onPressed: () => Navigator.pop(ctx, true),
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
        } else if (entry is TransferEntry) {
          final provider = context.read<TransferProvider>();
          await provider.reverseTransfer(
            entry.id,
            reason: 'Reversed by user from detail sheet',
          );
        }
        if (mounted) {
          Navigator.pop(context);
          SnackbarFeedback.showSuccess(
            context,
            isTransfer ? 'Transfer reversed successfully' : 'Transaction deleted',
          );
        }
      } catch (e) {
        if (mounted) {
          SnackbarFeedback.showError(
            context,
            e,
            operation: isTransfer
                ? FeedbackOperation.selfTransfer
                : FeedbackOperation.deleteTransaction,
          );
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
          SnackbarFeedback.showError(
            context,
            e,
            operation: FeedbackOperation.confirmIncome,
          );
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
      final validation = InputValidators.validateAmount(
        _purchaseAmountController.text,
        fieldLabel: 'Paid amount',
      );
      if (!validation.isValid) {
        SnackbarFeedback.showError(context, validation.errorMessage!);
        return;
      }
      final amount = validation.paise!;
      setState(() => _isActionInProgress = true);
      try {
        final provider = context.read<FutureExpensesProvider>();
        await provider.purchase(entry.rawFuture, amount: amount);
        if (mounted) {
          Navigator.pop(context);
          SnackbarFeedback.showSuccess(context, 'Item marked as purchased');
        }
      } catch (e) {
        if (mounted) {
          SnackbarFeedback.showError(
            context,
            e,
            operation: FeedbackOperation.purchaseWishlist,
          );
        }
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
    final isTransfer = widget.entry is TransferEntry;
    final transfer = isTransfer ? widget.entry as TransferEntry : null;

    Color iconCircleBg;
    Color iconColor;

    if (isTransfer) {
      iconCircleBg = colorScheme.surfaceContainerHigh;
      iconColor = transfer!.isIntraWorkspace
          ? colorScheme.primary
          : (transfer.isIncoming ? colorScheme.secondary : colorScheme.onSurfaceVariant);
    } else if (isIncome) {
      iconCircleBg = BudgoColors.incomeIconCircle(context);
      iconColor = BudgoColors.incomeIconColor(context);
    } else if (isPlanned) {
      iconCircleBg = colorScheme.surfaceContainerHigh;
      iconColor = colorScheme.primary;
    } else {
      iconCircleBg = BudgoColors.categoryIconCircle(context);
      iconColor = BudgoColors.categoryIconColor(context);
    }

    return BudgoBottomSheet(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                isTransfer
                    ? (transfer!.isIntraWorkspace
                        ? Icons.swap_horiz_rounded
                        : (transfer.isIncoming ? Icons.arrow_downward : Icons.arrow_outward))
                    : isIncome
                        ? Icons.arrow_downward
                        : widget.entry.category.categoryIcon,
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
            isPlanned
                ? 'Est. ${CurrencyFormatter.format(widget.entry.amount)}'
                : CurrencyFormatter.format(widget.entry.amount),
            style: (isIncome || (isTransfer && transfer!.isIncoming))
                ? AppTextStyles.amountDisplay(
                    context,
                  ).copyWith(color: BudgoColors.incomeColor(context))
                : (isTransfer && transfer!.isIntraWorkspace)
                    ? AppTextStyles.amountDisplay(context).copyWith(color: colorScheme.onSurfaceVariant)
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
                  if (isTransfer) ...[
                    const Divider(height: AppSpacing.lg),
                    _buildDetailRow('Source Account', transfer!.sourceAccountName),
                    const Divider(height: AppSpacing.lg),
                    _buildDetailRow('Destination Account', transfer.destinationAccountName),
                    const Divider(height: AppSpacing.lg),
                    _buildDetailRow(
                      'Status',
                      transfer.rawTransfer.status.name.toUpperCase(),
                    ),
                  ],
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
            BudgoAmountField(
              controller: _purchaseAmountController,
              label: 'Actual Paid Amount',
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: BudgoButton(
                    label: 'Cancel',
                    variant: BudgoButtonVariant.outlined,
                    onPressed: () => setState(() => _showPurchaseInput = false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: BudgoButton(
                    label: 'Confirm Purchase',
                    isLoading: _isActionInProgress,
                    onPressed: _purchasePlanned,
                  ),
                ),
              ],
            ),
          ] else if (isTransfer) ...[
            BudgoButton(
              label: 'Reverse Transfer',
              icon: Icons.undo_rounded,
              variant: BudgoButtonVariant.destructive,
              isLoading: _isActionInProgress,
              onPressed: _delete,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: BudgoButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    variant: BudgoButtonVariant.outlined,
                    onPressed: _edit,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: BudgoButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    variant: BudgoButtonVariant.destructive,
                    isLoading: _isActionInProgress,
                    onPressed: _delete,
                  ),
                ),
              ],
            ),
            if (isIncome && !(widget.entry as IncomeEntry).isConfirmed) ...[
              const SizedBox(height: AppSpacing.md),
              BudgoButton(
                label: 'Confirm Income',
                icon: Icons.check_rounded,
                isLoading: _isActionInProgress,
                onPressed: _confirmIncome,
              ),
            ],
            if (isPlanned) ...[
              const SizedBox(height: AppSpacing.md),
              BudgoButton(
                label: 'Mark as Purchased',
                icon: Icons.shopping_cart_outlined,
                onPressed: () => setState(() => _showPurchaseInput = true),
              ),
            ],
          ],
          ],
        ),
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
