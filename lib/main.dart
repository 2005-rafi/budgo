import 'package:expense/provider/reports_provider.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/budget_provider.dart';
import 'package:expense/provider/theme_provider.dart';
import 'package:expense/themes/util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/services/alert_throttle_service.dart';

import 'package:expense/screens/splash_screen.dart';
import 'package:expense/screens/app_shell.dart';
import 'package:expense/screens/reports_screen.dart';
import 'package:expense/screens/income_screen.dart';
import 'package:expense/screens/future_expenses_screen.dart';

// Import new providers and services
import 'package:expense/provider/app_navigation_provider.dart';
import 'package:expense/provider/dashboard_provider.dart';
import 'package:expense/provider/activity_provider.dart';
import 'package:expense/services/dashboard_service.dart';
import 'package:expense/services/activity_service.dart';
import 'package:expense/services/insight_engine_service.dart';

// Import routes, constants, and repositories
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/provider/finance_boxes.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/repositories/future_expense_repository.dart';
import 'package:expense/repositories/budget_repository.dart';
import 'package:expense/provider/app_preferences_provider.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/navigation/app_page_route.dart';
import 'package:expense/core/app_readiness_notifier.dart';
import 'package:expense/core/app_initializer.dart';

void main() async {
  // Phase 1: Pre-initialization (Hive, SharedPreferences, Migration)
  final prefs = await AppInitializer.preInit();

  // Phase 2: Repository & Service Setup
  final expenseRepo = HiveExpenseRepository(FinanceBoxes.expenses);
  final budgetRepo = HiveBudgetRepository(FinanceBoxes.budgets);
  final incomeRepo = HiveIncomeRepository();
  final futureExpenseRepo = HiveFutureExpenseRepository();
  final reminderRepo = HiveReminderRepository();

  final reportsDataService = ReportsDataService();
  final alertThrottleService = AlertThrottleService(prefs);

  final insightEngineService = InsightEngineService(
    reminderRepo: reminderRepo,
    reportsDataService: reportsDataService,
  );
  final dashboardService = DashboardService(
    reportsDataService: reportsDataService,
    insightEngineService: insightEngineService,
  );
  final activityService = ActivityService();

  // Phase 3: Provider Setup
  final appReadiness = AppReadinessNotifier();
  final themeProvider = ThemeProvider();
  final appPrefsProvider = AppPreferencesProvider(prefs);

  final expensesProvider = ExpensesProvider(expenseRepo, reportsDataService);
  final budgetProvider = BudgetProvider(budgetRepo, alertThrottleService);
  final incomeProvider = IncomeProvider(incomeRepo);
  final futureExpensesProvider = FutureExpensesProvider(
    futureExpenseRepo,
    expenseRepo,
  );
  final reminderProvider = ReminderProvider(reminderRepo);

  // Phase 4: Post-initialization (Parallel with App Startup)
  // We trigger postInit immediately. It handles all provider initializations
  // and marks appReadiness.ready when complete, allowing the SplashScreen to transition.
  AppInitializer.postInit(
    expensesProvider: expensesProvider,
    budgetProvider: budgetProvider,
    incomeProvider: incomeProvider,
    futureExpensesProvider: futureExpensesProvider,
    reminderProvider: reminderProvider,
    appReadiness: appReadiness,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: appPrefsProvider),
        ChangeNotifierProvider.value(value: appReadiness),
        ChangeNotifierProvider.value(value: expensesProvider),
        ChangeNotifierProvider.value(value: incomeProvider),
        ChangeNotifierProvider.value(value: reminderProvider),
        ChangeNotifierProvider(create: (_) => AppNavigationProvider()),
        ChangeNotifierProxyProvider2<
          IncomeProvider,
          ExpensesProvider,
          BudgetProvider
        >(
          create: (_) => budgetProvider,
          update: (_, income, expenses, budget) {
            budget ??= budgetProvider;
            budget.attachIncome(income);
            budget.attachExpenses(expenses);
            return budget;
          },
        ),
        ChangeNotifierProxyProvider<ExpensesProvider, FutureExpensesProvider>(
          create: (_) => futureExpensesProvider,
          update: (_, expensesProvider, futureProvider) {
            futureProvider ??= futureExpensesProvider;
            futureProvider.attachExpenses(expensesProvider);
            return futureProvider;
          },
        ),
        ChangeNotifierProxyProvider<ExpensesProvider, ReportsProvider>(
          create: (_) => ReportsProvider(service: reportsDataService),
          update: (_, expensesProvider, reportsProvider) {
            reportsProvider ??= ReportsProvider(service: reportsDataService);
            reportsProvider.onExpensesUpdated(expensesProvider);
            return reportsProvider;
          },
        ),
        ChangeNotifierProxyProvider4<
          ExpensesProvider,
          IncomeProvider,
          FutureExpensesProvider,
          BudgetProvider,
          DashboardProvider
        >(
          create: (context) => DashboardProvider(
            service: dashboardService,
            expensesProvider: Provider.of<ExpensesProvider>(
              context,
              listen: false,
            ),
            incomeProvider: Provider.of<IncomeProvider>(context, listen: false),
            futureExpensesProvider: Provider.of<FutureExpensesProvider>(
              context,
              listen: false,
            ),
            budgetProvider: Provider.of<BudgetProvider>(context, listen: false),
          ),
          update: (context, expenses, income, future, budget, previous) =>
              previous ??
              DashboardProvider(
                service: dashboardService,
                expensesProvider: expenses,
                incomeProvider: income,
                futureExpensesProvider: future,
                budgetProvider: budget,
              ),
        ),
        ChangeNotifierProxyProvider3<
          ExpensesProvider,
          IncomeProvider,
          FutureExpensesProvider,
          ActivityProvider
        >(
          create: (context) => ActivityProvider(
            service: activityService,
            expensesProvider: Provider.of<ExpensesProvider>(
              context,
              listen: false,
            ),
            incomeProvider: Provider.of<IncomeProvider>(context, listen: false),
            futureExpensesProvider: Provider.of<FutureExpensesProvider>(
              context,
              listen: false,
            ),
          ),
          update: (context, expenses, income, future, previous) =>
              previous ??
              ActivityProvider(
                service: activityService,
                expensesProvider: expenses,
                incomeProvider: income,
                futureExpensesProvider: future,
              ),
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
    TextTheme textTheme = createTextTheme(context, "Roboto", "Roboto");
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Budgo',
          theme: themeProvider.lightTheme.copyWith(
            textTheme: textTheme.apply(
              bodyColor: themeProvider.lightTheme.colorScheme.onSurface,
              displayColor: themeProvider.lightTheme.colorScheme.onSurface,
            ),
          ),
          darkTheme: themeProvider.darkTheme.copyWith(
            textTheme: textTheme.apply(
              bodyColor: themeProvider.darkTheme.colorScheme.onSurface,
              displayColor: themeProvider.darkTheme.colorScheme.onSurface,
            ),
          ),
          themeMode: themeProvider.themeMode,

          initialRoute: AppRoutes.splash,

          onGenerateRoute: (settings) {
            Widget builder;
            switch (settings.name) {
              case AppRoutes.splash:
                return PageRouteBuilder(
                  settings: settings,
                  pageBuilder: (context, anim, secAnim) => const SplashScreen(),
                  transitionsBuilder: (context, anim, secAnim, child) =>
                      FadeTransition(opacity: anim, child: child),
                );
              case AppRoutes.home:
                builder = const AppShell();
                break;
              case AppRoutes.reports:
                builder = const ReportsScreen();
                break;
              case AppRoutes.income:
                builder = const IncomeScreen();
                break;
              case AppRoutes.futureExpenses:
                builder = const FutureExpensesScreen();
                break;
              default:
                builder = const AppShell();
            }
            return AppPageRoute(child: builder, settings: settings);
          },
        );
      },
    );
  }
}
