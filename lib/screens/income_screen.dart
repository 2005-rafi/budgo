import 'package:expense/models/income.dart';
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});
  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  static const List<String> _sources = <String>[
    'Salary',
    'Freelance',
    'Gift',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final incomeProvider = context.watch<IncomeProvider>();
    final items = incomeProvider.items;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        drawer: const AppDrawer(currentRoute: AppRoutes.income),
        appBar: AppBar(
          title: const Text('Income'),
          backgroundColor: color.primary,
          foregroundColor: color.onPrimary,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: color.tertiary,
          foregroundColor: color.onTertiary,
          icon: const Icon(Icons.add),
          label: const Text('Add Income'),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => const _AddIncomeSheet(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _IncomeSummaryCard(
              totalConfirmed: incomeProvider.totalConfirmed,
              totalAll: incomeProvider.totalAll,
              pendingCount: items.where((i) => !i.isConfirmed).length,
            ),
            const SizedBox(height: 16),
            Text('History', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const _EmptyIncome()
            else
              ...items.map((inc) => _IncomeTile(income: inc)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _IncomeSummaryCard extends StatelessWidget {
  final double totalConfirmed;
  final double totalAll;
  final int pendingCount;

  const _IncomeSummaryCard({
    required this.totalConfirmed,
    required this.totalAll,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Card(
      color: color.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    title: 'Confirmed',
                    value: '₹${totalConfirmed.toStringAsFixed(0)}',
                    bg: color.primaryContainer,
                    fg: color.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatPill(
                    title: 'All entries',
                    value: '₹${totalAll.toStringAsFixed(0)}',
                    bg: color.secondaryContainer,
                    fg: color.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatPill(
                    title: 'Pending',
                    value: pendingCount.toString(),
                    bg: color.tertiaryContainer,
                    fg: color.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Only confirmed income affects net balance/budget.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String title;
  final String value;
  final Color bg;
  final Color fg;

  const _StatPill({
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

class _IncomeTile extends StatelessWidget {
  final Income income;
  const _IncomeTile({required this.income});

  Future<void> _confirmIfNeeded(BuildContext context) async {
    if (income.isConfirmed) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmIncomeDialog(),
    );

    if (ok == true) {
      await context.read<IncomeProvider>().confirmIncome(income);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final dateText = DateFormat.yMMMd().format(income.date);
    final statusText = income.isConfirmed
        ? 'Confirmed'
        : 'Pending confirmation';

    return Card(
      color: color.surfaceContainerHigh,
      child: ListTile(
        title: Text('${income.source} • ₹${income.amount.toStringAsFixed(0)}'),
        subtitle: Text(
          '$dateText • $statusText${income.description?.isNotEmpty == true ? ' • ${income.description}' : ''}',
        ),
        leading: Icon(
          income.isConfirmed ? Icons.verified_outlined : Icons.hourglass_bottom,
          color: income.isConfirmed ? color.primary : color.tertiary,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) async {
            final provider = context.read<IncomeProvider>();
            if (v == 'confirm') {
              await _confirmIfNeeded(context);
            } else if (v == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => const _ConfirmDeleteIncomeDialog(),
              );
              if (confirm == true) await provider.deleteIncome(income);
            }
          },
          itemBuilder: (_) => [
            if (!income.isConfirmed)
              const PopupMenuItem(value: 'confirm', child: Text('Confirm')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _confirmIfNeeded(context),
      ),
    );
  }
}

class _AddIncomeSheet extends StatefulWidget {
  const _AddIncomeSheet();

  @override
  State<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<_AddIncomeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();

  String _source = 'Salary';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.parse(_amount.text.trim());
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final addNow = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmIncomeDialog(),
    );

    final draft = Income(
      id: id,
      source: _source,
      amount: amount,
      date: _date,
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      isConfirmed: false,
    );

    final provider = context.read<IncomeProvider>();
    await provider.addIncomeDraft(draft);

    if (addNow == true) {
      final created = provider.items.firstWhere((i) => i.id == id);
      await provider.confirmIncome(created);
    }

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
            Text('Add income', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _source,
              decoration: const InputDecoration(
                labelText: 'Source',
                border: OutlineInputBorder(),
              ),
              items: IncomeScreen._sources
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                final n = double.tryParse(t);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text('Date: ${DateFormat.yMMMd().format(_date)}'),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
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

class _ConfirmIncomeDialog extends StatelessWidget {
  const _ConfirmIncomeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm income'),
      content: const Text('Add this income to the budget/net balance now?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _ConfirmDeleteIncomeDialog extends StatelessWidget {
  const _ConfirmDeleteIncomeDialog();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete income'),
      content: const Text('Delete this income entry?'),
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
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _EmptyIncome extends StatelessWidget {
  const _EmptyIncome();

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
            Icon(Icons.add_card_outlined, size: 34, color: color.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No income added', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Tap “Add Income” to create your first entry.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
