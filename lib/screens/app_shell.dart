import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/tokens/app_motion.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/providers/app_navigation_provider.dart';
import 'package:expense/widgets/sheets/app_quick_actions_sheet.dart';
import 'package:expense/widgets/sheets/reminders_management_sheet.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/design/components/budgo_feedback.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:expense/design/components/budgo_dialogs.dart';
import 'package:expense/screens/home_screen.dart';
import 'package:expense/screens/activity_screen.dart';
import 'package:expense/screens/reports_screen.dart';
import 'package:expense/screens/settings_screen.dart';

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

  ReceivePort? _bgActionPort;
  StreamSubscription<dynamic>? _bgActionSubscription;

  @override
  void initState() {
    super.initState();
    NotificationService.onActionTapped = _handleNotificationAction;
    _registerBackgroundActionPort();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLaunchNotification());
  }

  void _registerBackgroundActionPort() {
    IsolateNameServer.removePortNameMapping(
      NotificationService.kBackgroundActionPortName,
    );
    _bgActionPort = ReceivePort();
    IsolateNameServer.registerPortWithName(
      _bgActionPort!.sendPort,
      NotificationService.kBackgroundActionPortName,
    );
    _bgActionSubscription = _bgActionPort!.listen((message) {
      if (message is Map) {
        _dispatchNotificationAction(
          message['actionId'] as String?,
          message['reminderId'] as String?,
        );
      }
    });
  }

  Future<void> _checkLaunchNotification() async {
    final launchResponse =
        await NotificationService().getLaunchNotificationResponse();
    if (!mounted || launchResponse == null) return;
    _handleNotificationAction(launchResponse);
  }

  @override
  void dispose() {
    if (NotificationService.onActionTapped == _handleNotificationAction) {
      NotificationService.onActionTapped = null;
    }
    _bgActionSubscription?.cancel();
    _bgActionPort?.close();
    IsolateNameServer.removePortNameMapping(
      NotificationService.kBackgroundActionPortName,
    );
    super.dispose();
  }

  void _handleNotificationAction(NotificationResponse response) {
    _dispatchNotificationAction(response.actionId, response.payload);
  }

  void _dispatchNotificationAction(String? actionId, String? reminderId) {
    if (!mounted) return;
    if (reminderId == null) {
      if (actionId == null || actionId.isEmpty) {
        RemindersManagementSheet.show(context);
      }
      return;
    }

    final provider = context.read<ReminderProvider>();
    final reminder =
        provider.allItems.firstWhereOrNull((r) => r.id == reminderId);

    if (reminder == null) return;

    if (actionId == NotificationService.kActionDone ||
        actionId == NotificationService.kLegacyActionMarkPaid) {
      provider.markAsPaid(reminder).then((success) {
        if (!mounted) return;
        if (success) {
          SnackbarFeedback.showSuccess(context, 'Reminder marked as done');
        } else {
          SnackbarFeedback.showError(
            context,
            provider.lastError ??
                provider.errorMessage ??
                'Unable to update reminder.',
            operation: FeedbackOperation.toggleReminder,
          );
        }
      });
    } else if (actionId == NotificationService.kActionSkip) {
      final isRecurring =
          reminder.isRecurring && reminder.recurrenceType != 'none';
      provider.skipReminder(reminder).then((success) {
        if (!mounted) return;
        if (success) {
          SnackbarFeedback.showSuccess(
            context,
            isRecurring ? 'Skipped to next occurrence' : 'Reminder skipped',
          );
        } else {
          SnackbarFeedback.showError(
            context,
            provider.lastError ??
                provider.errorMessage ??
                'Unable to skip reminder.',
            operation: FeedbackOperation.toggleReminder,
          );
        }
      });
    } else if (actionId == NotificationService.kActionCancel) {
      provider.cancelReminderFromNotification(reminder).then((success) {
        if (!mounted) return;
        if (success) {
          SnackbarFeedback.showInfo(context, 'Reminder cancelled');
        } else {
          SnackbarFeedback.showError(
            context,
            provider.lastError ??
                provider.errorMessage ??
                'Unable to cancel reminder.',
            operation: FeedbackOperation.toggleReminder,
          );
        }
      });
    } else if (actionId == NotificationService.kLegacyActionRemindLater) {
      provider.remindLater(reminder).then((success) {
        if (!mounted) return;
        if (success) {
          SnackbarFeedback.showSuccess(
            context,
            'Reminder postponed by 6 hours',
          );
        } else {
          SnackbarFeedback.showError(
            context,
            provider.lastError ??
                provider.errorMessage ??
                'Unable to postpone reminder.',
            operation: FeedbackOperation.toggleReminder,
          );
        }
      });
    } else {
      if (reminder.workspaceId.isNotEmpty) {
        context.read<WorkspaceProvider>().setActiveWorkspace(reminder.workspaceId);
      }
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
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined_rounded),
            selectedIcon: Icon(Icons.insert_chart_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: AppMotion.fast,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: child,
        ),
        child: showFab
            ? FloatingActionButton(
                key: const ValueKey('app_shell_fab'),
                onPressed: () => AppQuickActionsSheet.show(context),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.add_rounded, size: 26),
              )
            : const SizedBox.shrink(key: ValueKey('fab_empty')),
      ),
      ),
    );
  }
}

