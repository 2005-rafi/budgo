import 'package:flutter/material.dart';
import '../navigation/app_routes.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  const AppDrawer({super.key, required this.currentRoute});

  void _go(BuildContext context, String route) {
    // Close the drawer route first
    Navigator.pop(context);

    // If already on the selected route, do nothing
    if (route == currentRoute) return;

    // Reset stack to the selected route
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _DrawerHeader(),

            _DrawerSectionTitle(title: 'Main'),
            _DrawerTile(
              selected: currentRoute == AppRoutes.home,
              icon: Icons.home_outlined,
              title: 'Home',
              onTap: () => _go(context, AppRoutes.home),
            ),
            _DrawerTile(
              selected: currentRoute == AppRoutes.expenses,
              icon: Icons.receipt_long_outlined,
              title: 'Expenses',
              onTap: () => _go(context, AppRoutes.expenses),
            ),

            const Divider(height: 24),
            _DrawerSectionTitle(title: 'Planning'),
            _DrawerTile(
              selected: currentRoute == AppRoutes.futureExpenses,
              icon: Icons.shopping_bag_outlined,
              title: 'Future Expenses',
              onTap: () => _go(context, AppRoutes.futureExpenses),
            ),
            _DrawerTile(
              selected: currentRoute == AppRoutes.income,
              icon: Icons.add_card_outlined,
              title: 'Income',
              onTap: () => _go(context, AppRoutes.income),
            ),
            _DrawerTile(
              selected: currentRoute == AppRoutes.budget,
              icon: Icons.savings_outlined,
              title: 'Budget',
              onTap: () => _go(context, AppRoutes.budget),
            ),

            const Divider(height: 24),
            _DrawerSectionTitle(title: 'Analytics'),
            _DrawerTile(
              selected: currentRoute == AppRoutes.reports,
              icon: Icons.bar_chart_outlined,
              title: 'Reports',
              onTap: () => _go(context, AppRoutes.reports),
            ),

            const Divider(height: 24),
            _DrawerSectionTitle(title: 'App'),
            _DrawerTile(
              selected: currentRoute == AppRoutes.settings,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => _go(context, AppRoutes.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      color: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: theme.colorScheme.onPrimary,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'Expense Manager',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track • Plan • Budget',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  final String title;
  const _DrawerSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}
