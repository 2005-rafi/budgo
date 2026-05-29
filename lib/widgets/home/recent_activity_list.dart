import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/widgets/common/app_transaction_tile.dart';
import 'package:expense/widgets/common/app_card.dart';
import 'package:expense/widgets/forms/transaction_detail_sheet.dart';

class RecentActivityList extends StatelessWidget {
  final List<TransactionEntry> transactions;
  final Function(TransactionEntry) onDelete;
  final Function(IncomeEntry)? onConfirm;

  const RecentActivityList({
    super.key,
    required this.transactions,
    required this.onDelete,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayList = transactions.take(5).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(displayList.length, (index) {
        final entry = displayList[index];
        final isLast = index == displayList.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
          child: AppCard(
            elevated: true,
            padding: EdgeInsets.zero,
            child: AppTransactionTile(
              title: entry.displayName,
              amount: entry.amount,
              category: entry.category,
              date: entry.date,
              isIncome: entry is IncomeEntry,
              isPending: entry is IncomeEntry && !entry.isConfirmed,
              isPlanned: entry is PlannedEntry,
              showDivider: false, // Hide divider inside individual cards
              onTap: () => TransactionDetailSheet.show(context, entry),
              onDelete: () => onDelete(entry),
              onConfirm: entry is IncomeEntry
                  ? () => onConfirm?.call(entry)
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
