import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense/design/budgo_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgoInputPolicy & BudgoTextSafetyFormatter', () {
    test('WorkspaceName policy blocks spaces and caps length at 20 graphemes', () {
      final formatter = BudgoTextSafetyFormatter(policy: BudgoInputPolicy.workspaceName);

      // Typing with spaces -> spaces are stripped
      const original = TextEditingValue(text: 'Goa');
      const typingWithSpace = TextEditingValue(
        text: 'Goa Trip 2026',
        selection: TextSelection.collapsed(offset: 13),
      );
      final result1 = formatter.formatEditUpdate(original, typingWithSpace);
      expect(result1.text, 'GoaTrip2026');

      // Clamps past 20 characters
      const overflow = TextEditingValue(
        text: 'ThisIsAVeryLongWorkspaceNameExceeding20',
        selection: TextSelection.collapsed(offset: 39),
      );
      final result2 = formatter.formatEditUpdate(original, overflow);
      expect(result2.text.length, 20);
      expect(result2.text, 'ThisIsAVeryLongWorks');
    });

    test('Formula injection characters are stripped from leading position', () {
      final formatter = BudgoTextSafetyFormatter(policy: BudgoInputPolicy.workspaceName);
      const original = TextEditingValue.empty;
      const formulaPasted = TextEditingValue(
        text: '=cmd|/C calc',
        selection: TextSelection.collapsed(offset: 12),
      );
      final result = formatter.formatEditUpdate(original, formulaPasted);
      expect(result.text, 'cmd|/Ccalc');
    });
  });

  group('BudgoTextField & BudgoCharacterCounter', () {
    testWidgets('Renders dynamic counter pill and updates live on input', (tester) async {
      final controller = TextEditingController(text: 'Initial');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BudgoTextField(
                controller: controller,
                inputPolicy: BudgoInputPolicy.workspaceName,
                label: 'Workspace Name',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace Name'), findsOneWidget);
      expect(find.text('7 / 20'), findsOneWidget);
      expect(find.text('Up to 20 characters · No spaces allowed'), findsOneWidget);

      // Enter more text
      await tester.enterText(find.byType(TextFormField), 'ProductLaunch');
      await tester.pumpAndSettle();

      expect(find.text('13 / 20'), findsOneWidget);

      // Entering spaces is prevented by the policy formatter
      await tester.enterText(find.byType(TextFormField), 'My Space Test');
      await tester.pumpAndSettle();
      expect(find.text('11 / 20'), findsOneWidget);
      expect(find.text('MySpaceTest'), findsOneWidget);
    });
  });

  group('BudgoLayeredActionLayout & BudgoActionDialog', () {
    testWidgets('Renders borderless 3-tier action matrix and handles callbacks', (tester) async {
      bool paidTapped = false;
      bool skipTapped = false;
      bool deleteTapped = false;
      bool editTapped = false;
      bool cancelTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: FilledButton(
                  onPressed: () {
                    BudgoActionDialog.show(
                      ctx,
                      title: 'Manage Reminder',
                      message: 'What would you like to do with "Internet Bill"?',
                      actions: BudgoLayeredActionLayout(
                        level1: [
                          BudgoActionCell(
                            label: 'Mark as Paid',
                            variant: BudgoButtonVariant.primary,
                            onPressed: () {
                              paidTapped = true;
                              Navigator.pop(ctx);
                            },
                          ),
                          BudgoActionCell(
                            label: 'Skip Cycle',
                            variant: BudgoButtonVariant.tonal,
                            onPressed: () {
                              skipTapped = true;
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                        level2: [
                          BudgoActionCell(
                            label: 'Delete',
                            variant: BudgoButtonVariant.destructive,
                            onPressed: () {
                              deleteTapped = true;
                              Navigator.pop(ctx);
                            },
                          ),
                          BudgoActionCell(
                            label: 'Edit',
                            variant: BudgoButtonVariant.tonal,
                            onPressed: () {
                              editTapped = true;
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                        level3: BudgoActionCell(
                          label: 'Cancel',
                          variant: BudgoButtonVariant.text,
                          onPressed: () {
                            cancelTapped = true;
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Actions'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Actions'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Reminder'), findsOneWidget);
      expect(find.text('What would you like to do with "Internet Bill"?'), findsOneWidget);
      expect(find.text('Mark as Paid'), findsOneWidget);
      expect(find.text('Skip Cycle'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Verify tap on Level 1 button
      await tester.tap(find.text('Mark as Paid'));
      await tester.pumpAndSettle();
      expect(paidTapped, isTrue);
      expect(skipTapped, isFalse);
      expect(deleteTapped, isFalse);
      expect(editTapped, isFalse);
      expect(cancelTapped, isFalse);
      expect(find.text('Manage Reminder'), findsNothing);
    });
  });
}
