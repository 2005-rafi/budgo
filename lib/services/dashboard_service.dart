import 'package:expense/models/transaction_entry.dart';
import 'package:expense/models/view_models/dashboard_view_model.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/services/insight_engine_service.dart';
import 'package:expense/services/safe_to_spend_service.dart';

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
    List<Transfer> transfers = const [],
    String activeWorkspaceId = '',
    int? totalBalance,
    SafeToSpendResult? safeToSpend,
    int totalVaultsAllocated = 0,
    Map<String, String> accountNames = const {},
    Map<String, String> workspaceNames = const {},
    required int? budgetLimit,
    required int? spentInActivePeriod,
    required double? budgetUsageRatio,
    required bool isMonthlyRefreshEnabled,
    bool isLoading = false,
  }) async {
    final currentMonthKey = now.year * 100 + now.month;
    final effectiveWs = activeWorkspaceId.isEmpty
        ? 'default_personal'
        : activeWorkspaceId;
    final partition = reportsDataService.partitionFor(effectiveWs);

    // Defensive workspace isolation if callers supply unfiltered lists
    String normWs(String wsId) => wsId.isEmpty ? 'default_personal' : wsId;
    final scopedIncomes = incomes
        .where((i) => normWs(i.workspaceId) == effectiveWs)
        .toList();
    final scopedFutureExpenses = futureExpenses
        .where((f) => normWs(f.workspaceId) == effectiveWs)
        .toList();

    final spentThisMonth = isMonthlyRefreshEnabled
        ? (partition.monthTotals[currentMonthKey] ?? 0)
        : partition.allCatTotals.values.fold(0, (sum, val) => sum + val);

    // Calculate confirmed income
    final incomeThisMonth = isMonthlyRefreshEnabled
      ? scopedIncomes
          .where((i) =>
              i.isConfirmed &&
              i.date.year == now.year &&
              i.date.month == now.month)
          .fold<int>(0, (sum, i) => sum + i.amount)
      : scopedIncomes
          .where((i) => i.isConfirmed)
          .fold<int>(0, (sum, i) => sum + i.amount);

    final balanceThisMonth = incomeThisMonth - spentThisMonth;

    // 1. Calculate top category for current month (strictly within active workspace)
    final currentMonthStart = partition.toEpochDay(
      DateTime(now.year, now.month, 1),
    );
    final currentMonthEnd = partition.toEpochDay(
      DateTime(now.year, now.month + 1, 0),
    );
    final startIdx = partition.lowerBound(currentMonthStart);
    final endIdx = partition.upperBound(currentMonthEnd);
    final thisMonthExpenses = partition.slice(startIdx, endIdx);

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
      final epochDay = partition.toEpochDay(date);
      final dailyTotal = partition.dayTotals[epochDay] ?? 0;
      weeklySparkData.add(dailyTotal);
    }

    // 3. Generate combined recent transactions (max 10) using bounded candidates
    final List<TransactionEntry> allEntries = [];

    // Bounded candidate selection: take at most 10 items from active workspace partition
    final expenseEntries = partition.sortedAsc.reversed
        .take(10)
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

    final incomeEntries = scopedIncomes
        .take(10)
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

    final unpurchasedPlanned = scopedFutureExpenses
        .where((f) => !f.isPurchased)
        .toList();
    unpurchasedPlanned.sort((a, b) {
      final da = a.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    final plannedEntries = unpurchasedPlanned
        .take(10)
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

    final transferEntries = transfers
        .where((t) =>
            activeWorkspaceId.isEmpty ||
            t.sourceWorkspaceId == activeWorkspaceId ||
            t.destinationWorkspaceId == activeWorkspaceId)
        .take(10)
        .map((t) {
          final isIntra = t.sourceWorkspaceId == t.destinationWorkspaceId;
          final isOut = t.sourceWorkspaceId == activeWorkspaceId;
          final direction = isIntra
              ? TransferDirection.intraWorkspace
              : isOut
                  ? TransferDirection.outgoing
                  : TransferDirection.incoming;

          final srcAcc = accountNames[t.sourceAccountId] ?? 'Account';
          final destAcc = accountNames[t.destinationAccountId] ?? 'Account';
          final otherWs = isIntra
              ? (workspaceNames[t.sourceWorkspaceId] ?? '')
              : isOut
                  ? (workspaceNames[t.destinationWorkspaceId] ?? 'Other Profile')
                  : (workspaceNames[t.sourceWorkspaceId] ?? 'Other Profile');

          final String displayName;
          if (isIntra) {
            displayName = 'Self-Transfer';
          } else if (isOut) {
            displayName = 'Transfer to $otherWs';
          } else {
            displayName = 'Transfer from $otherWs';
          }

          return TransferEntry(
            id: t.id,
            date: t.date,
            amount: t.amountPaise,
            displayName: displayName,
            category: 'Transfer',
            notes: t.note,
            rawTransfer: t,
            direction: direction,
            sourceAccountName: srcAcc,
            destinationAccountName: destAcc,
            otherWorkspaceName: otherWs,
          );
        })
        .toList();

    // Bounded 4-way merge pointers (max 10 items)
    int iExp = 0, iInc = 0, iPln = 0, iTrf = 0;
    while (allEntries.length < 10 &&
        (iExp < expenseEntries.length ||
            iInc < incomeEntries.length ||
            iPln < plannedEntries.length ||
            iTrf < transferEntries.length)) {
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

      if (iTrf < transferEntries.length) {
        if (best == null || transferEntries[iTrf].date.isAfter(best.date)) {
          best = transferEntries[iTrf];
          source = 3;
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
        } else if (source == 3) {
          iTrf++;
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
      workspaceId: activeWorkspaceId,
    );

    return DashboardViewModel(
      cashflowBalance: balanceThisMonth,
      totalBalance: totalBalance ?? balanceThisMonth,
      incomeThisMonth: incomeThisMonth,
      spentThisMonth: spentThisMonth,
      budgetLimit: budgetLimit,
      budgetRemaining: (budgetLimit != null && spentInActivePeriod != null)
          ? (budgetLimit - spentInActivePeriod)
          : null,
      budgetUsageRatio: budgetUsageRatio,
      safeToSpend: safeToSpend,
      totalVaultsAllocated: totalVaultsAllocated,
      recentTransactions: recentTransactions,
      insights: insights,
      weeklySparkData: weeklySparkData,
      topCategoryName: topCategoryName,
      topCategoryAmount: topCategoryAmount,
      isLoading: isLoading,
    );
  }
}
