import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/core/storage/atomic_writer.dart';

/// Repository interface for managing workspace-isolated [Budget] records.
abstract class BudgetRepository {
  /// Retrieves the active budget for the default workspace (legacy alias).
  Future<Budget?> getActiveBudget();

  /// Retrieves the active budget isolated to [workspaceId].
  Future<Budget?> getBudgetForWorkspace(String workspaceId);

  /// Saves or overwrites the active budget keyed strictly by `budget.workspaceId`.
  Future<void> saveActiveBudget(Budget budget);

  /// Clears/deletes the active budget for default workspace (legacy alias).
  Future<void> clearActiveBudget();

  /// Clears/deletes the active budget for [workspaceId].
  Future<void> clearBudgetForWorkspace(String workspaceId);

  /// Emits a stream of void events whenever the box changes.
  Stream<void> watch();
}

/// Hive implementation of [BudgetRepository] partitioned by workspace key.
class HiveBudgetRepository implements BudgetRepository {
  final Box<Budget>? _injectedBox;

  HiveBudgetRepository([this._injectedBox]);

  Box<Budget> get _box =>
      _injectedBox ?? Hive.box<Budget>(AppConstants.kBudgetsBox);

  @override
  Stream<void> watch() => _box.watch();

  String _normalizeWs(String workspaceId) =>
      workspaceId.isEmpty ? AppConstants.kDefaultWorkspaceId : workspaceId;

  @override
  Future<Budget?> getActiveBudget() =>
      getBudgetForWorkspace(AppConstants.kDefaultWorkspaceId);

  @override
  Future<Budget?> getBudgetForWorkspace(String workspaceId) async {
    try {
      final normWs = _normalizeWs(workspaceId);
      final key = AppConstants.budgetKeyForWorkspace(normWs);
      final scoped = _box.get(key);
      if (scoped != null) return scoped;

      // Lazy non-destructive migration from pre-workspace single global key
      if (normWs == AppConstants.kDefaultWorkspaceId) {
        final legacy = _box.get(AppConstants.kActiveBudgetKey);
        if (legacy != null &&
            (legacy.workspaceId.isEmpty ||
                legacy.workspaceId == AppConstants.kDefaultWorkspaceId)) {
          return legacy;
        }
      }
      return null;
    } catch (e) {
      throw StorageException('Failed to read active budget: $e');
    }
  }

  @override
  Future<void> saveActiveBudget(Budget budget) async {
    await AtomicWriter.instance.execute(() async {
      try {
        final normWs = _normalizeWs(budget.workspaceId);
        budget.workspaceId = normWs;
        final key = AppConstants.budgetKeyForWorkspace(normWs);
        await _box.put(key, budget);
        if (normWs == AppConstants.kDefaultWorkspaceId &&
            _box.containsKey(AppConstants.kActiveBudgetKey)) {
          await _box.delete(AppConstants.kActiveBudgetKey);
        }
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to save active budget: $e');
      }
    });
  }

  @override
  Future<void> clearActiveBudget() =>
      clearBudgetForWorkspace(AppConstants.kDefaultWorkspaceId);

  @override
  Future<void> clearBudgetForWorkspace(String workspaceId) async {
    await AtomicWriter.instance.execute(() async {
      try {
        final normWs = _normalizeWs(workspaceId);
        final key = AppConstants.budgetKeyForWorkspace(normWs);
        await _box.delete(key);
        if (normWs == AppConstants.kDefaultWorkspaceId &&
            _box.containsKey(AppConstants.kActiveBudgetKey)) {
          await _box.delete(AppConstants.kActiveBudgetKey);
        }
        await _box.flush();
      } catch (e) {
        throw StorageException('Failed to clear active budget: $e');
      }
    });
  }
}
