import 'dart:collection';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/models/expense.dart';

/// Isolated per-workspace OLAP aggregation cube storing chronologically sorted
/// expenses and pre-aggregated daily, weekly, monthly, category, and heatmap indices.
class WorkspaceReportPartition {
  static final DateTime kEpoch = DateTime(2020, 1, 1);
  static const int kEpochWeekday = 2; // Wednesday (3 - 1)
  static final DateTime _utcEpoch = DateTime.utc(2020, 1, 1);

  List<Expense> _sortedAsc = [];
  List<int> _epochDays = [];
  final Map<int, int> _dayTotals = {};
  final Map<int, int> _weekTotals = {};
  final Map<int, int> _monthTotals = {};
  final Map<String, int> _allCatTotals = {};
  final Map<int, Map<String, int>> _monthCatTotals = {};
  final Map<int, Map<int, int>> _heatmapCache = {};
  final Map<int, int> _yearMaxSpend = {};

  // Fast LUT cache: YYYYMMDD -> epochDay (zero DateTime allocations on hot paths)
  final Map<int, int> _dateKeyToEpochCache = {};
  final Set<int> _dirtyYearMax = {};
  bool _globalMaxDirty = false;
  int _globalMaxDailySpend = 0;

  DateTime? _firstExpenseDate;
  DateTime? _lastExpenseDate;

  int? _cachedHeatmapYear;
  Map<DateTime, int>? _cachedHeatmapData;
  int _lastVersion = 0;
  int _cachedVersion = -1;

  List<Expense> get sortedAsc => _sortedAsc;
  List<int> get epochDays => _epochDays;
  Map<int, int> get dayTotals => _dayTotals;
  Map<int, int> get weekTotals => _weekTotals;
  Map<int, int> get monthTotals => _monthTotals;
  Map<int, Map<String, int>> get monthCatTotals => _monthCatTotals;
  Map<String, int> get allCatTotals => _allCatTotals;
  DateTime? get firstExpenseDate => _firstExpenseDate;
  DateTime? get lastExpenseDate => _lastExpenseDate;
  Map<int, Map<int, int>> get heatmapCache => _heatmapCache;
  Map<int, Map<int, int>> get monthlyCache => _heatmapCache;

  int get globalMaxDailySpend {
    if (_globalMaxDirty) {
      int maxVal = 0;
      for (final dayTotal in _dayTotals.values) {
        if (dayTotal > maxVal) maxVal = dayTotal;
      }
      _globalMaxDailySpend = maxVal;
      _globalMaxDirty = false;
    }
    return _globalMaxDailySpend;
  }

  Map<int, int> get yearMaxSpend {
    if (_dirtyYearMax.isNotEmpty) {
      for (final targetYear in _dirtyYearMax.toList()) {
        int yearMax = 0;
        _dayTotals.forEach((dayKey, dailyTotal) {
          final date = epochToDateTime(dayKey);
          if (date.year == targetYear && dailyTotal > yearMax) {
            yearMax = dailyTotal;
          }
        });
        if (yearMax > 0) {
          _yearMaxSpend[targetYear] = yearMax;
        } else {
          _yearMaxSpend.remove(targetYear);
        }
      }
      _dirtyYearMax.clear();
    }
    return _yearMaxSpend;
  }

  void updateVersion() => _lastVersion++;

  int toEpochDay(DateTime date) {
    final dk = date.year * 10000 + date.month * 100 + date.day;
    final cached = _dateKeyToEpochCache[dk];
    if (cached != null) return cached;

    final utcMidnight = DateTime.utc(date.year, date.month, date.day);
    final ep = utcMidnight.difference(_utcEpoch).inDays;
    // Bound cache size cleanly for long-running sessions
    if (_dateKeyToEpochCache.length > 4096) {
      _dateKeyToEpochCache.clear();
    }
    _dateKeyToEpochCache[dk] = ep;
    return ep;
  }

  DateTime epochToDateTime(int epochDay) {
    final utcDate = _utcEpoch.add(Duration(days: epochDay));
    return DateTime(utcDate.year, utcDate.month, utcDate.day);
  }

  int mondayEpoch(int epochDay) {
    final weekday = (epochDay + kEpochWeekday) % 7;
    return epochDay - weekday;
  }

  int lowerBound(int startEpoch) {
    int lo = 0;
    int hi = _epochDays.length;
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      if (_epochDays[mid] >= startEpoch) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  int upperBound(int endEpoch) {
    int lo = 0;
    int hi = _epochDays.length;
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      if (_epochDays[mid] > endEpoch) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  List<Expense> slice(int lo, int hi) {
    if (lo < 0 || hi > _sortedAsc.length || lo > hi) return const [];
    return _sortedAsc.sublist(lo, hi);
  }

  int totalForRange(DateTime start, DateTime end) {
    int total = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    final DateTime targetEnd = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(targetEnd)) {
      if (current.day == 1) {
        final lastDayOfMonth = DateTime(current.year, current.month + 1, 0);
        if (!lastDayOfMonth.isAfter(targetEnd)) {
          final monthKey = current.year * 100 + current.month;
          total += _monthTotals[monthKey] ?? 0;
          current = DateTime(current.year, current.month + 1, 1);
          continue;
        }
      }
      final epochDay = toEpochDay(current);
      total += _dayTotals[epochDay] ?? 0;
      current = current.add(const Duration(days: 1));
    }
    return total;
  }

  Map<DateTime, int> generateHeatmapData(int year) {
    if (_cachedHeatmapYear == year &&
        _cachedVersion == _lastVersion &&
        _cachedHeatmapData != null) {
      return _cachedHeatmapData!;
    }

    final Map<DateTime, int> data = {};
    final startOfYear = toEpochDay(DateTime(year, 1, 1));
    final endOfYear = toEpochDay(DateTime(year, 12, 31));

    for (int day = startOfYear; day <= endOfYear; day++) {
      final total = _dayTotals[day];
      if (total != null && total > 0) {
        data[epochToDateTime(day)] = total;
      }
    }

    _cachedHeatmapYear = year;
    _cachedHeatmapData = data;
    _cachedVersion = _lastVersion;
    return data;
  }

  void updateForAdd(Expense e) {
    final epochDay = toEpochDay(e.date);

    // O(1) amortized append when inserting chronologically latest record
    final int insertIdx;
    if (_epochDays.isEmpty || epochDay >= _epochDays.last) {
      insertIdx = _epochDays.length;
    } else {
      insertIdx = upperBound(epochDay);
    }

    _epochDays.insert(insertIdx, epochDay);
    _sortedAsc.insert(insertIdx, e);

    final newDayTotal = (_dayTotals[epochDay] ?? 0) + e.amount;
    _dayTotals[epochDay] = newDayTotal;

    final weekEpoch = mondayEpoch(epochDay);
    _weekTotals[weekEpoch] = (_weekTotals[weekEpoch] ?? 0) + e.amount;

    final monthKey = e.date.year * 100 + e.date.month;
    _monthTotals[monthKey] = (_monthTotals[monthKey] ?? 0) + e.amount;

    _allCatTotals[e.category] = (_allCatTotals[e.category] ?? 0) + e.amount;

    _monthCatTotals.putIfAbsent(monthKey, () => {});
    _monthCatTotals[monthKey]![e.category] =
        (_monthCatTotals[monthKey]![e.category] ?? 0) + e.amount;

    if (!_globalMaxDirty && newDayTotal > _globalMaxDailySpend) {
      _globalMaxDailySpend = newDayTotal;
    }
    if (!_dirtyYearMax.contains(e.date.year) &&
        newDayTotal > (_yearMaxSpend[e.date.year] ?? 0)) {
      _yearMaxSpend[e.date.year] = newDayTotal;
    }

    _rebuildHeatmapForMonth(monthKey);
    updateVersion();

    if (_sortedAsc.isNotEmpty) {
      _firstExpenseDate = _sortedAsc.first.date;
      _lastExpenseDate = _sortedAsc.last.date;
    }
  }

  void updateForDelete(Expense e) {
    final epochDay = toEpochDay(e.date);
    final startIdx = lowerBound(epochDay);
    final endIdx = upperBound(epochDay);

    int targetIdx = -1;
    for (int i = startIdx; i < endIdx; i++) {
      if (_sortedAsc[i].key == e.key && identical(_sortedAsc[i], e)) {
        targetIdx = i;
        break;
      }
    }
    if (targetIdx == -1) {
      for (int i = startIdx; i < endIdx; i++) {
        if (_sortedAsc[i].key == e.key) {
          targetIdx = i;
          break;
        }
      }
    }
    if (targetIdx == -1) {
      for (int i = 0; i < _sortedAsc.length; i++) {
        if ((e.key != null && _sortedAsc[i].key == e.key) ||
            identical(_sortedAsc[i], e)) {
          targetIdx = i;
          break;
        }
      }
    }

    if (targetIdx == -1) return;

    _sortedAsc.removeAt(targetIdx);
    _epochDays.removeAt(targetIdx);

    final prevDayTotal = _dayTotals[epochDay] ?? 0;
    final dayVal = prevDayTotal - e.amount;
    if (dayVal <= 0) {
      _dayTotals.remove(epochDay);
    } else {
      _dayTotals[epochDay] = dayVal;
    }

    final weekEpoch = mondayEpoch(epochDay);
    final weekVal = (_weekTotals[weekEpoch] ?? 0) - e.amount;
    if (weekVal <= 0) {
      _weekTotals.remove(weekEpoch);
    } else {
      _weekTotals[weekEpoch] = weekVal;
    }

    final monthKey = e.date.year * 100 + e.date.month;
    final monthVal = (_monthTotals[monthKey] ?? 0) - e.amount;
    if (monthVal <= 0) {
      _monthTotals.remove(monthKey);
    } else {
      _monthTotals[monthKey] = monthVal;
    }

    final catVal = (_allCatTotals[e.category] ?? 0) - e.amount;
    if (catVal <= 0) {
      _allCatTotals.remove(e.category);
    } else {
      _allCatTotals[e.category] = catVal;
    }

    if (_monthCatTotals.containsKey(monthKey)) {
      final mCatVal =
          (_monthCatTotals[monthKey]![e.category] ?? 0) - e.amount;
      if (mCatVal <= 0) {
        _monthCatTotals[monthKey]!.remove(e.category);
        if (_monthCatTotals[monthKey]!.isEmpty) {
          _monthCatTotals.remove(monthKey);
        }
      } else {
        _monthCatTotals[monthKey]![e.category] = mCatVal;
      }
    }

    // Lazy dirty marking instead of O(D) full-history scan on every delete
    if (!_globalMaxDirty && prevDayTotal >= _globalMaxDailySpend) {
      _globalMaxDirty = true;
    }
    final curYearMax = _yearMaxSpend[e.date.year] ?? 0;
    if (prevDayTotal >= curYearMax) {
      _dirtyYearMax.add(e.date.year);
    }

    _rebuildHeatmapForMonth(monthKey);
    updateVersion();

    if (_sortedAsc.isNotEmpty) {
      _firstExpenseDate = _sortedAsc.first.date;
      _lastExpenseDate = _sortedAsc.last.date;
    } else {
      _firstExpenseDate = null;
      _lastExpenseDate = null;
    }
  }

  void _rebuildHeatmapForMonth(int monthKey) {
    _heatmapCache.remove(monthKey);
    final monthMap = <int, int>{};
    final year = monthKey ~/ 100;
    final month = monthKey % 100;

    final startEpoch = toEpochDay(DateTime(year, month, 1));
    final endEpoch = toEpochDay(DateTime(year, month + 1, 0));

    for (int day = startEpoch; day <= endEpoch; day++) {
      final total = _dayTotals[day];
      if (total != null) {
        monthMap[day] = total;
      }
    }

    if (monthMap.isNotEmpty) {
      _heatmapCache[monthKey] = monthMap;
    }
  }

  /// Rebuilds this isolated workspace partition cleanly. Uses an O(N) reverse pass
  /// when input is already sorted ascending/descending, avoiding O(N log N) TimSort.
  Future<void> rebuild(List<Expense> expenses) async {
    _dayTotals.clear();
    _weekTotals.clear();
    _monthTotals.clear();
    _allCatTotals.clear();
    _monthCatTotals.clear();
    _heatmapCache.clear();
    _yearMaxSpend.clear();
    _dirtyYearMax.clear();
    _globalMaxDirty = false;
    _globalMaxDailySpend = 0;

    if (expenses.isEmpty) {
      _sortedAsc = [];
      _epochDays = [];
      _firstExpenseDate = null;
      _lastExpenseDate = null;
      updateVersion();
      return;
    }

    // Detect pre-sorted descending or ascending sequence in linear pass
    bool isDescending = true;
    bool isAscending = true;
    for (int i = 0; i < expenses.length - 1; i++) {
      final cmp = expenses[i].date.compareTo(expenses[i + 1].date);
      if (cmp < 0) isDescending = false;
      if (cmp > 0) isAscending = false;
      if (!isDescending && !isAscending) break;
    }

    if (isAscending) {
      _sortedAsc = List<Expense>.from(expenses);
    } else if (isDescending) {
      _sortedAsc = List<Expense>.generate(
        expenses.length,
        (i) => expenses[expenses.length - 1 - i],
      );
    } else {
      _sortedAsc = List<Expense>.from(expenses)
        ..sort((a, b) => a.date.compareTo(b.date));
    }

    _epochDays = List<int>.filled(_sortedAsc.length, 0, growable: true);
    _firstExpenseDate = _sortedAsc.first.date;
    _lastExpenseDate = _sortedAsc.last.date;

    for (int i = 0; i < _sortedAsc.length; i++) {
      final e = _sortedAsc[i];
      final epochDay = toEpochDay(e.date);
      _epochDays[i] = epochDay;
      final amount = e.amount;

      _dayTotals[epochDay] = (_dayTotals[epochDay] ?? 0) + amount;

      final weekEpoch = mondayEpoch(epochDay);
      _weekTotals[weekEpoch] = (_weekTotals[weekEpoch] ?? 0) + amount;

      final monthKey = e.date.year * 100 + e.date.month;
      _monthTotals[monthKey] = (_monthTotals[monthKey] ?? 0) + amount;

      _allCatTotals[e.category] = (_allCatTotals[e.category] ?? 0) + amount;

      _monthCatTotals.putIfAbsent(monthKey, () => {});
      _monthCatTotals[monthKey]![e.category] =
          (_monthCatTotals[monthKey]![e.category] ?? 0) + amount;

      // Cooperatively yield on massive imports to maintain smooth UI frames on low-end devices
      if (i > 0 && i % 4000 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    for (final entry in _dayTotals.entries) {
      final epochDay = entry.key;
      final dailyTotal = entry.value;
      if (dailyTotal > _globalMaxDailySpend) {
        _globalMaxDailySpend = dailyTotal;
      }
      final date = epochToDateTime(epochDay);
      if (dailyTotal > (_yearMaxSpend[date.year] ?? 0)) {
        _yearMaxSpend[date.year] = dailyTotal;
      }
    }

    updateVersion();
  }
}

/// Partitioned OLAP Analytics Coordinator maintaining strict workspace isolation.
/// Workspace switching executes in O(1) by swapping the active partition cursor.
class ReportsDataService {
  static final DateTime kEpoch = WorkspaceReportPartition.kEpoch;
  static const int kEpochWeekday = WorkspaceReportPartition.kEpochWeekday;

  final Map<String, WorkspaceReportPartition> _partitions = {};
  String _activeWorkspaceId = AppConstants.kDefaultWorkspaceId;

  String _normWs(String? wsId) =>
      (wsId == null || wsId.isEmpty) ? AppConstants.kDefaultWorkspaceId : wsId;

  String get activeWorkspaceId => _activeWorkspaceId;

  WorkspaceReportPartition get _activePartition =>
      _partitions.putIfAbsent(_activeWorkspaceId, () => WorkspaceReportPartition());

  WorkspaceReportPartition partitionFor(String? workspaceId) {
    final norm = _normWs(workspaceId);
    return _partitions.putIfAbsent(norm, () => WorkspaceReportPartition());
  }

  UnmodifiableListView<String> get partitionIds =>
      UnmodifiableListView(_partitions.keys);

  /// Switches the active partition cursor in O(1).
  void setActiveWorkspace(String workspaceId) {
    final norm = _normWs(workspaceId);
    if (_activeWorkspaceId == norm) return;
    _activeWorkspaceId = norm;
    _partitions.putIfAbsent(norm, () => WorkspaceReportPartition());
  }

  void clearPartition(String workspaceId) {
    final norm = _normWs(workspaceId);
    _partitions.remove(norm);
    if (norm == _activeWorkspaceId) {
      _partitions[norm] = WorkspaceReportPartition();
    }
  }

  void clearAllPartitions() {
    _partitions.clear();
    _partitions[_activeWorkspaceId] = WorkspaceReportPartition();
  }

  // ---- Active-Workspace Scoped Delegations (Backwards-Compatible Surface) ----

  List<Expense> get sortedAsc => _activePartition.sortedAsc;
  List<int> get epochDays => _activePartition.epochDays;
  Map<int, int> get dayTotals => _activePartition.dayTotals;
  Map<int, int> get weekTotals => _activePartition.weekTotals;
  Map<int, int> get monthTotals => _activePartition.monthTotals;
  Map<int, Map<String, int>> get monthCatTotals => _activePartition.monthCatTotals;
  Map<String, int> get allCatTotals => _activePartition.allCatTotals;
  int get globalMaxDailySpend => _activePartition.globalMaxDailySpend;
  DateTime? get firstExpenseDate => _activePartition.firstExpenseDate;
  DateTime? get lastExpenseDate => _activePartition.lastExpenseDate;
  Map<int, Map<int, int>> get heatmapCache => _activePartition.heatmapCache;
  Map<int, Map<int, int>> get monthlyCache => _activePartition.monthlyCache;
  Map<int, int> get yearMaxSpend => _activePartition.yearMaxSpend;

  void updateVersion() => _activePartition.updateVersion();
  Map<DateTime, int> generateHeatmapData(int year) =>
      _activePartition.generateHeatmapData(year);
  int toEpochDay(DateTime date) => _activePartition.toEpochDay(date);
  DateTime epochToDateTime(int epochDay) =>
      _activePartition.epochToDateTime(epochDay);
  int mondayEpoch(int epochDay) => _activePartition.mondayEpoch(epochDay);
  int lowerBound(int startEpoch) => _activePartition.lowerBound(startEpoch);
  int upperBound(int endEpoch) => _activePartition.upperBound(endEpoch);
  List<Expense> slice(int lo, int hi) => _activePartition.slice(lo, hi);

  int totalForRange(DateTime start, DateTime end, {String? workspaceId}) {
    if (workspaceId != null && workspaceId.isNotEmpty) {
      return partitionFor(workspaceId).totalForRange(start, end);
    }
    return _activePartition.totalForRange(start, end);
  }

  void updateForAdd(Expense e) {
    partitionFor(e.workspaceId).updateForAdd(e);
  }

  void updateForDelete(Expense e) {
    partitionFor(e.workspaceId).updateForDelete(e);
  }

  /// Rebuilds all workspace partitions cleanly from [allExpenses] while keeping
  /// each workspace completely isolated from sibling workspaces.
  Future<void> rebuild(List<Expense> allExpenses) async {
    _partitions.clear();
    final Map<String, List<Expense>> byWorkspace = {};
    for (final e in allExpenses) {
      final ws = _normWs(e.workspaceId);
      byWorkspace.putIfAbsent(ws, () => []).add(e);
    }

    for (final entry in byWorkspace.entries) {
      final partition = WorkspaceReportPartition();
      await partition.rebuild(entry.value);
      _partitions[entry.key] = partition;
    }

    _partitions.putIfAbsent(
      _activeWorkspaceId,
      () => WorkspaceReportPartition(),
    );
  }
}
