import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/services/data_lifecycle_service.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/services/storage_info_service.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/job_record.dart';

class ExpensesProvider extends ChangeNotifier {
  final ExpenseRepository _repository;
  final ReportsDataService _reportsDataService;
  DataLifecycleService? _lifecycleService;
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

  // Heatmap & KPI Cache (strictly scoped to _activeWorkspaceId)
  Map<int, int> _currentMonthDailyTotals = {};
  int _maxDailySpend = 0;
  String _topCategoryThisMonth = '';
  int _avgDailySpendThisMonth = 0;

  // Partitioned inverted prefix search index: workspaceId -> (prefix -> Set<key>)
  final Map<String, Map<String, Set<int>>> _workspacePrefixIndex = {};
  final Map<int, List<String>> _keyToTokens = {};
  final Map<int, String> _keyToWorkspace = {};

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

  // Workspace Inverted Key Index: workspaceId -> Set of Hive keys & sorted List of expenses
  String _activeWorkspaceId = AppStateBox.activeWorkspaceId;
  final Map<String, Set<int>> _workspaceKeyIndex = {};
  final Map<String, List<Expense>> _workspaceExpenses = {};

  String get activeWorkspaceId => _activeWorkspaceId;
  int get dataVersion => _dataVersion;
  int get filteredDataVersion => _filteredDataVersion;
  List<Expense> get allExpenses => List.unmodifiable(_allNonArchivedItems);
  List<Expense> get activeWorkspaceExpenses =>
      List.unmodifiable(_workspaceExpenses[_activeWorkspaceId] ?? const []);

  List<Expense> get items => List.unmodifiable(_windowedItems);
  List<Expense> get recentExpenses => List.unmodifiable(_recentCache);
  Map<String, int> get categoryTotals =>
      Map.unmodifiable(_cachedCategoryTotals);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalSpent => _cachedTotal;
  int get total => _cachedTotal;

  int get windowStart => _windowStart;
  List<Expense> get windowedItems => List.unmodifiable(_windowedItems);
  bool get hasMore => _windowStart + kExpenseWindowSize < _filteredItems.length;

  Map<int, int> get currentMonthDailyTotals => _currentMonthDailyTotals;
  int get maxDailySpend => _maxDailySpend;
  String get topCategoryThisMonth => _topCategoryThisMonth;
  int get avgDailySpendThisMonth => _avgDailySpendThisMonth;

  FilterCriteria get criteria => _criteria;
  List<Expense> get filteredItems => List.unmodifiable(_filteredItems);
  int get filteredTotal => _filteredTotal;
  Map<String, int> get filteredCategoryTotals =>
      Map.unmodifiable(_filteredCategoryTotals);

  ExpensesProvider(
    this._repository,
    this._reportsDataService, {
    DataLifecycleService? lifecycleService,
  }) : _lifecycleService = lifecycleService {
    _reportsDataService.setActiveWorkspace(_activeWorkspaceId);
  }

  void attachLifecycleService(DataLifecycleService service) {
    _lifecycleService = service;
  }

  String _normWs(String? wsId) =>
      (wsId == null || wsId.isEmpty) ? AppConstants.kDefaultWorkspaceId : wsId;

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

  void setActiveWorkspace(String workspaceId) {
    final norm = _normWs(workspaceId);
    if (_activeWorkspaceId == norm) return;
    _activeWorkspaceId = norm;
    _reportsDataService.setActiveWorkspace(norm);
    _recomputeActiveWorkspaceMetrics();
    _applyFilters();
    _dataVersion++;
    notifyListeners();
  }

  /// Queries non-archived expenses across any subset of workspaces,
  /// optionally merging archived expenses cleanly from storage.
  Future<List<Expense>> getExpensesForWorkspaces(
    Set<String> workspaceIds, {
    DateTimeRange? range,
    bool includeArchived = false,
  }) async {
    final normalizedIds = workspaceIds.map(_normWs).toSet();
    if (!includeArchived && range != null) {
      final result = <Expense>[];
      for (final wsId in normalizedIds) {
        final wsList = _workspaceExpenses[wsId] ?? const [];
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
          999,
        );
        for (final e in wsList) {
          if (!e.date.isBefore(start) && !e.date.isAfter(end)) {
            result.add(e);
          }
        }
      }
      return result;
    }

    if (!includeArchived) {
      return [
        for (final wsId in normalizedIds) ...?_workspaceExpenses[wsId],
      ];
    }

    if (range != null) {
      return _repository.getRangeScoped(
        from: range.start,
        to: range.end,
        workspaceIds: normalizedIds,
        includeArchived: true,
      );
    }

    final all = await _repository.getAllExpenses();
    return all.where((e) => normalizedIds.contains(_normWs(e.workspaceId))).toList();
  }

  /// O(log N) binary-search insertion into a date-descending sorted list,
  /// with O(1) fast path when inserting the newest date.
  void _insertDescBinary(List<Expense> list, Expense e) {
    if (list.isEmpty || !e.date.isBefore(list.first.date)) {
      list.insert(0, e);
      return;
    }
    if (!e.date.isAfter(list.last.date)) {
      list.add(e);
      return;
    }
    int lo = 0;
    int hi = list.length;
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      if (list[mid].date.isBefore(e.date)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    list.insert(lo, e);
  }

  void _recomputeActiveWorkspaceMetrics() {
    final activeList = _workspaceExpenses[_activeWorkspaceId] ?? const [];
    _cachedTotal = activeList.fold<int>(0, (sum, e) => sum + e.amount);

    final Map<String, int> totals = {};
    for (var exp in activeList) {
      totals.update(
        exp.category,
        (value) => value + exp.amount,
        ifAbsent: () => exp.amount,
      );
    }
    _cachedCategoryTotals = totals;
    _recentCache = activeList.take(10).toList();
    _computeHeatmapAndKpis(activeList);
  }

  Future<void> load({bool isWatchEvent = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allNonArchivedItems = await _repository.getAll();
      StorageInfoService.invalidate();

      _reportsDataService.setActiveWorkspace(_activeWorkspaceId);

      // Partition into Inverted Workspace Index
      _workspaceKeyIndex.clear();
      _workspaceExpenses.clear();
      for (var exp in _allNonArchivedItems) {
        final wsId = _normWs(exp.workspaceId);
        if (exp.key is int) {
          _workspaceKeyIndex.putIfAbsent(wsId, () => {}).add(exp.key as int);
        }
        _workspaceExpenses.putIfAbsent(wsId, () => []).add(exp);
      }

      // Compute metrics strictly scoped to active workspace
      _recomputeActiveWorkspaceMetrics();

      // Build workspace-partitioned prefix index
      _buildSearchIndex();

      // Rebuild partitioned report cubes if this came from a box watch mutation
      if (isWatchEvent) {
        await _reportsDataService.rebuild(_allNonArchivedItems);
      }

      // Apply initial filters
      _applyFilters();

      _dataVersion++;
      _errorMessage = null;
    } on StorageException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = AppErrorTranslator.translate(e).title;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deferred rebuild of ReportsDataService partitioned cubes without blocking UI startup.
  Future<void> deferredRebuild() async {
    try {
      _reportsDataService.setActiveWorkspace(_activeWorkspaceId);
      await _reportsDataService.rebuild(_allNonArchivedItems);
    } catch (e) {
      debugPrint('Deferred rebuild error: $e');
    }
  }

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

  void _indexExpenseTokens(Expense exp, String wsId) {
    if (exp.key is! int) return;
    final int key = exp.key as int;
    final tokens = _tokenize('${exp.productName} ${exp.category}');
    _keyToTokens[key] = tokens;
    _keyToWorkspace[key] = wsId;
    final wsIndex = _workspacePrefixIndex.putIfAbsent(wsId, () => {});
    for (final token in tokens) {
      for (final prefix in _getPrefixes(token)) {
        wsIndex.putIfAbsent(prefix, () => {}).add(key);
      }
    }
  }

  void _removeExpenseTokens(int? key) {
    if (key == null) return;
    final tokens = _keyToTokens.remove(key);
    final oldWs = _keyToWorkspace.remove(key);
    if (tokens != null && oldWs != null) {
      final wsIndex = _workspacePrefixIndex[oldWs];
      if (wsIndex != null) {
        for (final token in tokens) {
          for (final prefix in _getPrefixes(token)) {
            wsIndex[prefix]?.remove(key);
            if (wsIndex[prefix]?.isEmpty ?? false) {
              wsIndex.remove(prefix);
            }
          }
        }
      }
    }
  }

  void _buildSearchIndex() {
    _workspacePrefixIndex.clear();
    _keyToTokens.clear();
    _keyToWorkspace.clear();
    for (final exp in _allNonArchivedItems) {
      _indexExpenseTokens(exp, _normWs(exp.workspaceId));
    }
  }

  Set<int> _searchKeys(String query) {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return {};

    final wsIndex = _workspacePrefixIndex[_activeWorkspaceId];
    if (wsIndex == null || wsIndex.isEmpty) return {};

    final List<Set<int>> sets = [];
    for (var token in tokens) {
      final prefix = token.substring(0, math.min(3, token.length));
      final matches = wsIndex[prefix];
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

  void _applyFilters() {
    final wsItems = _workspaceExpenses[_activeWorkspaceId] ?? const [];
    List<Expense> result = List.from(wsItems);

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

    if (_criteria.searchQuery.isNotEmpty) {
      final matchedKeys = _searchKeys(_criteria.searchQuery);
      result = result.where((e) => matchedKeys.contains(e.key)).toList();
    }

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

    if (_criteria.paymentMethod != null && _criteria.paymentMethod!.isNotEmpty) {
      result = result
          .where((e) => e.paymentMethod == _criteria.paymentMethod)
          .toList();
    }

    _filteredItems = result;
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

    _windowStart = 0;
    _updateWindowedItems();
    _filteredDataVersion++;
  }

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
    if (expense.workspaceId.isEmpty) {
      expense.workspaceId = _activeWorkspaceId;
    }
    final wsId = _normWs(expense.workspaceId);

    await AtomicWriter.instance.execute(() async {
      await _repository.add(expense);

      _insertDescBinary(_allNonArchivedItems, expense);

      if (expense.key is int) {
        _workspaceKeyIndex.putIfAbsent(wsId, () => {}).add(expense.key as int);
      }
      final wsList = _workspaceExpenses.putIfAbsent(wsId, () => []);
      _insertDescBinary(wsList, expense);

      _indexExpenseTokens(expense, wsId);
      _reportsDataService.updateForAdd(expense);

      if (wsId == _activeWorkspaceId) {
        _recomputeActiveWorkspaceMetrics();
        _applyFilters();
      }

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
        final oldWsId = _normWs(oldExpense.workspaceId);
        final newWsId = _normWs(expense.workspaceId);
        await _repository.update(expense.key as int, expense);

        _allNonArchivedItems.removeAt(oldIdx);
        _insertDescBinary(_allNonArchivedItems, expense);

        // Update workspace partitions cleanly
        _workspaceExpenses[oldWsId]?.removeWhere(
          (e) => (expense.key != null && e.key == expense.key) || identical(e, oldExpense),
        );
        if (oldWsId != newWsId && expense.key is int) {
          _workspaceKeyIndex[oldWsId]?.remove(expense.key as int);
          _workspaceKeyIndex.putIfAbsent(newWsId, () => {}).add(expense.key as int);
        }
        final newWsList = _workspaceExpenses.putIfAbsent(newWsId, () => []);
        _insertDescBinary(newWsList, expense);

        // Update search prefix index cleanly
        _removeExpenseTokens(expense.key as int?);
        _indexExpenseTokens(expense, newWsId);

        // Update reports partition(s) incrementally
        _reportsDataService.updateForDelete(oldExpense);
        _reportsDataService.updateForAdd(expense);

        if (oldWsId == _activeWorkspaceId || newWsId == _activeWorkspaceId) {
          _recomputeActiveWorkspaceMetrics();
          _applyFilters();
        }

        _dataVersion++;
      }
    });
    notifyListeners();
  }

  Future<void> deleteExpense(Expense expense) async {
    _skipNextWatch = true;
    final wsId = _normWs(expense.workspaceId);
    await AtomicWriter.instance.execute(() async {
      await _repository.delete(expense.key as int);

      if (Hive.isBoxOpen(AppConstants.kFutureExpensesBox)) {
        final futureBox = Hive.box<FutureExpense>(AppConstants.kFutureExpensesBox);
        for (final item in futureBox.values) {
          if (item.linkedExpenseKey == expense.key) {
            item.isPurchased = false;
            item.linkedExpenseKey = null;
            item.purchasedAmount = null;
            item.purchasedAt = null;
            await item.save();
          }
        }
      }

      _allNonArchivedItems.removeWhere(
        (e) => (expense.key != null && e.key == expense.key) || identical(e, expense),
      );
      if (expense.key is int) {
        _workspaceKeyIndex[wsId]?.remove(expense.key as int);
      }
      _workspaceExpenses[wsId]?.removeWhere(
        (e) => (expense.key != null && e.key == expense.key) || identical(e, expense),
      );

      _removeExpenseTokens(expense.key as int?);
      _reportsDataService.updateForDelete(expense);

      if (wsId == _activeWorkspaceId) {
        _recomputeActiveWorkspaceMetrics();
        _applyFilters();
      }

      _dataVersion++;
    });
    notifyListeners();
  }

  Future<List<Expense>> getAllExpenses() async {
    return await _repository.getAllExpenses();
  }

  int countOlderThan(int months, {Set<String>? workspaceIds}) {
    final threshold = DateTime.now().subtract(Duration(days: months * 30));
    if (workspaceIds != null && workspaceIds.isNotEmpty) {
      final normIds = workspaceIds.map(_normWs).toSet();
      int count = 0;
      for (final wsId in normIds) {
        final list = _workspaceExpenses[wsId] ?? const [];
        count += list.where((e) => e.date.isBefore(threshold)).length;
      }
      return count;
    }
    return _allNonArchivedItems.where((e) => e.date.isBefore(threshold)).length;
  }

  bool _isArchiveCancelled = false;

  void cancelArchive() {
    _isArchiveCancelled = true;
    _isArchiving = false;
    _archiveProgress = 0.0;
    notifyListeners();
  }

  Future<void> archiveOldExpenses(
    int months, {
    Set<String>? workspaceIds,
  }) async {
    if (_lifecycleService != null) {
      _isArchiving = true;
      _isArchiveCancelled = false;
      _archiveProgress = 0.0;
      notifyListeners();
      try {
        await _lifecycleService!.archiveExpenses(
          workspaceIds: workspaceIds ??
              _workspaceExpenses.keys.toSet(),
          olderThanMonths: months,
          onProgress: (p) {
            _archiveProgress = p;
            notifyListeners();
          },
          isCancelled: () => _isArchiveCancelled,
        );
      } finally {
        _isArchiving = false;
        notifyListeners();
        await load();
      }
      return;
    }

    await AtomicWriter.instance.execute(() async {
      _isArchiving = true;
      _isArchiveCancelled = false;
      _archiveProgress = 0.0;
      notifyListeners();

      try {
        final limitDate = DateTime.now().subtract(Duration(days: 30 * months));
        final normIds = workspaceIds?.map(_normWs).toSet();
        await _repository.batchArchiveWhere(
          (e) {
            if (!e.date.isBefore(limitDate)) return false;
            if (normIds != null && !normIds.contains(_normWs(e.workspaceId))) {
              return false;
            }
            return true;
          },
          chunkSize: AppConstants.kDbBatchChunkSize,
          onProgress: (p) {
            _archiveProgress = p;
            notifyListeners();
          },
          isCancelled: () => _isArchiveCancelled,
        );
      } catch (e) {
        debugPrint('Error during archiving: $e');
      } finally {
        _isArchiving = false;
        notifyListeners();
        await load();
      }
    });
    notifyListeners();
  }

  Future<void> resetAllData({List<Future<void> Function()>? additionalReloads}) async {
    if (_lifecycleService != null) {
      _isResetting = true;
      _resetProgress = 0.0;
      notifyListeners();
      try {
        await _lifecycleService!.factoryResetAllData(
          onProgress: (p) {
            _resetProgress = p;
            notifyListeners();
          },
        );
        if (additionalReloads != null) {
          for (final reload in additionalReloads) {
            await reload();
          }
        }
      } finally {
        _isResetting = false;
        notifyListeners();
        await load();
      }
      return;
    }

    await AtomicWriter.instance.execute(() async {
      _isResetting = true;
      _resetProgress = 0.0;
      notifyListeners();

      await AppStateBox.setPendingReset(true);

      try {
        final expensesBox = Hive.box<Expense>(AppConstants.kExpensesBox);
        await expensesBox.clear();
        await expensesBox.flush();
        _resetProgress = 0.20;
        notifyListeners();
        await Future.delayed(Duration.zero);

        final incomesBox = Hive.box<Income>(AppConstants.kIncomesBox);
        await incomesBox.clear();
        await incomesBox.flush();
        _resetProgress = 0.40;
        notifyListeners();
        await Future.delayed(Duration.zero);

        final futureBox = Hive.box<FutureExpense>(AppConstants.kFutureExpensesBox);
        for (var item in futureBox.values) {
          if (item.isPurchased) {
            item.isPurchased = false;
            item.linkedExpenseKey = null;
            item.purchasedAmount = null;
            item.purchasedAt = null;
            await item.save();
          }
        }
        await futureBox.flush();
        _resetProgress = 0.60;
        notifyListeners();
        await Future.delayed(Duration.zero);

        final remindersBox = Hive.box<Reminder>(AppConstants.kRemindersBox);
        await remindersBox.clear();
        await remindersBox.flush();
        _resetProgress = 0.80;
        notifyListeners();
        await Future.delayed(Duration.zero);

        final jobsBox = Hive.box<JobRecord>(AppConstants.kJobsBox);
        await jobsBox.clear();
        await jobsBox.flush();

        final budgetsBox = Hive.box<Budget>(AppConstants.kBudgetsBox);
        await budgetsBox.clear();
        await budgetsBox.flush();

        _resetProgress = 0.95;
        notifyListeners();
        await Future.delayed(Duration.zero);

        if (additionalReloads != null) {
          for (final reload in additionalReloads) {
            await reload();
          }
        }

        _resetProgress = 1.0;
      } catch (e) {
        debugPrint('Error during data reset: $e');
      } finally {
        await AppStateBox.setPendingReset(false);
        _isResetting = false;
        notifyListeners();
        await load();
      }
    });
    notifyListeners();
  }

  int totalBetween(DateTime start, DateTime endInclusive) {
    final activeList = _workspaceExpenses[_activeWorkspaceId] ?? const [];
    return _repository.totalBetween(activeList, start, endInclusive);
  }

  int totalForRange(DateTime start, DateTime end, {String? workspaceId}) {
    return _reportsDataService.totalForRange(
      start,
      end,
      workspaceId: workspaceId ?? _activeWorkspaceId,
    );
  }

  void _computeHeatmapAndKpis(List<Expense> scopedExpenses) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final thisMonthExpenses = scopedExpenses
        .where(
          (e) => e.date.year == currentYear && e.date.month == currentMonth,
        )
        .toList();

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

    _maxDailySpend = heatmap.isEmpty
        ? 0
        : heatmap.values.fold<int>(0, (m, val) => val > m ? val : m);

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
