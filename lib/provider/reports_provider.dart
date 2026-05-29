import 'dart:async';
import 'package:expense/models/expense.dart';
import 'package:expense/models/reports_view_model.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/core/top_k.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ReportsRangePreset { thisWeek, thisMonth, last30Days, thisYear, custom }

extension ReportsRangePresetExtension on ReportsRangePreset {
  String get label => switch (this) {
    ReportsRangePreset.thisWeek => 'This week',
    ReportsRangePreset.thisMonth => 'This month',
    ReportsRangePreset.last30Days => 'Last 30 days',
    ReportsRangePreset.thisYear => 'This year',
    ReportsRangePreset.custom => 'Custom',
  };

  DateTimeRange toRange(DateTime now) {
    DateTime startOfWeekMonday(DateTime d) {
      final x = DateTime(d.year, d.month, d.day);
      return x.subtract(Duration(days: x.weekday - 1));
    }

    switch (this) {
      case ReportsRangePreset.thisWeek:
        final start = startOfWeekMonday(now);
        final end = start.add(const Duration(days: 6));
        return DateTimeRange(start: start, end: end);
      case ReportsRangePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = (now.month == 12)
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final end = nextMonth.subtract(const Duration(days: 1));
        return DateTimeRange(start: start, end: end);
      case ReportsRangePreset.last30Days:
        final end = DateTime(now.year, now.month, now.day);
        final start = end.subtract(const Duration(days: 29));
        return DateTimeRange(start: start, end: end);
      case ReportsRangePreset.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case ReportsRangePreset.custom:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    }
  }
}

class ReportsProvider extends ChangeNotifier {
  final ReportsDataService _service;

  List<Expense> _rangeExpenses = [];
  ReportsViewModel? _viewModel;
  ReportsRangePreset _activePreset = ReportsRangePreset.thisMonth;
  late DateTimeRange _activeRange;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;
  int _lastKnownDataVersion = -1;
  int _buildGen = 0;

  ReportsProvider({required ReportsDataService service}) : _service = service {
    _activeRange = _activePreset.toRange(DateTime.now());
  }

  List<Expense> get rangeExpenses => _rangeExpenses;
  ReportsViewModel? get viewModel => _viewModel;
  ReportsRangePreset get activePreset => _activePreset;
  DateTimeRange get activeRange => _activeRange;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ReportsDataService get service => _service;

  void initialize(List<Expense> allExpenses) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final gen = ++_buildGen;
    _service
        .rebuild(allExpenses)
        .then((_) {
          if (gen != _buildGen) return;
          _activeRange = _activePreset.toRange(DateTime.now());
          _buildViewModel();
          _errorMessage = null;
          _isLoading = false;
          notifyListeners();
        })
        .catchError((e) {
          if (gen != _buildGen) return;
          _errorMessage = e.toString();
          _isLoading = false;
          notifyListeners();
        });
  }

  void onExpensesUpdated(ExpensesProvider expProvider) {
    if (expProvider.dataVersion != _lastKnownDataVersion) {
      _lastKnownDataVersion = expProvider.dataVersion;

      _debounce?.cancel();
      final gen = ++_buildGen;
      _debounce = Timer(const Duration(milliseconds: 50), () {
        if (gen != _buildGen) return;
        try {
          _buildViewModel();
          _errorMessage = null;
        } catch (e) {
          _errorMessage = e.toString();
        } finally {
          notifyListeners();
        }
      });
    }
  }

  void setRange(DateTimeRange range, ReportsRangePreset preset) {
    _activeRange = range;
    _activePreset = preset;
    _compute();
  }

  void setPreset(ReportsRangePreset preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case ReportsRangePreset.thisWeek:
        start = now.subtract(Duration(days: now.weekday - 1));
        break;
      case ReportsRangePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case ReportsRangePreset.last30Days:
        start = now.subtract(const Duration(days: 30));
        break;
      case ReportsRangePreset.thisYear:
        start = DateTime(now.year, 1, 1);
        break;
      case ReportsRangePreset.custom:
        return;
    }

    _activeRange = DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day, 23, 59, 59),
    );
    _activePreset = preset;
    _compute();
  }

  void _compute() {
    ++_buildGen;
    _buildViewModel();
    notifyListeners();
  }

  void clearRange() {
    _rangeExpenses = [];
    _viewModel = null;
    notifyListeners();
  }

  void _buildViewModel() {
    final startEpoch = _service.toEpochDay(_activeRange.start);
    final endEpoch = _service.toEpochDay(_activeRange.end);

    final lo = _service.lowerBound(startEpoch);
    final hi = _service.upperBound(endEpoch);

    _rangeExpenses = _service.slice(lo, hi);

    // Compute KPIs
    int totalSpent = 0;
    int transactionCount = _rangeExpenses.length;

    // Category totals using integer paise math
    final Map<String, int> catPaise = {};
    for (final e in _rangeExpenses) {
      final amount = e.amount;
      totalSpent += amount;
      catPaise[e.category] = (catPaise[e.category] ?? 0) + amount;
    }

    final int avgPerExpense = transactionCount == 0
        ? 0
        : (totalSpent / transactionCount).round();

    // Top category
    String topCategory = 'No data';
    int topCategoryAmount = 0;
    if (catPaise.isNotEmpty) {
      final sortedCats = catPaise.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCategory = sortedCats.first.key;
      topCategoryAmount = sortedCats.first.value;
    }

    // Pie slices
    final List<MapEntry<String, int>> sortedCategories =
        catPaise.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final int k = sortedCategories.length;
    final List<ChartPieSlice> slices = [];

    if (k <= 10) {
      for (int i = 0; i < k; i++) {
        final entry = sortedCategories[i];
        final pct = totalSpent <= 0 ? 0.0 : (entry.value / totalSpent) * 100;
        slices.add(
          ChartPieSlice(
            category: entry.key,
            amount: entry.value,
            percentage: pct,
            colorIndex: i,
          ),
        );
      }
    } else {
      final top10 = sortedCategories.take(10).toList();
      final otherSum = sortedCategories
          .skip(10)
          .fold<int>(0, (sum, entry) => sum + entry.value);

      for (int i = 0; i < 10; i++) {
        final entry = top10[i];
        final pct = totalSpent <= 0 ? 0.0 : (entry.value / totalSpent) * 100;
        slices.add(
          ChartPieSlice(
            category: entry.key,
            amount: entry.value,
            percentage: pct,
            colorIndex: i,
          ),
        );
      }

      if (otherSum > 0) {
        final otherPct = totalSpent <= 0 ? 0.0 : (otherSum / totalSpent) * 100;
        slices.add(
          ChartPieSlice(
            category: 'Other (${k - 10} categories)',
            amount: otherSum,
            percentage: otherPct,
            colorIndex: 10,
          ),
        );
      }
    }

    // Granularity & Bar Points
    final rangeDays =
        _activeRange.end.difference(_activeRange.start).inDays + 1;
    String granularity;
    if (rangeDays <= 31) {
      granularity = 'daily';
    } else if (rangeDays <= 182) {
      granularity = 'weekly';
    } else if (rangeDays <= 730) {
      granularity = 'monthly';
    } else {
      granularity = 'quarterly';
    }

    final List<ChartBarPoint> barPoints = [];

    if (granularity == 'daily') {
      for (int day = startEpoch; day <= endEpoch; day++) {
        final val = _service.dayTotals[day] ?? 0;
        final date = _service.epochToDateTime(day);
        barPoints.add(
          ChartBarPoint(
            xLabel: day - startEpoch,
            value: val,
            displayLabel: DateFormat('d MMM').format(date),
          ),
        );
      }
    } else if (granularity == 'weekly') {
      final startWeek = _service.mondayEpoch(startEpoch);
      final endWeek = _service.mondayEpoch(endEpoch);
      int index = 0;
      for (int week = startWeek; week <= endWeek; week += 7) {
        final val = _service.weekTotals[week] ?? 0;
        final date = _service.epochToDateTime(week);
        barPoints.add(
          ChartBarPoint(
            xLabel: index++,
            value: val,
            displayLabel: DateFormat('MMM d').format(date),
          ),
        );
      }
    } else if (granularity == 'monthly') {
      final startYear = _activeRange.start.year;
      final startMonth = _activeRange.start.month;
      final endYear = _activeRange.end.year;
      final endMonth = _activeRange.end.month;

      int curYear = startYear;
      int curMonth = startMonth;
      int index = 0;
      while (curYear * 100 + curMonth <= endYear * 100 + endMonth) {
        final monthKey = curYear * 100 + curMonth;
        final val = _service.monthTotals[monthKey] ?? 0;
        final date = DateTime(curYear, curMonth, 1);
        barPoints.add(
          ChartBarPoint(
            xLabel: index++,
            value: val,
            displayLabel: DateFormat('MMM yy').format(date),
          ),
        );

        curMonth++;
        if (curMonth > 12) {
          curMonth = 1;
          curYear++;
        }
      }
    } else {
      final startYear = _activeRange.start.year;
      final startMonth = _activeRange.start.month;
      final endYear = _activeRange.end.year;
      final endMonth = _activeRange.end.month;

      int startQuarter = ((startMonth - 1) ~/ 3) + 1;
      int endQuarter = ((endMonth - 1) ~/ 3) + 1;

      int curYear = startYear;
      int curQuarter = startQuarter;
      int index = 0;
      while (curYear * 10 + curQuarter <= endYear * 10 + endQuarter) {
        int sum = 0;
        for (int m = (curQuarter - 1) * 3 + 1; m <= curQuarter * 3; m++) {
          sum += _service.monthTotals[curYear * 100 + m] ?? 0;
        }
        barPoints.add(
          ChartBarPoint(
            xLabel: index++,
            value: sum,
            displayLabel: 'Q$curQuarter ${curYear.toString().substring(2)}',
          ),
        );

        curQuarter++;
        if (curQuarter > 4) {
          curQuarter = 1;
          curYear++;
        }
      }
    }

    // Log scale logic
    final sortedBarValues = barPoints.map((p) => p.value).toList()..sort();
    double median = 0.0;
    if (sortedBarValues.isNotEmpty) {
      int middle = sortedBarValues.length ~/ 2;
      if (sortedBarValues.length % 2 == 1) {
        median = sortedBarValues[middle].toDouble();
      } else {
        median = (sortedBarValues[middle - 1] + sortedBarValues[middle]) / 2.0;
      }
    }
    final double maxBarVal = sortedBarValues.isNotEmpty
        ? sortedBarValues.last.toDouble()
        : 0.0;
    final useLogScale = median > 0 && (maxBarVal / median) > 5.0;

    // Top 20 expenses using Heap Top-K
    final topExpenses = getTopK<Expense>(
      _rangeExpenses,
      20,
      (a, b) => a.amount.compareTo(b.amount),
    );

    // Heatmap cache for range months
    final Map<int, int> rangeHeatmap = {};
    int startYearMonth =
        _activeRange.start.year * 100 + _activeRange.start.month;
    int endYearMonth = _activeRange.end.year * 100 + _activeRange.end.month;

    _service.heatmapCache.forEach((monthKey, dayTotals) {
      if (monthKey >= startYearMonth && monthKey <= endYearMonth) {
        rangeHeatmap.addAll(dayTotals);
      }
    });

    final currentYear = DateTime.now().year;
    final yearMaxDailySpend = _service.yearMaxSpend[currentYear] ?? 0;

    // 5-3 · Weekend vs weekday behavioural pattern
    int weekdayTotal = 0;
    int weekdayCount = 0;
    int weekendTotal = 0;
    int weekendCount = 0;

    rangeHeatmap.forEach((epochDay, amount) {
      final date = _service.epochToDateTime(epochDay);
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        weekendTotal += amount;
        weekendCount++;
      } else {
        weekdayTotal += amount;
        weekdayCount++;
      }
    });

    final weekdayAvg = weekdayCount > 0 ? (weekdayTotal ~/ weekdayCount) : 0;
    final weekendAvg = weekendCount > 0 ? (weekendTotal ~/ weekendCount) : 0;

    // Final ViewModel construction
    _viewModel = ReportsViewModel(
      totalSpent: totalSpent,
      transactionCount: transactionCount,
      avgPerExpense: avgPerExpense,
      topCategory: topCategory,
      topCategoryAmount: topCategoryAmount,
      barPoints: barPoints,
      pieSlices: slices,
      topExpenses: topExpenses,
      rangeHeatmap: rangeHeatmap,
      activeRange: _activeRange,
      granularity: granularity,
      useLogScale: useLogScale,
      dailyAverage: rangeDays > 0 ? (totalSpent ~/ rangeDays) : 0,
      dailySpending: barPoints, // Alias for current bar points
      categoryDistribution: slices, // Alias for slices
      maxDailySpent: rangeHeatmap.isEmpty
          ? 0
          : rangeHeatmap.values.reduce((a, b) => a > b ? a : b),
      topCategories: slices.take(5).toList(),
      yearMaxDailySpend: yearMaxDailySpend,
      weekdayAvg: weekdayAvg,
      weekendAvg: weekendAvg,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
