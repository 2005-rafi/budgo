import 'package:expense/models/transaction_entry.dart';
import 'package:expense/models/view_models/dashboard_view_model.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/services/insight_engine_service.dart';

class DashboardService {
  final ReportsDataService reportsDataService;
  final InsightEngineService insightEngineService;

  DashboardService({
    required this.reportsDataService,
    required this.insightEngineService,
  });

  Future<DashboardViewModel> buildViewModel(
    DateTime now, {
    required List<Income> incomes,
    required List<FutureExpense> futureExpenses,
    required int? budgetLimit,
    required int? spentInActivePeriod,
    required double? budgetUsageRatio,
    bool isLoading = false,
  }) async {
    final currentMonthKey = now.year * 100 + now.month;
    final spentThisMonth = reportsDataService.monthTotals[currentMonthKey] ?? 0;

    // Calculate confirmed income for the current month
    final incomeThisMonth = incomes
        .where(
          (i) =>
              i.isConfirmed &&
              i.date.year == now.year &&
              i.date.month == now.month,
        )
        .fold<int>(0, (sum, i) => sum + i.amount);

    final balanceThisMonth = incomeThisMonth - spentThisMonth;

    // 1. Calculate top category for current month
    final currentMonthStart = reportsDataService.toEpochDay(
      DateTime(now.year, now.month, 1),
    );
    final currentMonthEnd = reportsDataService.toEpochDay(
      DateTime(now.year, now.month + 1, 0),
    );
    final startIdx = reportsDataService.lowerBound(currentMonthStart);
    final endIdx = reportsDataService.upperBound(currentMonthEnd);
    final thisMonthExpenses = reportsDataService.slice(startIdx, endIdx);

    final Map<String, int> thisMonthCatTotals = {};
    for (final e in thisMonthExpenses) {
      thisMonthCatTotals[e.category] =
          (thisMonthCatTotals[e.category] ?? 0) + e.amount;
    }

    String topCategoryName = '';
    int topCategoryAmount = 0;
    if (thisMonthCatTotals.isNotEmpty) {
      final topCat = thisMonthCatTotals.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      topCategoryName = topCat.key;
      topCategoryAmount = topCat.value;
    }

    // 2. Generate 7-day sparkline data (last 7 days including today)
    final List<int> weeklySparkData = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final epochDay = reportsDataService.toEpochDay(date);
      final dailyTotal = reportsDataService.dayTotals[epochDay] ?? 0;
      weeklySparkData.add(dailyTotal);
    }

    // 3. Generate combined recent transactions (max 10) using k-way merge (O(N))
    final List<TransactionEntry> allEntries = [];

    // Sources must be pre-sorted descending for efficient merge
    final expenseEntries = reportsDataService.sortedAsc.reversed
        .map(
          (e) => ExpenseEntry(
            id: e.key?.toString() ?? e.date.millisecondsSinceEpoch.toString(),
            date: e.date,
            amount: e.amount,
            displayName: e.productName,
            category: e.category,
            rawExpense: e,
          ),
        )
        .toList();

    final incomeEntries = incomes
        .map(
          (i) => IncomeEntry(
            id: i.id,
            date: i.date,
            amount: i.amount,
            displayName: i.source,
            category: 'Income',
            isConfirmed: i.isConfirmed,
            rawIncome: i,
          ),
        )
        .toList();

    final plannedEntries = futureExpenses
        .where((f) => !f.isPurchased)
        .map(
          (f) => PlannedEntry(
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
        )
        .toList();

    // k-way merge pointers
    int iExp = 0, iInc = 0, iPln = 0;
    while (allEntries.length < 10 &&
        (iExp < expenseEntries.length ||
            iInc < incomeEntries.length ||
            iPln < plannedEntries.length)) {
      TransactionEntry? best;
      int source = -1;

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
        allEntries.add(best);
        if (source == 0) {
          iExp++;
        } else if (source == 1) {
          iInc++;
        } else if (source == 2) {
          iPln++;
        }
      } else {
        break;
      }
    }
    final recentTransactions = allEntries;

    // 4. Generate behavioral insights
    final insights = await insightEngineService.generateInsights(
      now,
      budgetLimit,
      spentThisMonth,
    );

    return DashboardViewModel(
      cashflowBalance: balanceThisMonth,
      incomeThisMonth: incomeThisMonth,
      spentThisMonth: spentThisMonth,
      budgetLimit: budgetLimit,
      budgetRemaining: (budgetLimit != null && spentInActivePeriod != null)
          ? (budgetLimit - spentInActivePeriod)
          : null,
      budgetUsageRatio: budgetUsageRatio,
      recentTransactions: recentTransactions,
      insights: insights,
      weeklySparkData: weeklySparkData,
      topCategoryName: topCategoryName,
      topCategoryAmount: topCategoryAmount,
      isLoading: isLoading,
    );
  }
}
