class AppConstants {
  // Hive Box Names
  static const String kExpensesBox = 'expenses';
  static const String kIncomesBox = 'incomes';
  static const String kFutureExpensesBox = 'future_expenses';
  static const String kBudgetsBox = 'budgets';
  static const String kRemindersBox = 'reminders';
  static const String kJobsBox = 'jobs';
  static const String kAppStateBox = 'app_state';
  static const String kWorkspacesBox = 'workspaces';
  static const String kAccountsBox = 'accounts';
  static const String kTransfersBox = 'transfers';
  static const String kTransferJournalBox = 'transfer_journal';
  static const String kVaultsBox = 'savings_vaults';

  // Hive Special Keys
  static const String kActiveBudgetKey = 'active_budget';
  static String budgetKeyForWorkspace(String workspaceId) =>
      'budget_${workspaceId.isEmpty ? kDefaultWorkspaceId : workspaceId}';
  static const String kActiveWorkspaceIdKey = 'active_workspace_id';
  static const String kDefaultWorkspaceId = 'default_personal';
  static const String kCashAccountId = 'acc_default_cash';
  static const String kBankAccountId = 'acc_default_bank';
  static const String kUpiAccountId = 'acc_default_upi';

  // DBMS, Scaling & Export Guard Constants
  static const int kMaxPdfDetailRows = 4000;
  static const int kExportChunkSize = 1000;
  static const int kDbBatchChunkSize = 500;
  static const int kIsolateSortThreshold = 1000;
  static const String kExportSubdirName = 'budgo_exports';
  static const int kMaxChartBins = 31;
  static const String kPdfLogoAsset = 'assets/icon/app_logo_pdf.png';
  static const String kPdfFontRegularAsset = 'assets/fonts/Roboto-Regular.ttf';
  static const String kPdfFontBoldAsset = 'assets/fonts/Roboto-Bold.ttf';

  // SharedPreferences Keys
  static const String kThemeModeKey = 'isDarkMode';
  static const String kBudgetModeKey = 'isBudgetModeEnabled';
  static const String kMonthlyRefreshKey = 'monthlyRefresh';
  static const String kThemeContrastKey = 'themeContrast';
  static const String kCurrencySymbolKey = 'currencySymbol';
  static const String kPrivacyModeKey = 'isPrivacyModeEnabled';
  static const String kDefaultPaymentMethodKey = 'default_payment_method';

  // AppStateBox Keys & Category Constraints
  static const String kUserCategoriesKey = 'user_categories_v1';
  static const int kMaxCategoryLimit = 12;
  static const int kMaxCategoryNameLength = 16;

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
  static const double kMaxAmount = 10000000.0; // 1 Crore Rupees (legacy alias)
  static const double kMaxAmountRupees = 10000000.0; // 1 Crore Rupees
  static const int kMaxAmountPaise = 1000000000; // 100 Crore Paise
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
