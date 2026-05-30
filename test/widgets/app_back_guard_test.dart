import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense/widgets/app_back_guard.dart';

void main() {
  testWidgets('AppBackGuard intercepts navigation pop and invokes onBack callback', (WidgetTester tester) async {
    bool onBackCalled = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: AppBackGuard(
                        onBack: () async {
                          onBackCalled = true;
                          return false; // Prevent pop
                        },
                        child: const Center(
                          child: Text('Back Guard Content'),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Push'),
            ),
          ),
        ),
      ),
    );

    // Tap to push the route containing the guard
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    expect(find.text('Back Guard Content'), findsOneWidget);

    // Attempt to pop the route
    final context = tester.element(find.text('Back Guard Content'));
    await Navigator.of(context).maybePop();

    // Verify pop callback was triggered
    expect(onBackCalled, isTrue);

    // Verify the route was NOT actually popped (it remains visible in the tree)
    expect(find.text('Back Guard Content'), findsOneWidget);
  });
}
