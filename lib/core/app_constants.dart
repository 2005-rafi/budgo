class AppConstants {
  // Hive Box Names
  static const String kExpensesBox = 'expenses';
  static const String kIncomesBox = 'incomes';
  static const String kFutureExpensesBox = 'future_expenses';
  static const String kBudgetsBox = 'budgets';

  // Hive Special Keys
  static const String kActiveBudgetKey = 'active_budget';

  // SharedPreferences Keys
  static const String kThemeModeKey = 'isDarkMode';
  static const String kBudgetModeKey = 'isBudgetModeEnabled';
  static const String kThemeContrastKey = 'themeContrast';

  // Category Names
  static const List<String> kDefaultCategories = [
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Lend',
    'Other',
  ];
  static const String kCategoryOther = 'Other';

  // Income Sources
  static const List<String> kDefaultIncomeSources = [
    'Salary',
    'Freelance',
    'Gift',
    'Other',
  ];

  // Budget Periods
  static const String kPeriodDaily = 'daily';
  static const String kPeriodWeekly = 'weekly';
  static const String kPeriodMonthly = 'monthly';
  static const String kPeriodYearly = 'yearly';
  static const String kPeriodOverall = 'overall';

  // Validation Limits
  static const int kMaxProductNameLength = 100;
  static const double kMinAmount = 0.01;
  static const double kMaxAmount = 10000000.0;
  static const int kMaxDescriptionLength = 300;
  static const int kMaxCustomCategoryLength = 50;

  // Budget Threshold
  static const double kBudgetWarningThreshold = 0.9;

  // Pagination limit
  static const int kExpensePageSize = 50;

  // Helper Utilities
  static double normalizeMoney(double raw) => (raw * 100).round() / 100;
  static int dateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  static final DateTime kEpoch = DateTime(2020, 1, 1);
}
