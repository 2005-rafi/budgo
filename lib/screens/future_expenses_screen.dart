import 'package:expense/models/future_expense.dart';
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FutureExpensesScreen extends StatelessWidget {
  const FutureExpensesScreen({super.key});

  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  Future<double?> _askAmount(BuildContext context, {double? initial}) async {
    final controller = TextEditingController(
      text: initial == null ? '' : initial.toStringAsFixed(0),
    );

    final result = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm purchase'),
        
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (₹)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(context, v);
            },
            child: const Text('Add to expenses'),
          ),
        ],
      ),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final wishlist = context.watch<FutureExpensesProvider>();
    final planned = wishlist.planned;
    final purchased = wishlist.purchased;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        drawer: const AppDrawer(currentRoute: AppRoutes.futureExpenses),
        appBar: AppBar(
          title: const Text('Future Expenses'),
          backgroundColor: color.primary,
          foregroundColor: color.onPrimary,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: color.tertiary,
          foregroundColor: color.onTertiary,
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => const _AddFutureExpenseSheet(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WishlistSummaryCard(
              plannedCount: planned.length,
              purchasedCount: purchased.length,
              plannedEstimatedTotal: wishlist.totalPlannedEstimated,
            ),
            const SizedBox(height: 16),

            Text('Planned', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (planned.isEmpty)
              const _EmptyBlock(
                icon: Icons.shopping_bag_outlined,
                title: 'No planned items',
                subtitle: 'Add future purchases to track priorities and costs.',
                
              )
            else
              ...planned.map(
                (e) => _FutureExpenseTile(
                  item: e,
                  onMarkPurchased: () async {
                    final amount = await _askAmount(
                      context,
                      initial: e.estimatedCost,
                    );
                    if (amount == null || amount <= 0) return;

                    await context.read<FutureExpensesProvider>().purchase(
                      e,
                      amount: amount,
                      purchasedAt: DateTime.now(),
                    );
                  },
                  onMarkPlanned: () async {
                    await context.read<FutureExpensesProvider>().undoPurchase(
                      e,
                    );
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _ConfirmDialog(
                        title: 'Delete item',
                        message: 'Delete this future expense?',
                        confirmText: 'Delete',
                      ),
                    );
                    if (confirm == true) {
                      await context
                          .read<FutureExpensesProvider>()
                          .deleteFutureExpense(e);
                    }
                  },
                ),
              ),

            const SizedBox(height: 20),
            Text('Purchased', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (purchased.isEmpty)
              const _EmptyBlock(
                icon: Icons.check_circle_outline,
                title: 'No purchased items',
                subtitle: 'Mark an item as purchased to move it here.',
              )
            else
              ...purchased.map(
                (e) => _FutureExpenseTile(
                  item: e,
                  onMarkPurchased: () async {
                    // If already purchased, do nothing; user should use "Mark as planned" to undo.
                  },
                  onMarkPlanned: () async {
                    await context.read<FutureExpensesProvider>().undoPurchase(
                      e,
                    );
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _ConfirmDialog(
                        title: 'Delete item',
                        message: 'Delete this future expense?',
                        confirmText: 'Delete',
                      ),
                    );
                    if (confirm == true) {
                      await context
                          .read<FutureExpensesProvider>()
                          .deleteFutureExpense(e);
                    }
                  },
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _WishlistSummaryCard extends StatelessWidget {
  final int plannedCount;
  final int purchasedCount;
  final double plannedEstimatedTotal;

  const _WishlistSummaryCard({
    required this.plannedCount,
    required this.purchasedCount,
    required this.plannedEstimatedTotal,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Card(
      color: color.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _MiniStat(
                title: 'Planned',
                value: plannedCount.toString(),
                bg: color.primaryContainer,
                fg: color.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                title: 'Purchased',
                value: purchasedCount.toString(),
                bg: color.secondaryContainer,
                fg: color.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                title: 'Est. total',
                value: '₹${plannedEstimatedTotal.toStringAsFixed(0)}',
                bg: color.tertiaryContainer,
                fg: color.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final Color bg;
  final Color fg;

  const _MiniStat({
    required this.title,
    required this.value,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureExpenseTile extends StatelessWidget {
  final FutureExpense item;
  final Future<void> Function() onMarkPurchased;
  final Future<void> Function() onMarkPlanned;
  final Future<void> Function() onDelete;

  const _FutureExpenseTile({
    required this.item,
    required this.onMarkPurchased,
    required this.onMarkPlanned,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final dueText = item.dueDate == null
        ? 'No due date'
        : 'Due ${DateFormat.yMMMd().format(item.dueDate!)}';
    final costText = item.estimatedCost == null
        ? 'No cost'
        : '₹${item.estimatedCost!.toStringAsFixed(0)}';

    return Card(
      color: color.surfaceContainerHigh,
      child: ListTile(
        title: Text(item.title, style: theme.textTheme.bodyLarge),
        subtitle: Text('${item.category} • $dueText • $costText'),
        leading: _PriorityDot(priority: item.priority),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) async {
            if (v == 'purchase') {
              if (!item.isPurchased) await onMarkPurchased();
            } else if (v == 'planned') {
              if (item.isPurchased) await onMarkPlanned();
            } else if (v == 'delete') {
              await onDelete();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: item.isPurchased ? 'planned' : 'purchase',
              child: Text(
                item.isPurchased ? 'Mark as planned' : 'Mark as purchased',
              ),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final int priority;
  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final Color dot = switch (priority) {
      3 => color.error,
      2 => color.tertiary,
      _ => color.primary,
    };

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
    );
  }
}

class _AddFutureExpenseSheet extends StatefulWidget {
  const _AddFutureExpenseSheet();

  @override
  State<_AddFutureExpenseSheet> createState() => _AddFutureExpenseSheetState();
}

class _AddFutureExpenseSheetState extends State<_AddFutureExpenseSheet> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();

  String _category = 'General';
  int _priority = 1;
  DateTime? _dueDate;

  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final costText = _cost.text.trim();
    final parsedCost = costText.isEmpty ? null : double.tryParse(costText);

    final item = FutureExpense(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      estimatedCost: parsedCost,
      priority: _priority,
      dueDate: _dueDate,
      isPurchased: false,
      category: _category.trim().isEmpty ? 'General' : _category.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    await context.read<FutureExpensesProvider>().addFutureExpense(item);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 8),
            Text(
              'Add future expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Estimated cost (optional)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = double.tryParse(t);
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _category = v,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Low')),
                DropdownMenuItem(value: 2, child: Text('Medium')),
                DropdownMenuItem(value: 3, child: Text('High')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 1),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _dueDate == null
                    ? 'Pick due date (optional)'
                    : 'Due: ${DateFormat.yMMMd().format(_dueDate!)}',
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.primary,
                      foregroundColor: color.onPrimary,
                    ),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Card(
      color: color.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 34, color: color.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.error,
            foregroundColor: color.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
