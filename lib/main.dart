import 'dart:async';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/core/initialization/app_initializer.dart';
import 'package:expense/core/initialization/app_readiness_notifier.dart';
import 'package:expense/design/components/budgo_startup_error_view.dart';
import 'package:expense/navigation/app_page_route.dart';
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/activity_provider.dart';
import 'package:expense/providers/app_navigation_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/providers/budget_provider.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/dashboard_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/future_expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/reports_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/providers/theme_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/budget_repository.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/repositories/future_expense_repository.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/repositories/savings_vault_repository.dart';
import 'package:expense/repositories/transfer_repository.dart';
import 'package:expense/repositories/workspace_repository.dart';
import 'package:expense/screens/about_screen.dart';
import 'package:expense/screens/app_shell.dart';
import 'package:expense/screens/reports_screen.dart';
import 'package:expense/screens/splash_screen.dart';
import 'package:expense/services/activity_service.dart';
import 'package:expense/services/alert_throttle_service.dart';
import 'package:expense/services/dashboard_service.dart';
import 'package:expense/services/data_lifecycle_service.dart';
import 'package:expense/services/insight_engine_service.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/services/transfer_engine_service.dart';
import 'package:expense/services/vault_allocation_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Guarantee offline zero-latency font resolution without network stalls on cold start.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Replace default Flutter red crash box with calm, user-friendly recovery UI.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Widget error captured: ${details.exceptionAsString()}');
    return Material(
      child: BudgoStartupErrorView(
        title: 'Something displayed unexpectedly',
        message:
            'A screen encountered an unexpected layout issue. Please close and reopen ${AppBrand.appName} cleanly. Your local data remains safe.',
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Unhandled platform error caught safely: $error\n$stack');
    return true;
  };

  // Lazy-safe repositories & services (zero synchronous disk I/O before Frame #1).
  final expenseRepo = HiveExpenseRepository();
  final budgetRepo = HiveBudgetRepository();
  final incomeRepo = HiveIncomeRepository();
  final futureExpenseRepo = HiveFutureExpenseRepository();
  final reminderRepo = HiveReminderRepository();
  final workspaceRepo = HiveWorkspaceRepository();
  final accountRepo = HiveAccountRepository();
  final transferRepo = HiveTransferRepository();
  final vaultRepo = HiveSavingsVaultRepository();

  final transferEngineService = TransferEngineService(
    accountRepo,
    transferRepo,
  );
  final vaultAllocationService = VaultAllocationService(
    accountRepository: accountRepo,
    vaultRepository: vaultRepo,
  );

  final dataLifecycleService = DataLifecycleService();
  final reportsDataService = ReportsDataService();
  final alertThrottleService = AlertThrottleService();

  final insightEngineService = InsightEngineService(
    reminderRepo: reminderRepo,
    reportsDataService: reportsDataService,
  );
  final dashboardService = DashboardService(
    reportsDataService: reportsDataService,
    insightEngineService: insightEngineService,
  );
  final activityService = ActivityService();

  // Instantaneous provider setup (zero blocking I/O).
  final appReadiness = AppReadinessNotifier();
  final themeProvider = ThemeProvider();
  final appPrefsProvider = AppPreferencesProvider();
  final categoryProvider = CategoryProvider();

  final workspaceProvider = WorkspaceProvider(
    workspaceRepo,
    lifecycleService: dataLifecycleService,
  );
  final accountProvider = AccountProvider(accountRepo);
  final transferProvider = TransferProvider(transferRepo, transferEngineService);
  final savingsVaultProvider = SavingsVaultProvider(
    repository: vaultRepo,
    allocationService: vaultAllocationService,
  );

  final expensesProvider = ExpensesProvider(
    expenseRepo,
    reportsDataService,
    lifecycleService: dataLifecycleService,
  );
  final reportsProvider = ReportsProvider(service: reportsDataService);
  final budgetProvider = BudgetProvider(budgetRepo, alertThrottleService);
  final incomeProvider = IncomeProvider(incomeRepo);
  final futureExpensesProvider = FutureExpensesProvider(
    futureExpenseRepo,
    expenseRepo,
  );
  final reminderProvider = ReminderProvider(reminderRepo)
    ..workspaceResolver = (wsId) {
      final ws = workspaceProvider.workspaces.firstWhereOrNull(
        (w) => w.id == wsId,
      );
      return ws != null ? WorkspaceNotificationMeta.fromWorkspace(ws) : null;
    };

  workspaceProvider.onWorkspaceChanged = (wsId) {
    expensesProvider.setActiveWorkspace(wsId);
    incomeProvider.setActiveWorkspace(wsId);
    accountProvider.setActiveWorkspace(wsId);
    transferProvider.setActiveWorkspace(wsId);
    savingsVaultProvider.setActiveWorkspace(wsId);
    reminderProvider.setActiveWorkspace(wsId);
    futureExpensesProvider.setActiveWorkspace(wsId);
    reportsProvider.setActiveWorkspace(wsId);
    budgetProvider.setActiveWorkspace(wsId);
  };

  workspaceProvider.onWorkspaceDeletedCascade = () async {
    await Future.wait([
      accountProvider.load(),
      transferProvider.load(),
      savingsVaultProvider.load(),
      expensesProvider.load(),
      incomeProvider.load(),
      futureExpensesProvider.load(),
      budgetProvider.load(),
      reminderProvider.load(),
    ]);
    await expensesProvider.deferredRebuild();
    reportsProvider.onExpensesUpdated(expensesProvider);
  };

  Future<void> runBootPipeline() => AppInitializer.boot(
        appReadiness: appReadiness,
        expensesProvider: expensesProvider,
        budgetProvider: budgetProvider,
        incomeProvider: incomeProvider,
        futureExpensesProvider: futureExpensesProvider,
        reminderProvider: reminderProvider,
        workspaceProvider: workspaceProvider,
        accountProvider: accountProvider,
        transferProvider: transferProvider,
        savingsVaultProvider: savingsVaultProvider,
        themeProvider: themeProvider,
        appPrefsProvider: appPrefsProvider,
        categoryProvider: categoryProvider,
        alertThrottleService: alertThrottleService,
        lifecycleService: dataLifecycleService,
      );

  appReadiness.attachRetryCallback(runBootPipeline);

  // Render Branded Splash immediately on Frame #1, then boot storage/OS/threads smoothly.
  runApp(
    MultiProvider(
      providers: [
        Provider<DataLifecycleService>.value(value: dataLifecycleService),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: appPrefsProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: appReadiness),
        ChangeNotifierProvider.value(value: workspaceProvider),
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: transferProvider),
        ChangeNotifierProvider.value(value: savingsVaultProvider),
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
          create: (_) => reportsProvider,
          update: (_, expensesProvider, rp) {
            rp ??= reportsProvider;
            rp.onExpensesUpdated(expensesProvider);
            return rp;
          },
        ),
        ChangeNotifierProvider<DashboardProvider>(
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
            appPreferencesProvider: Provider.of<AppPreferencesProvider>(
              context,
              listen: false,
            ),
            accountProvider: Provider.of<AccountProvider>(
              context,
              listen: false,
            ),
            transferProvider: Provider.of<TransferProvider>(
              context,
              listen: false,
            ),
            workspaceProvider: Provider.of<WorkspaceProvider>(
              context,
              listen: false,
            ),
            savingsVaultProvider: Provider.of<SavingsVaultProvider>(
              context,
              listen: false,
            ),
            reminderProvider: Provider.of<ReminderProvider>(
              context,
              listen: false,
            ),
          ),
        ),
        ChangeNotifierProvider<ActivityProvider>(
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
            transferProvider: Provider.of<TransferProvider>(
              context,
              listen: false,
            ),
            workspaceProvider: Provider.of<WorkspaceProvider>(
              context,
              listen: false,
            ),
            accountProvider: Provider.of<AccountProvider>(
              context,
              listen: false,
            ),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );

  unawaited(runBootPipeline());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final lightBase = themeProvider.lightTheme;
        final darkBase = themeProvider.darkTheme;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppBrand.appName,
          theme: lightBase.copyWith(
            textTheme: lightBase.textTheme.apply(
              fontFamily: 'Roboto',
              bodyColor: lightBase.colorScheme.onSurface,
              displayColor: lightBase.colorScheme.onSurface,
            ),
          ),
          darkTheme: darkBase.copyWith(
            textTheme: darkBase.textTheme.apply(
              fontFamily: 'Roboto',
              bodyColor: darkBase.colorScheme.onSurface,
              displayColor: darkBase.colorScheme.onSurface,
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
              case AppRoutes.about:
                builder = const AboutScreen();
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
