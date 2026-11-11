import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/repositories/workspace_repository.dart';

class InMemoryWorkspaceRepository implements WorkspaceRepository {
  final Map<String, Workspace> _data = {};

  @override
  Future<void> add(Workspace workspace) async => _data[workspace.id] = workspace;

  @override
  Future<void> delete(String id) async => _data.remove(id);

  @override
  Future<List<Workspace>> getAll({bool includeArchived = false}) async =>
      _data.values.where((w) => includeArchived || !w.isArchived).toList();

  @override
  Future<Workspace?> getById(String id) async => _data[id];

  @override
  Future<Workspace?> getDefault() async =>
      _data.values.firstWhere((w) => w.isDefault, orElse: () => _data.values.first);

  @override
  Future<void> setArchived(String id, bool isArchived) async {
    final ws = _data[id];
    if (ws != null) ws.isArchived = isArchived;
  }

  @override
  Future<void> update(Workspace workspace) async => _data[workspace.id] = workspace;

  @override
  Stream<void> watch() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late InMemoryWorkspaceRepository workspaceRepo;
  late WorkspaceProvider workspaceProvider;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('workspace_test');
    Hive.init(tempDir.path);
    if (!Hive.isBoxOpen(AppStateBox.boxName)) {
      await Hive.openBox(AppStateBox.boxName);
    }

    workspaceRepo = InMemoryWorkspaceRepository();
    // Seed default workspace
    await workspaceRepo.add(Workspace(
      id: AppConstants.kDefaultWorkspaceId,
      name: 'Personal',
      type: WorkspaceType.personal,
      currency: '₹',
      initialBalance: 0,
      createdAt: DateTime(2026, 1, 1),
      iconCodePoint: 0xe491,
      colorValue: 0xFF2196F3,
      isDefault: true,
    ));

    workspaceProvider = WorkspaceProvider(workspaceRepo);
  });

  tearDown(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('WorkspaceProvider Tests (TEST-WS-01, TEST-SWEEP-01)', () {
    test('Loads default workspace and sets active', () async {
      await workspaceProvider.load();
      expect(workspaceProvider.workspaces.length, 1);
      expect(workspaceProvider.activeWorkspaceId, AppConstants.kDefaultWorkspaceId);
    });

    test('Creates new Trip workspace and sets as active', () async {
      await workspaceProvider.load();

      final tripWs = await workspaceProvider.createWorkspace(
        name: 'GoaVacation',
        type: WorkspaceType.trip,
        iconCodePoint: 0xe28a,
        colorValue: 0xFFFF9800,
      );

      expect(tripWs.type, WorkspaceType.trip);
      expect(workspaceProvider.workspaces.length, 2);
      expect(workspaceProvider.activeWorkspaceId, tripWs.id);

      // Domain barrier strictly rejects names containing spaces
      expect(
        () => workspaceProvider.createWorkspace(
          name: 'Goa Vacation',
          type: WorkspaceType.trip,
          iconCodePoint: 0xe28a,
          colorValue: 0xFFFF9800,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('TEST-SWEEP-01: Pre-deletion sweep gate blocks deleting workspace with remaining funds', () async {
      await workspaceProvider.load();

      final tripWs = await workspaceProvider.createWorkspace(
        name: 'ManaliTrip',
        type: WorkspaceType.trip,
        iconCodePoint: 0xe28a,
        colorValue: 0xFFFF9800,
      );

      // Remaining funds: ₹7,000 (700000 paise)
      expect(
        () => workspaceProvider.deleteWorkspace(tripWs.id, remainingFundsPaise: 700000),
        throwsA(isA<ValidationException>()),
      );

      // Verify workspace is still present
      expect(workspaceProvider.workspaces.any((w) => w.id == tripWs.id), isTrue);

      // With 0 funds remaining, deletion succeeds
      await workspaceProvider.deleteWorkspace(tripWs.id, remainingFundsPaise: 0);
      expect(workspaceProvider.workspaces.any((w) => w.id == tripWs.id), isFalse);
    });

    test('Renames any workspace including default workspace while preserving ID and isDefault', () async {
      await workspaceProvider.load();

      final defaultWs = workspaceProvider.activeWorkspace!;
      expect(defaultWs.id, AppConstants.kDefaultWorkspaceId);
      expect(defaultWs.isDefault, isTrue);
      expect(defaultWs.name, 'Personal');

      defaultWs.name = 'MainFinances';
      await workspaceProvider.updateWorkspace(defaultWs);

      expect(workspaceProvider.activeWorkspace?.name, 'MainFinances');
      expect(workspaceProvider.activeWorkspace?.id, AppConstants.kDefaultWorkspaceId);
      expect(workspaceProvider.activeWorkspace?.isDefault, isTrue);
    });
  });
}
