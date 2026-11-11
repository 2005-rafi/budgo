import 'dart:math' as math;

enum SafeToSpendStatus {
  healthy,
  tight,
  deficit,
}

class SafeToSpendResult {
  final int dailyAllowancePaise;
  final int effectiveDiscretionaryPaise;
  final int daysRemaining;
  final int deficitPaise;
  final SafeToSpendStatus status;

  // Transparent derivation inputs for user-facing breakdown sheets
  final bool isBudgetedMode;
  final int? budgetLimitPaise;
  final int confirmedIncomeThisMonthPaise;
  final int spentThisMonthPaise;
  final int liquidUnallocatedPaise;
  final int pendingRemindersPaise;
  final int totalVaultsAllocatedPaise;
  final int daysInMonth;
  final int currentDay;
  final bool wasCappedByLiquidBalance;
  final int rawRemainingPoolPaise;

  const SafeToSpendResult({
    required this.dailyAllowancePaise,
    required this.effectiveDiscretionaryPaise,
    required this.daysRemaining,
    this.deficitPaise = 0,
    required this.status,
    this.isBudgetedMode = false,
    this.budgetLimitPaise,
    this.confirmedIncomeThisMonthPaise = 0,
    this.spentThisMonthPaise = 0,
    this.liquidUnallocatedPaise = 0,
    this.pendingRemindersPaise = 0,
    this.totalVaultsAllocatedPaise = 0,
    this.daysInMonth = 30,
    this.currentDay = 1,
    this.wasCappedByLiquidBalance = false,
    this.rawRemainingPoolPaise = 0,
  });

  bool get isDeficit => status == SafeToSpendStatus.deficit;
  bool get isTight => status == SafeToSpendStatus.tight;
  bool get isHealthy => status == SafeToSpendStatus.healthy;

  double get exactDailyPaise =>
      daysRemaining > 0 ? effectiveDiscretionaryPaise / daysRemaining : 0.0;
}

class SafeToSpendService {
  /// Computes the daily Safe-to-Spend allowance with absolute zero-division protection,
  /// physical liquid fund ceiling, and an honest signed deficit state.
  static SafeToSpendResult compute({
    required DateTime now,
    required int? budgetLimitPaise,
    required int spentThisMonthPaise,
    required int liquidUnallocatedPaise,
    required int confirmedIncomeThisMonthPaise,
    int pendingRemindersPaise = 0,
    int totalVaultsAllocatedPaise = 0,
  }) {
    // 1. Invariant Temporal Calculation: D >= 1 at all times
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = math.max(1, daysInMonth - now.day + 1);

    // 2. Budget vs Physical Liquid Availability
    final int rawPool;
    final int effectiveCap;
    final bool hasExplicitBudget =
        budgetLimitPaise != null && budgetLimitPaise > 0;

    if (hasExplicitBudget) {
      rawPool = budgetLimitPaise - spentThisMonthPaise;
      if (rawPool <= 0) {
        return SafeToSpendResult(
          dailyAllowancePaise: 0,
          effectiveDiscretionaryPaise: 0,
          daysRemaining: daysRemaining,
          deficitPaise: -rawPool,
          status: SafeToSpendStatus.deficit,
          isBudgetedMode: true,
          budgetLimitPaise: budgetLimitPaise,
          confirmedIncomeThisMonthPaise: confirmedIncomeThisMonthPaise,
          spentThisMonthPaise: spentThisMonthPaise,
          liquidUnallocatedPaise: liquidUnallocatedPaise,
          pendingRemindersPaise: pendingRemindersPaise,
          totalVaultsAllocatedPaise: totalVaultsAllocatedPaise,
          daysInMonth: daysInMonth,
          currentDay: now.day,
          wasCappedByLiquidBalance: false,
          rawRemainingPoolPaise: rawPool,
        );
      }
      // Cannot spend more than physical unallocated liquid funds
      effectiveCap = math.min(rawPool, liquidUnallocatedPaise);
    } else {
      // Unbudgeted fallback: confirmed income minus spent minus pending bills
      rawPool =
          confirmedIncomeThisMonthPaise - spentThisMonthPaise - pendingRemindersPaise;
      effectiveCap = math.min(rawPool, liquidUnallocatedPaise);
    }

    final bool wasCapped = effectiveCap < rawPool;

    // 3. Deficit or Zero Check
    if (effectiveCap <= 0) {
      return SafeToSpendResult(
        dailyAllowancePaise: 0,
        effectiveDiscretionaryPaise: 0,
        daysRemaining: daysRemaining,
        deficitPaise: effectiveCap < 0 ? -effectiveCap : 0,
        status: SafeToSpendStatus.deficit,
        isBudgetedMode: hasExplicitBudget,
        budgetLimitPaise: budgetLimitPaise,
        confirmedIncomeThisMonthPaise: confirmedIncomeThisMonthPaise,
        spentThisMonthPaise: spentThisMonthPaise,
        liquidUnallocatedPaise: liquidUnallocatedPaise,
        pendingRemindersPaise: pendingRemindersPaise,
        totalVaultsAllocatedPaise: totalVaultsAllocatedPaise,
        daysInMonth: daysInMonth,
        currentDay: now.day,
        wasCappedByLiquidBalance: wasCapped,
        rawRemainingPoolPaise: rawPool,
      );
    }

    // 4. Daily Allowance Distribution (floor division keeps daysRemaining * daily <= effectiveCap)
    final dailyPaise = effectiveCap ~/ daysRemaining;

    // Thresholds: tight if allowance < ₹200 (20,000 paise)
    final status =
        dailyPaise < 20000 ? SafeToSpendStatus.tight : SafeToSpendStatus.healthy;

    return SafeToSpendResult(
      dailyAllowancePaise: dailyPaise,
      effectiveDiscretionaryPaise: effectiveCap,
      daysRemaining: daysRemaining,
      deficitPaise: 0,
      status: status,
      isBudgetedMode: hasExplicitBudget,
      budgetLimitPaise: budgetLimitPaise,
      confirmedIncomeThisMonthPaise: confirmedIncomeThisMonthPaise,
      spentThisMonthPaise: spentThisMonthPaise,
      liquidUnallocatedPaise: liquidUnallocatedPaise,
      pendingRemindersPaise: pendingRemindersPaise,
      totalVaultsAllocatedPaise: totalVaultsAllocatedPaise,
      daysInMonth: daysInMonth,
      currentDay: now.day,
      wasCappedByLiquidBalance: wasCapped,
      rawRemainingPoolPaise: rawPool,
    );
  }
}

