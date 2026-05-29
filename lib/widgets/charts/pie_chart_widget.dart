import 'package:flutter/material.dart';
import 'package:expense/core/app_motion.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:expense/models/reports_view_model.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/provider/app_navigation_provider.dart';
import 'package:expense/core/money.dart';

class PieChartWidget extends StatefulWidget {
  final List<ChartPieSlice> data;

  const PieChartWidget({super.key, required this.data});

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  int _touchedIndex = -1;

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase().trim()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'travel':
        return Icons.directions_car_outlined;
      case 'bills':
        return Icons.receipt_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'lend':
        return Icons.handshake_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'income':
        return Icons.arrow_downward_outlined;
      default:
        return Icons.attach_money_outlined;
    }
  }

  Color _getCategoryColor(String category, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lightPalette = {
      'food': const Color(0xFFE57373),         // Coral Red
      'travel': const Color(0xFF4FC3F7),       // Sky Blue
      'bills': const Color(0xFF81C784),        // Soft Green
      'shopping': const Color(0xFFFFB74D),     // Warm Amber
      'lend': const Color(0xFFBA68C8),         // Lavender Purple
      'entertainment': const Color(0xFFFF8A65),// Deep Apricot
      'health': const Color(0xFF4DB6AC),        // Minty Teal
      'education': const Color(0xFF90A4AE),     // Cool Grey
    };

    final darkPalette = {
      'food': const Color(0xFFEF9A9A),         // Soft Rose
      'travel': const Color(0xFF81D4FA),       // Pastel Sky Blue
      'bills': const Color(0xFFA5D6A7),        // Light Mint
      'shopping': const Color(0xFFFFCC80),     // Soft Orange
      'lend': const Color(0xFFE1BEE7),         // Soft Lavender
      'entertainment': const Color(0xFFFFCCBC),// Cream Peach
      'health': const Color(0xFF80CBC4),        // Soft Teal
      'education': const Color(0xFFB0BEC5),     // Blue Grey
    };

    final key = category.trim().toLowerCase();
    final palette = isDark ? darkPalette : lightPalette;
    if (palette.containsKey(key)) {
      return palette[key]!;
    }

    final hash = key.hashCode.abs();
    final fallbackColors = isDark
        ? [const Color(0xFF9FA8DA), const Color(0xFFB39DDB), const Color(0xFF80DEEA), const Color(0xFFD7CCC8)]
        : [const Color(0xFF5C6BC0), const Color(0xFFAB47BC), const Color(0xFF26C6DA), const Color(0xFF8D6E63)];
    return fallbackColors[hash % fallbackColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const Center(child: Text('No data'));
    final colorScheme = Theme.of(context).colorScheme;

    final sections = widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final slice = entry.value;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 48.0 : 38.0;

      return PieChartSectionData(
        color: _getCategoryColor(slice.category, context),
        value: slice.amount.toDouble(),
        title: '', // Titles removed for a clean modern ring layout
        radius: radius,
        borderSide: BorderSide(
          color: isTouched
              ? colorScheme.primary.withValues(alpha: 0.6)
              : colorScheme.surfaceContainerHigh,
          width: isTouched ? 3.0 : 2.0,
        ),
      );
    }).toList();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 55,
                  sections: sections,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapDownEvent) {
                        if (pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          setState(() {
                            _touchedIndex = -1;
                          });
                          return;
                        }
                        final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (index >= 0 && index < widget.data.length) {
                          setState(() {
                            _touchedIndex = (_touchedIndex == index) ? -1 : index;
                          });
                        }
                      }
                    },
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedSwitcher(
                  duration: AppMotion.standard,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_touchedIndex),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _touchedIndex == -1 ? 'TOTAL SPENT' : widget.data[_touchedIndex].category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: _touchedIndex == -1
                                ? colorScheme.onSurfaceVariant
                                : _getCategoryColor(widget.data[_touchedIndex].category, context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _touchedIndex == -1
                              ? widget.data
                                  .fold<int>(0, (sum, s) => sum + s.amount)
                                  .formatCompact()
                              : widget.data[_touchedIndex].amount.formatCompact(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _touchedIndex == -1
                              ? 'All Categories'
                              : '${widget.data[_touchedIndex].percentage.toStringAsFixed(1)}% of total',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Premium Legend List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.data.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final slice = widget.data[index];
            final isTouched = index == _touchedIndex;

            return _LegendRow(
              color: _getCategoryColor(slice.category, context),
              icon: _getCategoryIcon(slice.category),
              label: slice.category,
              percentage: slice.percentage,
              amount: slice.amount,
              isHighlighted: isTouched,
              onTap: () {
                setState(() {
                  _touchedIndex = isTouched ? -1 : index;
                });
              },
            );
          },
        ),
        if (_touchedIndex != -1) ...[
          const SizedBox(height: 16),
          _DetailRow(
            slice: widget.data[_touchedIndex],
            categoryColor: _getCategoryColor(widget.data[_touchedIndex].category, context),
          ),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final double percentage;
  final int amount;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _LegendRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.percentage,
    required this.amount,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? colorScheme.primaryContainer.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerLow.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? colorScheme.primary.withValues(alpha: 0.24)
                : colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: isHighlighted ? 1.5 : 1.0,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Category Icon Badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Label
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                      color: isHighlighted ? colorScheme.primary : colorScheme.onSurface,
                    ),
              ),
            ),
            // Amount & Percentage
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amount.formatCompact(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final ChartPieSlice slice;
  final Color categoryColor;

  const _DetailRow({
    required this.slice,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: categoryColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: categoryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  slice.category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
                const Spacer(),
                Text(
                  slice.amount.format(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This category represents ${slice.percentage.toStringAsFixed(1)}% of your total spending for the selected period.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: () {
                  context.read<AppNavigationProvider>().setIndex(1);
                  Navigator.of(context).pushNamed(
                    '/activity',
                    arguments: FilterCriteria(categories: {slice.category}),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: const Text(
                  'View Transactions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
