import 'package:flutter/foundation.dart';
import 'package:expense/models/transaction_entry.dart';
import 'insight_model.dart';

@immutable
class DashboardViewModel {
  final int cashflowBalance;
  final int incomeThisMonth;
  final int spentThisMonth;
  final int? budgetLimit;          // null if budget mode off
  final int? budgetRemaining;      // null if budget mode off
  final double? budgetUsageRatio;     // null if budget mode off
  final List<TransactionEntry> recentTransactions;  // exactly 10
  final List<InsightModel> insights;                // 1–5
  final List<int> weeklySparkData;               // exactly 7
  final String topCategoryName;
  final int topCategoryAmount;
  final bool isLoading;
  final String? errorMessage;

  const DashboardViewModel({
    required this.cashflowBalance,
    required this.incomeThisMonth,
    required this.spentThisMonth,
    this.budgetLimit,
    this.budgetRemaining,
    this.budgetUsageRatio,
    required this.recentTransactions,
    required this.insights,
    required this.weeklySparkData,
    required this.topCategoryName,
    required this.topCategoryAmount,
    this.isLoading = false,
    this.errorMessage,
  });

  factory DashboardViewModel.empty() => const DashboardViewModel(
        cashflowBalance: 0,
        incomeThisMonth: 0,
        spentThisMonth: 0,
        recentTransactions: [],
        insights: [],
        weeklySparkData: [0, 0, 0, 0, 0, 0, 0],
        topCategoryName: '',
        topCategoryAmount: 0,
      );
}
