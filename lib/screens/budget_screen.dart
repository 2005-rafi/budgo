import 'package:expense/navigation/app_routes.dart';
import 'package:expense/provider/budget_provider.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final budgetProvider = context.watch<BudgetProvider>();
    final expensesProvider = context.watch<ExpensesProvider>();

    final active = budgetProvider.activeBudget;
    final spent = budgetProvider.spentInActivePeriod(expensesProvider);
    final remaining = (active == null) ? 0.0 : (active.limit - spent);
    final ratio = (active == null || active.limit <= 0)
        ? 0.0
        : (spent / active.limit);
    final clamped = ratio.clamp(0.0, 1.0);

    final near = budgetProvider.isNearLimit(expensesProvider);
    final over = budgetProvider.isOverLimit(expensesProvider);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        drawer: const AppDrawer(currentRoute: AppRoutes.budget),
        appBar: AppBar(
          title: const Text('Budget'),
          backgroundColor: color.primary,
          foregroundColor: color.onPrimary,
          actions: [
            IconButton(
              tooltip: 'Set Budget',
              icon: const Icon(Icons.tune),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const _BudgetSetupDialog(),
              ),
            ),
            if (active != null)
              IconButton(
                tooltip: 'Clear Budget',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => const _ConfirmClearBudgetDialog(),
                  );
                  if (ok == true) {
                    await context.read<BudgetProvider>().clearBudget();
                  }
                },
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (active == null)
              const _NoBudgetCard()
            else
              _ActiveBudgetCard(
                period: active.period,
                limit: active.limit,
                start: active.startDate,
                end: active.endDate,
                spent: spent,
                remaining: remaining,
                progress: clamped,
                isNear: near,
                isOver: over,
              ),
            const SizedBox(height: 16),
            Text('Tips', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              color: color.surfaceContainerHigh,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Set a weekly/monthly budget to get alerts when nearing the limit.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBudgetCard extends StatelessWidget {
  const _NoBudgetCard();

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
            Icon(Icons.savings_outlined, size: 34, color: color.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No budget set', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the settings icon to set a weekly, monthly, or overall budget.',
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

class _ActiveBudgetCard extends StatelessWidget {
  final String period;
  final double limit;
  final DateTime start;
  final DateTime end;
  final double spent;
  final double remaining;
  final double progress;
  final bool isNear;
  final bool isOver;

  const _ActiveBudgetCard({
    required this.period,
    required this.limit,
    required this.start,
    required this.end,
    required this.spent,
    required this.remaining,
    required this.progress,
    required this.isNear,
    required this.isOver,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final barColor = isOver
        ? color.error
        : (isNear ? color.tertiary : color.primary);

    final periodLabel = period[0].toUpperCase() + period.substring(1);

    return Card(
      color: color.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Active budget', style: theme.textTheme.titleMedium),
                const Spacer(),
                Chip(label: Text(periodLabel)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Period: ${DateFormat.yMMMd().format(start)} → ${DateFormat.yMMMd().format(end)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _BudgetStat(
                    title: 'Limit',
                    value: '₹${limit.toStringAsFixed(0)}',
                    bg: color.primaryContainer,
                    fg: color.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BudgetStat(
                    title: 'Spent',
                    value: '₹${spent.toStringAsFixed(0)}',
                    bg: color.secondaryContainer,
                    fg: color.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BudgetStat(
                    title: 'Remaining',
                    value: '₹${remaining.toStringAsFixed(0)}',
                    bg: isOver ? color.errorContainer : color.tertiaryContainer,
                    fg: isOver
                        ? color.onErrorContainer
                        : color.onTertiaryContainer,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: progress,
                backgroundColor: color.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 8),

            if (isOver)
              Text(
                'Over budget. Reduce spending or increase the limit.',
                style: theme.textTheme.bodyMedium?.copyWith(color: color.error),
              )
            else if (isNear)
              Text(
                'Near limit. Consider slowing down spending.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color.tertiary,
                ),
              )
            else
              Text(
                '${(progress * 100).toStringAsFixed(0)}% used',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String title;
  final String value;
  final Color bg;
  final Color fg;

  const _BudgetStat({
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

class _BudgetSetupDialog extends StatefulWidget {
  const _BudgetSetupDialog();

  @override
  State<_BudgetSetupDialog> createState() => _BudgetSetupDialogState();
}

class _BudgetSetupDialogState extends State<_BudgetSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _limit = TextEditingController();

  String _period = 'monthly'; // overall | weekly | monthly
  DateTime _pickedDate = DateTime.now();

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _pickedDate = picked);
  }

  DateTime _startOfWeekMonday(DateTime d) {
    final dateOnly = DateTime(d.year, d.month, d.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final limit = double.parse(_limit.text.trim());
    final provider = context.read<BudgetProvider>();
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    if (_period == 'overall') {
      await provider.setBudget(limit);
    } else if (_period == 'weekly') {
      await provider.setWeeklyBudget(
        id: 'weekly_$id',
        limit: limit,
        weekStart: _startOfWeekMonday(_pickedDate),
      );
    } else {
      await provider.setMonthlyBudget(
        id: 'monthly_$id',
        limit: limit,
        anyDayInMonth: _pickedDate,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    final dateLabel = _period == 'overall'
        ? 'No date required'
        : (_period == 'weekly'
              ? 'Week of: ${DateFormat.yMMMd().format(_startOfWeekMonday(_pickedDate))}'
              : 'Month: ${DateFormat.yMMM().format(_pickedDate)}');

    return AlertDialog(
      title: const Text('Set budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _period,
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'overall', child: Text('Overall')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Limit (₹)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                final n = double.tryParse(t);
                if (n == null || n <= 0) return 'Enter a valid limit';
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _period == 'overall' ? null : _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(dateLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.primary,
            foregroundColor: color.onPrimary,
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ConfirmClearBudgetDialog extends StatelessWidget {
  const _ConfirmClearBudgetDialog();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Clear budget'),
      content: const Text('Remove the active budget?'),
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
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
