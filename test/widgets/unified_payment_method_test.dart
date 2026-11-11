import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/repositories/income_repository.dart';
import 'package:expense/repositories/workspace_repository.dart';
import 'package:expense/services/reports_data_service.dart';
import 'package:expense/widgets/sheets/transaction_bottom_sheet.dart';

class _MockBox<T> implements Box<T> {
  final Map<dynamic, T> _map = {};

  @override
  T? get(key, {T? defaultValue}) => _map[key] ?? defaultValue;

  @override
  Future<void> put(key, T value) async => _map[key] = value;

  @override
  Iterable<T> get values => _map.values;

  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GenericMockBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(key, {defaultValue}) => _map[key] ?? defaultValue;

  @override
  Future<void> put(key, value) async => _map[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unified Payment Method & Category Accordion Widget Tests', () {
    late SharedPreferences prefs;
    late AppPreferencesProvider prefsProvider;
    late CategoryProvider catProvider;
    late AccountProvider accountProvider;
    late WorkspaceProvider workspaceProvider;
    late ExpensesProvider expensesProvider;
    late IncomeProvider incomeProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AppConstants.kDefaultPaymentMethodKey: 'UPI',
      });
      prefs = await SharedPreferences.getInstance();
      prefsProvider = AppPreferencesProvider(prefs);

      final appStateBox = _GenericMockBox();
      catProvider = CategoryProvider(appStateBox);

      final accountBox = _MockBox<Account>();
      final now = DateTime.now();

      // Seed 3 standard accounts
      await accountBox.put(
        AppConstants.kCashAccountId,
        Account(
          id: AppConstants.kCashAccountId,
          workspaceId: AppConstants.kDefaultWorkspaceId,
          name: 'Cash Wallet',
          type: AccountType.cash,
          balancePaise: 500000,
          iconCodePoint: Icons.payments.codePoint,
          colorValue: 0xFF4CAF50,
          isDefault: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await accountBox.put(
        AppConstants.kUpiAccountId,
        Account(
          id: AppConstants.kUpiAccountId,
          workspaceId: AppConstants.kDefaultWorkspaceId,
          name: 'UPI / GPay',
          type: AccountType.upi,
          balancePaise: 1000000,
          iconCodePoint: Icons.qr_code.codePoint,
          colorValue: 0xFF9C27B0,
          isDefault: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await accountBox.put(
        AppConstants.kBankAccountId,
        Account(
          id: AppConstants.kBankAccountId,
          workspaceId: AppConstants.kDefaultWorkspaceId,
          name: 'Bank Account',
          type: AccountType.bankAccount,
          balancePaise: 2500000,
          iconCodePoint: Icons.account_balance.codePoint,
          colorValue: 0xFF1976D2,
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final accountRepo = HiveAccountRepository(accountBox);
      accountProvider = AccountProvider(accountRepo);
      await accountProvider.initialize(initialWorkspaceId: AppConstants.kDefaultWorkspaceId);
      await accountProvider.load();

      final wsBox = _MockBox<Workspace>();
      await wsBox.put(
        AppConstants.kDefaultWorkspaceId,
        Workspace(
          id: AppConstants.kDefaultWorkspaceId,
          name: 'Personal',
          type: WorkspaceType.personal,
          currency: '₹',
          initialBalance: 0,
          createdAt: now,
          iconCodePoint: Icons.person.codePoint,
          colorValue: 0xFF2196F3,
          isDefault: true,
        ),
      );
      workspaceProvider = WorkspaceProvider(HiveWorkspaceRepository(wsBox));
      await workspaceProvider.load();

      final expBox = _MockBox<Expense>();
      expensesProvider = ExpensesProvider(
        HiveExpenseRepository(expBox),
        ReportsDataService(),
      );

      final incBox = _MockBox<Income>();
      incomeProvider = IncomeProvider(HiveIncomeRepository(incBox));
    });

    testWidgets('TransactionBottomSheet has unified payment selector with UPI pre-selected', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: prefsProvider),
            ChangeNotifierProvider.value(value: catProvider),
            ChangeNotifierProvider.value(value: accountProvider),
            ChangeNotifierProvider.value(value: workspaceProvider),
            ChangeNotifierProvider.value(value: expensesProvider),
            ChangeNotifierProvider.value(value: incomeProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TransactionBottomSheet(mode: TransactionMode.expense),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify duplicate SegmentedButton is GONE
      expect(find.byType(SegmentedButton<String>), findsNothing);

      // 2. Verify unified Payment Method selector displays all 3 accounts
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Cash Wallet'), findsOneWidget);
      expect(find.text('UPI / GPay'), findsOneWidget);
      expect(find.text('Bank Account'), findsOneWidget);

      // 3. Verify 'UPI / GPay' is pre-selected by default because preference is UPI
      final upiChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('UPI / GPay'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(upiChip.selected, true);

      final cashChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Cash Wallet'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(cashChip.selected, false);
    });

    testWidgets('Top 4 categories are rendered initially and expand on More tap', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: prefsProvider),
            ChangeNotifierProvider.value(value: catProvider),
            ChangeNotifierProvider.value(value: accountProvider),
            ChangeNotifierProvider.value(value: workspaceProvider),
            ChangeNotifierProvider.value(value: expensesProvider),
            ChangeNotifierProvider.value(value: incomeProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TransactionBottomSheet(mode: TransactionMode.expense),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 5 active categories: Food, Travel, Bills, Shopping, Entertainment
      // Initially, only top 4 (Food, Travel, Bills, Shopping) should be visible
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Entertainment'), findsNothing);

      // Verify 'More (5)' expander is visible
      expect(find.text('More (5)'), findsOneWidget);

      // Tap 'More (5)' to expand accordion
      await tester.tap(find.text('More (5)'));
      await tester.pumpAndSettle();

      // Now all 5 categories are visible
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);

      // Tap 'Less' to collapse accordion
      await tester.tap(find.text('Less'));
      await tester.pumpAndSettle();

      expect(find.text('Entertainment'), findsNothing);
      expect(find.text('More (5)'), findsOneWidget);
    });
  });
}
