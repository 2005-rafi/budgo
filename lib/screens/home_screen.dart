import 'package:auto_size_text/auto_size_text.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/provider/budget_provider.dart';
import 'package:expense/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<String> _categories = <String>[
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Others',
  ];
  Future<void> _confirmExit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Do you want to quit Budgo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (ok == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final budget = context.watch<BudgetProvider>().budget;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        drawer: const AppDrawer(currentRoute: AppRoutes.home),
        appBar: AppBar(
          title: const Text("Expense Tracker"),
          backgroundColor: color.primary,
          foregroundColor: color.onPrimary,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: color.tertiary,
          foregroundColor: color.onTertiary,
          onPressed: () => Navigator.pushNamed(context, '/add-expense'),
          label: const Text("Add Expense"),
          icon: const Icon(Icons.add),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ValueListenableBuilder(
            valueListenable: Hive.box<Expense>('expenses').listenable(),
            builder: (context, Box<Expense> box, _) {
              final entries = box.toMap().entries.toList();
              entries.sort((a, b) => b.value.date.compareTo(a.value.date));

              final totalSpent = entries.fold<double>(
                0.0,
                (sum, e) => sum + e.value.amount,
              );
              final remaining = budget - totalSpent;
              final isOverBudget = remaining < 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Summary", style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _SummarySection(
                    budget: budget,
                    spent: totalSpent,
                    remaining: remaining,
                    isOverBudget: isOverBudget,
                  ),
                  const SizedBox(height: 12),
                  _BudgetProgressBar(spent: totalSpent, budget: budget),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: "Recent Expenses",
                    trailing: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.expenses),
                      child: const Text("View all"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: entries.isEmpty
                        ? _EmptyState(
                            title: "No expenses yet",
                            subtitle: "Add your first expense to see it here.",
                            icon: Icons.receipt_long_outlined,
                          )
                        : _RecentExpensesList(
                            entries: entries,
                            categories: _categories,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final double budget;
  final double spent;
  final double remaining;
  final bool isOverBudget;

  const _SummarySection({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.isOverBudget,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Row(
      children: [
        _SummaryCard(
          title: "Budget",
          value: "₹${budget.toStringAsFixed(2)}",
          bgColor: color.primaryContainer,
          textColor: color.onPrimaryContainer,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          title: "Spent",
          value: "₹${spent.toStringAsFixed(2)}",
          bgColor: color.secondaryContainer,
          textColor: color.onSecondaryContainer,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          title: "Remaining",
          value: "₹${remaining.toStringAsFixed(2)}",
          bgColor: isOverBudget
              ? color.errorContainer
              : color.tertiaryContainer,
          textColor: isOverBudget
              ? color.onErrorContainer
              : color.onTertiaryContainer,
        ),
      ],
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  final double spent;
  final double budget;

  const _BudgetProgressBar({required this.spent, required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final ratio = (budget <= 0) ? 0.0 : (spent / budget);
    final clamped = ratio.clamp(0.0, 1.0);

    final barColor = ratio >= 1
        ? color.error
        : (ratio >= 0.9 ? color.tertiary : color.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          budget <= 0 ? "Set a budget to track progress" : "Budget usage",
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: budget <= 0 ? null : clamped,
            backgroundColor: color.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          budget <= 0
              ? "No budget set"
              : "${(ratio * 100).toStringAsFixed(0)}% used",
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RecentExpensesList extends StatelessWidget {
  final List<MapEntry<dynamic, Expense>> entries;
  final List<String> categories;

  const _RecentExpensesList({required this.entries, required this.categories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final visible = entries.take(12).toList();

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = visible[index];
        final exp = entry.value;
        final key = entry.key;

        return Card(
          color: color.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(exp.productName, style: theme.textTheme.bodyLarge),
            subtitle: Text(
              "${exp.category} • ${DateFormat.yMMMd().format(exp.date)}",
              style: theme.textTheme.bodyMedium,
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'edit') {
                  await showDialog(
                    context: context,
                    builder: (_) => _ExpenseEditDialog(
                      expenseKey: key,
                      existing: exp,
                      categories: categories,
                    ),
                  );
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => const _ConfirmDeleteDialog(),
                  );
                  if (confirm == true) {
                    await Hive.box<Expense>('expenses').delete(key);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color bgColor;
  final Color textColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            AutoSizeText(
              title,
              maxLines: 1,
              minFontSize: 10,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 6),
            AutoSizeText(
              value,
              maxLines: 1,
              minFontSize: 14,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: color.primary.withOpacity(0.85)),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text("Delete Expense"),
      content: const Text("Do you really want to delete this expense?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.error,
            foregroundColor: color.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    );
  }
}

class _ExpenseEditDialog extends StatefulWidget {
  final dynamic expenseKey;
  final Expense existing;
  final List<String> categories;

  const _ExpenseEditDialog({
    required this.expenseKey,
    required this.existing,
    required this.categories,
  });

  @override
  State<_ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends State<_ExpenseEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  late String _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing.productName);
    _amountController = TextEditingController(
      text: widget.existing.amount.toStringAsFixed(2),
    );
    _category = widget.existing.category;
    _date = widget.existing.date;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return AlertDialog(
      title: const Text("Edit Expense"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              items: widget.categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _category = val ?? _category),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(DateFormat.yMMMd().format(_date)),
                const Spacer(),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text("Change Date"),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.primary,
            foregroundColor: color.onPrimary,
          ),
          onPressed: () async {
            final newName = _nameController.text.trim();
            final newAmount = double.tryParse(_amountController.text.trim());

            if (newName.isEmpty || newAmount == null || newAmount <= 0) return;

            final updated = Expense(
              productName: newName,
              amount: newAmount,
              category: _category,
              date: _date,
            );

            await Hive.box<Expense>('expenses').put(widget.expenseKey, updated);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
