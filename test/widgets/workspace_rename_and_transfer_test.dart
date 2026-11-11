import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_journal_entry.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/transfer_repository.dart';
import 'package:expense/repositories/workspace_repository.dart';
import 'package:expense/services/transfer_engine_service.dart';
import 'package:expense/widgets/sheets/self_transfer_bottom_sheet.dart';
import 'package:expense/widgets/sheets/workspace_switcher_sheet.dart';

class _InMemoryWorkspaceRepo implements WorkspaceRepository {
  final Map<String, Workspace> _data = {};

  @override
  Future<void> add(Workspace workspace) async => _data[workspace.id] = workspace;

  @override
  Future<void> delete(String id) async => _data.remove(id);

  @override
  Future<List<Workspace>> getAll({bool includeArchived = false}) async {
    final list = _data.values.where((w) => includeArchived || !w.isArchived).toList();
    list.sort((a, b) => a.isDefault ? -1 : (b.isDefault ? 1 : a.createdAt.compareTo(b.createdAt)));
    return list;
  }

  @override
  Future<Workspace?> getById(String id) async => _data[id];

  @override
  Future<Workspace?> getDefault() async =>
      _data.values.firstWhere((w) => w.isDefault, orElse: () => _data.values.first);

  @override
  Future<void> setArchived(String id, bool isArchived) async {}

  @override
  Future<void> update(Workspace workspace) async => _data[workspace.id] = workspace;

  @override
  Stream<void> watch() => const Stream.empty();
}

class _InMemoryAccountRepo implements AccountRepository {
  final Map<String, Account> _data = {};

  @override
  Future<void> add(Account account) async => _data[account.id] = account;

  @override
  Future<void> delete(String id) async => _data.remove(id);

  @override
  Future<List<Account>> getAll({bool includeArchived = false}) async =>
      _data.values.where((a) => includeArchived || !a.isArchived).toList();

  @override
  Future<Account?> getById(String id) async => _data[id];

  @override
  Future<List<Account>> getByWorkspace(String workspaceId, {bool includeArchived = false}) async =>
      _data.values.where((a) => a.workspaceId == workspaceId && (includeArchived || !a.isArchived)).toList();

  @override
  Future<Account?> getDefault(String workspaceId) async =>
      _data.values.firstWhere((a) => a.workspaceId == workspaceId && a.isDefault);

  @override
  int getNetWorthPaise({bool includeArchived = false}) =>
      _data.values.where((a) => includeArchived || !a.isArchived).fold<int>(0, (sum, a) => sum + a.balancePaise);

  @override
  Future<void> setArchived(String id, bool isArchived) async {}

  @override
  Future<void> update(Account account) async => _data[account.id] = account;

  @override
  Future<void> updateBalance(String accountId, int deltaPaise) async {
    final acc = _data[accountId];
    if (acc == null) throw ValidationException('Not found');
    acc.balancePaise += deltaPaise;
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

class _InMemoryTransferRepo implements TransferRepository {
  final Map<String, Transfer> _transfers = {};

  @override
  Future<Transfer?> getById(String id) async => _transfers[id];

  @override
  Future<List<Transfer>> getAll() async => _transfers.values.toList();

  @override
  Future<List<Transfer>> getByAccount(String accountId) async =>
      _transfers.values.where((t) => t.sourceAccountId == accountId || t.destinationAccountId == accountId).toList();

  @override
  Future<List<Transfer>> getByWorkspace(String workspaceId) async =>
      _transfers.values.where((t) => t.sourceWorkspaceId == workspaceId || t.destinationWorkspaceId == workspaceId).toList();

  @override
  Future<void> recordTransfer(Transfer transfer) async => _transfers[transfer.id] = transfer;

  @override
  Future<void> updateStatus(String transferId, TransferStatus status, {String? failureReason}) async {
    final t = _transfers[transferId];
    if (t != null) {
      t.status = status;
      t.failureReason = failureReason;
    }
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

class _MockJournalBox implements Box<TransferJournalEntry> {
  final Map<dynamic, TransferJournalEntry> _map = {};

  @override
  Future<void> put(dynamic key, TransferJournalEntry value) async => _map[key] = value;

  @override
  Future<void> delete(dynamic key) async => _map.remove(key);

  @override
  Future<void> flush() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _InMemoryWorkspaceRepo wsRepo;
  late _InMemoryAccountRepo accRepo;
  late _InMemoryTransferRepo trfRepo;
  late WorkspaceProvider wsProvider;
  late AccountProvider accProvider;
  late TransferProvider trfProvider;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ws_rename_trf_test');
    Hive.init(tempDir.path);
    if (!Hive.isBoxOpen(AppStateBox.boxName)) {
      await Hive.openBox(AppStateBox.boxName);
    }

    wsRepo = _InMemoryWorkspaceRepo();
    accRepo = _InMemoryAccountRepo();
    trfRepo = _InMemoryTransferRepo();

    final now = DateTime(2026, 1, 1);

    await wsRepo.add(Workspace(
      id: AppConstants.kDefaultWorkspaceId,
      name: 'Personal',
      type: WorkspaceType.personal,
      currency: '₹',
      initialBalance: 0,
      createdAt: now,
      iconCodePoint: Icons.person_rounded.codePoint,
      colorValue: 0xFF2196F3,
      isDefault: true,
    ));

    await wsRepo.add(Workspace(
      id: 'ws_trip',
      name: 'Goa Trip',
      type: WorkspaceType.trip,
      currency: '₹',
      initialBalance: 0,
      createdAt: now.add(const Duration(days: 1)),
      iconCodePoint: Icons.flight_takeoff_rounded.codePoint,
      colorValue: 0xFFFF9800,
      isDefault: false,
    ));

    // Seed Personal accounts
    await accRepo.add(Account(
      id: AppConstants.kBankAccountId,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'Bank Account',
      type: AccountType.bankAccount,
      balancePaise: 500000, // ₹5,000
      iconCodePoint: Icons.account_balance_rounded.codePoint,
      colorValue: 0xFF1976D2,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ));
    await accRepo.add(Account(
      id: AppConstants.kCashAccountId,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'Cash Wallet',
      type: AccountType.cash,
      balancePaise: 100000, // ₹1,000
      iconCodePoint: Icons.payments_rounded.codePoint,
      colorValue: 0xFF4CAF50,
      isDefault: false,
      createdAt: now.add(const Duration(milliseconds: 1)),
      updatedAt: now,
    ));
    await accRepo.add(Account(
      id: AppConstants.kUpiAccountId,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'UPI / GPay',
      type: AccountType.upi,
      balancePaise: 0,
      iconCodePoint: Icons.qr_code_rounded.codePoint,
      colorValue: 0xFF9C27B0,
      isDefault: false,
      createdAt: now.add(const Duration(milliseconds: 2)),
      updatedAt: now,
    ));

    // Seed Goa Trip accounts (initially only Cash to test ensureStandardAccountsForWorkspace)
    await accRepo.add(Account(
      id: 'acc_trip_cash',
      workspaceId: 'ws_trip',
      name: 'Trip Cash Wallet',
      type: AccountType.cash,
      balancePaise: 0,
      iconCodePoint: Icons.payments_rounded.codePoint,
      colorValue: 0xFF4CAF50,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ));

    wsProvider = WorkspaceProvider(wsRepo);
    accProvider = AccountProvider(accRepo);
    trfProvider = TransferProvider(
      trfRepo,
      TransferEngineService(accRepo, trfRepo, _MockJournalBox()),
    );

    await wsProvider.load();
    await accProvider.initialize(initialWorkspaceId: wsProvider.activeWorkspaceId);
    await trfProvider.initialize(initialWorkspaceId: wsProvider.activeWorkspaceId);
  });

  tearDown(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: wsProvider),
        ChangeNotifierProvider.value(value: accProvider),
        ChangeNotifierProvider.value(value: trfProvider),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('Workspace Rename & Workspace-to-Workspace Transfer Tests', () {
    test('ensureStandardAccountsForWorkspace idempotently provisions Cash, Bank, and UPI', () async {
      await accProvider.ensureStandardAccountsForWorkspace('ws_trip');

      final tripAccounts = accProvider.getAccountsForWorkspace('ws_trip');
      expect(tripAccounts.length, 3);
      expect(tripAccounts.any((a) => a.type == AccountType.cash), isTrue);
      expect(tripAccounts.any((a) => a.type == AccountType.bankAccount), isTrue);
      expect(tripAccounts.any((a) => a.type == AccountType.upi), isTrue);

      // Re-running should remain idempotent (still 3)
      await accProvider.ensureStandardAccountsForWorkspace('ws_trip');
      expect(accProvider.getAccountsForWorkspace('ws_trip').length, 3);
    });

    testWidgets('User can rename Default workspace in WorkspaceSwitcherSheet', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const WorkspaceSwitcherSheet()));
      await tester.pumpAndSettle();

      // Default workspace initially named Personal
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      // Tap tune button on Personal workspace row (first tune button)
      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Edit Workspace: Personal'), findsOneWidget);

      // Enter new name (respects no-spaces policy)
      await tester.enterText(find.widgetWithText(TextFormField, 'Personal'), 'DailyWallet');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // UI updates to show DailyWallet while Default badge remains
      expect(find.text('DailyWallet'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(wsProvider.activeWorkspace?.id, AppConstants.kDefaultWorkspaceId);
    });

    testWidgets('SelfTransferBottomSheet executes cross-workspace transfer with clarity note', (tester) async {
      await accProvider.ensureStandardAccountsForWorkspace('ws_trip');

      await tester.pumpWidget(wrapWithProviders(const SelfTransferBottomSheet()));
      await tester.pumpAndSettle();

      // Shows FROM and TO endpoint badges and cash flow explanatory banner
      expect(find.text('FROM'), findsOneWidget);
      expect(find.text('TO'), findsOneWidget);
      expect(
        find.textContaining('UPI & Bank share the same underlying bank balance'),
        findsOneWidget,
      );

      // Enter transfer amount of ₹1,500
      await tester.enterText(find.byType(TextField).first, '1500');
      await tester.ensureVisible(find.text('Transfer Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transfer Now'));
      await tester.pumpAndSettle();

      // Verify Personal Bank debited ₹1,500 (5000 - 1500 = 3500 = 350000 paise)
      // and Goa Trip Cash credited ₹1,500 (150000 paise)
      final personalBank = accProvider.getById(AppConstants.kBankAccountId);
      final tripCash = accProvider.getById('acc_trip_cash');

      expect(personalBank?.balancePaise, 350000);
      expect(tripCash?.balancePaise, 150000);
    });
  });
}
