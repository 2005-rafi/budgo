import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/repositories/savings_vault_repository.dart';
import 'package:expense/services/vault_allocation_service.dart';
import 'package:expense/widgets/home/pay_yourself_first_card.dart';
import 'package:expense/widgets/sheets/vault_management_sheet.dart';

class _MemAccountRepo implements AccountRepository {
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
  Future<Account?> getDefault(String workspaceId) async => _data.values.first;

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
    if (acc != null) acc.balancePaise += deltaPaise;
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

class _MemVaultRepo implements SavingsVaultRepository {
  final Map<String, SavingsVault> _data = {};

  @override
  Future<void> add(SavingsVault vault) async => _data[vault.id] = vault;

  @override
  Future<void> delete(String id) async => _data.remove(id);

  @override
  Future<List<SavingsVault>> getAll({bool includeArchived = false}) async =>
      _data.values.where((v) => includeArchived || !v.isArchived).toList();

  @override
  Future<SavingsVault?> getById(String id) async => _data[id];

  @override
  Future<List<SavingsVault>> getByParentAccount(String parentAccountId, {bool includeArchived = false}) async =>
      _data.values.where((v) => v.parentAccountId == parentAccountId && (includeArchived || !v.isArchived)).toList();

  @override
  Future<List<SavingsVault>> getByWorkspace(String workspaceId, {bool includeArchived = false}) async =>
      _data.values.where((v) => v.workspaceId == workspaceId && (includeArchived || !v.isArchived)).toList();

  @override
  Future<void> setArchived(String id, bool isArchived) async {}

  @override
  Future<void> update(SavingsVault vault) async => _data[vault.id] = vault;

  @override
  Future<void> updateCurrentAmount(String vaultId, int deltaPaise) async {}

  @override
  Stream<void> watch() => const Stream.empty();
}

class _MemIncomeRepo implements IncomeRepository {
  final Map<String, Income> _data = {};

  @override
  Future<void> add(Income income) async => _data[income.id] = income;

  @override
  Future<void> confirm(Income income) async {
    income.isConfirmed = true;
    _data[income.id] = income;
  }

  @override
  int confirmedForMonth(DateTime date) => _data.values
      .where((i) => i.isConfirmed && i.date.year == date.year && i.date.month == date.month)
      .fold<int>(0, (s, i) => s + i.amount);

  @override
  int confirmedTotal(List<Income> incomes) =>
      incomes.where((i) => i.isConfirmed).fold<int>(0, (s, i) => s + i.amount);

  @override
  Future<void> delete(Income income) async => _data.remove(income.id);

  @override
  Future<List<Income>> getAll() async => _data.values.toList();

  @override
  Stream<void> watch() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _MemAccountRepo accRepo;
  late _MemVaultRepo vaultRepo;
  late _MemIncomeRepo incomeRepo;
  late SavingsVaultProvider vaultProvider;
  late IncomeProvider incomeProvider;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('toast_vault_test');
    Hive.init(tempDir.path);
    if (!Hive.isBoxOpen(AppStateBox.boxName)) {
      await Hive.openBox(AppStateBox.boxName);
    }

    accRepo = _MemAccountRepo();
    vaultRepo = _MemVaultRepo();
    incomeRepo = _MemIncomeRepo();

    final now = DateTime.now();

    // Bank has ₹0, UPI has ₹10,000 (mirrors Screenshot 2)
    await accRepo.add(Account(
      id: AppConstants.kBankAccountId,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'Bank Account',
      type: AccountType.bankAccount,
      balancePaise: 0,
      iconCodePoint: Icons.account_balance_rounded.codePoint,
      colorValue: 0xFF1976D2,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    ));
    await accRepo.add(Account(
      id: AppConstants.kUpiAccountId,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'UPI / GPay',
      type: AccountType.upi,
      balancePaise: 1000000, // ₹10,000
      iconCodePoint: Icons.qr_code_rounded.codePoint,
      colorValue: 0xFF9C27B0,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    ));
    await accRepo.add(Account(
      id: AppConstants.kCashAccountId,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      name: 'Cash Wallet',
      type: AccountType.cash,
      balancePaise: 0,
      iconCodePoint: Icons.payments_rounded.codePoint,
      colorValue: 0xFF4CAF50,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ));

    await vaultRepo.add(SavingsVault(
      id: 'v_savings',
      workspaceId: AppConstants.kDefaultWorkspaceId,
      parentAccountId: AppConstants.kBankAccountId,
      name: 'Savings',
      targetPaise: 5000000,
      currentPaise: 0,
      iconCodePoint: Icons.savings_outlined.codePoint,
      colorValue: 0xFF4CAF50,
      priority: 0,
      createdAt: now,
      updatedAt: now,
    ));

    await incomeRepo.add(Income(
      id: 'inc_salary',
      source: 'Salary',
      amount: 1000000,
      date: now,
      description: 'Monthly Salary',
      isConfirmed: true,
      workspaceId: AppConstants.kDefaultWorkspaceId,
      accountId: AppConstants.kUpiAccountId,
    ));

    final service = VaultAllocationService(
      accountRepository: accRepo,
      vaultRepository: vaultRepo,
    );
    vaultProvider = SavingsVaultProvider(
      repository: vaultRepo,
      allocationService: service,
    );
    incomeProvider = IncomeProvider(incomeRepo);

    await vaultProvider.load();
    await incomeProvider.load();
  });

  tearDown(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Rich Error Translation & Vault Allocation Feedback Tests', () {
    test('Pooled Bank+UPI liquidity allows Bank vault reserve when Salary is in UPI', () async {
      final ok = await vaultProvider.deposit('v_savings', 100000); // ₹1,000

      expect(ok, isTrue);
      expect(vaultProvider.errorMessage, isNull);
      final vault = await vaultRepo.getById('v_savings');
      expect(vault?.currentPaise, 100000);
    });

    test('Vault deposit failure preserves explained InsufficientFundsException with Cash hint', () async {
      // Bank+UPI has only ₹500; Cash Wallet holds ₹10,000
      await accRepo.updateBalance(AppConstants.kUpiAccountId, -950000); // UPI -> ₹500
      await accRepo.updateBalance(AppConstants.kCashAccountId, 1000000); // Cash -> ₹10,000

      final ok = await vaultProvider.deposit('v_savings', 100000); // Request ₹1,000

      expect(ok, isFalse);
      expect(vaultProvider.lastError, isA<InsufficientFundsException>());
      expect(vaultProvider.errorMessage, isNotNull);

      final err = vaultProvider.lastError as InsufficientFundsException;
      expect(err.availablePaise, 50000);
      expect(err.requestedPaise, 100000);
      expect(err.guidance, contains('Cash Wallet'));
    });

    testWidgets('PayYourselfFirstCard surfaces explained toast instead of generic Allocation failed.', (tester) async {
      // Leave Bank+UPI at ₹0 and Cash Wallet at ₹10,000
      await accRepo.updateBalance(AppConstants.kUpiAccountId, -1000000);
      await accRepo.updateBalance(AppConstants.kCashAccountId, 1000000);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vaultProvider),
            ChangeNotifierProvider.value(value: incomeProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PayYourselfFirstCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reserve ₹1,000.00'));
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Never shows opaque "Allocation failed."
      expect(find.text('Allocation failed.'), findsNothing);
      // Shows explained title + recovery hint pointing to Cash Wallet
      expect(find.textContaining('Not enough funds in Bank & UPI pool'), findsOneWidget);
      expect(find.textContaining('Cash Wallet'), findsOneWidget);
    });

    testWidgets('VaultManagementSheet validates Deposit inline and renders rich error toast', (tester) async {
      // Leave Bank+UPI at ₹200
      await accRepo.updateBalance(AppConstants.kUpiAccountId, -980000);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vaultProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VaultManagementSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deposit'));
      await tester.pumpAndSettle();

      final dialogDepositBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Deposit'),
      );

      // Attempt empty / invalid submit keeps dialog open with inline validation error
      await tester.tap(dialogDepositBtn);
      await tester.pumpAndSettle();
      expect(find.text('Deposit amount is required'), findsOneWidget);

      // Now enter ₹1,000 (> ₹200 free) and submit
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pumpAndSettle();
      expect(find.text('Deposit amount is required'), findsNothing);
      await tester.tap(dialogDepositBtn);
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        vaultProvider.errorMessage,
        isNotNull,
        reason: 'Provider error was not set; dialogs=${find.byType(AlertDialog).evaluate().length}, '
            'spinners=${find.byType(CircularProgressIndicator).evaluate().length}, '
            'fields=${find.byType(TextField).evaluate().length}',
      );
      expect(find.byType(BudgoToastBanner), findsOneWidget, reason: 'BudgoToastBanner was not shown');
      expect(find.text('Deposit failed.'), findsNothing);
      expect(find.textContaining('Free: ₹200.00, Needed: ₹1,000.00'), findsOneWidget);
      SnackbarFeedback.dismissCurrent();
    });

    testWidgets('SnackbarFeedback renders above modal bottom sheet in root Overlay and remains interactive', (tester) async {
      bool retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (rootCtx) => Center(
                child: FilledButton(
                  onPressed: () {
                    BudgoBottomSheet.show(
                      rootCtx,
                      builder: (sheetCtx) => BudgoBottomSheet(
                        key: const ValueKey('test_modal_sheet'),
                        title: 'Modal Form',
                        child: BudgoButton(
                          label: 'Trigger Sheet Toast',
                          onPressed: () {
                            SnackbarFeedback.showError(
                              sheetCtx,
                              'Select a future date',
                              guidance: 'Pick an upcoming time or switch recurrence.',
                              actionLabel: 'Fix',
                              onAction: () => retryTapped = true,
                            );
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trigger Sheet Toast'));
      await tester.pumpAndSettle();

      final toastFinder = find.byType(BudgoToastBanner);
      final sheetFinder = find.byKey(const ValueKey('test_modal_sheet'));
      expect(toastFinder, findsOneWidget);
      expect(sheetFinder, findsOneWidget);

      // Verify top-layer toast floats vertically above the modal bottom sheet content
      final toastRect = tester.getRect(toastFinder);
      final sheetRect = tester.getRect(sheetFinder);
      expect(toastRect.top, lessThan(sheetRect.top));

      // Verify toast action button is directly clickable on the topmost layer
      await tester.tap(find.text('Fix'));
      await tester.pumpAndSettle();
      expect(retryTapped, isTrue);

      SnackbarFeedback.dismissCurrent();
    });

    test('CategoryProvider sets distinct DuplicateEntityException & LimitExceededException', () async {
      final box = Hive.box(AppStateBox.boxName);
      final catProvider = CategoryProvider(box);

      final dupOk = await catProvider.addCategory(
        name: 'food',
        iconId: 'restaurant',
        colorValue: 0xFF000000,
      );
      expect(dupOk, isFalse);
      expect(catProvider.lastError, isA<DuplicateEntityException>());

      // Fill up to max 12 categories (starting from 5)
      for (int i = 0; i < 7; i++) {
        await catProvider.addCategory(
          name: 'Cat$i',
          iconId: 'star',
          colorValue: 0xFF111111,
        );
      }

      final overLimitOk = await catProvider.addCategory(
        name: 'CatOver',
        iconId: 'star',
        colorValue: 0xFF111111,
      );
      expect(overLimitOk, isFalse);
      expect(catProvider.lastError, isA<LimitExceededException>());
    });
  });
}
