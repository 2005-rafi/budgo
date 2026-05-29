import 'package:expense/models/expense.dart';

class ReportsDataService {
  static final DateTime kEpoch = DateTime(2020, 1, 1);
  static const int kEpochWeekday = 2; // Wednesday (3 - 1)

  List<Expense> _sortedAsc = [];
  List<int> _epochDays = [];
  final Map<int, int> _dayTotals = {};
  final Map<int, int> _weekTotals = {};
  final Map<int, int> _monthTotals = {};
  final Map<String, int> _allCatTotals = {};
  final Map<int, Map<String, int>> _monthCatTotals = {};
  int _globalMaxDailySpend = 0;
  DateTime? _firstExpenseDate;
  DateTime? _lastExpenseDate;

  // Heatmap cache: monthKey -> (epochDay -> totalPaise)
  final Map<int, Map<int, int>> _heatmapCache = {};
  final Map<int, int> _yearMaxSpend = {};

  // Heatmap cache
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

  void updateVersion() => _lastVersion++;

  /// Generates a map of Date -> Total Minor Units for a given year.
  /// Uses a simple cache to avoid recomputing if data hasn't changed.
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

  Map<String, int> get allCatTotals => _allCatTotals;
  int get globalMaxDailySpend => _globalMaxDailySpend;
  DateTime? get firstExpenseDate => _firstExpenseDate;
  DateTime? get lastExpenseDate => _lastExpenseDate;
  Map<int, Map<int, int>> get heatmapCache => _heatmapCache;
  Map<int, Map<int, int>> get monthlyCache => _heatmapCache;
  Map<int, int> get yearMaxSpend => _yearMaxSpend;

  int toEpochDay(DateTime date) {
    final localMidnight = DateTime(date.year, date.month, date.day);
    final utcMidnight = DateTime.utc(
      localMidnight.year,
      localMidnight.month,
      localMidnight.day,
    );
    final utcEpoch = DateTime.utc(kEpoch.year, kEpoch.month, kEpoch.day);
    return utcMidnight.difference(utcEpoch).inDays;
  }

  DateTime epochToDateTime(int epochDay) {
    final utcEpoch = DateTime.utc(kEpoch.year, kEpoch.month, kEpoch.day);
    final utcDate = utcEpoch.add(Duration(days: epochDay));
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
    if (lo < 0 || hi > _sortedAsc.length || lo > hi) return [];
    return _sortedAsc.sublist(lo, hi);
  }

  int totalForRange(DateTime start, DateTime end) {
    int total = 0;

    DateTime current = DateTime(start.year, start.month, start.day);
    final DateTime targetEnd = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(targetEnd)) {
      // If we are at the start of a month and the whole month is within range
      if (current.day == 1) {
        final lastDayOfMonth = DateTime(current.year, current.month + 1, 0);
        if (!lastDayOfMonth.isAfter(targetEnd)) {
          final monthKey = current.year * 100 + current.month;
          total += _monthTotals[monthKey] ?? 0;
          current = DateTime(current.year, current.month + 1, 1);
          continue;
        }
      }

      // Otherwise, add daily total
      final epochDay = toEpochDay(current);
      total += _dayTotals[epochDay] ?? 0;
      current = current.add(const Duration(days: 1));
    }

    return total;
  }

  void updateForAdd(Expense e) {
    final epochDay = toEpochDay(e.date);

    // 1. Find insertion point using binary search
    int lo = 0;
    int hi = _epochDays.length;
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      if (_epochDays[mid] >= epochDay) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }

    _epochDays.insert(lo, epochDay);
    _sortedAsc.insert(lo, e);

    // 2. Update totals
    _dayTotals[epochDay] = (_dayTotals[epochDay] ?? 0) + e.amount;

    final weekEpoch = mondayEpoch(epochDay);
    _weekTotals[weekEpoch] = (_weekTotals[weekEpoch] ?? 0) + e.amount;

    final monthKey = e.date.year * 100 + e.date.month;
    _monthTotals[monthKey] = (_monthTotals[monthKey] ?? 0) + e.amount;

    _allCatTotals[e.category] = (_allCatTotals[e.category] ?? 0) + e.amount;

    _monthCatTotals.putIfAbsent(monthKey, () => {});
    _monthCatTotals[monthKey]![e.category] =
        (_monthCatTotals[monthKey]![e.category] ?? 0) + e.amount;

    // 3. Update global and year max daily spends
    if (_dayTotals[epochDay]! > _globalMaxDailySpend) {
      _globalMaxDailySpend = _dayTotals[epochDay]!;
    }

    if (_dayTotals[epochDay]! > (_yearMaxSpend[e.date.year] ?? 0)) {
      _yearMaxSpend[e.date.year] = _dayTotals[epochDay]!;
    }

    // 4. Rebuild heatmap cache for the affected month
    _rebuildHeatmapForMonth(monthKey);
    updateVersion();

    // 5. Update first/last expense dates
    if (_sortedAsc.isNotEmpty) {
      _firstExpenseDate = _sortedAsc.first.date;
      _lastExpenseDate = _sortedAsc.last.date;
    }
  }

  void updateForDelete(Expense e) {
    final epochDay = toEpochDay(e.date);

    // 1. Narrow search range using lower/upper bound of epochDay
    final startIdx = lowerBound(epochDay);
    final endIdx = upperBound(epochDay);

    int targetIdx = -1;
    for (int i = startIdx; i < endIdx; i++) {
      if (_sortedAsc[i].key == e.key) {
        targetIdx = i;
        break;
      }
    }

    // Fallback if not found in daily bounds
    if (targetIdx == -1) {
      for (int i = 0; i < _sortedAsc.length; i++) {
        if (_sortedAsc[i].key == e.key) {
          targetIdx = i;
          break;
        }
      }
    }

    if (targetIdx != -1) {
      _sortedAsc.removeAt(targetIdx);
      _epochDays.removeAt(targetIdx);

      // 2. Subtract from totals
      final dayVal = (_dayTotals[epochDay] ?? 0) - e.amount;
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

      // 3. Recompute global and year max daily spends
      _globalMaxDailySpend = 0;
      for (final dayTotal in _dayTotals.values) {
        if (dayTotal > _globalMaxDailySpend) {
          _globalMaxDailySpend = dayTotal;
        }
      }

      int yearMax = 0;
      _dayTotals.forEach((dayKey, dailyTotal) {
        final date = epochToDateTime(dayKey);
        if (date.year == e.date.year) {
          if (dailyTotal > yearMax) {
            yearMax = dailyTotal;
          }
        }
      });
      if (yearMax > 0) {
        _yearMaxSpend[e.date.year] = yearMax;
      } else {
        _yearMaxSpend.remove(e.date.year);
      }

      // 4. Rebuild heatmap cache for the affected month
      _rebuildHeatmapForMonth(monthKey);
      updateVersion();

      // 5. Update first/last expense dates
      if (_sortedAsc.isNotEmpty) {
        _firstExpenseDate = _sortedAsc.first.date;
        _lastExpenseDate = _sortedAsc.last.date;
      } else {
        _firstExpenseDate = null;
        _lastExpenseDate = null;
      }
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
      if (_dayTotals.containsKey(day)) {
        monthMap[day] = _dayTotals[day]!;
      }
    }

    if (monthMap.isNotEmpty) {
      _heatmapCache[monthKey] = monthMap;
    }
  }

  Future<void> rebuild(List<Expense> allExpenses) async {
    _sortedAsc = List.from(allExpenses);
    _sortedAsc.sort((a, b) => a.date.compareTo(b.date));

    _epochDays = List.generate(
      _sortedAsc.length,
      (i) => toEpochDay(_sortedAsc[i].date),
    );

    _dayTotals.clear();
    _weekTotals.clear();
    _monthTotals.clear();
    _allCatTotals.clear();
    _monthCatTotals.clear();
    _heatmapCache.clear();
    _yearMaxSpend.clear();
    _globalMaxDailySpend = 0;

    if (_sortedAsc.isEmpty) {
      _firstExpenseDate = null;
      _lastExpenseDate = null;
      return;
    }

    _firstExpenseDate = _sortedAsc.first.date;
    _lastExpenseDate = _sortedAsc.last.date;

    for (int i = 0; i < _sortedAsc.length; i++) {
      final e = _sortedAsc[i];
      final epochDay = _epochDays[i];
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
    }

    for (final dayTotal in _dayTotals.values) {
      if (dayTotal > _globalMaxDailySpend) {
        _globalMaxDailySpend = dayTotal;
      }
    }

    for (final entry in _dayTotals.entries) {
      final epochDay = entry.key;
      final dailyTotal = entry.value;
      final date = epochToDateTime(epochDay);

      final year = date.year;
      if (dailyTotal > (_yearMaxSpend[year] ?? 0)) {
        _yearMaxSpend[year] = dailyTotal;
      }

      final monthKey = date.year * 100 + date.month;
      _heatmapCache.putIfAbsent(monthKey, () => {})[epochDay] = dailyTotal;
    }
    updateVersion();
  }
}
