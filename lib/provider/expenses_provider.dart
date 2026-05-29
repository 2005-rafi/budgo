import 'dart:async';
import 'dart:math' as math;
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/core/app_exception.dart';
import 'package:expense/core/app_constants.dart';
import 'package:expense/core/app_state_box.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/services/storage_info_service.dart';
import 'package:expense/core/atomic_writer.dart';
import 'package:expense/models/job_record.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/future_expense.dart';
import '../models/budget.dart';
import '../models/reminder.dart';

class ExpensesProvider extends ChangeNotifier {
  final ExpenseRepository _repository;
  final ReportsDataService _reportsDataService;
  List<Expense> _allNonArchivedItems = [];
  StreamSubscription<void>? _boxSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  int _cachedTotal = 0; // In minor units (paise)
  Map<String, int> _cachedCategoryTotals = {};

  bool _isArchiving = false;
  double _archiveProgress = 0.0;
  bool _isResetting = false;
  double _resetProgress = 0.0;

  bool get isArchiving => _isArchiving;
  double get archiveProgress => _archiveProgress;
  bool get isResetting => _isResetting;
  double get resetProgress => _resetProgress;

  // Sliding window pagination state
  int _windowStart = 0;
  static const int kExpenseWindowSize = 100;
  List<Expense> _windowedItems = [];

  // Heatmap & KPI Cache
  Map<int, int> _currentMonthDailyTotals = {};
  int _maxDailySpend = 0;
  String _topCategoryThisMonth = '';
  int _avgDailySpendThisMonth = 0;

  // Inverted prefix search index: prefix (1-3 chars) -> Set of expense keys
  final Map<String, Set<int>> _prefixIndex = {};
  final Map<int, List<String>> _keyToTokens = {};

  // Filter criteria & filtered states
  FilterCriteria _criteria = const FilterCriteria();
  List<Expense> _filteredItems = [];
  int _filteredTotal = 0;
  Map<String, int> _filteredCategoryTotals = {};
  int _filteredDataVersion = 0;

  // Incremental caching / optimization additions
  List<Expense> _recentCache = [];
  bool _skipNextWatch = false;
  int _dataVersion = 0;

  int get dataVersion => _dataVersion;
  int get filteredDataVersion => _filteredDataVersion;
  List<Expense> get allExpenses => List.unmodifiable(_allNonArchivedItems);

  // Public items getter returns the current windowed slice
  List<Expense> get items => List.unmodifiable(_windowedItems);
  List<Expense> get recentExpenses => List.unmodifiable(_recentCache);
  Map<String, int> get categoryTotals =>
      Map.unmodifiable(_cachedCategoryTotals);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalSpent => _cachedTotal;
  int get total => _cachedTotal;

  // Sliding window pagination getters
  int get windowStart => _windowStart;
  List<Expense> get windowedItems => List.unmodifiable(_windowedItems);
  bool get hasMore => _windowStart + kExpenseWindowSize < _filteredItems.length;

  // Heatmap & KPI getters
  Map<int, int> get currentMonthDailyTotals => _currentMonthDailyTotals;
  int get maxDailySpend => _maxDailySpend;
  String get topCategoryThisMonth => _topCategoryThisMonth;
  int get avgDailySpendThisMonth => _avgDailySpendThisMonth;

  // Filter getters
  FilterCriteria get criteria => _criteria;
  List<Expense> get filteredItems => List.unmodifiable(_filteredItems);
  int get filteredTotal => _filteredTotal;
  Map<String, int> get filteredCategoryTotals =>
      Map.unmodifiable(_filteredCategoryTotals);

  ExpensesProvider(this._repository, this._reportsDataService);

  Future<void> initialize() async {
    _boxSubscription ??= _repository.watch().listen((_) {
      if (_skipNextWatch) {
        _skipNextWatch = false;
        return;
      }
      load(isWatchEvent: true);
    });
    await load();
  }

  Future<void> load({bool isWatchEvent = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allNonArchivedItems = await _repository.getAll();
      StorageInfoService.invalidate();

      // Note: ReportsDataService rebuild deferred to post-frame to unblock UI startup

      // Compute totals on the full active list
      _cachedTotal = _allNonArchivedItems.fold<int>(
        0,
        (sum, e) => sum + e.amount,
      );

      final Map<String, int> totals = {};
      for (var exp in _allNonArchivedItems) {
        totals.update(
          exp.category,
          (value) => value + exp.amount,
          ifAbsent: () => exp.amount,
        );
      }
      _cachedCategoryTotals = totals;

      // Set recent cache
      _recentCache = _allNonArchivedItems.take(10).toList();

      // Compute heatmap & KPIs
      _computeHeatmapAndKpis(_allNonArchivedItems);

      // Build prefix index
      _buildSearchIndex();

      // Apply initial filters
      _applyFilters();

      _dataVersion++;
      _errorMessage = null;
    } on StorageException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deferred rebuild of ReportsDataService without notifying listeners.
  /// Called post-frame to unblock UI startup.
  /// Safe to call multiple times; rebuilds are idempotent.
  Future<void> deferredRebuild() async {
    try {
      await _reportsDataService.rebuild(_allNonArchivedItems);
    } catch (e) {
      debugPrint('Deferred rebuild error: $e');
    }
  }

  // Tokenization helper
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .toList();
  }

  Set<String> _getPrefixes(String token) {
    final Set<String> prefixes = {};
    for (int i = 1; i <= math.min(3, token.length); i++) {
      prefixes.add(token.substring(0, i));
    }
    return prefixes;
  }

  // Build the inverted prefix search index
  void _buildSearchIndex() {
    _prefixIndex.clear();
    _keyToTokens.clear();
    for (var exp in _allNonArchivedItems) {
      if (exp.key != null) {
        final int key = exp.key as int;
        final tokens = _tokenize('${exp.productName} ${exp.category}');
        _keyToTokens[key] = tokens;
        for (var token in tokens) {
          for (var prefix in _getPrefixes(token)) {
            _prefixIndex.putIfAbsent(prefix, () => {}).add(key);
          }
        }
      }
    }
  }

  // Search the prefix index (smallest-first intersection)
  Set<int> _searchKeys(String query) {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return {};

    final List<Set<int>> sets = [];
    for (var token in tokens) {
      final prefix = token.substring(0, math.min(3, token.length));
      final matches = _prefixIndex[prefix];
      if (matches == null || matches.isEmpty) {
        return {};
      }
      sets.add(matches);
    }

    if (sets.isEmpty) return {};

    sets.sort((a, b) => a.length.compareTo(b.length));

    Set<int> result = Set<int>.from(sets.first);
    for (int i = 1; i < sets.length; i++) {
      result = result.intersection(sets[i]);
      if (result.isEmpty) break;
    }
    return result;
  }

  // Debounced filter application
  Timer? _debounceTimer;

  void setFilter(FilterCriteria criteria) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (criteria.searchQuery != _criteria.searchQuery) {
      _criteria = criteria;
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _applyFilters();
        notifyListeners();
      });
    } else {
      _criteria = criteria;
      _applyFilters();
      notifyListeners();
    }
  }

  // Core filter logic
  void _applyFilters() {
    List<Expense> result = List.from(_allNonArchivedItems);

    // Apply custom date filter if set
    if (_criteria.date != null) {
      final filterDate = _criteria.date!;
      result = result
          .where(
            (e) =>
                e.date.year == filterDate.year &&
                e.date.month == filterDate.month &&
                e.date.day == filterDate.day,
          )
          .toList();
    }

    // Apply custom range filter if set
    if (_criteria.dateRange != null) {
      final range = _criteria.dateRange!;
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      result = result
          .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
          .toList();
    }

    // Apply Search Query using Inverted Index if query is present
    if (_criteria.searchQuery.isNotEmpty) {
      final matchedKeys = _searchKeys(_criteria.searchQuery);
      result = result.where((e) => matchedKeys.contains(e.key)).toList();
    }

    // Apply Active Category/Date/High-Spend filters
    if (_criteria.categories.isNotEmpty) {
      final categoryFilters = _criteria.categories
          .where((f) => AppConstants.kDefaultCategories.contains(f))
          .toSet();
      if (categoryFilters.isNotEmpty) {
        result = result
            .where((e) => categoryFilters.contains(e.category))
            .toList();
      }

      final now = DateTime.now();
      if (_criteria.categories.contains('This Week')) {
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeek = DateTime(monday.year, monday.month, monday.day);
        result = result.where((e) => !e.date.isBefore(startOfWeek)).toList();
      } else if (_criteria.categories.contains('This Month')) {
        final startOfMonth = DateTime(now.year, now.month, 1);
        result = result.where((e) => !e.date.isBefore(startOfMonth)).toList();
      }

      if (_criteria.categories.contains('High Spend')) {
        result = result
            .where((e) => e.amount > _avgDailySpendThisMonth)
            .toList();
      }
    }

    _filteredItems = result;

    // Compute totals specifically for the filtered subset
    _filteredTotal = _filteredItems.fold<int>(0, (sum, e) => sum + e.amount);

    final Map<String, int> totals = {};
    for (var exp in _filteredItems) {
      totals.update(
        exp.category,
        (value) => value + exp.amount,
        ifAbsent: () => exp.amount,
      );
    }
    _filteredCategoryTotals = totals;

    // Reset window
    _windowStart = 0;
    _updateWindowedItems();

    _filteredDataVersion++;
  }

  // Sliding window navigation
  void advanceWindow() {
    if (_windowStart + kExpenseWindowSize >= _filteredItems.length) return;
    _windowStart = math.min(_windowStart + 50, _filteredItems.length - 50);
    if (_windowStart < 0) _windowStart = 0;
    _updateWindowedItems();
    notifyListeners();
  }

  void retreatWindow() {
    if (_windowStart == 0) return;
    _windowStart = math.max(_windowStart - 50, 0);
    _updateWindowedItems();
    notifyListeners();
  }

  void _updateWindowedItems() {
    _windowedItems = _filteredItems.sublist(
      _windowStart,
      math.min(_windowStart + kExpenseWindowSize, _filteredItems.length),
    );
  }

  Future<void> addExpense(Expense expense) async {
    _skipNextWatch = true;
    await AtomicWriter.instance.execute(() async {
      await _repository.add(expense);

      // Insert into _allNonArchivedItems in sorted descending order
      int index = _allNonArchivedItems.indexWhere(
        (e) => e.date.isBefore(expense.date),
      );
      if (index == -1) {
        _allNonArchivedItems.add(expense);
      } else {
        _allNonArchivedItems.insert(index, expense);
      }

      // Insert into recent cache
      if (_recentCache.length < 10) {
        _recentCache.add(expense);
        _recentCache.sort((a, b) => b.date.compareTo(a.date));
      } else if (expense.date.isAfter(_recentCache.last.date)) {
        _recentCache.add(expense);
        _recentCache.sort((a, b) => b.date.compareTo(a.date));
        _recentCache.removeLast();
      }

      // Update totals
      _cachedTotal += expense.amount;
      _cachedCategoryTotals.update(
        expense.category,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );

      // Update inverted search index
      if (expense.key != null) {
        final int key = expense.key as int;
        final tokens = _tokenize('${expense.productName} ${expense.category}');
        _keyToTokens[key] = tokens;
        for (var token in tokens) {
          for (var prefix in _getPrefixes(token)) {
            _prefixIndex.putIfAbsent(prefix, () => {}).add(key);
          }
        }
      }

      // Update reports data service incrementally
      _reportsDataService.updateForAdd(expense);

      // Recalculate heatmap & KPIs
      _computeHeatmapAndKpis(_allNonArchivedItems);

      // Reapply filters
      _applyFilters();

      _dataVersion++;
    });
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    _skipNextWatch = true;
    await AtomicWriter.instance.execute(() async {
      final oldIdx = _allNonArchivedItems.indexWhere(
        (e) => e.key == expense.key,
      );
      if (oldIdx != -1) {
        final oldExpense = _allNonArchivedItems[oldIdx];
        await _repository.update(expense.key as int, expense);

        // Update in-memory: remove old, insert new
        _allNonArchivedItems.removeAt(oldIdx);
        int newIdx = _allNonArchivedItems.indexWhere(
          (e) => e.date.isBefore(expense.date),
        );
        if (newIdx == -1) {
          _allNonArchivedItems.add(expense);
        } else {
          _allNonArchivedItems.insert(newIdx, expense);
        }

        // Update recent cache
        _recentCache.removeWhere((e) => e.key == expense.key);
        if (_recentCache.length < 10 ||
            expense.date.isAfter(_recentCache.last.date)) {
          _recentCache.add(expense);
          _recentCache.sort((a, b) => b.date.compareTo(a.date));
          if (_recentCache.length > 10) _recentCache.removeLast();
        }
        if (_recentCache.length < 10 && _allNonArchivedItems.length >= 10) {
          _recentCache = _allNonArchivedItems.take(10).toList();
        }

        // Update totals
        _cachedTotal = _cachedTotal - oldExpense.amount + expense.amount;

        // Update category totals
        _cachedCategoryTotals.update(
          oldExpense.category,
          (v) => v - oldExpense.amount,
        );
        _cachedCategoryTotals.update(
          expense.category,
          (v) => v + expense.amount,
          ifAbsent: () => expense.amount,
        );

        // Update inverted search index
        if (expense.key != null) {
          final int key = expense.key as int;
          final oldTokens = _keyToTokens[key];
          if (oldTokens != null) {
            for (var token in oldTokens) {
              for (var prefix in _getPrefixes(token)) {
                _prefixIndex[prefix]?.remove(key);
                if (_prefixIndex[prefix]?.isEmpty ?? false) {
                  _prefixIndex.remove(prefix);
                }
              }
            }
          }
          final tokens = _tokenize(
            '${expense.productName} ${expense.category}',
          );
          _keyToTokens[key] = tokens;
          for (var token in tokens) {
            for (var prefix in _getPrefixes(token)) {
              _prefixIndex.putIfAbsent(prefix, () => {}).add(key);
            }
          }
        }

        // Update reports data service incrementally
        _reportsDataService.updateForDelete(oldExpense);
        _reportsDataService.updateForAdd(expense);

        _computeHeatmapAndKpis(_allNonArchivedItems);

        // Reapply filters
        _applyFilters();

        _dataVersion++;
      }
    });
    notifyListeners();
  }

  Future<void> deleteExpense(Expense expense) async {
    _skipNextWatch = true;
    await AtomicWriter.instance.execute(() async {
      await _repository.delete(expense.key as int);

      _allNonArchivedItems.removeWhere((e) => e.key == expense.key);
      _recentCache.removeWhere((e) => e.key == expense.key);
      if (_recentCache.length < 10 && _allNonArchivedItems.length >= 10) {
        _recentCache = _allNonArchivedItems.take(10).toList();
      }

      // Update totals
      _cachedTotal -= expense.amount;

      _cachedCategoryTotals.update(expense.category, (v) => v - expense.amount);

      // Update inverted search index
      if (expense.key != null) {
        final int key = expense.key as int;
        final tokens = _keyToTokens.remove(key);
        if (tokens != null) {
          for (var token in tokens) {
            for (var prefix in _getPrefixes(token)) {
              _prefixIndex[prefix]?.remove(key);
              if (_prefixIndex[prefix]?.isEmpty ?? false) {
                _prefixIndex.remove(prefix);
              }
            }
          }
        }
      }

      // Update reports data service incrementally
      _reportsDataService.updateForDelete(expense);

      _computeHeatmapAndKpis(_allNonArchivedItems);

      // Reapply filters
      _applyFilters();

      _dataVersion++;
    });
    notifyListeners();
  }

  Future<List<Expense>> getAllExpenses() async {
    return await _repository.getAllExpenses();
  }

  int countOlderThan(int months) {
    final threshold = DateTime.now().subtract(Duration(days: months * 30));
    return _allNonArchivedItems.where((e) => e.date.isBefore(threshold)).length;
  }

  Isolate? _activeArchiveIsolate;

  void cancelArchive() {
    if (_activeArchiveIsolate != null) {
      _activeArchiveIsolate!.kill(priority: Isolate.immediate);
      _activeArchiveIsolate = null;
      _isArchiving = false;
      _archiveProgress = 0.0;
      notifyListeners();
    }
  }

  Future<void> archiveOldExpenses(int months) async {
    await AtomicWriter.instance.execute(() async {
      _isArchiving = true;
      _archiveProgress = 0.0;
      notifyListeners();

      final dir = await getApplicationDocumentsDirectory();
      final receivePort = ReceivePort();

      try {
        final isolate = await Isolate.spawn(_archiveIsolateEntry, {
          'dirPath': dir.path,
          'months': months,
          'sendPort': receivePort.sendPort,
        });
        _activeArchiveIsolate = isolate;

        await for (final message in receivePort) {
          if (message is Map) {
            if (message['done'] == true) {
              break;
            }
            final completed = message['completed'] as int;
            final total = message['total'] as int;
            _archiveProgress = total > 0 ? completed / total : 0.0;
            notifyListeners();
          }
        }
      } catch (_) {
        // Handle error or cancellation
      } finally {
        receivePort.close();
        if (_activeArchiveIsolate != null) {
          _activeArchiveIsolate!.kill(priority: Isolate.immediate);
          _activeArchiveIsolate = null;
        }
        _isArchiving = false;
        notifyListeners();
        await load();
      }
    });
    notifyListeners();
  }

  Future<void> resetAllData() async {
    await AtomicWriter.instance.execute(() async {
      _isResetting = true;
      _resetProgress = 0.0;
      notifyListeners();

      // 1. Write PendingReset marker (runs on main thread)
      await AppStateBox.setPendingReset(true);

      final dir = await getApplicationDocumentsDirectory();
      final receivePort = ReceivePort();
      Isolate? resetIsolate;

      try {
        resetIsolate = await Isolate.spawn(_resetIsolateEntry, {
          'dirPath': dir.path,
          'sendPort': receivePort.sendPort,
        });

        await for (final message in receivePort) {
          if (message is Map) {
            if (message['done'] == true) {
              break;
            }
            _resetProgress = message['progress'] as double;
            notifyListeners();
          }
        }
      } catch (_) {
        // Handle error
      } finally {
        receivePort.close();
        if (resetIsolate != null) {
          resetIsolate.kill(priority: Isolate.immediate);
        }
        await AppStateBox.setPendingReset(false);
        _isResetting = false;
        notifyListeners();
        await load();
      }
    });
    notifyListeners();
  }

  int totalBetween(DateTime start, DateTime endInclusive) {
    return _repository.totalBetween(_allNonArchivedItems, start, endInclusive);
  }

  int totalForRange(DateTime start, DateTime end) {
    return _reportsDataService.totalForRange(start, end);
  }

  void _computeHeatmapAndKpis(List<Expense> allExpenses) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Filter current month expenses
    final thisMonthExpenses = allExpenses
        .where(
          (e) => e.date.year == currentYear && e.date.month == currentMonth,
        )
        .toList();

    // Heatmap data
    final Map<int, int> heatmap = {};
    for (var exp in thisMonthExpenses) {
      final dayKey = AppConstants.dateKey(exp.date);
      heatmap.update(
        dayKey,
        (val) => val + exp.amount,
        ifAbsent: () => exp.amount,
      );
    }
    _currentMonthDailyTotals = heatmap;

    // Max daily spend
    if (heatmap.isEmpty) {
      _maxDailySpend = 0;
    } else {
      _maxDailySpend = heatmap.values.fold<int>(
        0,
        (m, val) => val > m ? val : m,
      );
    }

    // Top Category
    final Map<String, int> catTotals = {};
    for (var exp in thisMonthExpenses) {
      catTotals.update(
        exp.category,
        (val) => val + exp.amount,
        ifAbsent: () => exp.amount,
      );
    }

    if (catTotals.isEmpty) {
      _topCategoryThisMonth = '';
    } else {
      var topCat = '';
      var maxCatSpend = -1;
      catTotals.forEach((cat, amt) {
        if (amt > maxCatSpend) {
          maxCatSpend = amt;
          topCat = cat;
        }
      });
      _topCategoryThisMonth = topCat;
    }

    // Avg Daily Spend
    final daysElapsed = now.day;
    final totalSpentThisMonth = thisMonthExpenses.fold<int>(
      0,
      (sum, e) => sum + e.amount,
    );
    _avgDailySpendThisMonth =
        (totalSpentThisMonth / (daysElapsed > 0 ? daysElapsed : 1)).round();
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

void _archiveIsolateEntry(Map<String, dynamic> args) async {
  final String dirPath = args['dirPath'];
  final int months = args['months'];
  final SendPort sendPort = args['sendPort'];

  try {
    Hive.init(dirPath);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExpenseAdapter());

    final box = await Hive.openBox<Expense>(AppConstants.kExpensesBox);
    final limitDate = DateTime.now().subtract(Duration(days: 30 * months));

    final toArchive = box.values
        .where((e) => e.date.isBefore(limitDate) && e.isArchived != true)
        .toList();

    final total = toArchive.length;
    int completed = 0;

    const chunkSize = 50;
    for (int i = 0; i < total; i += chunkSize) {
      final chunk = toArchive.sublist(i, math.min(i + chunkSize, total));
      for (var expense in chunk) {
        expense.isArchived = true;
        await expense.save();
      }
      completed += chunk.length;
      sendPort.send({'completed': completed, 'total': total, 'done': false});
    }

    await box.flush();
    await box.close();
    sendPort.send({'completed': total, 'total': total, 'done': true});
  } catch (e) {
    sendPort.send({'error': e.toString(), 'done': true});
  }
}

void _resetIsolateEntry(Map<String, dynamic> args) async {
  final String dirPath = args['dirPath'];
  final SendPort sendPort = args['sendPort'];

  try {
    Hive.init(dirPath);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExpenseAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(IncomeAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FutureExpenseAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ReminderAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(JobRecordAdapter());

    // Clear expenses box
    final expensesBox = await Hive.openBox<Expense>(AppConstants.kExpensesBox);
    await expensesBox.clear();
    await expensesBox.flush();
    sendPort.send({'step': 'expenses_cleared', 'progress': 0.20});

    // Clear incomes box
    final incomesBox = await Hive.openBox<Income>(AppConstants.kIncomesBox);
    await incomesBox.clear();
    await incomesBox.flush();
    sendPort.send({'step': 'incomes_cleared', 'progress': 0.40});

    // Reset future expenses
    final futureBox = await Hive.openBox<FutureExpense>(
      AppConstants.kFutureExpensesBox,
    );
    final list = futureBox.values.toList();
    for (var item in list) {
      if (item.isPurchased) {
        item.isPurchased = false;
        item.linkedExpenseKey = null;
        item.purchasedAmount = null;
        item.purchasedAt = null;
        await item.save();
      }
    }
    await futureBox.flush();
    sendPort.send({'step': 'future_expenses_reset', 'progress': 0.60});

    // Clear reminders box
    final remindersBox = await Hive.openBox<Reminder>('reminders');
    await remindersBox.clear();
    await remindersBox.flush();
    sendPort.send({'step': 'reminders_cleared', 'progress': 0.80});

    // Clear jobs box
    final jobsBox = await Hive.openBox<JobRecord>('jobs');
    await jobsBox.clear();
    await jobsBox.flush();
    sendPort.send({'step': 'jobs_cleared', 'progress': 0.90});

    // Close boxes
    await expensesBox.close();
    await incomesBox.close();
    await futureBox.close();
    await remindersBox.close();
    await jobsBox.close();

    sendPort.send({'step': 'complete', 'progress': 1.0, 'done': true});
  } catch (e) {
    sendPort.send({'error': e.toString(), 'done': true});
  }
}
