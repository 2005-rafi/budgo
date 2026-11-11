import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/models/savings_vault.dart';

abstract class SavingsVaultRepository {
  Future<List<SavingsVault>> getAll({bool includeArchived = false});
  Future<List<SavingsVault>> getByWorkspace(String workspaceId, {bool includeArchived = false});
  Future<List<SavingsVault>> getByParentAccount(String parentAccountId, {bool includeArchived = false});
  Future<SavingsVault?> getById(String id);
  Future<void> add(SavingsVault vault);
  Future<void> update(SavingsVault vault);
  Future<void> updateCurrentAmount(String vaultId, int deltaPaise);
  Future<void> delete(String id);
  Future<void> setArchived(String id, bool isArchived);
  Stream<void> watch();
}

class HiveSavingsVaultRepository implements SavingsVaultRepository {
  final Box<SavingsVault>? _injectedBox;

  HiveSavingsVaultRepository([this._injectedBox]);

  Box<SavingsVault> get _box =>
      _injectedBox ?? Hive.box<SavingsVault>(AppConstants.kVaultsBox);

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<List<SavingsVault>> getAll({bool includeArchived = false}) async {
    try {
      final list = _box.values.where((v) => includeArchived || !v.isArchived).toList();
      list.sort((a, b) => a.priority.compareTo(b.priority));
      return list;
    } catch (e) {
      throw StorageException('Failed to read savings vaults: $e');
    }
  }

  @override
  Future<List<SavingsVault>> getByWorkspace(String workspaceId, {bool includeArchived = false}) async {
    try {
      final list = _box.values
          .where((v) => v.workspaceId == workspaceId && (includeArchived || !v.isArchived))
          .toList();
      list.sort((a, b) => a.priority.compareTo(b.priority));
      return list;
    } catch (e) {
      throw StorageException('Failed to get savings vaults for workspace $workspaceId: $e');
    }
  }

  @override
  Future<List<SavingsVault>> getByParentAccount(String parentAccountId, {bool includeArchived = false}) async {
    try {
      final list = _box.values
          .where((v) => v.parentAccountId == parentAccountId && (includeArchived || !v.isArchived))
          .toList();
      list.sort((a, b) => a.priority.compareTo(b.priority));
      return list;
    } catch (e) {
      throw StorageException('Failed to get vaults for parent account $parentAccountId: $e');
    }
  }

  @override
  Future<SavingsVault?> getById(String id) async {
    try {
      return _box.get(id);
    } catch (e) {
      throw StorageException('Failed to get savings vault $id: $e');
    }
  }

  @override
  Future<void> add(SavingsVault vault) async {
    try {
      await AtomicWriter.instance.execute(() async {
        await _box.put(vault.id, vault);
      });
    } catch (e) {
      throw StorageException('Failed to add savings vault: $e');
    }
  }

  @override
  Future<void> update(SavingsVault vault) async {
    try {
      await AtomicWriter.instance.execute(() async {
        await _box.put(vault.id, vault);
      });
    } catch (e) {
      throw StorageException('Failed to update savings vault ${vault.id}: $e');
    }
  }

  @override
  Future<void> updateCurrentAmount(String vaultId, int deltaPaise) async {
    try {
      await AtomicWriter.instance.execute(() async {
        final vault = _box.get(vaultId);
        if (vault == null) {
          throw NotFoundException('Savings vault not found: $vaultId');
        }
        final newAmount = vault.currentPaise + deltaPaise;
        if (newAmount < 0) {
          throw ValidationException('Vault current amount cannot be negative');
        }
        vault.currentPaise = newAmount;
        vault.updatedAt = DateTime.now();
        await _box.put(vaultId, vault);
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw StorageException('Failed to update vault amount for $vaultId: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await AtomicWriter.instance.execute(() async {
        final vault = _box.get(id);
        if (vault != null && vault.currentPaise > 0) {
          throw ValidationException('Cannot delete vault with allocated funds. Withdraw funds first.');
        }
        await _box.delete(id);
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw StorageException('Failed to delete savings vault $id: $e');
    }
  }

  @override
  Future<void> setArchived(String id, bool isArchived) async {
    try {
      await AtomicWriter.instance.execute(() async {
        final vault = _box.get(id);
        if (vault != null) {
          vault.isArchived = isArchived;
          vault.updatedAt = DateTime.now();
          await _box.put(id, vault);
        }
      });
    } catch (e) {
      throw StorageException('Failed to set archive status for vault $id: $e');
    }
  }
}

