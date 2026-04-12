import 'package:expense/models/budget.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/budget_provider.dart';
import 'package:expense/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:expense/models/expense.dart';
import 'package:expense/screens/add_expense_screen.dart';
import 'package:expense/screens/expense_list_screen.dart';
import 'package:expense/screens/home_screen.dart';
import 'package:expense/screens/splash_screen.dart';
import 'package:expense/screens/settings_screen.dart';

// Import new screens
import 'package:expense/screens/income_screen.dart';
import 'package:expense/screens/future_expenses_screen.dart';
import 'package:expense/screens/budget_screen.dart';
import 'package:expense/screens/reports_screen.dart';

// Import routes
import 'package:expense/navigation/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);

  // Register adapters
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(IncomeAdapter());
  Hive.registerAdapter(FutureExpenseAdapter());
  Hive.registerAdapter(BudgetAdapter());

  // Open boxes
  await Hive.openBox<Expense>('expenses');
  await Hive.openBox<Income>('incomes');
  await Hive.openBox<FutureExpense>('future_expenses');
  await Hive.openBox<Budget>('budgets');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ExpensesProvider()..load()),
        ChangeNotifierProvider(create: (_) => IncomeProvider()..load()),
        ChangeNotifierProvider(create: (_) => FutureExpensesProvider()..load()),
        ChangeNotifierProxyProvider<IncomeProvider, BudgetProvider>(
          create: (_) => BudgetProvider()..load(),
          update: (_, income, budget) {
            budget ??= BudgetProvider()..load();
            budget.attachIncome(income);
            return budget;
          },
        ),
        ChangeNotifierProxyProvider<ExpensesProvider, FutureExpensesProvider>(
          create: (_) => FutureExpensesProvider()..load(),
          update: (_, expensesProvider, futureProvider) {
            futureProvider ??= FutureExpensesProvider()..load();
            futureProvider.attachExpenses(expensesProvider);
            return futureProvider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Budgo',
          theme: themeProvider.materialTheme.darkScheme().copyWith(
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: themeProvider.materialTheme.darkScheme().copyWith(
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          themeMode: themeProvider.themeMode,

          initialRoute: AppRoutes.splash,

          routes: {
            // Existing routes
            AppRoutes.splash: (context) => const SplashScreen(),
            AppRoutes.home: (context) => const HomeScreen(),
            '/add-expense': (context) => const AddExpenseScreen(),
            AppRoutes.expenses: (context) => const ExpenseListScreen(),
            AppRoutes.settings: (context) => const SettingsScreen(),

            // New routes for Phase 3
            AppRoutes.income: (context) => const IncomeScreen(),
            AppRoutes.futureExpenses: (context) => const FutureExpensesScreen(),
            AppRoutes.budget: (context) => const BudgetScreen(),
            AppRoutes.reports: (context) => const ReportsScreen(),
          },
        );
      },
    );
  }
}
