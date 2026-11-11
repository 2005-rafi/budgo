import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/services/safe_to_spend_service.dart';
import 'package:expense/widgets/home/app_budget_card.dart';
import 'package:expense/widgets/sheets/safe_to_spend_derivation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MoneyFormatter.symbol = '₹';
    MoneyFormatter.locale = 'en_IN';
  });

  testWidgets('Tapping Safe-to-Spend pill opens mathematical derivation bottom sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final prefsProvider = AppPreferencesProvider(prefs);

    MoneyFormatter.symbol = '₹';
    MoneyFormatter.locale = 'en_IN';

    final sts = SafeToSpendService.compute(
      now: DateTime(2026, 11, 10),
      budgetLimitPaise: null,
      spentThisMonthPaise: 0,
      liquidUnallocatedPaise: 100000,
      confirmedIncomeThisMonthPaise: 100000,
    );

    bool setBudgetTapped = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppPreferencesProvider>.value(
        value: prefsProvider,
        child: MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AppBudgetCard(
                budgetLimit: null,
                spent: 0,
                income: 100000,
                balance: 100000,
                safeToSpend: sts,
                onSetBudget: () => setBudgetTapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('₹47.61 / day'), findsOneWidget);
    expect(find.text('Tight limit'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safe_to_spend_badge')));
    await tester.pumpAndSettle();

    expect(find.text('How Daily Safe-to-Spend Works'), findsOneWidget);
    expect(find.textContaining('not an expense average'), findsOneWidget);
    expect(find.text('21 days'), findsOneWidget);
    expect(find.textContaining('₹1,000.00 ÷ 21 days'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SafeToSpendDerivationSheet),
        matching: find.text('Set Budget'),
      ),
    );
    await tester.pumpAndSettle();
    expect(setBudgetTapped, isTrue);
  });
}

