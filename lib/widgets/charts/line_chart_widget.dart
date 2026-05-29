import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense/core/money.dart';
import 'package:intl/intl.dart';

import 'package:expense/models/reports_view_model.dart';

class LineChartWidget extends StatefulWidget {
  final List<ChartBarPoint> data;
  final Color color;
  final DateTimeRange? range;
  final int? averageSpend;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.color,
    this.range,
    this.averageSpend,
  });

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  late List<FlSpot> _spots;
  late double _minX;
  late double _maxX;
  late double _minY;
  late double _maxY;

  @override
  void initState() {
    super.initState();
    _buildSpots();
  }

  @override
  void didUpdateWidget(LineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _buildSpots();
    }
  }

  void _buildSpots() {
    if (widget.data.isEmpty) {
      _spots = [];
      _minX = 0;
      _maxX = 0;
      _minY = 0;
      _maxY = 100;
      return;
    }

    _spots = widget.data.map((point) {
      return FlSpot(point.xLabel.toDouble(), point.value.toDouble());
    }).toList();

    _minX = _spots.first.x;
    _maxX = _spots.last.x;

    final values = widget.data.map((p) => p.value).toList();
    _minY = 0;
    _maxY = values.isEmpty
        ? 100
        : values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    if (_spots.isEmpty) return const Center(child: Text('No data'));
    final colorScheme = Theme.of(context).colorScheme;

    final rangeDays = widget.range != null
        ? widget.range!.end.difference(widget.range!.start).inDays + 1
        : 0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (widget.averageSpend != null && widget.averageSpend! > 0)
              HorizontalLine(
                y: widget.averageSpend!.toDouble(),
                color: colorScheme.secondary,
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  labelResolver: (line) =>
                      'Avg: ${widget.averageSpend!.formatCompact()}',
                ),
              ),
          ],
        ),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            if (widget.range != null && rangeDays <= 31)
              ...List.generate(rangeDays, (i) {
                final date = widget.range!.start.add(Duration(days: i));
                if (date.weekday == DateTime.saturday ||
                    date.weekday == DateTime.sunday) {
                  return VerticalRangeAnnotation(
                    x1: i.toDouble() - 0.5,
                    x2: i.toDouble() + 0.5,
                    color: colorScheme.surfaceContainerLow.withValues(
                      alpha: 0.5,
                    ),
                  );
                }
                return null;
              }).whereType<VerticalRangeAnnotation>(),
          ],
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _calculateBottomInterval(rangeDays),
              getTitlesWidget: (value, meta) {
                if (widget.range == null) {
                  return const SizedBox.shrink();
                }
                
                final index = value.toInt();
                if (index < 0 || index >= widget.data.length) {
                  return const SizedBox.shrink();
                }

                final date = widget.range!.start.add(Duration(days: index));
                String label = '';

                if (rangeDays <= 14) {
                  label = DateFormat('E').format(date);
                } else if (rangeDays <= 31) {
                  if (index == 0 || index == 14 || index == rangeDays - 1) {
                    label = date.day.toString();
                  } else {
                    return const SizedBox.shrink();
                  }
                } else {
                  if (index == 0 || (index > 0 && date.day == 1)) {
                    label = DateFormat('MMM').format(date);
                  } else {
                    return const SizedBox.shrink();
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: _maxY > 0 ? (_maxY / 4) : 1000,
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
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            left: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
        ),
        minX: _minX,
        maxX: _maxX,
        minY: _minY,
        maxY: _maxY,
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: true,
            color: widget.color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                // Only show dots for peak or if few points
                if (rangeDays <= 14) return true;
                return spot.y == _maxY / 1.2; // Peak dot
              },
              getDotPainter: (spot, percent, barData, index) {
                final isPeak = spot.y == _maxY / 1.2;
                return FlDotCirclePainter(
                  radius: isPeak ? 4 : 2,
                  color: isPeak ? colorScheme.tertiary : widget.color,
                  strokeWidth: 1,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0.2),
                  widget.color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) =>
                Theme.of(context).colorScheme.surfaceContainerHigh,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = widget.range?.start.add(Duration(days: index));
                final dateStr = date != null
                    ? DateFormat('MMM d').format(date)
                    : '';

                return LineTooltipItem(
                  '$dateStr\n${spot.y.toInt().format()}',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _calculateBottomInterval(int rangeDays) {
    if (rangeDays <= 7) return 1;
    if (rangeDays <= 14) return 2;
    if (rangeDays <= 31) return 1; // Handled by manual logic
    return 1; // Handled by manual logic
  }
}
