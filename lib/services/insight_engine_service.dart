import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:expense/models/view_models/insight_model.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/core/money.dart';
import 'package:expense/models/reminder.dart';

class InsightEngineService {
  final ReminderRepository reminderRepo;
  final ReportsDataService reportsDataService;

  InsightEngineService({
    required this.reminderRepo,
    required this.reportsDataService,
  });

  Future<List<InsightModel>> generateInsights(
    DateTime now,
    int? budgetLimit,
    int? spentThisMonth,
  ) async {
    // 1. Fetch data from repos/services
    final List<Reminder> reminders = await reminderRepo.getAll();

    // Prepare serializable payload for isolate
    final payload = {
      'now': now.toIso8601String(),
      'budgetLimit': budgetLimit,
      'spentThisMonth': spentThisMonth,
      'monthTotals': reportsDataService.monthTotals,
      'monthCatTotals': reportsDataService.monthCatTotals,
      'reminders': reminders
          .map(
            (r) => {
              'id': r.id,
              'title': r.title,
              'isActive': r.isActive,
              'scheduledAt': r.scheduledAt.toIso8601String(),
            },
          )
          .toList(),
    };

    // 2. Offload heuristic computation to isolate
    return await compute(_computeInsights, payload);
  }
}

List<InsightModel> _computeInsights(Map<String, dynamic> payload) {
  final List<InsightModel> insights = [];
  final DateTime now = DateTime.parse(payload['now']);
  final int? budgetLimit = payload['budgetLimit'];
  final int? spentThisMonth = payload['spentThisMonth'];
  final Map<int, int> monthTotals = Map<int, int>.from(payload['monthTotals']);
  final Map<int, Map<String, int>> monthCatTotals =
      (payload['monthCatTotals'] as Map).map(
        (k, v) => MapEntry(k as int, Map<String, int>.from(v)),
      );
  final List<Map<String, dynamic>> remindersData =
      List<Map<String, dynamic>>.from(payload['reminders']);

  // 1. Budget Over & Burn Rate check
  if (budgetLimit != null && spentThisMonth != null && budgetLimit > 0) {
    if (spentThisMonth > budgetLimit) {
      insights.add(
        const InsightModel(
          id: 'budget_over',
          title: 'Budget Exceeded',
          message:
              'You have exceeded your monthly limit! Consider pausing non-essential expenses.',
          type: 'warning',
          icon: Icons.error_outline,
        ),
      );
    } else {
      final daysInMonth = _getDaysInMonth(now.year, now.month);
      final elapsedDays = now.day;
      if (elapsedDays > 0) {
        final dailyBurn = spentThisMonth / elapsedDays;
        final projectedSpend = dailyBurn * daysInMonth;
        if (projectedSpend > budgetLimit * 1.1) {
          final diff = (projectedSpend - budgetLimit).round();
          insights.add(
            InsightModel(
              id: 'budget_burn_rate',
              title: 'High Burn Rate',
              message:
                  'At this rate, you will exceed your budget by ${diff.formatCompact()}.',
              type: 'warning',
              icon: Icons.warning_amber_outlined,
            ),
          );
        }
      }
    }
  }

  // 2. Reminders Due within 3 days
  final threeDaysFromNow = now.add(const Duration(days: 3));
  for (final r in remindersData) {
    final scheduledAt = DateTime.parse(r['scheduledAt']);
    if (r['isActive'] == true &&
        scheduledAt.isAfter(now) &&
        scheduledAt.isBefore(threeDaysFromNow)) {
      insights.add(
        InsightModel(
          id: 'reminder_${r['id']}',
          title: 'Bill Due Soon',
          message:
              '"${r['title']}" is due on ${_formatDayAndMonth(scheduledAt)}.',
          type: 'warning',
          icon: Icons.alarm_outlined,
        ),
      );
    }
  }

  // 3. Category Spike
  final currentMonthKey = now.year * 100 + now.month;
  final thisMonthCatTotals = monthCatTotals[currentMonthKey] ?? {};

  if (thisMonthCatTotals.isNotEmpty) {
    final topCatEntry = thisMonthCatTotals.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    final topCat = topCatEntry.key;
    final topCatAmount = topCatEntry.value;

    int pastThreeMonthsCatTotal = 0;
    int monthsCount = 0;
    for (int i = 1; i <= 3; i++) {
      var targetYear = now.year;
      var targetMonth = now.month - i;
      if (targetMonth <= 0) {
        targetYear -= 1;
        targetMonth += 12;
      }
      final pmKey = targetYear * 100 + targetMonth;
      final pmCatTotals = monthCatTotals[pmKey];
      if (pmCatTotals != null) {
        pastThreeMonthsCatTotal += pmCatTotals[topCat] ?? 0;
        monthsCount++;
      }
    }

    if (monthsCount > 0) {
      final avgCatSpend = pastThreeMonthsCatTotal / monthsCount;
      if (avgCatSpend > 0 && topCatAmount > avgCatSpend * 1.5) {
        insights.add(
          InsightModel(
            id: 'category_spike_$topCat',
            title: 'Spike in $topCat',
            message:
                'You spent ${topCatAmount.format()} on $topCat this month, above your typical average.',
            type: 'warning',
            icon: Icons.trending_up_outlined,
          ),
        );
      }
    }
  }

  // 4. Savings Observation
  var lmYear = now.year;
  var lmMonth = now.month - 1;
  if (lmMonth <= 0) {
    lmYear -= 1;
    lmMonth += 12;
  }
  final lastMonthKey = lmYear * 100 + lmMonth;
  final lastMonthSpent = monthTotals[lastMonthKey] ?? 0;
  if (lastMonthSpent > 0 && spentThisMonth != null && spentThisMonth > 0) {
    if (spentThisMonth < lastMonthSpent * 0.9) {
      insights.add(
        InsightModel(
          id: 'savings_obs',
          title: 'Lower Spend Trend',
          message:
              'You have spent ${(lastMonthSpent - spentThisMonth).formatCompact()} less than last month at this stage.',
          type: 'success',
          icon: Icons.sentiment_very_satisfied_outlined,
        ),
      );
    }
  }

  if (insights.isEmpty) {
    insights.add(
      const InsightModel(
        id: 'all_good',
        title: 'Healthy Finances',
        message: 'Your spending is well within limits this month. Keep it up!',
        type: 'success',
        icon: Icons.check_circle_outline,
      ),
    );
  }

  // Priority ranking: overBudget > reminderDue > categorySpike > burnRate > savingsObservation
  insights.sort((a, b) {
    final aPriority = _getInsightPriority(a.id);
    final bPriority = _getInsightPriority(b.id);
    return aPriority.compareTo(bPriority);
  });

  return insights.take(5).toList();
}

int _getInsightPriority(String id) {
  if (id == 'budget_over') return 0;
  if (id.startsWith('reminder_')) return 1;
  if (id.startsWith('category_spike_')) return 2;
  if (id == 'budget_burn_rate') return 3;
  if (id == 'savings_obs') return 4;
  return 5;
}

int _getDaysInMonth(int year, int month) {
  if (month == DateTime.february) {
    final bool isLeapYear =
        (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);
    return isLeapYear ? 29 : 28;
  }
  const List<int> daysInMonth = [
    31,
    -1,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  return daysInMonth[month - 1];
}

String _formatDayAndMonth(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
