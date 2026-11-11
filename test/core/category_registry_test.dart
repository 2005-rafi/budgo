import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense/core/registries/category_registry.dart';
import 'package:expense/core/registries/curated_icons_catalog.dart';

void main() {
  group('CategoryRegistry', () {
    test('CuratedIconsCatalog contains exactly 100 unique offline icon pairs with outlined and filled variants', () {
      final icons = CuratedIconsCatalog.allIcons;
      expect(icons.length, equals(100));

      final ids = <String>{};
      for (final pair in icons) {
        expect(ids.add(pair.id), isTrue, reason: 'Duplicate icon id: ${pair.id}');
        expect(pair.outlined, isNotNull);
        expect(pair.filled, isNotNull);
        expect(pair.getIcon(isSelected: false), equals(pair.outlined));
        expect(pair.getIcon(isSelected: true), equals(pair.filled));
      }
    });

    test('resolves canonical expense categories case-insensitively', () {
      final foodDef = CategoryRegistry.get('food');
      expect(foodDef.id, 'food');
      expect(foodDef.label, 'Food');
      expect(foodDef.icon, Icons.restaurant_outlined);
      expect(foodDef.isExpense, isTrue);

      final upperTravel = CategoryRegistry.get('TRAVEL');
      expect(upperTravel.id, 'travel');
      expect(upperTravel.label, 'Travel');
      expect(upperTravel.icon, Icons.directions_car_outlined);

      final spacedBills = CategoryRegistry.get('  Bills  ');
      expect(spacedBills.id, 'bills');
      expect(spacedBills.label, 'Bills');
      expect(spacedBills.icon, Icons.receipt_outlined);
    });

    test('resolves canonical income categories', () {
      final salaryDef = CategoryRegistry.get('salary');
      expect(salaryDef.id, 'salary');
      expect(salaryDef.label, 'Salary');
      expect(salaryDef.icon, Icons.work_outline);
      expect(salaryDef.isIncome, isTrue);

      final freelanceDef = CategoryRegistry.get('Freelance');
      expect(freelanceDef.id, 'freelance');
      expect(freelanceDef.icon, Icons.laptop_outlined);
    });

    test('falls back gracefully on unknown custom category', () {
      final custom = CategoryRegistry.get('Cryptocurrency');
      expect(custom.id, 'cryptocurrency');
      expect(custom.label, 'Cryptocurrency');
      expect(custom.icon, Icons.category_outlined);
      expect(custom.isExpense, isTrue);
    });

    test('falls back on null or empty string', () {
      final nullResult = CategoryRegistry.get(null);
      expect(nullResult.id, 'other');

      final emptyResult = CategoryRegistry.get('   ');
      expect(emptyResult.id, 'other');
    });

    test('String extension methods operate identically to CategoryRegistry.get', () {
      expect('food'.categoryIcon, Icons.restaurant_outlined);
      expect('shopping'.categoryIcon, Icons.shopping_bag_outlined);
      expect('health'.categoryIcon, Icons.medical_services_outlined);
      expect('education'.categoryIcon, Icons.school_outlined);
      expect('lend'.categoryIcon, Icons.handshake_outlined);
      expect('entertainment'.categoryIcon, Icons.movie_outlined);
    });

    test('allExpenses and allIncomes collections are non-empty', () {
      final expenses = CategoryRegistry.allExpenses;
      final incomes = CategoryRegistry.allIncomes;

      expect(expenses.isNotEmpty, isTrue);
      expect(incomes.isNotEmpty, isTrue);
      expect(expenses.any((c) => c.label == 'Food'), isTrue);
      expect(incomes.any((c) => c.label == 'Salary'), isTrue);
    });

    testWidgets('resolves theme-adaptive light and dark colors', (tester) async {
      late Color lightFoodColor;
      late Color darkFoodColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData.light(),
            child: Builder(
              builder: (context) {
                lightFoodColor = 'food'.resolveCategoryColor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData.dark(),
            child: Builder(
              builder: (context) {
                darkFoodColor = 'food'.resolveCategoryColor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(lightFoodColor, isNotNull);
      expect(darkFoodColor, isNotNull);
      // Light (0xFFE57373) and dark (0xFFEF9A9A) palettes use calibrated different shades
      expect(lightFoodColor, isNot(equals(darkFoodColor)));
    });
  });
}
