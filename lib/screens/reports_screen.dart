import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expense/models/reports_view_model.dart';
import 'package:expense/models/filter_criteria.dart';

import 'package:expense/provider/reports_provider.dart';
import 'package:expense/provider/app_navigation_provider.dart';

import 'package:expense/services/report_export_service.dart';

import 'package:expense/core/money.dart';
import 'package:expense/core/app_layout.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_spacing.dart';

import 'package:expense/widgets/charts/insight_line.dart';
import 'package:expense/widgets/dashboard/calendar_heatmap.dart';
import 'package:expense/widgets/empty_state_placeholder.dart';
import 'package:expense/widgets/charts/line_chart_widget.dart';
import 'package:expense/widgets/charts/bar_chart_widget.dart';
import 'package:expense/widgets/charts/pie_chart_widget.dart';
import 'package:expense/widgets/charts/chart_panel.dart';

class ReportsScreen extends StatefulWidget {
  static const String routeName = '/reports';

  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ScrollController _scrollController = ScrollController();

  DateTime _heatmapMonth = DateTime.now();
  bool _isYearlyHeatmap = false;
  bool _isExporting = false;
  double? _exportProgress;

  @override
  void initState() {
    super.initState();
    _heatmapMonth = DateTime(_heatmapMonth.year, _heatmapMonth.month, 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Use read to avoid rebuild during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReportsProvider>().clearRange();
      }
    });
    super.dispose();
  }

  void _updateRangeAndCompute(
    ReportsProvider provider,
    DateTimeRange newRange,
    ReportsRangePreset preset,
  ) {
    provider.setRange(newRange, preset);
    // Task 4-C-4: Sync heatmap month with range
    setState(() {
      _heatmapMonth = DateTime(newRange.start.year, newRange.start.month, 1);
    });
  }

  Future<void> _pickCustomRange(ReportsProvider provider) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: provider.activeRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _updateRangeAndCompute(provider, picked, ReportsRangePreset.custom);
    }
  }

  void _confirmExport(BuildContext context, ReportsProvider provider) {
    final expenses = provider.rangeExpenses;
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No expenses to export.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final color = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Export Data',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Exporting ${expenses.length} transaction(s) for the selected period.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: color.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Export CSV'),
                  subtitle: const Text('Generates a full spreadsheet file.'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _runCsvExport(provider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Export PDF'),
                  subtitle: Text(
                    'Generates a formatted multi-page document (~${(expenses.length / 40).ceil()} pages).',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _runPdfExport(provider);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  void _runCsvExport(ReportsProvider provider) async {
    setState(() {
      _isExporting = true;
      _exportProgress = null;
    });

    final result = await ReportExportService.exportExpensesCsv(
      expenses: provider.rangeExpenses,
      range: provider.activeRange,
    );

    if (!mounted) return;
    setState(() {
      _isExporting = false;
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV Export ready')));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.value!.path)],
          subject: 'Expenses CSV Export',
        ),
      );
    } else {
      _showExportError(result.error);
    }
  }

  void _runPdfExport(ReportsProvider provider) async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    final title = 'Budgo Expenses Report';
    final result = await ReportExportService.buildExpensesPdfBytes(
      expenses: provider.rangeExpenses,
      range: provider.activeRange,
      title: title,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _exportProgress = progress;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _isExporting = false;
      _exportProgress = null;
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF Export ready')));

      final dateFmt = DateFormat('yyyyMMdd');
      final fileBase =
          'budgo_expenses_${dateFmt.format(provider.activeRange.start)}_${dateFmt.format(provider.activeRange.end)}_${DateTime.now().millisecondsSinceEpoch}';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileBase.pdf');
      await tempFile.writeAsBytes(result.value!);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: 'Expenses PDF Export',
        ),
      );
    } else {
      _showExportError(result.error);
    }
  }

  void _showExportError(ExportError? error) {
    if (error == null) return;
    final message = error.message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _navigateMonth(
    int monthsOffset,
    DateTime? firstDate,
    DateTime? lastDate,
  ) {
    setState(() {
      final newMonth = DateTime(
        _heatmapMonth.year,
        _heatmapMonth.month + monthsOffset,
        1,
      );
      if (firstDate != null &&
          newMonth.isBefore(DateTime(firstDate.year, firstDate.month, 1))) {
        return;
      }
      if (lastDate != null &&
          newMonth.isAfter(DateTime(lastDate.year, lastDate.month, 1))) {
        return;
      }
      _heatmapMonth = newMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: color.surface,
        foregroundColor: color.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        actions: _isExporting
            ? []
            : [
                IconButton(
                  tooltip: 'Pick date range',
                  icon: const Icon(Icons.date_range_outlined),
                  onPressed: () =>
                      _pickCustomRange(context.read<ReportsProvider>()),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'export') {
                      _confirmExport(context, context.read<ReportsProvider>());
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Export Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Stack(
        children: [
          Selector<ReportsProvider, (bool, String?, int?)>(
            selector: (_, p) =>
                (p.isLoading, p.errorMessage, p.viewModel?.transactionCount),
            builder: (context, data, _) {
              final (isLoading, errorMessage, transactionCount) = data;

              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (errorMessage != null) {
                return Center(child: Text('Error: $errorMessage'));
              }
              if (transactionCount == 0) {
                return const Center(
                  child: EmptyStatePlaceholder(
                    icon: Icons.analytics_outlined,
                    title: 'No reports yet',
                    message:
                        'Track some expenses to see your financial patterns here.',
                  ),
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 6-3 · Range selector — compact chip row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding(context),
                        vertical: AppSpacing.md,
                      ),
                      child: _buildRangeChips(context),
                    ),
                  ),

                  // 6-1 · Compact sticky KPI bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _KPIHeaderDelegate(),
                  ),

                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: AppLayout.screenPadding(context),
                      right: AppLayout.screenPadding(context),
                      top: AppSpacing.md,
                      bottom: AppLayout.bottomPadding(context) + 40,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 6-2 · Scroll order
                        // (1) period summary insight (Already in KPI section or above)

                        // (2) heatmap ChartPanel
                        _buildHeatmapSection(context),
                        const SizedBox(height: AppSpacing.xl),

                        // (3) trend chart ChartPanel
                        // (4) pie chart ChartPanel
                        _buildChartsSection(context),
                        const SizedBox(height: AppSpacing.xl),

                        // (5) top expenses list
                        _buildTopExpensesSection(context),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),

          // Global Export Loader
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(AppSpacing.xl),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(value: _exportProgress),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _exportProgress != null
                              ? 'Generating PDF (${(_exportProgress! * 100).toInt()}%)...'
                              : 'Preparing export...',
                          style: AppTextStyles.body(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRangeChips(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportsRangePreset.values.map((preset) {
          final isSelected = provider.activePreset == preset;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(preset.label),
              selected: isSelected,
              onSelected: (val) {
                if (val) provider.setPreset(preset);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartsSection(BuildContext context) {
    return Selector<ReportsProvider, ReportsViewModel?>(
      selector: (_, p) => p.viewModel,
      builder: (context, vm, _) {
        if (vm == null) return const SizedBox.shrink();

        // 5-3 & 5-4 logic
        final weekendVsWeekdayText = vm.weekdayAvg > 0
            ? 'Weekends ${vm.weekendAvg > vm.weekdayAvg ? 'higher' : 'lower'} by ${((vm.weekendAvg - vm.weekdayAvg).abs() / vm.weekdayAvg * 100).toStringAsFixed(0)}% vs weekdays'
            : null;

        final peakDay = vm.dailySpending.isNotEmpty
            ? vm.dailySpending.reduce((a, b) => a.value > b.value ? a : b)
            : null;
        final anomalyText =
            (peakDay != null &&
                vm.dailyAverage > 0 &&
                peakDay.value > vm.dailyAverage * 2)
            ? 'Spike on ${peakDay.displayLabel}: ${peakDay.value.format()} (${(peakDay.value / vm.dailyAverage * 100).toStringAsFixed(0)}% above avg)'
            : null;

        return Column(
          children: [
            ChartPanel(
              title: 'Daily Spending Trend',
              subtitle:
                  '${DateFormat('MMM d').format(vm.activeRange.start)} - ${DateFormat('MMM d').format(vm.activeRange.end)} · ${vm.transactionCount} transactions · ${vm.dailyAverage.format()}/day',
              keyFinding: peakDay != null
                  ? 'Peak: ${peakDay.displayLabel} · ${peakDay.value.format()}'
                  : null,
              chart: Column(
                children: [
                  if (weekendVsWeekdayText != null) ...[
                    InsightLine(
                      icon: Icons.calendar_view_week,
                      text: weekendVsWeekdayText,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (anomalyText != null) ...[
                    InsightLine(
                      icon: Icons.warning_amber_outlined,
                      text: anomalyText,
                      iconColor: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                  ],
                  AspectRatio(
                    aspectRatio: 1.7,
                    child: LineChartWidget(
                      data: vm.dailySpending,
                      color: Theme.of(context).colorScheme.primary,
                      range: vm.activeRange,
                      averageSpend: vm.dailyAverage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ChartPanel(
              title: 'Period Spending Breakdown',
              subtitle: 'Bar chart view of spending over the active period',
              chart: AspectRatio(
                aspectRatio: 1.7,
                child: BarChartWidget(
                  data: vm.barPoints,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ChartPanel(
              title: 'Spending by Category',
              subtitle: 'Distribution of expenses across categories',
              keyFinding: vm.topCategories.isNotEmpty
                  ? 'Top: ${vm.topCategories.first.category} · ${vm.topCategories.first.percentage.toStringAsFixed(1)}%'
                  : null,
              chart: Column(
                children: [
                  if (vm.topCategories.isNotEmpty) ...[
                    InsightLine(
                      icon: Icons.pie_chart_outline,
                      text:
                          'Top category: ${vm.topCategories.first.category} · ${vm.topCategories.first.percentage.toStringAsFixed(1)}% of total spending',
                    ),
                    const SizedBox(height: 12),
                  ],
                  PieChartWidget(data: vm.categoryDistribution),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeatmapSection(BuildContext context) {
    return Selector<ReportsProvider, ReportsViewModel?>(
      selector: (_, p) => p.viewModel,
      builder: (context, vm, _) {
        if (vm == null) return const SizedBox.shrink();

        return ChartPanel(
          title: 'Activity Map',
          subtitle: _isYearlyHeatmap
              ? 'Yearly overview of spending intensity'
              : 'Daily spending intensity for ${DateFormat('MMMM y').format(_heatmapMonth)}',
          actions: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Month'),
                  icon: Icon(Icons.calendar_view_month, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Year'),
                  icon: Icon(Icons.calendar_view_day, size: 16),
                ),
              ],
              selected: {_isYearlyHeatmap},
              onSelectionChanged: (val) {
                setState(() => _isYearlyHeatmap = val.first);
              },
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
          chart: Column(
            children: [
              if (!_isYearlyHeatmap) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _navigateMonth(-1, null, null),
                    ),
                    Text(
                      DateFormat('MMMM y').format(_heatmapMonth),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _navigateMonth(1, null, null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              CalendarHeatmapWidget(
                data: vm.rangeHeatmap,
                month: _isYearlyHeatmap ? null : _heatmapMonth,
                year: _heatmapMonth.year,
                maxAmount: vm.maxDailySpent,
                normalizationMax: vm.yearMaxDailySpend,
                isYearOverview: _isYearlyHeatmap,
                onMonthTap: (date) {
                  setState(() {
                    _heatmapMonth = date;
                    _isYearlyHeatmap = false;
                  });
                },
                onDayTap: (date, amount) {
                  final criteria = FilterCriteria(date: date);
                  context.read<AppNavigationProvider>().setIndex(1);
                  Navigator.of(
                    context,
                  ).pushNamed('/activity', arguments: criteria);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopExpensesSection(BuildContext context) {
    return Selector<ReportsProvider, ReportsViewModel?>(
      selector: (_, p) => p.viewModel,
      builder: (context, vm, _) {
        if (vm == null || vm.topExpenses.isEmpty) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;
        final topFive = vm.topExpenses.take(5).toList();

        return ChartPanel(
          title: 'Top Expenses',
          subtitle: 'Individual high-value transactions',
          chart: Column(
            children: [
              ...topFive.asMap().entries.map((entry) {
                final index = entry.key;
                final expense = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  title: Text(
                    expense.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(expense.category),
                  trailing: Text(
                    expense.amount.format(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    context.read<AppNavigationProvider>().setIndex(1);
                    Navigator.of(context).pushNamed('/activity');
                  },
                  child: const Text('See all →'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KPIHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Selector<ReportsProvider, ReportsViewModel?>(
      selector: (_, p) => p.viewModel,
      builder: (context, vm, _) {
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: vm == null
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    _buildKPIItem(
                      context,
                      'Total Spent',
                      vm.totalSpent.formatCompact(),
                      colorScheme.primary,
                    ),
                    _buildKPIItem(
                      context,
                      'Count',
                      '${vm.transactionCount}',
                      colorScheme.onSurface,
                    ),
                    _buildKPIItem(
                      context,
                      'Avg/Day',
                      vm.dailyAverage.formatCompact(),
                      colorScheme.secondary,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildKPIItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
