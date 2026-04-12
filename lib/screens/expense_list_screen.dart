import 'package:expense/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:expense/models/expense.dart';

class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});
  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final box = Hive.box<Expense>('expenses');

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("All Expenses"),
          backgroundColor: color.primary,
          foregroundColor: color.onPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/home'),
          ),
        ),
        body: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<Expense> box, _) {
            final expenses = box.values.toList().reversed.toList();

            final Map<String, double> categoryTotals = {};
            double totalAmount = 0.0;

            for (var exp in expenses) {
              totalAmount += exp.amount;
              categoryTotals.update(
                exp.category,
                (value) => value + exp.amount,
                ifAbsent: () => exp.amount,
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Spent: ₹${totalAmount.toStringAsFixed(2)}",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color.onSurface, // or color.onSurfaceVariant
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Chart Section
                  if (categoryTotals.isNotEmpty) ...[
                    Text(
                      "📊 Expense by Category",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color.onSurface, // or color.onSurfaceVariant
                      ),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 1.3,
                      child: PieChart(
                        PieChartData(
                          sections: _generateChartSections(
                            categoryTotals,
                            totalAmount,
                            color,
                            theme,
                          ),
                          centerSpaceRadius: 30,
                          sectionsSpace: 2,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    "📅 Expenses List",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color.onSurface, // or color.onSurfaceVariant
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (expenses.isEmpty)
                    Center(
                      child: Text(
                        "No expenses found.",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color.onSurface, // or color.onSurfaceVariant
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final exp = expenses[index];
                        return Card(
                          elevation: 1,
                          color: color.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.secondaryContainer,
                              foregroundColor: color.onSecondaryContainer,
                              child: Text(
                                exp.category[0].toUpperCase(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: color.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              exp.productName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: color.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              "${exp.category} • ${DateFormat.yMMMd().format(exp.date)}",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: color.onSurface,
                              ),
                            ),
                            trailing: Text(
                              "₹${exp.amount.toStringAsFixed(2)}",
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: color.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<PieChartSectionData> _generateChartSections(
    Map<String, double> categoryTotals,
    double totalAmount,
    ColorScheme color,
    ThemeData theme,
  ) {
    final List<Color> sectionColors = [
      color.primary,
      color.secondary,
      color.tertiary,
      color.primaryContainer,
      color.secondaryContainer,
      color.tertiaryContainer,
      color.errorContainer,
    ];

    final List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    categoryTotals.forEach((category, amount) {
      final percent = (amount / totalAmount) * 100;
      final sectionColor = sectionColors[colorIndex % sectionColors.length];
      colorIndex++;

      sections.add(
        PieChartSectionData(
          title: "$category\n${percent.toStringAsFixed(1)}%",
          value: amount,
          radius: 60,
          titleStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          color: sectionColor,
        ),
      );
    });

    return sections;
  }
}
