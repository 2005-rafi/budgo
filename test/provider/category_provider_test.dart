import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense/core/registries/category_registry.dart';
import 'package:expense/providers/category_provider.dart';

class _FakeBox implements Box {
  final Map<dynamic, dynamic> _storage = {};

  @override
  dynamic get(key, {defaultValue}) => _storage[key] ?? defaultValue;

  @override
  Future<void> put(key, value) async {
    _storage[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CategoryProvider Tests', () {
    late _FakeBox fakeBox;
    late CategoryProvider provider;

    setUp(() {
      fakeBox = _FakeBox();
      provider = CategoryProvider(fakeBox);
    });

    test('Initializes with 5 default categories on clean launch', () {
      expect(provider.activeCount, 5);
      expect(provider.canAddMore, true);
      final names = provider.categories.map((c) => c.name).toList();
      expect(names, ['Food', 'Travel', 'Bills', 'Shopping', 'Entertainment']);

      // Verify CategoryRegistry has them registered
      expect(CategoryRegistry.get('Food').label, 'Food');
      expect(CategoryRegistry.get('Travel').label, 'Travel');
    });

    test('Adds new category within 16-char limit and registers in CategoryRegistry', () async {
      final success = await provider.addCategory(
        name: 'Gym & Fitness',
        iconId: 'fitness_center',
        colorValue: 0xFF4CAF50,
      );

      expect(success, true);
      expect(provider.activeCount, 6);
      expect(provider.categories.last.name, 'Gym & Fitness');

      final def = CategoryRegistry.get('Gym & Fitness');
      expect(def.label, 'Gym & Fitness');
    });

    test('Rejects category name exceeding 16 characters', () async {
      final success = await provider.addCategory(
        name: 'Super Long Category Name Exceeding Limit',
        iconId: 'category',
        colorValue: 0xFF000000,
      );

      expect(success, false);
      expect(provider.activeCount, 5);
    });

    test('Rejects duplicate category name (case-insensitive)', () async {
      final success = await provider.addCategory(
        name: 'food',
        iconId: 'fastfood',
        colorValue: 0xFFE57373,
      );

      expect(success, false);
      expect(provider.activeCount, 5);
    });

    test('Enforces strict ceiling of 12 categories maximum', () async {
      // 5 are already present. Add 7 more to reach 12.
      for (int i = 1; i <= 7; i++) {
        final added = await provider.addCategory(
          name: 'Extra Cat $i',
          iconId: 'category',
          colorValue: 0xFF2196F3,
        );
        expect(added, true);
      }

      expect(provider.activeCount, 12);
      expect(provider.canAddMore, false);

      // Attempting to add a 13th category must fail
      final added13th = await provider.addCategory(
        name: 'Cat 13',
        iconId: 'category',
        colorValue: 0xFF2196F3,
      );
      expect(added13th, false);
      expect(provider.activeCount, 12);
    });

    test('Archiving category soft-deletes and preserves at least 1 active', () async {
      final foodId = provider.categories.first.id;
      final archived = await provider.archiveCategory(foodId);
      expect(archived, true);
      expect(provider.activeCount, 4);
      expect(provider.categories.any((c) => c.id == foodId), false);

      // Archive remaining until 1 left
      final remainingIds = provider.categories.map((c) => c.id).toList();
      for (int i = 0; i < remainingIds.length - 1; i++) {
        await provider.archiveCategory(remainingIds[i]);
      }
      expect(provider.activeCount, 1);

      // Archiving the last remaining category must be blocked
      final lastId = provider.categories.first.id;
      final archivedLast = await provider.archiveCategory(lastId);
      expect(archivedLast, false);
      expect(provider.activeCount, 1);
    });

    test('Reordering categories updates sort order', () async {
      // Move 'Shopping' (index 3) to index 0
      await provider.reorderCategories(3, 0);
      expect(provider.categories.first.name, 'Shopping');
    });
  });
}
