import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_constants.dart';
import 'package:expense/core/app_layout.dart';
import 'package:expense/core/money.dart';
import 'package:intl/intl.dart';

class CalendarHeatmapWidget extends StatelessWidget {
  final DateTime? month;
  final int? year;
  final Map<int, int> data;
  final int maxAmount;
  final int? normalizationMax; // Task 5-2
  final Function(DateTime, int)? onDayTap;
  final Function(DateTime)? onMonthTap;
  final bool showTitle;
  final bool isYearOverview;

  const CalendarHeatmapWidget({
    super.key,
    this.month,
    this.year,
    required this.data,
    required this.maxAmount,
    this.normalizationMax,
    this.onDayTap,
    this.onMonthTap,
    this.showTitle = false,
    this.isYearOverview = false,
  }) : assert(
         month != null || year != null,
         'Either month or year must be provided',
       );

  int _toEpochDay(DateTime date) {
    final localMidnight = DateTime(date.year, date.month, date.day);
    final utcMidnight = DateTime.utc(
      localMidnight.year,
      localMidnight.month,
      localMidnight.day,
    );
    final utcEpoch = DateTime.utc(
      AppConstants.kEpoch.year,
      AppConstants.kEpoch.month,
      AppConstants.kEpoch.day,
    );
    return utcMidnight.difference(utcEpoch).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final int effectiveMax = (normalizationMax ?? maxAmount) > 0
        ? (normalizationMax ?? maxAmount)
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            month != null
                ? DateFormat('MMMM yyyy').format(month!)
                : 'Year $year',
            style: AppTextStyles.title(
              context,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        isYearOverview
            ? _buildYearOverviewGrid(
                context,
                year ?? DateTime.now().year,
                effectiveMax,
              )
            : month != null
            ? _buildMonthGrid(context, month!, effectiveMax)
            : _buildYearGrid(context, year!, effectiveMax),

        const SizedBox(height: AppSpacing.lg),

        // 2-12 · Legend shows actual values
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              0.formatCompact(),
              style: AppTextStyles.labelSmall(context).copyWith(fontSize: 10),
            ),
            const SizedBox(width: AppSpacing.xs),
            _LegendBox(ratio: 0.0, maxAmount: effectiveMax),
            const SizedBox(width: 2),
            _LegendBox(ratio: 0.25, maxAmount: effectiveMax),
            const SizedBox(width: 2),
            _LegendBox(ratio: 0.5, maxAmount: effectiveMax),
            const SizedBox(width: 2),
            _LegendBox(ratio: 0.75, maxAmount: effectiveMax),
            const SizedBox(width: 2),
            _LegendBox(ratio: 1.0, maxAmount: effectiveMax),
            const SizedBox(width: AppSpacing.xs),
            Text(
              effectiveMax.formatCompact(),
              style: AppTextStyles.labelSmall(context).copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearOverviewGrid(
    BuildContext context,
    int year,
    int effectiveMax,
  ) {
    // Calculate monthly totals
    final Map<int, int> monthlyTotals = {};
    for (int m = 1; m <= 12; m++) {
      int total = 0;
      final daysInMonth = DateTime(year, m + 1, 0).day;
      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(year, m, d);
        total += data[_toEpochDay(date)] ?? 0;
      }
      monthlyTotals[m] = total;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final monthIdx = index + 1;
        final monthDate = DateTime(year, monthIdx, 1);
        final amount = monthlyTotals[monthIdx] ?? 0;

        return _MonthCell(
          date: monthDate,
          amount: amount,
          maxAmount: effectiveMax,
          onTap: onMonthTap,
        );
      },
    );
  }

  Widget _buildMonthGrid(
    BuildContext context,
    DateTime month,
    int effectiveMax,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final weekdayOfFirst = firstDay.weekday; // 1 = Mon, 7 = Sun

    // Adjust for Monday start (1)
    final paddingDays = weekdayOfFirst - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: paddingDays + daysInMonth,
      itemBuilder: (context, index) {
        if (index < paddingDays) return const SizedBox.shrink();

        final day = index - paddingDays + 1;
        final date = DateTime(month.year, month.month, day);
        final amount = data[_toEpochDay(date)] ?? 0;

        return _HeatmapCell(
          date: date,
          amount: amount,
          maxAmount: effectiveMax,
          onTap: onDayTap,
        );
      },
    );
  }

  Widget _buildYearGrid(BuildContext context, int year, int effectiveMax) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: List.generate(12, (i) {
        final monthDate = DateTime(year, i + 1, 1);
        return SizedBox(
          width:
              (MediaQuery.of(context).size.width -
                  AppLayout.screenPadding(context) * 2 -
                  AppSpacing.md * 2) /
              3.5,
          child: Column(
            children: [
              Text(
                DateFormat('MMM').format(monthDate),
                style: AppTextStyles.labelSmall(context),
              ),
              const SizedBox(height: 4),
              _buildMiniMonth(context, monthDate, effectiveMax),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMiniMonth(
    BuildContext context,
    DateTime month,
    int effectiveMax,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: 35, // Fixed size for alignment
      itemBuilder: (context, index) {
        final day = index - (firstDay.weekday - 1) + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

        final date = DateTime(month.year, month.month, day);
        final amount = data[_toEpochDay(date)] ?? 0;

        return _HeatmapCell(
          date: date,
          amount: amount,
          maxAmount: effectiveMax,
          isMini: true,
          onTap: onDayTap,
        );
      },
    );
  }
}

class _MonthCell extends StatelessWidget {
  final DateTime date;
  final int amount;
  final int maxAmount;
  final Function(DateTime)? onTap;

  const _MonthCell({
    required this.date,
    required this.amount,
    required this.maxAmount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFuture = date.isAfter(DateTime.now());

    Color cellColor;
    if (isFuture) {
      cellColor = colorScheme.surfaceContainerLowest.withValues(alpha: 0.4);
    } else if (amount == 0 || maxAmount <= 0) {
      cellColor = colorScheme.surfaceContainerLowest;
    } else {
      // 2-9 · Use same adaptive intensity scaling as 2-2
      final double amountRupees = amount / 100.0;
      final double maxRupees = maxAmount / 100.0;
      final double logAmount = math.log(amountRupees + 1);
      final double logMax = math.log(maxRupees + 1);
      final double ratio = (logAmount / (logMax > 0 ? logMax : 1)).clamp(
        0.0,
        1.0,
      );

      double opacity;
      if (ratio <= 0.0) {
        opacity = 0.0;
      } else if (ratio <= 0.1) {
        opacity = 0.15;
      } else if (ratio <= 0.25) {
        opacity = 0.30;
      } else if (ratio <= 0.45) {
        opacity = 0.50;
      } else if (ratio <= 0.65) {
        opacity = 0.70;
      } else if (ratio <= 0.85) {
        opacity = 0.85;
      } else {
        opacity = 1.0;
      }

      cellColor = colorScheme.primary.withValues(alpha: opacity);
    }

    final Color textColor = amount == 0 || isFuture
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : ThemeData.estimateBrightnessForColor(cellColor) == Brightness.dark
        ? Colors.white
        : colorScheme.onSurface;

    return Semantics(
      label: '${DateFormat('MMMM y').format(date)}: ${amount.format()}',
      child: Tooltip(
        message: '${DateFormat('MMMM y').format(date)}: ${amount.format()}',
        child: InkWell(
          onTap: isFuture ? null : () => onTap?.call(date),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          splashColor: colorScheme.primary.withValues(alpha: 0.15),
          child: Container(
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM').format(date),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (amount > 0)
                  Text(
                    amount.formatCompact(),
                    style: TextStyle(
                      fontSize: 8,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  final DateTime date;
  final int amount;
  final int maxAmount;
  final bool isMini;
  final Function(DateTime, int)? onTap;

  const _HeatmapCell({
    required this.date,
    required this.amount,
    required this.maxAmount,
    this.isMini = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final isFuture = date.isAfter(DateTime.now());

    Color cellColor;
    if (isFuture) {
      // 2-4 · Future days use surfaceContainerLowest at 40% opacity
      cellColor = colorScheme.surfaceContainerLowest.withValues(alpha: 0.4);
    } else if (amount == 0 || maxAmount <= 0) {
      // 2-3 · Zero-spend day uses surfaceContainerLowest
      cellColor = colorScheme.surfaceContainerLowest;
    } else {
      // 2-1 · Adaptive intensity scaling using Log scale for high variance
      // Handles dynamic expense ranges more gracefully than linear or pow
      final double amountRupees = amount / 100.0;
      final double maxRupees = maxAmount / 100.0;
      final double logAmount = math.log(amountRupees + 1);
      final double logMax = math.log(maxRupees + 1);
      final double ratio = (logAmount / (logMax > 0 ? logMax : 1)).clamp(
        0.0,
        1.0,
      );

      // 2-2 · Progressive intensity buckets (7 levels for finer granularity)
      double opacity;
      if (ratio <= 0.0) {
        opacity = 0.0;
      } else if (ratio <= 0.1) {
        opacity = 0.15;
      } else if (ratio <= 0.25) {
        opacity = 0.30;
      } else if (ratio <= 0.45) {
        opacity = 0.50;
      } else if (ratio <= 0.65) {
        opacity = 0.70;
      } else if (ratio <= 0.85) {
        opacity = 0.85;
      } else {
        opacity = 1.0;
      }

      cellColor = colorScheme.primary.withValues(alpha: opacity);
    }

    // 2-5 · WCAG AA text contrast on cells
    final Color textColor = amount == 0 || isFuture
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : ThemeData.estimateBrightnessForColor(cellColor) == Brightness.dark
        ? Colors.white
        : colorScheme.onSurface;

    return Semantics(
      // 2-11 · Semantics labels
      label: isFuture
          ? '${DateFormat('d MMM').format(date)}: no data'
          : amount == 0
          ? '${DateFormat('d MMM').format(date)}: no spending'
          : '${DateFormat('d MMM').format(date)}: ${amount.format()}',
      child: Tooltip(
        // 2-7 · Per-cell amount tooltip (using basic Tooltip for now as it handles positioning)
        message: isFuture
            ? 'Future date'
            : '${DateFormat('MMM d').format(date)}: ${amount.format()}',
        child: InkWell(
          // 2-6 · Cell tap feedback with InkWell
          onTap: isFuture ? null : () => onTap?.call(date, amount),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          splashColor: colorScheme.primary.withValues(alpha: 0.15),
          child: Container(
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: isToday
                  ? Border.all(
                      color: colorScheme.secondary,
                      width: isMini ? 1 : 1.5,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: isMini
                ? null
                : Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LegendBox extends StatelessWidget {
  final double ratio;
  final int maxAmount;

  const _LegendBox({required this.ratio, required this.maxAmount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color cellColor;
    if (ratio == 0) {
      cellColor = colorScheme.surfaceContainerLowest;
    } else {
      // Use same progressive buckets for legend consistency
      double opacity;
      if (ratio <= 0.1) {
        opacity = 0.15;
      } else if (ratio <= 0.25) {
        opacity = 0.30;
      } else if (ratio <= 0.45) {
        opacity = 0.50;
      } else if (ratio <= 0.65) {
        opacity = 0.70;
      } else if (ratio <= 0.85) {
        opacity = 0.85;
      } else {
        opacity = 1.0;
      }
      cellColor = colorScheme.primary.withValues(alpha: opacity);
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
