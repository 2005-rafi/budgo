import 'package:expense/models/expense.dart';
import 'package:expense/navigation/app_routes.dart';
import 'package:expense/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

// import 'package:provider/provider.dart';
// import 'package:expense/provider/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  Future<void> _showResetDialog(BuildContext context) async {
    final color = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Reset'),
        content: const Text('Are you sure you want to delete all expenses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color.error,
              foregroundColor: color.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Hive.box<Expense>('expenses').clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All expenses deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    // final themeProvider = context.watch<ThemeProvider>();
    // final isDark = themeProvider.isDarkMode;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        drawer: const AppDrawer(currentRoute: AppRoutes.settings),
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: color.primary,
          foregroundColor: color.onPrimary,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Text('General', style: theme.textTheme.titleMedium),
            // const SizedBox(height: 8),
            // Card(
            //   color: color.surfaceContainerHigh,
            //   child: SwitchListTile.adaptive(
            //     secondary: Icon(
            //       isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            //     ),
            //     title: Text(isDark ? 'Dark mode' : 'Light mode'),
            //     subtitle: Text(
            //       isDark ? 'Enabled' : 'Enabled',
            //       style: theme.textTheme.bodySmall,
            //     ),
            //     // subtitle: Text(isDark ? 'On' : 'Off', style: theme.textTheme.bodySmall),
            //     value: isDark,
            //     onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
            //   ),
            // ),
            const SizedBox(height: 24),
            Text('Danger Zone', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              color: color.tertiaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: color.onTertiaryContainer,
                ),
                title: Text(
                  'Reset all expenses',
                  style: TextStyle(color: color.onTertiaryContainer),
                ),
                subtitle: Text(
                  'Deletes all expense records from this device.',
                  style: TextStyle(
                    color: color.onTertiaryContainer,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: color.onTertiaryContainer,
                ),
                onTap: () => _showResetDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
