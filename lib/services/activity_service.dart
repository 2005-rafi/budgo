import 'package:expense/models/transaction_entry.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/models/timeline_group.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';

class ActivityService {
  List<TimelineGroup> buildTimeline({
    required List<Expense> filteredExpenses,
    required List<Income> allIncomes,
    required List<FutureExpense> allFutureExpenses,
    required FilterCriteria criteria,
  }) {
    final now = DateTime.now();

    final specificCategories = criteria.categories.difference({
      'All',
      'Expenses',
      'Income',
      'Planned',
      'Today',
      'This Week',
      'This Month',
      'High Spend',
    });

    final hasSpecificCategory = specificCategories.isNotEmpty;
    // Map 'Lend/Borrow' category to 'Lend' in the specific categories check
    final mappedSpecificCategories = specificCategories.map((c) => c == 'Lend/Borrow' ? 'Lend' : c).toSet();

    final showAll = criteria.categories.isEmpty ||
        criteria.categories.contains('All') ||
        criteria.categories.difference({
          'Today',
          'This Week',
          'This Month',
          'High Spend',
        }).isEmpty;

    // If specific categories are selected, we show anything matching those categories.
    // Otherwise, we respect the Expenses/Income/Planned toggles.
    final showExpenses =
        hasSpecificCategory ||
        showAll ||
        criteria.categories.contains('Expenses');
    final showIncome =
        (hasSpecificCategory && specificCategories.contains('Income')) ||
        showAll ||
        criteria.categories.contains('Income');
    // Note: Incomes usually don't have categories in this app except 'Income' itself.

    final showPlanned =
        hasSpecificCategory ||
        showAll ||
        criteria.categories.contains('Planned');

    // 1. Prepare and filter sources (already sorted descending)
    final List<TransactionEntry> expenseEntries = [];
    if (showExpenses) {
      for (final e in filteredExpenses) {
        if (hasSpecificCategory && !mappedSpecificCategories.contains(e.category)) {
          continue;
        }
        expenseEntries.add(
          ExpenseEntry(
            id: e.key?.toString() ?? e.date.millisecondsSinceEpoch.toString(),
            date: e.date,
            amount: e.amount,
            displayName: e.productName,
            category: e.category,
            rawExpense: e,
          ),
        );
      }
    }

    final List<TransactionEntry> incomeEntries = [];
    if (showIncome) {
      final filteredIncomes = _filterIncomes(allIncomes, criteria);
      for (final i in filteredIncomes) {
        // Incomes are shown if no specific category is selected OR if 'Income' category is selected
        if (hasSpecificCategory && !mappedSpecificCategories.contains('Income')) {
          continue;
        }
        incomeEntries.add(
          IncomeEntry(
            id: i.id,
            date: i.date,
            amount: i.amount,
            displayName: i.source,
            category: 'Income',
            isConfirmed: i.isConfirmed,
            rawIncome: i,
          ),
        );
      }
    }

    final List<TransactionEntry> plannedEntries = [];
    if (showPlanned) {
      final filteredPlanned = _filterPlanned(allFutureExpenses, criteria);
      for (final f in filteredPlanned) {
        if (hasSpecificCategory && !mappedSpecificCategories.contains(f.category)) {
          continue;
        }
        plannedEntries.add(
          PlannedEntry(
            id: f.id,
            date: f.dueDate ?? DateTime.now(),
            amount: f.estimatedCost ?? 0,
            displayName: f.title,
            category: f.category,
            priority: f.priority == 0
                ? 'low'
                : f.priority == 2
                ? 'high'
                : 'medium',
            dueDate: f.dueDate,
            rawFuture: f,
          ),
        );
      }
    }

    // 2. K-way merge (since sources are pre-sorted descending)
    final List<TransactionEntry> merged = [];
    int iExp = 0, iInc = 0, iPln = 0;

    while (iExp < expenseEntries.length ||
        iInc < incomeEntries.length ||
        iPln < plannedEntries.length) {
      TransactionEntry? best;
      int source = -1; // 0: exp, 1: inc, 2: pln

      if (iExp < expenseEntries.length) {
        best = expenseEntries[iExp];
        source = 0;
      }

      if (iInc < incomeEntries.length) {
        if (best == null || incomeEntries[iInc].date.isAfter(best.date)) {
          best = incomeEntries[iInc];
          source = 1;
        }
      }

      if (iPln < plannedEntries.length) {
        if (best == null || plannedEntries[iPln].date.isAfter(best.date)) {
          best = plannedEntries[iPln];
          source = 2;
        }
      }

      if (best != null) {
        merged.add(best);
        if (source == 0) {
          iExp++;
        } else if (source == 1) {
          iInc++;
        } else if (source == 2) {
          iPln++;
        }
      }
    }

    // 3. Group by relative time
    return _groupTransactions(merged, now);
  }

  int _firstIncomeLessThanOrEqual(List<Income> list, DateTime targetEnd) {
    int lo = 0;
    int hi = list.length;
    while (lo < hi) {
      int mid = lo + ((hi - lo) >> 1);
      if (!list[mid].date.isAfter(targetEnd)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  int _firstIncomeLessThan(List<Income> list, DateTime targetStart) {
    int lo = 0;
    int hi = list.length;
    while (lo < hi) {
      int mid = lo + ((hi - lo) >> 1);
      if (list[mid].date.isBefore(targetStart)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  List<Income> _filterIncomes(List<Income> incomes, FilterCriteria criteria) {
    if (incomes.isEmpty) return [];

    List<Income> result = incomes;

    // Apply custom date filter if set
    if (criteria.date != null) {
      final d = criteria.date!;
      final startOfDay = DateTime(d.year, d.month, d.day);
      final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);

      final startIdx = _firstIncomeLessThanOrEqual(result, endOfDay);
      final endIdx = _firstIncomeLessThan(result, startOfDay);
      result = result.sublist(startIdx, endIdx);
    } else if (criteria.dateRange != null) {
      final range = criteria.dateRange!;
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

      final startIdx = _firstIncomeLessThanOrEqual(result, end);
      final endIdx = _firstIncomeLessThan(result, start);
      result = result.sublist(startIdx, endIdx);
    } else if (criteria.categories.contains('This Week')) {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);
      final sunday = monday.add(const Duration(days: 6));
      final endOfWeek = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);

      final startIdx = _firstIncomeLessThanOrEqual(result, endOfWeek);
      final endIdx = _firstIncomeLessThan(result, startOfWeek);
      result = result.sublist(startIdx, endIdx);
    } else if (criteria.categories.contains('This Month')) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final lastDay = _lastDayOfMonth(now.year, now.month);
      final endOfMonth = DateTime(now.year, now.month, lastDay, 23, 59, 59);

      final startIdx = _firstIncomeLessThanOrEqual(result, endOfMonth);
      final endIdx = _firstIncomeLessThan(result, startOfMonth);
      result = result.sublist(startIdx, endIdx);
    } else if (criteria.categories.contains('Today')) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final startIdx = _firstIncomeLessThanOrEqual(result, todayEnd);
      final endIdx = _firstIncomeLessThan(result, todayStart);
      result = result.sublist(startIdx, endIdx);
    }

    if (criteria.searchQuery.isNotEmpty) {
      final query = criteria.searchQuery.toLowerCase();
      result = result.where((i) {
        final matchesSource = i.source.toLowerCase().contains(query);
        final matchesNotes =
            i.description?.toLowerCase().contains(query) ?? false;
        final matchesAmount = i.amount.toString().contains(query);
        return matchesSource || matchesNotes || matchesAmount;
      }).toList();
    }

    return result;
  }

  List<FutureExpense> _filterPlanned(
    List<FutureExpense> planned,
    FilterCriteria criteria,
  ) {
    return planned.where((f) {
      // Only show non-purchased items in activity wishlist
      if (f.isPurchased) return false;

      // Category filter (if specific categories are requested, check matches)
      final specificCategories = criteria.categories.difference({
        'All',
        'Expenses',
        'Income',
        'Planned',
      });
      if (specificCategories.isNotEmpty &&
          !specificCategories.contains(f.category)) {
        return false;
      }

      // Search query filter
      if (criteria.searchQuery.isNotEmpty) {
        final query = criteria.searchQuery.toLowerCase();
        final matchesTitle = f.title.toLowerCase().contains(query);
        final matchesNotes = f.notes?.toLowerCase().contains(query) ?? false;
        final matchesAmount = (f.estimatedCost ?? 0).toString().contains(query);
        if (!matchesTitle && !matchesNotes && !matchesAmount) return false;
      }

      // Date filter
      if (criteria.date != null && f.dueDate != null) {
        final d = criteria.date!;
        if (f.dueDate!.year != d.year ||
            f.dueDate!.month != d.month ||
            f.dueDate!.day != d.day) {
          return false;
        }
      }

      // Date range filter
      if (criteria.dateRange != null && f.dueDate != null) {
        final range = criteria.dateRange!;
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
        if (f.dueDate!.isBefore(start) || f.dueDate!.isAfter(end)) return false;
      }

      // Timing filters
      if (f.dueDate != null) {
        if (criteria.categories.contains('Today')) {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
          if (f.dueDate!.isBefore(todayStart) || f.dueDate!.isAfter(todayEnd)) {
            return false;
          }
        } else if (criteria.categories.contains('This Week')) {
          final now = DateTime.now();
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeek = DateTime(monday.year, monday.month, monday.day);
          final sunday = monday.add(const Duration(days: 6));
          final endOfWeek = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
          if (f.dueDate!.isBefore(startOfWeek) || f.dueDate!.isAfter(endOfWeek)) {
            return false;
          }
        } else if (criteria.categories.contains('This Month')) {
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          final lastDay = _lastDayOfMonth(now.year, now.month);
          final endOfMonth = DateTime(now.year, now.month, lastDay, 23, 59, 59);
          if (f.dueDate!.isBefore(startOfMonth) || f.dueDate!.isAfter(endOfMonth)) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  List<TimelineGroup> _groupTransactions(
    List<TransactionEntry> items,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final Map<String, List<TransactionEntry>> grouped = {};

    for (final item in items) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      String groupTitle;

      if (date == today) {
        groupTitle = 'Today';
      } else if (date == yesterday) {
        groupTitle = 'Yesterday';
      } else if (date.isAfter(monday.subtract(const Duration(days: 1)))) {
        groupTitle = 'This Week';
      } else if (date.year == today.year && date.month == today.month) {
        groupTitle = 'Earlier this month';
      } else {
        groupTitle = _formatMonthYear(item.date);
      }

      grouped.putIfAbsent(groupTitle, () => []).add(item);
    }

    return grouped.entries
        .map((e) => TimelineGroup(title: e.key, items: e.value))
        .toList();
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  int _lastDayOfMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const daysInMonths = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonths[month];
  }
}
