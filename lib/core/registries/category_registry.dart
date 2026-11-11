import 'package:flutter/material.dart';
import 'package:expense/core/registries/curated_icons_catalog.dart';
import 'package:expense/models/user_category.dart';

/// Metadata definition for a transaction category.
class CategoryDefinition {
  final String id;
  final String label;
  final IconData icon;
  final IconData? outlinedIcon;
  final IconData? filledIcon;
  final Color Function(BuildContext context) colorResolver;
  final bool isExpense;
  final bool isIncome;

  const CategoryDefinition({
    required this.id,
    required this.label,
    required this.icon,
    this.outlinedIcon,
    this.filledIcon,
    required this.colorResolver,
    this.isExpense = true,
    this.isIncome = false,
  });

  IconData getIcon({required bool isSelected}) {
    if (isSelected && filledIcon != null) return filledIcon!;
    if (!isSelected && outlinedIcon != null) return outlinedIcon!;
    return icon;
  }

  Color resolveColor(BuildContext context) => colorResolver(context);
}

/// Centralized registry providing canonical metadata, icons, and theme-adaptive
/// colors for all expense categories and income sources.
class CategoryRegistry {
  CategoryRegistry._();

  // --- Light Palette ---
  static const Map<String, Color> _lightPalette = {
    'food': Color(0xFFE57373),         // Coral Red
    'travel': Color(0xFF4FC3F7),       // Sky Blue
    'bills': Color(0xFF81C784),        // Soft Green
    'shopping': Color(0xFFFFB74D),     // Warm Amber
    'lend': Color(0xFFBA68C8),         // Lavender Purple
    'entertainment': Color(0xFFFF8A65),// Deep Apricot
    'health': Color(0xFF4DB6AC),       // Minty Teal
    'education': Color(0xFF90A4AE),    // Cool Grey
    'other': Color(0xFF9E9E9E),        // Neutral Grey
    'salary': Color(0xFF66BB6A),       // Vibrant Green
    'freelance': Color(0xFF26A69A),    // Rich Teal
    'gift': Color(0xFFAB47BC),         // Vibrant Purple
  };

  // --- Dark Palette ---
  static const Map<String, Color> _darkPalette = {
    'food': Color(0xFFEF9A9A),         // Soft Rose
    'travel': Color(0xFF81D4FA),       // Pastel Sky Blue
    'bills': Color(0xFFA5D6A7),        // Light Mint
    'shopping': Color(0xFFFFCC80),     // Soft Orange
    'lend': Color(0xFFE1BEE7),         // Soft Lavender
    'entertainment': Color(0xFFFFCCBC),// Cream Peach
    'health': Color(0xFF80CBC4),       // Soft Teal
    'education': Color(0xFFB0BEC5),    // Blue Grey
    'other': Color(0xFFBDBDBD),        // Light Grey
    'salary': Color(0xFF81C784),       // Soft Vibrant Green
    'freelance': Color(0xFF4DB6AC),    // Soft Teal
    'gift': Color(0xFFCE93D8),         // Soft Purple
  };

  // --- Fallback Palettes for Custom Categories ---
  static const List<Color> _lightFallback = [
    Color(0xFF5C6BC0),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
    Color(0xFF8D6E63),
    Color(0xFF7E57C2),
    Color(0xFF29B6F6),
  ];

  static const List<Color> _darkFallback = [
    Color(0xFF9FA8DA),
    Color(0xFFB39DDB),
    Color(0xFF80DEEA),
    Color(0xFFD7CCC8),
    Color(0xFFB388FF),
    Color(0xFF80D8FF),
  ];

  static Color _resolve(String key, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? _darkPalette : _lightPalette;
    if (palette.containsKey(key)) {
      return palette[key]!;
    }
    final hash = key.hashCode.abs();
    final fallbacks = isDark ? _darkFallback : _lightFallback;
    return fallbacks[hash % fallbacks.length];
  }

  // --- Canonical Definitions ---
  static final Map<String, CategoryDefinition> _definitions = {
    'food': CategoryDefinition(
      id: 'food',
      label: 'Food',
      icon: Icons.restaurant_outlined,
      colorResolver: (ctx) => _resolve('food', ctx),
      isExpense: true,
    ),
    'travel': CategoryDefinition(
      id: 'travel',
      label: 'Travel',
      icon: Icons.directions_car_outlined,
      colorResolver: (ctx) => _resolve('travel', ctx),
      isExpense: true,
    ),
    'bills': CategoryDefinition(
      id: 'bills',
      label: 'Bills',
      icon: Icons.receipt_outlined,
      colorResolver: (ctx) => _resolve('bills', ctx),
      isExpense: true,
    ),
    'shopping': CategoryDefinition(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined,
      colorResolver: (ctx) => _resolve('shopping', ctx),
      isExpense: true,
    ),
    'lend': CategoryDefinition(
      id: 'lend',
      label: 'Lend',
      icon: Icons.handshake_outlined,
      colorResolver: (ctx) => _resolve('lend', ctx),
      isExpense: true,
    ),
    'entertainment': CategoryDefinition(
      id: 'entertainment',
      label: 'Entertainment',
      icon: Icons.movie_outlined,
      colorResolver: (ctx) => _resolve('entertainment', ctx),
      isExpense: true,
    ),
    'health': CategoryDefinition(
      id: 'health',
      label: 'Health',
      icon: Icons.medical_services_outlined,
      colorResolver: (ctx) => _resolve('health', ctx),
      isExpense: true,
    ),
    'education': CategoryDefinition(
      id: 'education',
      label: 'Education',
      icon: Icons.school_outlined,
      colorResolver: (ctx) => _resolve('education', ctx),
      isExpense: true,
    ),
    'other': CategoryDefinition(
      id: 'other',
      label: 'Other',
      icon: Icons.category_outlined,
      colorResolver: (ctx) => _resolve('other', ctx),
      isExpense: true,
      isIncome: true,
    ),
    // Incomes
    'salary': CategoryDefinition(
      id: 'salary',
      label: 'Salary',
      icon: Icons.work_outline,
      colorResolver: (ctx) => _resolve('salary', ctx),
      isExpense: false,
      isIncome: true,
    ),
    'freelance': CategoryDefinition(
      id: 'freelance',
      label: 'Freelance',
      icon: Icons.laptop_outlined,
      colorResolver: (ctx) => _resolve('freelance', ctx),
      isExpense: false,
      isIncome: true,
    ),
    'gift': CategoryDefinition(
      id: 'gift',
      label: 'Gift',
      icon: Icons.card_giftcard_outlined,
      colorResolver: (ctx) => _resolve('gift', ctx),
      isExpense: false,
      isIncome: true,
    ),
    'income': CategoryDefinition(
      id: 'income',
      label: 'Income',
      icon: Icons.arrow_downward_outlined,
      colorResolver: (ctx) => Theme.of(ctx).colorScheme.secondary,
      isExpense: false,
      isIncome: true,
    ),
  };

  static final Map<String, CategoryDefinition> _customDefinitions = {};

  /// Synchronize dynamic user categories with the registry.
  static void syncWithUserCategories(Map<String, UserCategory> userCategories) {
    _customDefinitions.clear();
    for (final entry in userCategories.entries) {
      final userCat = entry.value;
      final key = entry.key;
      final pair = CuratedIconsCatalog.get(userCat.iconId);
      _customDefinitions[key] = CategoryDefinition(
        id: userCat.id,
        label: userCat.name,
        icon: pair.outlined,
        outlinedIcon: pair.outlined,
        filledIcon: pair.filled,
        colorResolver: (ctx) => Color(userCat.colorValue),
        isExpense: true,
      );
    }
  }

  /// Fallback definition for custom or unrecognized categories.
  static CategoryDefinition _createFallback(String categoryName) {
    final key = categoryName.trim().toLowerCase();
    return CategoryDefinition(
      id: key,
      label: categoryName.trim().isNotEmpty ? categoryName.trim() : 'Other',
      icon: Icons.category_outlined,
      outlinedIcon: Icons.category_outlined,
      filledIcon: Icons.category,
      colorResolver: (ctx) => _resolve(key, ctx),
      isExpense: true,
    );
  }

  /// Look up metadata for a category name (case-insensitive, trimmed).
  static CategoryDefinition get(String? categoryName) {
    if (categoryName == null || categoryName.trim().isEmpty) {
      return _definitions['other']!;
    }
    final key = categoryName.trim().toLowerCase();
    return _customDefinitions[key] ?? _definitions[key] ?? _createFallback(categoryName);
  }

  /// All canonical expense categories.
  static List<CategoryDefinition> get allExpenses =>
      _definitions.values.where((c) => c.isExpense).toList(growable: false);

  /// All canonical income sources.
  static List<CategoryDefinition> get allIncomes =>
      _definitions.values.where((c) => c.isIncome).toList(growable: false);
}

/// Syntactic sugar extension on String for convenient category access.
extension CategoryStringExtension on String {
  CategoryDefinition get categoryDef => CategoryRegistry.get(this);
  IconData get categoryIcon => categoryDef.icon;
  IconData categoryStateIcon({bool isSelected = false}) => categoryDef.getIcon(isSelected: isSelected);
  Color resolveCategoryColor(BuildContext context) => categoryDef.resolveColor(context);
}

