import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/provider/app_navigation_provider.dart';
import 'package:expense/widgets/common/app_quick_actions_sheet.dart';
import 'home_screen.dart';
import 'activity_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    ActivityScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<AppNavigationProvider>();
    final currentIndex = navProvider.currentIndex;
    final showFab = currentIndex == 0 || currentIndex == 1;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          navProvider.setIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () => AppQuickActionsSheet.show(context),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: const Icon(Icons.add, size: 24),
            )
          : null,
    );
  }
}
