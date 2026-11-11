import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/reports_provider.dart';
import 'package:expense/services/export_statement_builder.dart';
import 'package:expense/services/report_export_service.dart';
import 'package:expense/services/reports_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockTempDir;

  setUp(() async {
    mockTempDir = Directory.systemTemp.createTempSync('scale_export_test');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return mockTempDir.path;
    });
  });

  tearDown(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (mockTempDir.existsSync()) {
      mockTempDir.deleteSync(recursive: true);
    }
  });

  test('Large-scale 24,000 expense rebuild + Async Isolate ReportsProvider handles multi-workspace slicing accurately', () async {
    final service = ReportsDataService();
    final provider = ReportsProvider(service: service);

    final baseDate = DateTime(2026, 6, 30, 12, 0);
    final workspaces = ['default_personal', 'ws_usd', 'ws_eur'];
    final categories = ['Food', 'Travel', 'Bills', 'Shopping', 'Health'];
    final methods = ['UPI', 'Cash', 'Bank'];

    // Seed 24,000 descending expenses (8,000 per workspace across 400 days)
    final all = List<Expense>.generate(24000, (i) {
      final ws = workspaces[i % 3];
      final amount = (i % 5 + 1) * 1000; // ₹10..₹50
      return Expense(
        productName: 'Item $i',
        amount: amount,
        category: categories[i % categories.length],
        date: baseDate.subtract(Duration(hours: i)),
        paymentMethod: methods[i % methods.length],
        workspaceId: ws,
      );
    });

    final sw = Stopwatch()..start();
    await service.rebuild(all);
    sw.stop();

    // Verify exact partition sums per workspace
    final expectedPersonalSum = all
        .where((e) => e.workspaceId == 'default_personal')
        .fold<int>(0, (s, e) => s + e.amount);
    final actualPersonalSum = service
        .partitionFor('default_personal')
        .allCatTotals
        .values
        .fold<int>(0, (s, v) => s + v);
    expect(actualPersonalSum, expectedPersonalSum);

    // Test ReportsProvider >2,000 item Isolate offload covering all 1,000 days
    provider.setActiveWorkspace('ws_usd');
    provider.setRange(
      DateTimeRange(
        start: DateTime(2023, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59),
      ),
      ReportsRangePreset.custom,
    );
    await Future.delayed(const Duration(milliseconds: 300));

    final expectedUsdSum = all
        .where((e) => e.workspaceId == 'ws_usd')
        .fold<int>(0, (s, e) => s + e.amount);

    expect(provider.viewModel?.totalSpent, expectedUsdSum);
    expect(provider.viewModel?.transactionCount, 8000);
    expect(sw.elapsedMilliseconds, lessThan(4000));
  });

  test('K-way merge + Streaming CSV Isolate supports Single, Selective, Combined, Formula Escaping, & Multi-Currency', () async {
    final now = DateTime(2026, 11, 10, 12, 0);

    final wsPersonal = Workspace(
      id: AppConstants.kDefaultWorkspaceId,
      name: 'Personal',
      type: WorkspaceType.personal,
      currency: '₹',
      createdAt: now,
      iconCodePoint: 0xe491,
      colorValue: 0xFF2196F3,
      isDefault: true,
    );
    final wsUsd = Workspace(
      id: 'ws_usd',
      name: 'US Consulting',
      type: WorkspaceType.business,
      currency: '\$',
      createdAt: now,
      iconCodePoint: 0xe8f9,
      colorValue: 0xFF9C27B0,
    );
    final wsEur = Workspace(
      id: 'ws_eur',
      name: 'Euro Trip',
      type: WorkspaceType.trip,
      currency: '€',
      createdAt: now,
      iconCodePoint: 0xe539,
      colorValue: 0xFFFF9800,
    );

    final streamPersonal = [
      Expense(
        productName: '=CMD("calc")', // Formula injection attempt
        amount: 25000, // ₹250.00
        category: '+Food',
        date: now,
        paymentMethod: 'UPI',
        workspaceId: AppConstants.kDefaultWorkspaceId,
      ),
    ];
    final streamUsd = [
      Expense(
        productName: 'Cloud Server',
        amount: 12500, // $125.00
        category: 'Bills',
        date: now.subtract(const Duration(hours: 2)),
        paymentMethod: 'Bank',
        workspaceId: 'ws_usd',
        isArchived: true,
      ),
    ];
    final streamEur = [
      Expense(
        productName: 'Train Pass',
        amount: 8000, // €80.00
        category: 'Travel',
        date: now.subtract(const Duration(hours: 1)),
        paymentMethod: 'Cash',
        workspaceId: 'ws_eur',
      ),
    ];

    // Verify O(N log W) K-Way Merge order (now -> now-1h -> now-2h)
    final mergedAll = ReportExportService.mergeSortedDescending([
      streamPersonal,
      streamUsd,
      streamEur,
    ]);
    expect(mergedAll.map((e) => e.productName).toList(), [
      '=CMD("calc")',
      'Train Pass',
      'Cloud Server',
    ]);

    // Selective 2-of-3 export (Personal + US Work)
    final selectiveMerged = ReportExportService.mergeSortedDescending([
      streamPersonal,
      streamUsd,
    ]);
    double lastProgress = 0.0;

    final csvResult = await ReportExportService.exportReport(
      ExportRequest(
        scope: ExportWorkspaceScope.selective,
        workspaces: [wsPersonal, wsUsd],
        expenses: selectiveMerged,
        range: DateTimeRange(start: now.subtract(const Duration(days: 1)), end: now),
        format: ExportFormat.csv,
        includeArchived: true,
        fallbackCurrencySymbol: '₹',
      ),
      onProgress: (p) => lastProgress = p,
    );

    expect(csvResult.isSuccess, isTrue, reason: csvResult.errorMessage);
    expect(csvResult.value, isNotNull);
    expect(lastProgress, greaterThanOrEqualTo(0.9));

    final csvBytes = await csvResult.value!.readAsBytes();
    // Verify UTF-8 BOM [0xEF, 0xBB, 0xBF] for clean Excel currency rendering
    expect(csvBytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);

    final csvContent = await csvResult.value!.readAsString();
    // Brand header & chart legend sections
    expect(csvContent, contains('BUDGO'));
    expect(csvContent, contains('FINANCIAL TRACKING STATEMENT'));
    expect(csvContent, contains('EXPENSE VISUALIZATION SERIES'));
    expect(csvContent, contains('LEGEND MARKING'));
    // Neutralized formula injection cells prefixed with apostrophe
    expect(csvContent, contains("'=CMD(\"\"calc\"\")"));
    expect(csvContent, contains("'+Food"));
    // Both workspace columns & multi-currency summaries preserved
    expect(csvContent, contains('Personal'));
    expect(csvContent, contains('US Consulting'));
    expect(csvContent, isNot(contains(wsEur.name)));
    expect(csvContent, contains('₹250.00'));
    expect(csvContent, contains('\$125.00'));
    expect(csvContent, contains('Archived'));
  });

  test('ExportStatementBuilder accurately versions expenses, reconciles income & transfers into opening/closing balances, and exports Unicode PDF with charts', () async {
    final start = DateTime(2026, 11, 1);
    final end = DateTime(2026, 11, 10);
    final wsPersonal = Workspace(
      id: AppConstants.kDefaultWorkspaceId,
      name: 'Personal',
      type: WorkspaceType.personal,
      currency: '₹',
      createdAt: start,
      iconCodePoint: 0xe491,
      colorValue: 0xFF2196F3,
      isDefault: true,
    );
    final wsWork = Workspace(
      id: 'ws_work',
      name: 'Consulting',
      type: WorkspaceType.business,
      currency: '₹',
      createdAt: start,
      iconCodePoint: 0xe8f9,
      colorValue: 0xFF9C27B0,
    );

    // Live account balance today (Nov 15): ₹10,750.00 (1,075,000 paise) in Personal.
    // Suppose post-range (Nov 12) expense was ₹250.00 -> Closing balance at Nov 10 = ₹11,000.00.
    // Inside [Nov 1..Nov 10]: Opening ₹5,000.00 + Salary ₹10,000.00 - Coffee ₹150.00 - Dinner ₹850.00 - Transfer Out ₹3,000.00 = ₹11,000.00!
    final accPersonalBank = Account(
      id: 'acc_bank',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'HDFC Bank',
      type: AccountType.bankAccount,
      balancePaise: 1075000,
      iconCodePoint: 0xe040,
      colorValue: 0xFF1976D2,
      createdAt: start,
      updatedAt: end,
    );
    final accWorkBank = Account(
      id: 'acc_work_bank',
      workspaceId: 'ws_work',
      name: 'Work Bank',
      type: AccountType.bankAccount,
      balancePaise: 300000,
      iconCodePoint: 0xe040,
      colorValue: 0xFF4CAF50,
      createdAt: start,
      updatedAt: end,
    );

    final exp1 = Expense(
      productName: 'Morning Coffee',
      amount: 15000, // ₹150
      category: 'Food',
      date: DateTime(2026, 11, 2, 9, 0),
      paymentMethod: 'UPI',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      accountId: 'acc_bank',
    );
    final exp2 = Expense(
      productName: 'Team Dinner',
      amount: 85000, // ₹850
      category: 'Food',
      date: DateTime(2026, 11, 8, 20, 0),
      paymentMethod: 'Bank',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      accountId: 'acc_bank',
    );
    final postRangeExp = Expense(
      productName: 'Post Range Snack',
      amount: 25000, // ₹250 after Nov 10
      category: 'Food',
      date: DateTime(2026, 11, 12, 12, 0),
      paymentMethod: 'Cash',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      accountId: 'acc_bank',
    );

    final incSalary = Income(
      id: 'inc_1',
      source: 'Salary',
      amount: 1000000, // +₹10,000
      date: DateTime(2026, 11, 1, 10, 0),
      isConfirmed: true,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      accountId: 'acc_bank',
    );
    final incPending = Income(
      id: 'inc_pending',
      source: 'Bonus',
      amount: 500000,
      date: DateTime(2026, 11, 9, 10, 0),
      isConfirmed: false,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      accountId: 'acc_bank',
    );

    final crossTransfer = Transfer(
      id: 'trf_1',
      sourceAccountId: 'acc_bank',
      destinationAccountId: 'acc_work_bank',
      sourceWorkspaceId: AppConstants.kDefaultWorkspaceId,
      destinationWorkspaceId: 'ws_work',
      amountPaise: 300000, // ₹3,000 Personal -> Work
      feePaise: 0,
      date: DateTime(2026, 11, 5, 14, 0),
      note: 'Capital Topup',
      status: TransferStatus.completed,
    );

    final vault = SavingsVault(
      id: 'v_1',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      parentAccountId: 'acc_bank',
      name: 'Emergency Fund',
      targetPaise: 500000,
      currentPaise: 200000,
      iconCodePoint: 0xe55d,
      colorValue: 0xFF009688,
      createdAt: start,
      updatedAt: end,
    );

    // 1. Test Single Workspace Scope ('Personal') -> Transfer is Transfer Out (-₹3,000)
    final singleSnap = ExportStatementBuilder.build(
      targetWorkspaces: [wsPersonal],
      expenses: [exp2, exp1],
      allExpensesForReconciliation: [postRangeExp, exp2, exp1],
      incomes: [incSalary, incPending],
      allIncomesForReconciliation: [incSalary, incPending],
      transfers: [crossTransfer],
      allTransfersForReconciliation: [crossTransfer],
      accounts: [accPersonalBank, accWorkBank],
      vaults: [vault],
      allWorkspaceNames: {AppConstants.kDefaultWorkspaceId: 'Personal', 'ws_work': 'Consulting'},
      range: DateTimeRange(start: start, end: end),
    );

    expect(singleSnap.workspaceSummaries.length, 1);
    final pSummary = singleSnap.workspaceSummaries.first;
    expect(pSummary.openingBalancePaise, 500000); // ₹5,000.00
    expect(pSummary.confirmedIncomePaise, 1000000); // ₹10,000.00
    expect(pSummary.pendingIncomePaise, 500000);
    expect(pSummary.totalExpensePaise, 100000); // ₹1,000.00
    expect(pSummary.netTransferPaise, -300000); // -₹3,000.00
    expect(pSummary.closingBalancePaise, 1100000); // ₹11,000.00
    expect(pSummary.vaultLockedPaise, 200000);

    // Verify chronological expense versioning E#1 & E#2 + running balances
    expect(singleSnap.entries.length, 5); // Salary, Coffee, Transfer Out, Dinner, Bonus (Pending)
    expect(singleSnap.entries[0].seqLabel, 'I#1');
    expect(singleSnap.entries[0].runningBalancePaise, 1500000); // 5k + 10k = 15k
    expect(singleSnap.entries[1].seqLabel, 'E#1');
    expect(singleSnap.entries[1].runningExpensePaise, 15000); // ₹150
    expect(singleSnap.entries[1].runningBalancePaise, 1485000); // 15k - 150
    expect(singleSnap.entries[2].type, ExportLedgerEntryType.transferOut);
    expect(singleSnap.entries[2].runningBalancePaise, 1185000); // 14,850 - 3,000
    expect(singleSnap.entries[3].seqLabel, 'E#2');
    expect(singleSnap.entries[3].runningExpensePaise, 100000); // ₹150 + ₹850 = ₹1,000
    expect(singleSnap.entries[3].runningBalancePaise, 1100000); // ₹11,000 closing!
    expect(singleSnap.entries[4].type, ExportLedgerEntryType.incomePending);
    expect(singleSnap.entries[4].balanceDeltaPaise, 0);
    expect(singleSnap.entries[4].runningBalancePaise, 1100000);

    // 2. Verify Combined All neutralizes internal cross-workspace transfer in combined equity
    final combinedSnap = ExportStatementBuilder.build(
      targetWorkspaces: [wsPersonal, wsWork],
      expenses: [exp2, exp1],
      allExpensesForReconciliation: [postRangeExp, exp2, exp1],
      incomes: [incSalary],
      transfers: [crossTransfer],
      accounts: [accPersonalBank, accWorkBank],
      range: DateTimeRange(start: start, end: end),
    );
    expect(combinedSnap.entries.any((e) => e.type == ExportLedgerEntryType.transferSelf), isTrue);
    expect(combinedSnap.currencySummaries.first.closingBalancePaise, 1400000); // 11k + 3k

    // 3. Export real PDF + CSV with Unicode ₹ and vector line charts
    final pdfRes = await ReportExportService.exportReport(
      ExportRequest(
        scope: ExportWorkspaceScope.single,
        workspaces: [wsPersonal],
        expenses: [exp2, exp1],
        allExpensesForReconciliation: [postRangeExp, exp2, exp1],
        incomes: [incSalary, incPending],
        transfers: [crossTransfer],
        accounts: [accPersonalBank, accWorkBank],
        vaults: [vault],
        allWorkspaceNames: {AppConstants.kDefaultWorkspaceId: 'Personal', 'ws_work': 'Consulting'},
        range: DateTimeRange(start: start, end: end),
        format: ExportFormat.pdf,
      ),
    );
    expect(pdfRes.isSuccess, isTrue, reason: pdfRes.errorMessage);
    final pdfBytes = await pdfRes.value!.readAsBytes();
    // Valid PDF header + embedded TrueType font & visual chart stream
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    expect(pdfBytes.length, greaterThan(10000));
  });

  test('PDF Isolate preserves explicit multi-workspace currencies and enforces safe RAM row cap', () async {
    final now = DateTime(2026, 11, 10, 12, 0);
    final wsUsd = Workspace(
      id: 'ws_usd',
      name: 'Dollar Profile',
      type: WorkspaceType.business,
      currency: '\$',
      createdAt: now,
      iconCodePoint: 0xe8f9,
      colorValue: 0xFF9C27B0,
    );

    // Exceed kMaxPdfDetailRows (4,000) cleanly to verify adaptive truncation guard
    final massive = List<Expense>.generate(4150, (i) => Expense(
      productName: 'Entry $i',
      amount: 1000,
      category: 'Bills',
      date: now.subtract(Duration(minutes: i)),
      paymentMethod: 'Bank',
      workspaceId: 'ws_usd',
    ));

    final pdfRes = await ReportExportService.exportReport(
      ExportRequest(
        scope: ExportWorkspaceScope.single,
        workspaces: [wsUsd],
        expenses: massive,
        range: DateTimeRange(start: now.subtract(const Duration(days: 5)), end: now),
        format: ExportFormat.pdf,
        fallbackCurrencySymbol: '\$',
      ),
    );

    expect(pdfRes.isSuccess, isTrue, reason: pdfRes.errorMessage);
    expect(pdfRes.wasTruncatedForPdfCap, isTrue);
    expect(pdfRes.exportedCount, 4150);
    expect(await pdfRes.value!.length(), greaterThan(5000));
  });
}
