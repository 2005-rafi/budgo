import 'dart:math' as math;

import 'package:expense/models/expense.dart';
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/services/report_export_service.dart';
import 'package:expense/widgets/app_drawer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range;
  late _RangePreset _preset;

  @override
  void initState() {
    super.initState();
    _preset = _RangePreset.thisMonth;
    _range = _preset.toRange(DateTime.now());
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _preset = _RangePreset.custom;
        _range = picked;
      });
    }
  }

  List<Expense> _expensesInRange(List<Expense> all) {
    final start = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final end = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      23,
      59,
      59,
    );

    final filtered = all
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Map<String, double> _categoryTotals(List<Expense> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  List<_TimePoint> _timeSeries(List<Expense> expenses) {
    final days = _range.duration.inDays + 1;
    final weekly = days > 35;

    final buckets = <DateTime, double>{};

    DateTime normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime startOfWeekMonday(DateTime d) {
      final x = normalizeDay(d);
      return x.subtract(Duration(days: x.weekday - 1));
    }

    for (final e in expenses) {
      final key = weekly ? startOfWeekMonday(e.date) : normalizeDay(e.date);
      buckets[key] = (buckets[key] ?? 0) + e.amount;
    }

    final keys = buckets.keys.toList()..sort();
    final labelFmt = weekly ? DateFormat('MMM d') : DateFormat('d MMM');
    final maxBars = weekly ? 12 : 14;
    final trimmed = keys.length > maxBars
        ? keys.sublist(keys.length - maxBars)
        : keys;

    return trimmed
        .map(
          (k) => _TimePoint(label: labelFmt.format(k), value: buckets[k] ?? 0),
        )
        .toList();
  }

  Future<void> _showExportSheet(List<Expense> filtered) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final title = 'Expenses report';
    final fileBase =
        'expenses_${dateFmt.format(_range.start)}_${dateFmt.format(_range.end)}';

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final color = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Export CSV'),
                  subtitle: const Text(
                    'Share a CSV file (best for full data).',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await ReportExportService.exportExpensesCsv(
                      expenses: filtered,
                      range: _range,
                    );
                    await Share.shareXFiles([XFile(file.path)], text: title);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Export PDF'),
                  subtitle: const Text('Share a printable PDF summary.'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final bytes = await ReportExportService.buildExpensesPdfBytes(
                      expenses: filtered,
                      range: _range,
                      title:
                          '$title (${dateFmt.format(_range.start)} → ${dateFmt.format(_range.end)})',
                    );
                    await Printing.sharePdf(
                      bytes: bytes,
                      filename: '$fileBase.pdf',
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Tip: PDF shows up to 200 rows for readability; CSV exports everything.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: color.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final expensesProvider = context.watch<ExpensesProvider>();
    final all = expensesProvider.items;
    final filtered = _expensesInRange(all);

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final total = filtered.fold<double>(0, (s, e) => s + e.amount);
    final count = filtered.length;
    final avg = count == 0 ? 0 : total / count;

    final categoryTotals = _categoryTotals(filtered);
    final topCategory = categoryTotals.entries.isEmpty
        ? null
        : (categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;

    final timeSeries = _timeSeries(filtered);
    void _goHome(BuildContext context) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    }

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        drawer: const AppDrawer(currentRoute: AppRoutes.reports),
        appBar: AppBar(
          title: const Text('Reports'),
          backgroundColor: color.primary,
          foregroundColor: color.onPrimary,
          actions: [
            IconButton(
              tooltip: 'Pick date range',
              icon: const Icon(Icons.date_range_outlined),
              onPressed: _pickCustomRange,
            ),
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _showExportSheet(filtered),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RangeSelector(
              preset: _preset,
              range: _range,
              onPreset: (p) => setState(() {
                _preset = p;
                _range = p.toRange(DateTime.now());
              }),
              onCustom: _pickCustomRange,
            ),
            const SizedBox(height: 12),

            _KpiRow(
              kpis: [
                _Kpi(
                  title: 'Total spent',
                  value: currency.format(total),
                  kind: _KpiKind.primary,
                ),
                _Kpi(
                  title: 'Transactions',
                  value: '$count',
                  kind: _KpiKind.secondary,
                ),
                _Kpi(
                  title: 'Avg/expense',
                  value: currency.format(avg),
                  kind: _KpiKind.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 10),

            _InsightCard(
              title: 'Top category',
              icon: Icons.local_offer_outlined,
              child: Text(
                topCategory == null
                    ? 'No data in this range.'
                    : '${topCategory.key} • ${currency.format(topCategory.value)}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),

            _InsightCard(
              title: 'Spending trend',
              icon: Icons.bar_chart_outlined,
              child: timeSeries.isEmpty
                  ? const _EmptyChartHint()
                  : _BarChartCard(points: timeSeries),
            ),
            const SizedBox(height: 12),

            _InsightCard(
              title: 'Category split',
              icon: Icons.pie_chart_outline,
              child: categoryTotals.isEmpty
                  ? const _EmptyChartHint()
                  : _CategoryPieCard(categoryTotals: categoryTotals),
            ),
            const SizedBox(height: 12),

            _InsightCard(
              title: 'Top expenses',
              icon: Icons.receipt_long_outlined,
              child: filtered.isEmpty
                  ? const _EmptyChartHint(
                      message: 'No expenses in selected range.',
                    )
                  : _TopExpensesList(expenses: filtered.take(8).toList()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

enum _RangePreset { thisWeek, thisMonth, last30Days, custom }

extension on _RangePreset {
  String get label => switch (this) {
    _RangePreset.thisWeek => 'This week',
    _RangePreset.thisMonth => 'This month',
    _RangePreset.last30Days => 'Last 30 days',
    _RangePreset.custom => 'Custom',
  };

  DateTimeRange toRange(DateTime now) {
    DateTime startOfWeekMonday(DateTime d) {
      final x = DateTime(d.year, d.month, d.day);
      return x.subtract(Duration(days: x.weekday - 1));
    }

    switch (this) {
      case _RangePreset.thisWeek:
        final start = startOfWeekMonday(now);
        final end = start.add(const Duration(days: 6));
        return DateTimeRange(start: start, end: end);
      case _RangePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = (now.month == 12)
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final end = nextMonth.subtract(const Duration(days: 1));
        return DateTimeRange(start: start, end: end);
      case _RangePreset.last30Days:
        final end = DateTime(now.year, now.month, now.day);
        final start = end.subtract(const Duration(days: 29));
        return DateTimeRange(start: start, end: end);
      case _RangePreset.custom:
        // Caller will set it.
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    }
  }
}

class _RangeSelector extends StatelessWidget {
  final _RangePreset preset;
  final DateTimeRange range;
  final ValueChanged<_RangePreset> onPreset;
  final VoidCallback onCustom;

  const _RangeSelector({
    required this.preset,
    required this.range,
    required this.onPreset,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date range', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in [
                  _RangePreset.thisWeek,
                  _RangePreset.thisMonth,
                  _RangePreset.last30Days,
                ])
                  ChoiceChip(
                    label: Text(p.label),
                    selected: preset == p,
                    onSelected: (_) => onPreset(p),
                  ),
                ActionChip(label: const Text('Custom'), onPressed: onCustom),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${dateFmt.format(range.start)} → ${dateFmt.format(range.end)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

enum _KpiKind { primary, secondary, tertiary }

class _Kpi {
  final String title;
  final String value;
  final _KpiKind kind;

  _Kpi({required this.title, required this.value, required this.kind});
}

class _KpiRow extends StatelessWidget {
  final List<_Kpi> kpis;
  const _KpiRow({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    Color bg(_KpiKind k) => switch (k) {
      _KpiKind.primary => c.primaryContainer,
      _KpiKind.secondary => c.secondaryContainer,
      _KpiKind.tertiary => c.tertiaryContainer,
    };

    Color fg(_KpiKind k) => switch (k) {
      _KpiKind.primary => c.onPrimaryContainer,
      _KpiKind.secondary => c.onSecondaryContainer,
      _KpiKind.tertiary => c.onTertiaryContainer,
    };

    return Row(
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg(kpis[i].kind),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    kpis[i].title,
                    style: TextStyle(
                      color: fg(kpis[i].kind),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kpis[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg(kpis[i].kind),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i != kpis.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InsightCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyChartHint extends StatelessWidget {
  final String message;
  const _EmptyChartHint({this.message = 'Not enough data to show chart.'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}

class _TimePoint {
  final String label;
  final double value;

  _TimePoint({required this.label, required this.value});
}

class _BarChartCard extends StatelessWidget {
  final List<_TimePoint> points;
  const _BarChartCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = Theme.of(context).colorScheme;

    final maxY = points.isEmpty
        ? 0
        : points.map((e) => e.value).reduce(math.max);
    final roundedMaxY = (maxY <= 0) ? 10.0 : (maxY * 1.25);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: roundedMaxY,
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, meta) => Text(
                  v.toStringAsFixed(0),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length)
                    return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      points[i].label,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(points.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].value,
                  color: c.primary,
                  borderRadius: BorderRadius.circular(6),
                  width: 14,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _CategoryPieCard extends StatelessWidget {
  final Map<String, double> categoryTotals;
  const _CategoryPieCard({required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const _EmptyChartHint();

    // Top 5 + Other
    final top = entries.take(5).toList();
    final otherSum = entries.skip(5).fold<double>(0, (s, e) => s + e.value);

    final data = <MapEntry<String, double>>[
      ...top,
      if (otherSum > 0) MapEntry('Other', otherSum),
    ];

    final palette = <Color>[
      c.primary,
      c.tertiary,
      c.secondary,
      c.error,
      c.primaryContainer,
      c.tertiaryContainer,
    ];

    return Row(
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: List.generate(data.length, (i) {
                final value = data[i].value;
                final pct = (value / total) * 100;
                return PieChartSectionData(
                  value: value,
                  title: pct >= 12 ? '${pct.toStringAsFixed(0)}%' : '',
                  radius: 56,
                  color: palette[i % palette.length],
                  titleStyle: theme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < data.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette[i % palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${data[i].key} • ₹${data[i].value.toStringAsFixed(0)}',
                          style: theme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopExpensesList extends StatelessWidget {
  final List<Expense> expenses;
  const _TopExpensesList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Column(
      children: expenses.map((e) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(e.productName, style: theme.textTheme.bodyLarge),
          subtitle: Text(
            '${e.category} • ${DateFormat.yMMMd().format(e.date)}',
          ),
          trailing: Text(
            currency.format(e.amount),
            style: theme.textTheme.titleSmall,
          ),
        );
      }).toList(),
    );
  }
}
