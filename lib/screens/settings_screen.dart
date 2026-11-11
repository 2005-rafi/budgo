import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/providers/theme_provider.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/services/storage_info_service.dart';
import 'package:expense/widgets/tiles/app_settings_tile.dart';
import 'package:expense/widgets/sheets/data_management_sheet.dart';
import 'package:expense/widgets/sheets/reminders_management_sheet.dart';
import 'package:expense/widgets/sheets/workspace_switcher_sheet.dart';
import 'package:expense/widgets/sheets/self_transfer_bottom_sheet.dart';
import 'package:expense/widgets/sheets/category_management_sheet.dart';
import 'package:expense/widgets/sheets/vault_management_sheet.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/services/data_lifecycle_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _storageSize = 'Loading...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStorageSize();
    });
  }

  Future<void> _loadStorageSize() async {
    final size = await StorageInfoService.getBoxSizeDescription();
    if (mounted) {
      setState(() {
        _storageSize = size;
      });
    }
  }

  Future<void> _confirmReset() async {
    final confirm1 = await ConfirmationDialog.show(
      context,
      title: 'Danger Zone: Reset Data',
      message:
          'This will permanently delete all your expenses, incomes, budgets, and settings. This cannot be undone.',
      confirmLabel: 'Next Step',
      isDestructive: true,
    );
    if (!confirm1) return;

    if (!mounted) return;
    final confirm2 = await ConfirmationDialog.show(
      context,
      title: 'Are you absolutely sure?',
      message:
          'All local database files will be wiped. We recommend exporting a CSV backup first.',
      confirmLabel: 'I Understand',
      isDestructive: true,
    );
    if (!confirm2) return;

    if (!mounted) return;
    final verification = await FactoryResetVerificationDialog.show(context);
    if (verification == null || !verification.confirmed) return;

    if (!mounted) return;
    try {
      DataLifecycleService? lifecycleService;
      try {
        lifecycleService = context.read<DataLifecycleService>();
      } on ProviderNotFoundException {
        lifecycleService = DataLifecycleService();
      }
      await lifecycleService.factoryResetAllData(
        resetCategories: verification.resetCategories,
      );
      if (!mounted) return;
      await reloadAllAppProviders(
        context,
        includeCategories: verification.resetCategories,
      );
      if (!mounted) return;
      SnackbarFeedback.showSuccess(context, 'All data reset cleanly.');
      _loadStorageSize();
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(context, e, operation: FeedbackOperation.resetData);
      }
    }
  }

  void _openArchiveSheet() {
    WorkspaceArchiveSheet.show(
      context,
      onCompleted: () {
        StorageInfoService.invalidate();
        _loadStorageSize();
      },
    );
  }

  void _openClearWorkspaceSheet() {
    WorkspaceClearSheet.show(
      context,
      onCompleted: () {
        StorageInfoService.invalidate();
        _loadStorageSize();
      },
    );
  }

  void _openStorageBreakdown() {
    StorageBreakdownSheet.show(
      context,
      onChanged: _loadStorageSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final themeProvider = context.watch<ThemeProvider>();
    final reminderProvider = context.watch<ReminderProvider>();
    final prefsProvider = context.watch<AppPreferencesProvider>();
    
    final activeRemindersCount = reminderProvider.items
        .where((r) => r.isActive && r.state == 'active')
        .length;

    return Scaffold(
      appBar: const BudgoAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          // Group 1 — Preferences (daily use)
          const AppSectionHeader(label: 'Preferences'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppSettingsTile(
                    type: AppSettingsTileType.segmented,
                    title: 'App Appearance',
                    segmentedWidget: BudgoSegmentedControl<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto, size: 18),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 18),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 18),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: themeProvider.themeMode,
                      onSelected: themeProvider.setThemeMode,
                    ),
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.segmented,
                    title: 'Theme Contrast',
                    segmentedWidget: BudgoSegmentedControl<ThemeContrast>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeContrast.low,
                          icon: Icon(Icons.brightness_low, size: 18),
                          label: Text('Low'),
                        ),
                        ButtonSegment(
                          value: ThemeContrast.medium,
                          icon: Icon(Icons.brightness_medium, size: 18),
                          label: Text('Medium'),
                        ),
                        ButtonSegment(
                          value: ThemeContrast.high,
                          icon: Icon(Icons.brightness_high, size: 18),
                          label: Text('High'),
                        ),
                      ],
                      selected: themeProvider.contrast,
                      onSelected: themeProvider.setContrast,
                    ),
                  ),
                  AppSettingsTile(
                    type: AppSettingsTileType.segmented,
                    title: 'Currency',
                    segmentedWidget: BudgoSegmentedControl<String>(
                      segments: const [
                        ButtonSegment(value: '₹', label: Text('₹')),
                        ButtonSegment(value: '\$', label: Text('\$')),
                        ButtonSegment(value: '€', label: Text('€')),
                        ButtonSegment(value: '¥', label: Text('¥')),
                      ],
                      selected: prefsProvider.currencySymbol,
                      onSelected: prefsProvider.setCurrencySymbol,
                    ),
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.toggle,
                    title: 'Enable Budget Mode',
                    subtitle: 'Track spending against limits',
                    leadingIcon: Icons.track_changes_outlined,
                    value: prefsProvider.isBudgetModeEnabled,
                    onChanged: (val) {
                      prefsProvider.setBudgetMode(val);
                    },
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.toggle,
                    title: 'Monthly Refresh',
                    subtitle: 'Show total tracking for current month only',
                    leadingIcon: Icons.autorenew,
                    value: prefsProvider.isMonthlyRefreshEnabled,
                    onChanged: (val) {
                      prefsProvider.setMonthlyRefresh(val);
                    },
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.toggle,
                    title: 'Privacy Mode (Hide Balance)',
                    subtitle: 'Mask financial balances across the app',
                    leadingIcon: Icons.visibility_off_outlined,
                    value: prefsProvider.isPrivacyModeEnabled,
                    onChanged: (val) {
                      prefsProvider.setPrivacyMode(val);
                    },
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.segmented,
                    title: 'Default Payment Method',
                    subtitle: 'Pre-selected when logging transactions',
                    segmentedWidget: BudgoSegmentedControl<String>(
                      segments: const [
                        ButtonSegment(value: 'UPI', label: Text('UPI')),
                        ButtonSegment(value: 'Cash', label: Text('Cash')),
                        ButtonSegment(value: 'Bank', label: Text('Bank')),
                      ],
                      selected: prefsProvider.defaultPaymentMethod,
                      onSelected: prefsProvider.setDefaultPaymentMethod,
                    ),
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.navigation,
                    title: 'Categories',
                    subtitle:
                        '${context.watch<CategoryProvider>().activeCount} of 12 active categories',
                    leadingIcon: Icons.category_outlined,
                    onTap: () => CategoryManagementSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Group 2 — Profiles & Accounts
          const AppSectionHeader(label: 'Profiles & Accounts'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppSettingsTile(
                    type: AppSettingsTileType.navigation,
                    title: 'Workspaces & Profiles',
                    subtitle: 'Manage personal, business, and trip workspaces',
                    leadingIcon: Icons.folder_shared_outlined,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const WorkspaceSwitcherSheet(),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.navigation,
                    title: 'Self-Transfer',
                    subtitle: 'Transfer funds between accounts',
                    leadingIcon: Icons.swap_horiz_rounded,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const SelfTransferBottomSheet(),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.navigation,
                    title: 'Savings Vaults & Goals',
                    subtitle: '${context.watch<SavingsVaultProvider>().activeVaults.length} active goals',
                    leadingIcon: Icons.savings_outlined,
                    onTap: () => VaultManagementSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Group 3 — Data (occasional use)
          const AppSectionHeader(label: 'Data'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppSettingsTile(
                    type: AppSettingsTileType.info,
                    title: 'Storage Used',
                    leadingIcon: Icons.storage_outlined,
                    trailingValue: _storageSize,
                    onTap: _openStorageBreakdown,
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.navigation,
                    title: 'Reminders',
                    leadingIcon: Icons.notifications_active_outlined,
                    trailingValue: '$activeRemindersCount active',
                    onTap: () => RemindersManagementSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Group 3 — Danger Zone (rare use)
          const AppSectionHeader(label: 'Danger Zone'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: AppCard(
              padding: EdgeInsets.zero,
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              child: Column(
                children: [
                  AppSettingsTile(
                    type: AppSettingsTileType.action,
                    title: 'Archive Old Data',
                    subtitle: 'Archive older expenses per workspace',
                    leadingIcon: Icons.archive_outlined,
                    destructive: true,
                    onTap: _openArchiveSheet,
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.action,
                    title: 'Clear Workspace Data',
                    subtitle: 'Wipe specific workspace(s) with full isolation',
                    leadingIcon: Icons.cleaning_services_outlined,
                    destructive: true,
                    onTap: _openClearWorkspaceSheet,
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.action,
                    title: 'Reset All Data',
                    subtitle: 'Permanently wipe all workspaces & local records',
                    leadingIcon: Icons.delete_forever_outlined,
                    destructive: true,
                    onTap: _confirmReset,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Group 4 — Information
          const AppSectionHeader(label: 'Information'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppSettingsTile(
                    type: AppSettingsTileType.navigation,
                    title: 'About & Legal',
                    leadingIcon: Icons.info_outline,
                    onTap: () {
                      Navigator.pushNamed(context, '/about');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
