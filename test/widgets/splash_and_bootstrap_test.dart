import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense/core/initialization/app_initializer.dart';
import 'package:expense/core/initialization/app_readiness_notifier.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/providers/budget_provider.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/future_expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/reminder_provider.dart';
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
import 'package:expense/screens/splash_screen.dart';
import 'package:expense/services/alert_throttle_service.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/services/transfer_engine_service.dart';
import 'package:expense/services/vault_allocation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SplashScreen renders branding, wavy progress bar, dynamic status, and transitions cleanly', (tester) async {
    final readiness = AppReadinessNotifier();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: readiness,
        child: MaterialApp(
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.home: (_) => const Scaffold(body: Text('Home Arrived')),
          },
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Budgo'), findsOneWidget);
    expect(find.text('FINANCIAL ASSISTANT'), findsOneWidget);
    expect(find.byType(BudgoWavyProgressIndicator), findsOneWidget);
    expect(find.text('Warming up your workspace'), findsOneWidget);

    readiness.updateProgress(0.68, 'Preparing your financial assistant');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Preparing your financial assistant'), findsOneWidget);

    readiness.markReady();
    // Advance past the 420ms minimum showcase hold + postFrame route transition
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Home Arrived'), findsOneWidget);
  });

  testWidgets('SplashScreen renders calm error recovery view on failure and supports Retry Startup', (tester) async {
    final readiness = AppReadinessNotifier();
    bool retryInvoked = false;
    readiness.attachRetryCallback(() async {
      retryInvoked = true;
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: readiness,
        child: MaterialApp(
          home: const SplashScreen(),
          routes: {
            AppRoutes.home: (_) => const Scaffold(body: Text('Home Arrived')),
          },
        ),
      ),
    );

    await tester.pump();

    readiness.markFailed(
      title: 'Storage unavailable',
      guidance: 'Please check device permissions and retry startup.',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BudgoStartupErrorView), findsOneWidget);
    expect(find.text('Storage unavailable'), findsOneWidget);
    expect(find.text('Retry Startup'), findsOneWidget);
    expect(find.text('Close App'), findsOneWidget);

    await tester.tap(find.text('Retry Startup'));
    await tester.pump();

    expect(retryInvoked, isTrue);
    expect(readiness.hasFailed, isFalse);
  });

  test('AppInitializer.boot completes cleanly despite OS notification failure and recovers from critical boot error on retry', () async {
    final tempDir = Directory.systemTemp.createTempSync('splash_boot_test');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall call) async {
      return tempDir.path;
    });
    SharedPreferences.setMockInitialValues({});

    try {
      final appReadiness = AppReadinessNotifier();
      final reportsDataService = ReportsDataService();
      final alertThrottleService = AlertThrottleService();
      final themeProvider = ThemeProvider();
      final appPrefsProvider = AppPreferencesProvider();
      final categoryProvider = CategoryProvider();

      final expRepo = HiveExpenseRepository();
      final incRepo = HiveIncomeRepository();
      final budgetRepo = HiveBudgetRepository();
      final futRepo = HiveFutureExpenseRepository();
      final remRepo = HiveReminderRepository();
      final wsRepo = HiveWorkspaceRepository();
      final accRepo = HiveAccountRepository();
      final trfRepo = HiveTransferRepository();
      final vaultRepo = HiveSavingsVaultRepository();

      final expProvider = ExpensesProvider(expRepo, reportsDataService);
      final budgetProvider = BudgetProvider(budgetRepo, alertThrottleService);
      final incProvider = IncomeProvider(incRepo);
      final futProvider = FutureExpensesProvider(futRepo, expRepo);
      final remProvider = ReminderProvider(remRepo);
      final wsProvider = WorkspaceProvider(wsRepo);
      final accProvider = AccountProvider(accRepo);
      final trfProvider = TransferProvider(
        trfRepo,
        TransferEngineService(accRepo, trfRepo),
      );
      final vaultProvider = SavingsVaultProvider(
        repository: vaultRepo,
        allocationService: VaultAllocationService(
          accountRepository: accRepo,
          vaultRepository: vaultRepo,
        ),
      );

      bool failPrefs = true;
      final List<String> seenMessages = [];
      appReadiness.addListener(() {
        seenMessages.add(appReadiness.statusMessage);
      });

      Future<void> runBoot() => AppInitializer.boot(
            appReadiness: appReadiness,
            expensesProvider: expProvider,
            budgetProvider: budgetProvider,
            incomeProvider: incProvider,
            futureExpensesProvider: futProvider,
            reminderProvider: remProvider,
            workspaceProvider: wsProvider,
            accountProvider: accProvider,
            transferProvider: trfProvider,
            savingsVaultProvider: vaultProvider,
            themeProvider: themeProvider,
            appPrefsProvider: appPrefsProvider,
            categoryProvider: categoryProvider,
            alertThrottleService: alertThrottleService,
            initStorageHook: () async {
              if (failPrefs) {
                throw FileSystemException('Simulated storage read error');
              }
              return SharedPreferences.getInstance();
            },
            initNotificationsHook: () async {
              throw TimeoutException('Simulated OS notification timeout');
            },
          );

      appReadiness.attachRetryCallback(runBoot);

      // 1. Simulate critical early storage failure -> must land cleanly in BootStatus.failed (never infinite loop)
      await runBoot();
      expect(appReadiness.hasFailed, isTrue);
      expect(appReadiness.errorTitle, isNotNull);
      expect(appReadiness.errorGuidance, isNot(contains('Exception:')));

      // 2. Retry after fault clears -> notification failure degrades gracefully & reaches ready!
      failPrefs = false;
      await appReadiness.retry();

      expect(appReadiness.isReady, isTrue);
      expect(appReadiness.progress, 1.0);
      expect(seenMessages, contains('Preparing your financial assistant'));
      expect(appReadiness.nonFatalWarnings, isNotEmpty);
      expect(wsProvider.workspaces, isNotEmpty);

      await Hive.close();
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  });
}
