import 'dart:async';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/view_models/reports_view_model.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/core/utils/top_k.dart';
import 'package:flutter/foundation.dart';
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

/// Top-level isolate worker aggregating heavy (>2,000 items) range metrics off the UI thread.
Map<String, dynamic> _aggregateReportsIsolate(Map<String, dynamic> payload) {
  final List<int> amounts = payload['amounts'] as List<int>;
  final List<int> epochDays = payload['epochDays'] as List<int>;
  final List<int> monthKeys = payload['monthKeys'] as List<int>;
  final List<String> categories = payload['categories'] as List<String>;
  final int kEpochWeekday = payload['kEpochWeekday'] as int;

  int totalSpent = 0;
  final Map<String, int> catPaise = {};
  final Map<int, int> activeDayTotals = {};
  final Map<int, int> activeWeekTotals = {};
  final Map<int, int> activeMonthTotals = {};

  for (int i = 0; i < amounts.length; i++) {
    final amount = amounts[i];
    final epochDay = epochDays[i];
    final monthKey = monthKeys[i];
    final category = categories[i];

    totalSpent += amount;
    catPaise[category] = (catPaise[category] ?? 0) + amount;
    activeDayTotals[epochDay] = (activeDayTotals[epochDay] ?? 0) + amount;

    final weekEpoch = epochDay - ((epochDay + kEpochWeekday) % 7);
    activeWeekTotals[weekEpoch] = (activeWeekTotals[weekEpoch] ?? 0) + amount;
    activeMonthTotals[monthKey] = (activeMonthTotals[monthKey] ?? 0) + amount;
  }

  return {
    'totalSpent': totalSpent,
    'catPaise': catPaise,
    'activeDayTotals': activeDayTotals,
    'activeWeekTotals': activeWeekTotals,
    'activeMonthTotals': activeMonthTotals,
  };
}

class ReportsProvider extends ChangeNotifier {
  final ReportsDataService _service;

  String _activeWorkspaceId = AppStateBox.activeWorkspaceId;
  List<Expense> _rangeExpenses = [];
  ReportsViewModel? _viewModel;
  ReportsRangePreset _activePreset = ReportsRangePreset.thisMonth;
  late DateTimeRange _activeRange;
  String? _paymentMethod;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;
  int _lastKnownDataVersion = -1;
  int _buildGen = 0;

  ReportsProvider({required ReportsDataService service}) : _service = service {
    _activeRange = _activePreset.toRange(DateTime.now());
    _service.setActiveWorkspace(_activeWorkspaceId);
  }

  String _normWs(String? wsId) =>
      (wsId == null || wsId.isEmpty) ? AppConstants.kDefaultWorkspaceId : wsId;

  String get activeWorkspaceId => _activeWorkspaceId;
  List<Expense> get rangeExpenses => _rangeExpenses;
  ReportsViewModel? get viewModel => _viewModel;
  ReportsRangePreset get activePreset => _activePreset;
  DateTimeRange get activeRange => _activeRange;
  String? get paymentMethod => _paymentMethod;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ReportsDataService get service => _service;

  /// Switches the active report scope cleanly in O(1) to [workspaceId] and rebuilds metrics.
  void setActiveWorkspace(String workspaceId) {
    final norm = _normWs(workspaceId);
    if (_activeWorkspaceId == norm) return;
    _activeWorkspaceId = norm;
    _service.setActiveWorkspace(norm);
    _compute();
  }

  void initialize(List<Expense> allExpenses, {String? activeWorkspaceId}) {
    if (activeWorkspaceId != null && activeWorkspaceId.isNotEmpty) {
      _activeWorkspaceId = _normWs(activeWorkspaceId);
    }
    _service.setActiveWorkspace(_activeWorkspaceId);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final gen = ++_buildGen;
    _service
        .rebuild(allExpenses)
        .then((_) {
          if (gen != _buildGen) return;
          _activeRange = _activePreset.toRange(DateTime.now());
          _scheduleOrBuildViewModel(gen);
        })
        .catchError((e) {
          if (gen != _buildGen) return;
          _errorMessage = AppErrorTranslator.translate(e).title;
          _isLoading = false;
          notifyListeners();
        });
  }

  void onExpensesUpdated(ExpensesProvider expProvider) {
    final wsChanged = expProvider.activeWorkspaceId != _activeWorkspaceId;
    if (wsChanged) {
      _activeWorkspaceId = _normWs(expProvider.activeWorkspaceId);
      _service.setActiveWorkspace(_activeWorkspaceId);
    }
    if (wsChanged || expProvider.dataVersion != _lastKnownDataVersion) {
      _lastKnownDataVersion = expProvider.dataVersion;

      _debounce?.cancel();
      final gen = ++_buildGen;
      _debounce = Timer(const Duration(milliseconds: 30), () {
        if (gen != _buildGen) return;
        _scheduleOrBuildViewModel(gen);
      });
    }
  }

  void setRange(DateTimeRange range, ReportsRangePreset preset) {
    _activeRange = range;
    _activePreset = preset;
    _compute();
  }

  void setPreset(ReportsRangePreset preset) {
    if (preset == ReportsRangePreset.custom) return;
    final range = preset.toRange(DateTime.now());
    _activeRange = DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
    );
    _activePreset = preset;
    _compute();
  }

  void setPaymentMethod(String? method) {
    if (_paymentMethod != method) {
      _paymentMethod = method;
      _compute();
    }
  }

  void _compute() {
    final gen = ++_buildGen;
    _scheduleOrBuildViewModel(gen);
  }

  void clearRange() {
    _rangeExpenses = [];
    _viewModel = null;
    notifyListeners();
  }

  void _scheduleOrBuildViewModel(int gen) {
    try {
      final partition = _service.partitionFor(_activeWorkspaceId);
      final startEpoch = partition.toEpochDay(_activeRange.start);
      final endEpoch = partition.toEpochDay(_activeRange.end);

      final lo = partition.lowerBound(startEpoch);
      final hi = partition.upperBound(endEpoch);

      var sliced = partition.slice(lo, hi);
      if (_paymentMethod != null && _paymentMethod!.isNotEmpty) {
        final targetPm = _paymentMethod!.toLowerCase();
        sliced = sliced
            .where((e) => e.paymentMethod.toLowerCase() == targetPm)
            .toList();
      }
      _rangeExpenses = sliced;

      // For very large datasets in range (>= 2000), offload aggregation off UI isolate
      if (sliced.length >= 2000) {
        _isLoading = true;
        notifyListeners();
        final amounts = List<int>.filled(sliced.length, 0);
        final epochDays = List<int>.filled(sliced.length, 0);
        final monthKeys = List<int>.filled(sliced.length, 0);
        final categories = List<String>.filled(sliced.length, '');
        for (int i = 0; i < sliced.length; i++) {
          final e = sliced[i];
          amounts[i] = e.amount;
          epochDays[i] = partition.toEpochDay(e.date);
          monthKeys[i] = e.date.year * 100 + e.date.month;
          categories[i] = e.category;
        }

        unawaited(
          compute(_aggregateReportsIsolate, {
            'amounts': amounts,
            'epochDays': epochDays,
            'monthKeys': monthKeys,
            'categories': categories,
            'kEpochWeekday': WorkspaceReportPartition.kEpochWeekday,
          }).then((agg) {
            if (gen != _buildGen) return;
            _finalizeViewModel(
              partition: partition,
              startEpoch: startEpoch,
              endEpoch: endEpoch,
              totalSpent: agg['totalSpent'] as int,
              catPaise: Map<String, int>.from(agg['catPaise'] as Map),
              activeDayTotals: Map<int, int>.from(agg['activeDayTotals'] as Map),
              activeWeekTotals:
                  Map<int, int>.from(agg['activeWeekTotals'] as Map),
              activeMonthTotals:
                  Map<int, int>.from(agg['activeMonthTotals'] as Map),
            );
            _errorMessage = null;
            _isLoading = false;
            notifyListeners();
          }).catchError((e) {
            if (gen != _buildGen) return;
            _errorMessage = AppErrorTranslator.translate(e).title;
            _isLoading = false;
            notifyListeners();
          }),
        );
        return;
      }

      // Synchronous O(N) fast path for < 2,000 items
      int totalSpent = 0;
      final Map<String, int> catPaise = {};
      final Map<int, int> activeDayTotals = {};
      final Map<int, int> activeWeekTotals = {};
      final Map<int, int> activeMonthTotals = {};

      for (final e in _rangeExpenses) {
        final amount = e.amount;
        totalSpent += amount;
        catPaise[e.category] = (catPaise[e.category] ?? 0) + amount;

        final epochDay = partition.toEpochDay(e.date);
        final weekEpoch = partition.mondayEpoch(epochDay);
        final monthKey = e.date.year * 100 + e.date.month;

        activeDayTotals[epochDay] = (activeDayTotals[epochDay] ?? 0) + amount;
        activeWeekTotals[weekEpoch] = (activeWeekTotals[weekEpoch] ?? 0) + amount;
        activeMonthTotals[monthKey] = (activeMonthTotals[monthKey] ?? 0) + amount;
      }

      _finalizeViewModel(
        partition: partition,
        startEpoch: startEpoch,
        endEpoch: endEpoch,
        totalSpent: totalSpent,
        catPaise: catPaise,
        activeDayTotals: activeDayTotals,
        activeWeekTotals: activeWeekTotals,
        activeMonthTotals: activeMonthTotals,
      );
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = AppErrorTranslator.translate(e).title;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _finalizeViewModel({
    required WorkspaceReportPartition partition,
    required int startEpoch,
    required int endEpoch,
    required int totalSpent,
    required Map<String, int> catPaise,
    required Map<int, int> activeDayTotals,
    required Map<int, int> activeWeekTotals,
    required Map<int, int> activeMonthTotals,
  }) {
    final int transactionCount = _rangeExpenses.length;
    final int avgPerExpense = transactionCount == 0
        ? 0
        : (totalSpent / transactionCount).round();

    final List<MapEntry<String, int>> sortedCategories =
        catPaise.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final String topCategory =
        sortedCategories.isNotEmpty ? sortedCategories.first.key : 'No data';
    final int topCategoryAmount =
        sortedCategories.isNotEmpty ? sortedCategories.first.value : 0;

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

    final rangeDays =
        _activeRange.end.difference(_activeRange.start).inDays + 1;
    final String granularity;
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
        final val = activeDayTotals[day] ?? 0;
        final date = partition.epochToDateTime(day);
        barPoints.add(
          ChartBarPoint(
            xLabel: day - startEpoch,
            value: val,
            displayLabel: DateFormat('d MMM').format(date),
          ),
        );
      }
    } else if (granularity == 'weekly') {
      final startWeek = partition.mondayEpoch(startEpoch);
      final endWeek = partition.mondayEpoch(endEpoch);
      int index = 0;
      for (int week = startWeek; week <= endWeek; week += 7) {
        final val = activeWeekTotals[week] ?? 0;
        final date = partition.epochToDateTime(week);
        barPoints.add(
          ChartBarPoint(
            xLabel: index++,
            value: val,
            displayLabel: DateFormat('MMM d').format(date),
          ),
        );
      }
    } else if (granularity == 'monthly') {
      int curYear = _activeRange.start.year;
      int curMonth = _activeRange.start.month;
      final endKey = _activeRange.end.year * 100 + _activeRange.end.month;
      int index = 0;
      while (curYear * 100 + curMonth <= endKey) {
        final monthKey = curYear * 100 + curMonth;
        final val = activeMonthTotals[monthKey] ?? 0;
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
      int curYear = _activeRange.start.year;
      int curQuarter = ((_activeRange.start.month - 1) ~/ 3) + 1;
      final endQuarter = ((_activeRange.end.month - 1) ~/ 3) + 1;
      final endQKey = _activeRange.end.year * 10 + endQuarter;
      int index = 0;
      while (curYear * 10 + curQuarter <= endQKey) {
        int sum = 0;
        for (int m = (curQuarter - 1) * 3 + 1; m <= curQuarter * 3; m++) {
          sum += activeMonthTotals[curYear * 100 + m] ?? 0;
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
    final double maxBarVal =
        sortedBarValues.isNotEmpty ? sortedBarValues.last.toDouble() : 0.0;
    final useLogScale = median > 0 && (maxBarVal / median) > 5.0;

    // Heap Top-K O(N log 20)
    final topExpenses = getTopK<Expense>(
      _rangeExpenses,
      20,
      (a, b) => a.amount.compareTo(b.amount),
    );

    final Map<int, int> rangeHeatmap = activeDayTotals;
    final currentYear = DateTime.now().year;
    final yearMaxDailySpend = partition.yearMaxSpend[currentYear] ??
        (activeDayTotals.isEmpty
            ? 0
            : activeDayTotals.values.reduce((a, b) => a > b ? a : b));

    int weekdayTotal = 0;
    int weekdayCount = 0;
    int weekendTotal = 0;
    int weekendCount = 0;

    rangeHeatmap.forEach((epochDay, amount) {
      final date = partition.epochToDateTime(epochDay);
      if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        weekendTotal += amount;
        weekendCount++;
      } else {
        weekdayTotal += amount;
        weekdayCount++;
      }
    });

    final weekdayAvg = weekdayCount > 0 ? (weekdayTotal ~/ weekdayCount) : 0;
    final weekendAvg = weekendCount > 0 ? (weekendTotal ~/ weekendCount) : 0;

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
      dailySpending: barPoints,
      categoryDistribution: slices,
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
