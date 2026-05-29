import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense/core/money.dart';

import 'package:expense/models/reports_view_model.dart';

class BarChartWidget extends StatelessWidget {
  final List<ChartBarPoint> data;
  final Color color;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Find max value to scale Y axis
    final maxVal = data.map((p) => p.value).reduce((a, b) => a > b ? a : b).toDouble();
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.15;

    // Determine standard bar width based on data count
    final double barWidth = data.length <= 7 ? 16 : data.length <= 15 ? 10 : 6;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => colorScheme.surfaceContainerHigh,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= data.length) return null;
              final point = data[groupIndex];
              return BarTooltipItem(
                '${point.displayLabel}\n${point.value.format()}',
                TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: maxY > 0 ? (maxY / 4) : 1000,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().formatCompact(),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }

                // Show fewer labels if there are too many data points
                final interval = (data.length / 5).ceil();
                if (data.length > 7 && index % interval != 0 && index != data.length - 1) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    data[index].displayLabel,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            left: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: point.value.toDouble(),
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: barWidth,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
