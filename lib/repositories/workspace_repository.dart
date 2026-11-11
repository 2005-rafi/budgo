import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/models/workspace.dart';

abstract class WorkspaceRepository {
  Future<List<Workspace>> getAll({bool includeArchived = false});
  Future<Workspace?> getById(String id);
  Future<Workspace?> getDefault();
  Future<void> add(Workspace workspace);
  Future<void> update(Workspace workspace);
  Future<void> delete(String id);
  Future<void> setArchived(String id, bool isArchived);
  Stream<void> watch();
}

class HiveWorkspaceRepository implements WorkspaceRepository {
  final Box<Workspace>? _injectedBox;

  HiveWorkspaceRepository([this._injectedBox]);

  Box<Workspace> get _box =>
      _injectedBox ?? Hive.box<Workspace>(AppConstants.kWorkspacesBox);

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<List<Workspace>> getAll({bool includeArchived = false}) async {
    try {
      final list = _box.values.where((w) => includeArchived || !w.isArchived).toList();
      list.sort((a, b) {
        if (a.isDefault) return -1;
        if (b.isDefault) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
      return list;
    } catch (e) {
      throw StorageException('Failed to read workspaces: $e');
    }
  }

  @override
  Future<Workspace?> getById(String id) async {
    try {
      return _box.get(id);
    } catch (e) {
      throw StorageException('Failed to find workspace $id: $e');
    }
  }

  @override
  Future<Workspace?> getDefault() async {
    try {
      return _box.values.firstWhere(
        (w) => w.isDefault,
        orElse: () => _box.values.first,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> add(Workspace workspace) async {
    try {
      await AtomicWriter.instance.execute(() async {
        await _box.put(workspace.id, workspace);
        await _box.flush();
      });
    } catch (e) {
      throw StorageException('Failed to add workspace: $e');
    }
  }

  @override
  Future<void> update(Workspace workspace) async {
    try {
      await AtomicWriter.instance.execute(() async {
        await _box.put(workspace.id, workspace);
        await _box.flush();
      });
    } catch (e) {
      throw StorageException('Failed to update workspace: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await AtomicWriter.instance.execute(() async {
        await _box.delete(id);
        await _box.flush();
      });
    } catch (e) {
      throw StorageException('Failed to delete workspace: $e');
    }
  }

  @override
  Future<void> setArchived(String id, bool isArchived) async {
    try {
      await AtomicWriter.instance.execute(() async {
        final ws = _box.get(id);
        if (ws != null) {
          ws.isArchived = isArchived;
          await ws.save();
          await _box.flush();
        }
      });
    } catch (e) {
      throw StorageException('Failed to set archive status: $e');
    }
  }
}

