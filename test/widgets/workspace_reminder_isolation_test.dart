import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/repositories/reminder_repository.dart';
import 'package:expense/repositories/workspace_repository.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/widgets/sheets/reminders_management_sheet.dart';
import 'package:expense/widgets/tiles/smart_notification_tile.dart';

class _MemWorkspaceRepo implements WorkspaceRepository {
  final List<Workspace> items = [];

  @override
  Future<void> add(Workspace workspace) async => items.add(workspace);

  @override
  Future<void> delete(String id) async =>
      items.removeWhere((w) => w.id == id);

  @override
  Future<List<Workspace>> getAll({bool includeArchived = false}) async =>
      items.where((w) => includeArchived || !w.isArchived).toList();

  @override
  Future<Workspace?> getById(String id) async {
    for (final w in items) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<Workspace?> getDefault() async =>
      items.isEmpty ? null : items.first;

  @override
  Future<void> setArchived(String id, bool isArchived) async {}

  @override
  Future<void> update(Workspace workspace) async {}

  @override
  Stream<void> watch() => const Stream.empty();
}

class _MemReminderRepo implements ReminderRepository {
  final List<Reminder> items = [];

  @override
  Future<void> add(Reminder reminder) async => items.add(reminder);

  @override
  Future<void> delete(Reminder reminder) async =>
      items.removeWhere((r) => r.id == reminder.id);

  @override
  Future<List<Reminder>> getAll() async => List.of(items);

  @override
  Future<void> toggleActive(Reminder reminder) async {
    reminder.isActive = !reminder.isActive;
  }

  @override
  Future<void> update(Reminder reminder) async {
    final idx = items.indexWhere((r) => r.id == reminder.id);
    if (idx != -1) items[idx] = reminder;
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

class _StubNotificationService implements NotificationService {
  @override
  Future<void> cancelAllReminders() async {}

  @override
  Future<void> cancelReminder(int id) async {}

  @override
  Future<NotificationResponse?> getLaunchNotificationResponse() async => null;

  @override
  Future<List<PendingNotificationRequest>> getPendingReminders() async => [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> initializeForBackground() async {}

  @override
  Future<bool> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String recurrence = 'none',
    RecurrenceRule? recurrenceRule,
    String? payload,
    int? amount,
    String? category,
    String? notes,
    WorkspaceNotificationMeta? workspace,
  }) async =>
      true;

  @override
  Future<bool> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _MemWorkspaceRepo wsRepo;
  late _MemReminderRepo remRepo;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ws_rem_iso_test');
    Hive.init(tempDir.path);
    if (!Hive.isBoxOpen(AppStateBox.boxName)) {
      await Hive.openBox(AppStateBox.boxName);
    }
    await AppStateBox.setActiveWorkspaceId(AppConstants.kDefaultWorkspaceId);

    wsRepo = _MemWorkspaceRepo();
    wsRepo.items.addAll([
      Workspace(
        id: AppConstants.kDefaultWorkspaceId,
        name: 'Personal',
        type: WorkspaceType.personal,
        currency: '₹',
        createdAt: DateTime(2026, 1, 1),
        iconCodePoint: 0xe491,
        colorValue: 0xFF2196F3,
        isDefault: true,
      ),
      Workspace(
        id: 'ws_trip',
        name: 'Goa Trip',
        type: WorkspaceType.trip,
        currency: '₹',
        createdAt: DateTime(2026, 11, 1),
        iconCodePoint: 0xe539,
        colorValue: 0xFFFF9800,
      ),
    ]);

    remRepo = _MemReminderRepo();
    remRepo.items.addAll([
      Reminder(
        id: 'rem_personal',
        title: 'Electricity Bill',
        scheduledAt: DateTime(2026, 11, 20, 9, 0),
        workspaceId: AppConstants.kDefaultWorkspaceId,
      ),
      Reminder(
        id: 'rem_trip',
        title: 'Hotel Balance',
        scheduledAt: DateTime(2026, 11, 22, 10, 0),
        workspaceId: 'ws_trip',
      ),
    ]);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('RemindersManagementSheet isolates active workspace by default and reveals workspace-styled pills in All Workspaces mode', (tester) async {
    final wsProvider = WorkspaceProvider(wsRepo);
    await wsProvider.initialize();
    final remProvider = ReminderProvider(remRepo, _StubNotificationService());
    await remProvider.initialize(
      initialWorkspaceId: wsProvider.activeWorkspaceId,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wsProvider),
          ChangeNotifierProvider.value(value: remProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RemindersManagementSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Isolated default view shows ONLY active workspace's reminder
    expect(find.text('Electricity Bill'), findsOneWidget);
    expect(find.text('Hotel Balance'), findsNothing);
    expect(find.text('Workspace: Personal'), findsOneWidget);

    // Toggle to 'All Workspaces'
    await tester.tap(find.text('All Workspaces'));
    await tester.pumpAndSettle();

    expect(find.text('Electricity Bill'), findsOneWidget);
    expect(find.text('Hotel Balance'), findsOneWidget);
    expect(find.byType(SmartNotificationTile), findsNWidgets(2));
    expect(find.text('Goa Trip'), findsOneWidget);
  });

  testWidgets('Leading radio button in SmartNotificationTile marks reminder as paid without triggering body dialog', (tester) async {
    final wsProvider = WorkspaceProvider(wsRepo);
    await wsProvider.initialize();
    final remProvider = ReminderProvider(remRepo, _StubNotificationService());
    await remProvider.initialize(
      initialWorkspaceId: wsProvider.activeWorkspaceId,
    );

    // Add a daily recurring reminder (mirroring EMI in user screenshot)
    final recurringReminder = Reminder(
      id: 'rem_emi',
      title: 'EMI',
      scheduledAt: DateTime(2026, 11, 10, 22, 55),
      isRecurring: true,
      recurrenceType: 'daily',
      workspaceId: AppConstants.kDefaultWorkspaceId,
    );
    await remProvider.addReminder(recurringReminder);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: wsProvider),
          ChangeNotifierProvider.value(value: remProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RemindersManagementSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EMI'), findsOneWidget);

    // Find the leading action button for EMI tile
    final emiTile = find.ancestor(
      of: find.text('EMI'),
      matching: find.byType(SmartNotificationTile),
    );
    final leadingButton = find.descendant(
      of: emiTile,
      matching: find.byType(BudgoPressable),
    );
    expect(leadingButton, findsOneWidget);

    // Tap the leading radio button
    await tester.tap(leadingButton);
    await tester.pumpAndSettle();

    // Verify it did NOT trigger the 'Manage Reminder' AlertDialog
    expect(find.text('Manage Reminder'), findsNothing);

    // Verify the reminder scheduled date advanced to tomorrow (Nov 11)
    expect(recurringReminder.scheduledAt.day, 11);

    // Verify explanatory success toast was triggered with next scheduled date
    expect(find.textContaining('marked as paid for today! Next: Nov 11'), findsOneWidget);
  });
}

