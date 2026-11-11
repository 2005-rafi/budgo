import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/widgets/home/app_budget_card.dart';
import 'package:expense/widgets/tiles/app_transaction_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GPay UI/UX Refinement Tests', () {
    testWidgets('AppTransactionTile renders amounts without + or - signs', (tester) async {
      // 1. Income Tile
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTransactionTile(
              title: 'Monthly Paycheck',
              amount: 1000000, // ₹10,000.00
              category: 'Salary',
              date: DateTime.now(),
              isIncome: true,
              isPending: false,
              isPlanned: false,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Monthly Paycheck'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('₹10,000.00'), findsOneWidget);
      expect(find.text('+₹10,000.00'), findsNothing);
      expect(find.text('-₹10,000.00'), findsNothing);

      // 2. Expense Tile
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTransactionTile(
              title: 'Grocery',
              amount: 50000, // ₹500.00
              category: 'Food',
              date: DateTime.now(),
              isIncome: false,
              isPending: false,
              isPlanned: false,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('-₹500.00'), findsNothing);
      expect(find.text('+₹500.00'), findsNothing);
    });

    testWidgets('AppBudgetCard has no eye toggle and reacts to AppPreferencesProvider privacy mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final prefsProvider = AppPreferencesProvider(prefs);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: prefsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: AppBudgetCard(
                budgetLimit: 5000000,
                spent: 200000, // ₹2,000.00
                income: 1000000, // ₹10,000.00
                balance: 800000, // ₹8,000.00
              ),
            ),
          ),
        ),
      );

      // Verify no eye button is present on the card
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      // Verify subtotals have NO + or - prefixes
      expect(find.text('₹10,000.00'), findsOneWidget); // Income
      expect(find.text('₹2,000.00'), findsOneWidget); // Spent
      expect(find.text('+₹10,000.00'), findsNothing);
      expect(find.text('-₹2,000.00'), findsNothing);

      // Verify initial balance
      expect(find.text('₹8,000.00'), findsOneWidget);

      // Now toggle Privacy Mode in preferences
      await prefsProvider.setPrivacyMode(true);
      await tester.pumpAndSettle();

      // Balances should now be masked reactively without any manual screen refresh
      expect(find.text('₹ ••••••'), findsOneWidget); // Total Balance masked
      expect(find.text('₹ ••••'), findsNWidgets(2)); // Both Income and Spent masked
      expect(find.text('+ ₹ ••••'), findsNothing);
      expect(find.text('- ₹ ••••'), findsNothing);

      // Disable Privacy Mode
      await prefsProvider.setPrivacyMode(false);
      await tester.pumpAndSettle();

      expect(find.text('₹8,000.00'), findsOneWidget);
    });
  });
}
