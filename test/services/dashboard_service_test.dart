import 'package:flutter_test/flutter_test.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/services/dashboard_service.dart';
import 'package:expense/services/insight_engine_service.dart';
import 'package:expense/services/reports_data_service.dart';

class FakeReminderRepository implements ReminderRepository {
  @override
  Future<List<Reminder>> getAll() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DashboardService Bounded Merge Tests', () {
    test('buildViewModel caps recent transactions at 10 and sorts descending', () async {
      final reportsService = ReportsDataService();
      final reminderRepo = FakeReminderRepository();
      final insightService = InsightEngineService(
        reminderRepo: reminderRepo,
        reportsDataService: reportsService,
      );

      final dashboardService = DashboardService(
        reportsDataService: reportsService,
        insightEngineService: insightService,
      );

      final now = DateTime(2026, 6, 15);

      // 15 expenses
      final expenses = List.generate(
        15,
        (i) => Expense(
          productName: 'Exp $i',
          amount: (i + 1) * 1000,
          category: 'Food',
          date: now.subtract(Duration(days: i)),
        ),
      );
      await reportsService.rebuild(expenses);

      // 10 incomes
      final incomes = List.generate(
        10,
        (i) => Income(
          id: 'inc_$i',
          source: 'Income $i',
          amount: 50000,
          date: now.subtract(Duration(hours: i * 12)),
          isConfirmed: true,
        ),
      );

      // 10 planned items (with arbitrary priority)
      final futureExpenses = List.generate(
        10,
        (i) => FutureExpense(
          id: 'fut_$i',
          title: 'Planned $i',
          priority: 3 - (i % 3), // Unsorted priorities
          dueDate: now.add(Duration(days: i)),
          isPurchased: false,
          category: 'Shopping',
        ),
      );

      final vm = await dashboardService.buildViewModel(
        now,
        incomes: incomes,
        futureExpenses: futureExpenses,
        budgetLimit: 1000000,
        spentInActivePeriod: 50000,
        budgetUsageRatio: 0.05,
        isMonthlyRefreshEnabled: true,
      );

      expect(vm.recentTransactions.length, lessThanOrEqualTo(10));
      expect(vm.recentTransactions.isNotEmpty, true);

      // Verify that merged entries are sorted in descending order by date
      for (int i = 0; i < vm.recentTransactions.length - 1; i++) {
        final current = vm.recentTransactions[i].date;
        final next = vm.recentTransactions[i + 1].date;
        expect(
          current.isAfter(next) || current.isAtSameMomentAs(next),
          true,
          reason: 'Entry $i ($current) should be >= entry ${i + 1} ($next)',
        );
      }
    });

    test('buildViewModel includes TransferEntry in 4-way merge and exposes totalBalance', () async {
      final reportsService = ReportsDataService();
      final reminderRepo = FakeReminderRepository();
      final insightService = InsightEngineService(
        reminderRepo: reminderRepo,
        reportsDataService: reportsService,
      );

      final dashboardService = DashboardService(
        reportsDataService: reportsService,
        insightEngineService: insightService,
      );

      final now = DateTime(2026, 6, 15);

      // 1 expense today
      final expenses = [
        Expense(
          productName: 'Coffee',
          amount: 25000,
          category: 'Food',
          date: now.subtract(const Duration(hours: 3)),
          workspaceId: 'ws_personal',
        ),
      ];
      await reportsService.rebuild(expenses);
      reportsService.setActiveWorkspace('ws_personal');

      // 1 income yesterday
      final incomes = [
        Income(
          id: 'inc_salary',
          source: 'Salary',
          amount: 1000000,
          date: now.subtract(const Duration(days: 1)),
          isConfirmed: true,
          workspaceId: 'ws_personal',
        ),
      ];

      // 1 inter-workspace transfer (most recent)
      final transfers = [
        Transfer(
          id: 'trf_1',
          sourceAccountId: 'acc_bank',
          destinationAccountId: 'acc_trip_cash',
          sourceWorkspaceId: 'ws_personal',
          destinationWorkspaceId: 'ws_goa_trip',
          amountPaise: 500000,
          date: now.subtract(const Duration(hours: 1)),
          status: TransferStatus.completed,
        ),
      ];

      final vm = await dashboardService.buildViewModel(
        now,
        incomes: incomes,
        futureExpenses: [],
        transfers: transfers,
        activeWorkspaceId: 'ws_personal',
        totalBalance: 750000,
        accountNames: {'acc_bank': 'HDFC Bank', 'acc_trip_cash': 'Trip Cash'},
        workspaceNames: {'ws_personal': 'Personal', 'ws_goa_trip': 'Goa Trip'},
        budgetLimit: 1000000,
        spentInActivePeriod: 25000,
        budgetUsageRatio: 0.025,
        isMonthlyRefreshEnabled: true,
      );

      expect(vm.totalBalance, 750000);
      expect(vm.recentTransactions.length, 3);

      // 1st entry should be the transfer (1 hour ago)
      expect(vm.recentTransactions[0], isA<TransferEntry>());
      final trfEntry = vm.recentTransactions[0] as TransferEntry;
      expect(trfEntry.direction, TransferDirection.outgoing);
      expect(trfEntry.displayName, 'Transfer to Goa Trip');
      expect(trfEntry.amount, 500000);

      // 2nd entry should be the expense (3 hours ago)
      expect(vm.recentTransactions[1], isA<ExpenseEntry>());

      // 3rd entry should be the income (1 day ago)
      expect(vm.recentTransactions[2], isA<IncomeEntry>());
    });
  });
}

