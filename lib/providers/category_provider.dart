import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/registries/category_registry.dart';
import 'package:expense/models/user_category.dart';

class CategoryProvider extends ChangeNotifier {
  Box? _appStateBox;
  List<UserCategory> _categories = [];
  Object? _lastError;
  String? _errorMessage;

  Object? get lastError => _lastError;
  String? get errorMessage => _errorMessage;

  List<UserCategory> get categories {
    final list = _categories.where((c) => !c.isArchived).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<UserCategory> get allCategories => List.unmodifiable(_categories);

  int get activeCount => categories.length;
  bool get canAddMore => activeCount < AppConstants.kMaxCategoryLimit;

  CategoryProvider([this._appStateBox]) {
    _load();
  }

  void attachBox(Box box) {
    _appStateBox = box;
    _load();
    notifyListeners();
  }

  void _load() {
    final box = _appStateBox;
    final raw = box?.get(AppConstants.kUserCategoriesKey);
    if (raw != null) {
      try {
        final List<dynamic> list = raw is String ? jsonDecode(raw) : (raw as List);
        _categories = list
            .map((item) => UserCategory.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (e) {
        debugPrint('CategoryProvider: Failed to parse stored categories, resetting: $e');
        _categories = List.from(_buildDefaultCategories());
      }
    } else {
      _categories = List.from(_buildDefaultCategories());
    }

    _syncRegistry();
  }

  static List<UserCategory> _buildDefaultCategories() {
    return const [
      UserCategory(
        id: 'cat_food',
        name: 'Food',
        iconId: 'restaurant',
        colorValue: 0xFFE57373, // Coral Red
        isDefault: true,
        sortOrder: 0,
      ),
      UserCategory(
        id: 'cat_travel',
        name: 'Travel',
        iconId: 'directions_car',
        colorValue: 0xFF4FC3F7, // Sky Blue
        isDefault: true,
        sortOrder: 1,
      ),
      UserCategory(
        id: 'cat_bills',
        name: 'Bills',
        iconId: 'receipt',
        colorValue: 0xFF81C784, // Soft Green
        isDefault: true,
        sortOrder: 2,
      ),
      UserCategory(
        id: 'cat_shopping',
        name: 'Shopping',
        iconId: 'shopping_bag',
        colorValue: 0xFFFFB74D, // Warm Amber
        isDefault: true,
        sortOrder: 3,
      ),
      UserCategory(
        id: 'cat_entertainment',
        name: 'Entertainment',
        iconId: 'movie',
        colorValue: 0xFFFF8A65, // Deep Apricot
        isDefault: true,
        sortOrder: 4,
      ),
    ];
  }

  void _syncRegistry() {
    final map = <String, UserCategory>{};
    for (final cat in _categories) {
      map[cat.name.toLowerCase().trim()] = cat;
    }
    CategoryRegistry.syncWithUserCategories(map);
  }

  Future<void> _persist() async {
    final box = _appStateBox;
    if (box != null) {
      final jsonList = _categories.map((c) => c.toJson()).toList();
      await box.put(AppConstants.kUserCategoriesKey, jsonEncode(jsonList));
    }
    _syncRegistry();
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
    _errorMessage = null;
  }

  void _setError(AppException err) {
    _lastError = err;
    _errorMessage = err.message;
  }

  Future<bool> addCategory({
    required String name,
    required String iconId,
    required int colorValue,
  }) async {
    _clearError();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _setError(ValidationException('Category name is required.'));
      return false;
    }
    if (trimmed.length > AppConstants.kMaxCategoryNameLength) {
      _setError(
        LimitExceededException(
          'Category name cannot exceed ${AppConstants.kMaxCategoryNameLength} characters.',
          maxLimit: AppConstants.kMaxCategoryNameLength,
          guidance: 'Shorten the category name and try again.',
        ),
      );
      return false;
    }
    if (!canAddMore) {
      _setError(
        LimitExceededException(
          'Maximum of ${AppConstants.kMaxCategoryLimit} active categories reached.',
          maxLimit: AppConstants.kMaxCategoryLimit,
          guidance: 'Archive an unused category in Settings before adding a new one.',
        ),
      );
      return false;
    }
    final isDuplicate = categories.any(
      (c) => c.name.toLowerCase().trim() == trimmed.toLowerCase(),
    );
    if (isDuplicate) {
      _setError(
        DuplicateEntityException(
          'A category named "$trimmed" already exists.',
          entityType: 'category',
        ),
      );
      return false;
    }

    final newCat = UserCategory(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      iconId: iconId,
      colorValue: colorValue,
      isDefault: false,
      isArchived: false,
      sortOrder: _categories.length,
    );

    _categories.add(newCat);
    await _persist();
    return true;
  }

  Future<bool> updateCategory(UserCategory updated) async {
    _clearError();
    final index = _categories.indexWhere((c) => c.id == updated.id);
    if (index == -1) {
      _setError(NotFoundException('Category could not be found.', entityType: 'category'));
      return false;
    }

    final trimmed = updated.name.trim();
    if (trimmed.isEmpty) {
      _setError(ValidationException('Category name is required.'));
      return false;
    }
    if (trimmed.length > AppConstants.kMaxCategoryNameLength) {
      _setError(
        LimitExceededException(
          'Category name cannot exceed ${AppConstants.kMaxCategoryNameLength} characters.',
          maxLimit: AppConstants.kMaxCategoryNameLength,
          guidance: 'Shorten the category name and try again.',
        ),
      );
      return false;
    }

    final isDuplicate = categories.any(
      (c) => c.id != updated.id && c.name.toLowerCase().trim() == trimmed.toLowerCase(),
    );
    if (isDuplicate) {
      _setError(
        DuplicateEntityException(
          'Another category named "$trimmed" already exists.',
          entityType: 'category',
        ),
      );
      return false;
    }

    _categories[index] = updated.copyWith(name: trimmed);
    await _persist();
    return true;
  }

  Future<bool> archiveCategory(String categoryId) async {
    _clearError();
    if (activeCount <= 1) {
      _setError(
        ValidationException(
          'At least 1 active category is required.',
          guidance: 'Create another category before archiving this one.',
        ),
      );
      return false;
    }

    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) {
      _setError(NotFoundException('Category could not be found.', entityType: 'category'));
      return false;
    }

    _categories[index] = _categories[index].copyWith(isArchived: true);
    await _persist();
    return true;
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final active = categories.toList();
    if (oldIndex < 0 || oldIndex >= active.length) return;
    if (newIndex < 0 || newIndex > active.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = active.removeAt(oldIndex);
    active.insert(newIndex, item);

    // Update sortOrder
    for (int i = 0; i < active.length; i++) {
      final catId = active[i].id;
      final idx = _categories.indexWhere((c) => c.id == catId);
      if (idx != -1) {
        _categories[idx] = _categories[idx].copyWith(sortOrder: i);
      }
    }

    await _persist();
  }

  Future<void> resetToDefaults() async {
    _categories = List.from(_buildDefaultCategories());
    await _persist();
  }

  void reload() {
    _load();
    notifyListeners();
  }
}
