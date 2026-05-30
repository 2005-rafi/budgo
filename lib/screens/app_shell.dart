import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/provider/app_navigation_provider.dart';
import 'package:expense/widgets/common/app_quick_actions_sheet.dart';
import 'package:expense/widgets/forms/reminders_management_sheet.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/widgets/snackbar_feedback.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:expense/widgets/app_back_guard.dart';
import 'package:expense/widgets/common/app_exit_dialog.dart';
import 'home_screen.dart';
import 'activity_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final List<Widget> _screens = const [
    HomeScreen(),
    ActivityScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.onActionTapped = _handleNotificationAction;
  }

  @override
  void dispose() {
    if (NotificationService.onActionTapped == _handleNotificationAction) {
      NotificationService.onActionTapped = null;
    }
    super.dispose();
  }

  void _handleNotificationAction(NotificationResponse response) {
    final actionId = response.actionId;
    final reminderId = response.payload;
    if (reminderId == null) return;

    if (!mounted) return;
    final provider = context.read<ReminderProvider>();
    final reminder = provider.items.firstWhereOrNull((r) => r.id == reminderId);
    
    if (reminder == null) return;

    if (actionId == 'mark_paid') {
      provider.markAsPaid(reminder).then((success) {
        if (success && mounted) {
          SnackbarFeedback.showSuccess(context, 'Reminder marked as paid');
        }
      });
    } else if (actionId == 'remind_later') {
      provider.remindLater(reminder).then((success) {
        if (success && mounted) {
          SnackbarFeedback.showSuccess(context, 'Reminder postponed by 6 hours');
        }
      });
    } else {
      // Default / 'view' action
      RemindersManagementSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<AppNavigationProvider>();
    final currentIndex = navProvider.currentIndex;
    final showFab = currentIndex == 0 || currentIndex == 1;

    return AppBackGuard(
      onBack: () async {
        final shouldQuit = await AppExitDialog.show(context);
        if (shouldQuit) {
          await SystemNavigator.pop();
        }
        return false;
      },
      child: Scaffold(
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
      ),
    );
  }
}

