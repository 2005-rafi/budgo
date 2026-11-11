import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/app_navigation_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/reports_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/repositories/workspace_repository.dart';
import 'package:expense/screens/reports_screen.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/widgets/sheets/data_management_sheet.dart';
import 'package:expense/widgets/sheets/export_bottom_sheet.dart';

class _MemWsRepo implements WorkspaceRepository {
  final List<Workspace> items;
  _MemWsRepo(this.items);
  @override
  Future<void> add(Workspace w) async => items.add(w);
  @override
  Future<void> delete(String id) async => items.removeWhere((w) => w.id == id);
  @override
  Future<List<Workspace>> getAll({bool includeArchived = false}) async => items;
  @override
  Future<Workspace?> getById(String id) async => items.firstWhere((w) => w.id == id);
  @override
  Future<Workspace?> getDefault() async => items.first;
  @override
  Future<void> setArchived(String id, bool isArchived) async {}
  @override
  Future<void> update(Workspace w) async {}
  @override
  Stream<void> watch() => const Stream.empty();
}

class _MemExpRepo implements ExpenseRepository {
  final List<Expense> items;
  _MemExpRepo(this.items);
  @override
  Future<List<Expense>> getAll() async => items.where((e) => !e.isArchived).toList();
  @override
  Future<List<Expense>> getAllExpenses() async => items;
  @override
  Future<List<Expense>> getArchived() async => items.where((e) => e.isArchived).toList();
  @override
  Future<List<Expense>> getRangeScoped({
    required DateTime from,
    required DateTime to,
    Set<String>? workspaceIds,
    bool includeArchived = false,
  }) async {
    return items.where((e) {
      if (!includeArchived && e.isArchived) return false;
      if (workspaceIds != null && !workspaceIds.contains(e.workspaceId)) return false;
      return true;
    }).toList();
  }
  @override
  Stream<void> watch() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late WorkspaceProvider wsProvider;
  late ExpensesProvider expProvider;
  late ReportsProvider repProvider;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ui_iso_export_test');
    Hive.init(tempDir.path);
    await Hive.openBox(AppStateBox.boxName);

    final now = DateTime.now();
    final wsRepo = _MemWsRepo([
      Workspace(
        id: AppConstants.kDefaultWorkspaceId,
        name: 'Personal',
        type: WorkspaceType.personal,
        currency: '₹',
        createdAt: now,
        iconCodePoint: 0xe491,
        colorValue: 0xFF2196F3,
        isDefault: true,
      ),
      Workspace(
        id: 'ws_work',
        name: 'Business',
        type: WorkspaceType.business,
        currency: '\$',
        createdAt: now,
        iconCodePoint: 0xe8f9,
        colorValue: 0xFF9C27B0,
      ),
    ]);

    final expRepo = _MemExpRepo([
      Expense(
        productName: 'Personal Lunch',
        amount: 20000,
        category: 'Food',
        date: now,
        paymentMethod: 'UPI',
        workspaceId: AppConstants.kDefaultWorkspaceId,
      ),
      Expense(
        productName: 'Business Domain',
        amount: 150000,
        category: 'Bills',
        date: now,
        paymentMethod: 'Bank',
        workspaceId: 'ws_work',
      ),
      Expense(
        productName: 'Archived Domain',
        amount: 80000,
        category: 'Bills',
        date: now,
        paymentMethod: 'Bank',
        workspaceId: 'ws_work',
        isArchived: true,
      ),
    ]);

    final reportsService = ReportsDataService();
    wsProvider = WorkspaceProvider(wsRepo);
    await wsProvider.initialize();

    expProvider = ExpensesProvider(expRepo, reportsService);
    await expProvider.load();
    await expProvider.deferredRebuild();

    repProvider = ReportsProvider(service: reportsService);
    repProvider.initialize(
      expProvider.allExpenses,
      activeWorkspaceId: AppConstants.kDefaultWorkspaceId,
    );

    wsProvider.onWorkspaceChanged = (wsId) {
      expProvider.setActiveWorkspace(wsId);
      repProvider.setActiveWorkspace(wsId);
    };
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('ReportsScreen isolates active workspace and exposes Bank payment filter', (tester) async {
    tester.view.physicalSize = const Size(800, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wsProvider),
          ChangeNotifierProvider.value(value: expProvider),
          ChangeNotifierProvider.value(value: repProvider),
          ChangeNotifierProvider(create: (_) => AppNavigationProvider()),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repProvider.isLoading, isFalse);
    expect(find.text('Personal • Isolated Analytics'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Personal Lunch'), findsOneWidget);
    expect(find.text('Business Domain'), findsNothing);
    expect(repProvider.viewModel?.topExpenses.map((e) => e.productName), ['Personal Lunch']);

    // Switch active workspace dynamically -> Reports immediately isolates to Business!
    await tester.runAsync(() => wsProvider.setActiveWorkspace('ws_work'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Business • Isolated Analytics'), findsOneWidget);
    expect(find.text('Business Domain'), findsOneWidget);
    expect(find.text('Personal Lunch'), findsNothing);
    expect(repProvider.viewModel?.topExpenses.map((e) => e.productName), ['Business Domain']);
  });

  testWidgets('ExportBottomSheet supports Single, Selective, All scopes and Archived count toggle', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wsProvider),
          ChangeNotifierProvider.value(value: expProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ExportBottomSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default Single ('Personal') shows 1 record and all financial statement sections
    expect(find.text('Export 1 Record(s)'), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Selective'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfers'), findsOneWidget);
    expect(find.text('Line Charts'), findsOneWidget);

    // Switch to 'All' combined -> sees 2 non-archived records (Personal + Business)
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Export 2 Record(s)'), findsOneWidget);
    expect(find.textContaining('Multi-currency workspaces detected'), findsOneWidget);

    // Enable 'Include Archived Records' -> count climbs to 3!
    final archivedFinder = find.text('Include Archived Records');
    await tester.ensureVisible(archivedFinder);
    await tester.tap(archivedFinder);
    await tester.pumpAndSettle();
    expect(find.text('Export 3 Record(s)'), findsOneWidget);
  });

  testWidgets('FactoryResetVerificationDialog disposes cleanly and supports optional custom categories toggle', (tester) async {
    ({bool confirmed, bool resetCategories})? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: FilledButton(
                onPressed: () async {
                  dialogResult = await FactoryResetVerificationDialog.show(ctx);
                },
                child: const Text('Open Reset'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Reset'));
    await tester.pumpAndSettle();

    // Toggle category reset checkbox and type RESET
    await tester.tap(find.text('Also reset custom categories to defaults'));
    await tester.enterText(find.byType(TextField), 'RESET');
    await tester.pumpAndSettle();

    await tester.tap(find.text('RESET EVERYTHING'));
    await tester.pumpAndSettle();

    expect(dialogResult?.confirmed, isTrue);
    expect(dialogResult?.resetCategories, isTrue);
  });

  testWidgets('Settings data management sheets render cleanly with workspace controls', (tester) async {
    // 1. StorageBreakdownSheet
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StorageBreakdownSheet())),
    );
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Storage Breakdown'), findsOneWidget);
    expect(find.text('Optimize & Compact DB'), findsOneWidget);

    // 2. WorkspaceArchiveSheet
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wsProvider),
          ChangeNotifierProvider.value(value: expProvider),
        ],
        child: const MaterialApp(home: Scaffold(body: WorkspaceArchiveSheet())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Archive Old Data'), findsOneWidget);
    expect(find.text('Workspace Scope'), findsOneWidget);

    // 3. WorkspaceClearSheet
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wsProvider),
          ChangeNotifierProvider.value(value: expProvider),
        ],
        child: const MaterialApp(home: Scaffold(body: WorkspaceClearSheet())),
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Clear Workspace Data'), findsOneWidget);
    expect(find.textContaining('Personal'), findsOneWidget);
    expect(find.textContaining('Business'), findsOneWidget);
  });
}
