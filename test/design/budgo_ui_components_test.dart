import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/design/budgo_ui.dart';

Widget _wrapTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  tearDown(() {
    MoneyFormatter.symbol = '₹';
    MoneyFormatter.locale = 'en_IN';
  });

  group('BudgoAppBar & BudgoSliverAppBar', () {
    testWidgets('BudgoAppBar renders title, subtitle, and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            appBar: BudgoAppBar(
              title: 'Reports',
              subtitle: 'Monthly Summary',
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Monthly Summary'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    });

    testWidgets('BudgoSliverAppBar renders title and action in CustomScrollView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                BudgoSliverAppBar(
                  title: 'Your Finances',
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 200)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Your Finances'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
    });
  });

  group('BudgoTextField, BudgoAmountField & BudgoSearchField', () {
    testWidgets('BudgoTextField shows label, hint, and validates input', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapTestApp(
          Form(
            key: formKey,
            child: BudgoTextField(
              controller: controller,
              label: 'Category Name',
              hint: 'e.g. Groceries',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
            ),
          ),
        ),
      );

      expect(find.text('Category Name'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Name required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Coffee');
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('BudgoAmountField tracks dynamic MoneyFormatter.symbol and presets', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      int? tappedPreset;
      bool fullBalanceTapped = false;

      MoneyFormatter.symbol = '₹';
      MoneyFormatter.locale = 'en_IN';

      await tester.pumpWidget(
        _wrapTestApp(
          BudgoAmountField(
            controller: controller,
            quickPresetsPaise: const [50000, 100000],
            onPresetSelected: (paise) => tappedPreset = paise,
            showFullBalanceAction: true,
            onFullBalanceTap: () => fullBalanceTapped = true,
          ),
        ),
      );

      expect(find.textContaining('₹'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('+₹500'));
      expect(tappedPreset, 50000);
      await tester.tap(find.text('Full Balance'));
      expect(fullBalanceTapped, isTrue);

      MoneyFormatter.symbol = r'$';
      MoneyFormatter.locale = 'en_US';

      await tester.pumpWidget(
        _wrapTestApp(
          BudgoAmountField(
            controller: controller,
            quickPresetsPaise: const [50000],
          ),
        ),
      );

      expect(find.textContaining(r'$'), findsAtLeastNWidgets(1));
    });

    testWidgets('BudgoSearchField clears text and notifies listeners on clear tap', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      bool clearedCalled = false;

      await tester.pumpWidget(
        _wrapTestApp(
          BudgoSearchField(
            controller: controller,
            hint: 'Search transactions',
            onChanged: changes.add,
            onCleared: () => clearedCalled = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.pump();

      expect(changes.last, 'coffee');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(changes.last, isEmpty);
      expect(clearedCalled, isTrue);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });

  group('BudgoDropdownField & BudgoPickerField', () {
    testWidgets('BudgoDropdownField displays options and invokes onChanged', (tester) async {
      String? selected = 'bank';

      await tester.pumpWidget(
        _wrapTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return BudgoDropdownField<String>(
                label: 'Account',
                value: selected,
                options: const [
                  BudgoDropdownItem(value: 'bank', label: 'Bank Account', trailingText: '₹5,000'),
                  BudgoDropdownItem(value: 'cash', label: 'Cash Wallet', trailingText: '₹1,200'),
                ],
                onChanged: (val) => setState(() => selected = val),
              );
            },
          ),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Bank Account'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Open menu renders options with trailing badges and selected checkmark
      expect(find.text('₹1,200'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('Cash Wallet').last);
      await tester.pumpAndSettle();

      expect(selected, 'cash');
    });

    testWidgets('BudgoPickerField renders label, value and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrapTestApp(
          BudgoPickerField(
            icon: Icons.calendar_today_outlined,
            label: 'Due Date',
            value: 'Nov 10, 2026',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Due Date'), findsOneWidget);
      expect(find.text('Nov 10, 2026'), findsOneWidget);

      await tester.tap(find.byType(BudgoPickerField));
      expect(tapped, isTrue);
    });
  });

  group('BudgoSwitchTile', () {
    testWidgets('BudgoSwitchTile toggles boolean value on tap', (tester) async {
      bool enabled = false;

      await tester.pumpWidget(
        _wrapTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return BudgoSwitchTile(
                title: 'Auto-Allocate Savings',
                subtitle: 'Reserve salary portion automatically',
                icon: Icons.savings_outlined,
                value: enabled,
                onChanged: (val) => setState(() => enabled = val),
              );
            },
          ),
        ),
      );

      expect(find.text('Auto-Allocate Savings'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      await tester.tap(find.byType(BudgoSwitchTile));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);
    });
  });

  group('BudgoChoiceGroup & BudgoSegmentedControl', () {
    testWidgets('BudgoChoiceGroup collapses with maxVisibleCount and expands/collapses', (tester) async {
      String selected = 'food';
      final options = List.generate(
        6,
        (i) => BudgoChoiceOption<String>(
          value: i == 0 ? 'food' : 'cat_$i',
          label: i == 0 ? 'Food' : 'Category $i',
        ),
      );

      await tester.pumpWidget(
        _wrapTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return BudgoChoiceGroup<String>(
                options: options,
                selectedValue: selected,
                maxVisibleCount: 4,
                onSelected: (val) => setState(() => selected = val),
              );
            },
          ),
        ),
      );

      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text('More (6)'), findsOneWidget);
      expect(find.text('Category 5'), findsNothing);

      await tester.tap(find.text('More (6)'));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(6));
      expect(find.text('Category 5'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);

      await tester.tap(find.text('Category 5'));
      await tester.pumpAndSettle();
      expect(selected, 'cat_5');

      // When collapsing while an overflow option is selected, BudgoChoiceGroup
      // preserves the selected option alongside the top 4 options (5 total).
      await tester.tap(find.text('Less'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(5));
      expect(find.text('Category 5'), findsOneWidget);
      expect(find.text('Category 4'), findsNothing);

      // Selecting an option within the top 4 collapses strictly back to 4 chips.
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(selected, 'food');
      expect(find.byType(ChoiceChip), findsNWidgets(4));
    });

    testWidgets('BudgoSegmentedControl updates selection on tap', (tester) async {
      String mode = 'expense';

      await tester.pumpWidget(
        _wrapTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return BudgoSegmentedControl<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: mode,
                onSelected: (val) => setState(() => mode = val),
              );
            },
          ),
        ),
      );

      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(mode, 'income');
    });
  });

  group('BudgoBottomSheet', () {
    testWidgets('BudgoBottomSheet renders header, subtitle, child, and footer via show', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: BudgoButton(
                  label: 'Open Sheet',
                  expanded: false,
                  onPressed: () {
                    BudgoBottomSheet.show(
                      context,
                      builder: (_) => const BudgoBottomSheet(
                        title: 'Vault Allocation',
                        subtitle: 'Assign funds safely',
                        icon: Icons.savings_outlined,
                        footer: BudgoButton(
                          label: 'Confirm Vault',
                          onPressed: null,
                        ),
                        child: Text('Body Content'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Vault Allocation'), findsOneWidget);
      expect(find.text('Assign funds safely'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Confirm Vault'), findsOneWidget);
    });
  });
}

