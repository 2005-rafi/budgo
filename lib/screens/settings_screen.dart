import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/provider/theme_provider.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/provider/app_preferences_provider.dart';
import 'package:expense/services/storage_info_service.dart';
import 'package:expense/widgets/confirmation_dialog.dart';
import 'package:expense/widgets/snackbar_feedback.dart';
import 'package:expense/widgets/common/app_card.dart';
import 'package:expense/widgets/common/app_section_header.dart';
import 'package:expense/widgets/common/app_settings_tile.dart';
import 'package:expense/widgets/forms/reminders_management_sheet.dart';

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
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'All local database files will be wiped. We recommend exporting a CSV backup first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
    if (confirm2 != true) return;

    if (!mounted) return;
    final confirm3 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Final Verification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please type "RESET" in all caps to confirm deletion.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'RESET',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) {
                return TextButton(
                  onPressed: value.text == 'RESET'
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('RESET EVERYTHING'),
                );
              },
            ),
          ],
        );
      },
    );
    if (confirm3 != true) return;

    if (!mounted) return;
    final expensesProvider = context.read<ExpensesProvider>();
    await expensesProvider.resetAllData();
    if (!mounted) return;
    await Future.wait([
      context.read<IncomeProvider>().load(),
      context.read<ReminderProvider>().load(),
      context.read<FutureExpensesProvider>().load(),
    ]);
    if (!mounted) return;
    SnackbarFeedback.showSuccess(context, 'All data reset successfully.');
    _loadStorageSize();
  }

  Future<void> _confirmArchive() async {
    final provider = context.read<ExpensesProvider>();
    final count = provider.countOlderThan(12);

    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Archive Data',
      message:
          'Archive $count expenses older than 12 months to improve performance? They will still be available in exports.',
      confirmLabel: 'Archive Now',
    );

    if (confirm) {
      if (!mounted) return;
      await provider.archiveOldExpenses(12);
      if (!mounted) return;
      SnackbarFeedback.showSuccess(context, 'Expenses archived successfully.');
      _loadStorageSize();
    }
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
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
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
                    segmentedWidget: SegmentedButton<ThemeMode>(
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
                      selected: {themeProvider.themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        themeProvider.setThemeMode(newSelection.first);
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.comfortable,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.segmented,
                    title: 'Theme Contrast',
                    segmentedWidget: SegmentedButton<ThemeContrast>(
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
                      selected: {themeProvider.contrast},
                      onSelectionChanged: (Set<ThemeContrast> newSelection) {
                        themeProvider.setContrast(newSelection.first);
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.comfortable,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Group 2 — Data (occasional use)
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
                    onTap: () {
                      StorageInfoService.invalidate();
                      _loadStorageSize();
                    },
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
                    subtitle: 'Move 12+ month old items to archive',
                    leadingIcon: Icons.archive_outlined,
                    destructive: true,
                    onTap: _confirmArchive,
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.action,
                    title: 'Reset All Data',
                    subtitle: 'Permanently wipe all local records',
                    leadingIcon: Icons.delete_forever_outlined,
                    destructive: true,
                    onTap: _confirmReset,
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
