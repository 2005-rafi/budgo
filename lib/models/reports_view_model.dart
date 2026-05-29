import 'package:expense/models/expense.dart';
import 'package:flutter/material.dart';

class ChartBarPoint {
  final int xLabel;
  final int value;
  final String displayLabel;

  const ChartBarPoint({
    required this.xLabel,
    required this.value,
    required this.displayLabel,
  });
}

class ChartPieSlice {
  final String category;
  final int amount;
  final double percentage;
  final int colorIndex;

  const ChartPieSlice({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.colorIndex,
  });
}

class ReportsViewModel {
  final int totalSpent;
  final int transactionCount;
  final int avgPerExpense;
  final String topCategory;
  final int topCategoryAmount;
  final List<ChartBarPoint> barPoints;
  final List<ChartPieSlice> pieSlices;
  final List<Expense> topExpenses;
  final Map<int, int> rangeHeatmap;
  final DateTimeRange activeRange;
  final String granularity;
  final bool useLogScale;
  
  // New getters for screen (Task 4-C)
  final int dailyAverage;
  final List<ChartBarPoint> dailySpending;
  final List<ChartPieSlice> categoryDistribution;
  final int maxDailySpent;
  final List<ChartPieSlice> topCategories;
  final int yearMaxDailySpend;
  final int weekdayAvg;
  final int weekendAvg;

  const ReportsViewModel({
    required this.totalSpent,
    required this.transactionCount,
    required this.avgPerExpense,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.barPoints,
    required this.pieSlices,
    required this.topExpenses,
    required this.rangeHeatmap,
    required this.activeRange,
    required this.granularity,
    required this.useLogScale,
    required this.dailyAverage,
    required this.dailySpending,
    required this.categoryDistribution,
    required this.maxDailySpent,
    required this.topCategories,
    required this.yearMaxDailySpend,
    required this.weekdayAvg,
    required this.weekendAvg,
  });
}
