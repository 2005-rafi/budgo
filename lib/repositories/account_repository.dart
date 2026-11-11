import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/models/account.dart';

abstract class AccountRepository {
  Future<List<Account>> getAll({bool includeArchived = false});
  Future<List<Account>> getByWorkspace(String workspaceId, {bool includeArchived = false});
  Future<Account?> getById(String id);
  Future<Account?> getDefault(String workspaceId);
  Future<void> add(Account account);
  Future<void> update(Account account);
  Future<void> updateBalance(String accountId, int deltaPaise);
  Future<void> delete(String id);
  Future<void> setArchived(String id, bool isArchived);
  int getNetWorthPaise({bool includeArchived = false});
  Stream<void> watch();
}

class HiveAccountRepository implements AccountRepository {
  final Box<Account>? _injectedBox;

  HiveAccountRepository([this._injectedBox]);

  Box<Account> get _box =>
      _injectedBox ?? Hive.box<Account>(AppConstants.kAccountsBox);

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<List<Account>> getAll({bool includeArchived = false}) async {
    try {
      final list = _box.values.where((a) => includeArchived || !a.isArchived).toList();
      list.sort((a, b) {
        if (a.isDefault) return -1;
        if (b.isDefault) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
      return list;
    } catch (e) {
      throw StorageException('Failed to read accounts: $e');
    }
  }

  @override
  Future<List<Account>> getByWorkspace(String workspaceId, {bool includeArchived = false}) async {
    try {
      final list = _box.values
          .where((a) => a.workspaceId == workspaceId && (includeArchived || !a.isArchived))
          .toList();
      list.sort((a, b) {
        if (a.isDefault) return -1;
        if (b.isDefault) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
      return list;
    } catch (e) {
      throw StorageException('Failed to get accounts for workspace $workspaceId: $e');
    }
  }

  @override
  Future<Account?> getById(String id) async {
    try {
      return _box.get(id);
    } catch (e) {
      throw StorageException('Failed to find account $id: $e');
    }
  }

  @override
  Future<Account?> getDefault(String workspaceId) async {
    try {
      final accounts = _box.values.where((a) => a.workspaceId == workspaceId && !a.isArchived);
      return accounts.firstWhere(
        (a) => a.isDefault,
        orElse: () => accounts.isNotEmpty ? accounts.first : _box.values.first,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> add(Account account) async {
    try {
      await AtomicWriter.instance.execute(() async {
        await _box.put(account.id, account);
        await _box.flush();
      });
    } catch (e) {
      throw StorageException('Failed to add account: $e');
    }
  }

  @override
  Future<void> update(Account account) async {
    try {
      await AtomicWriter.instance.execute(() async {
        account.updatedAt = DateTime.now();
        await _box.put(account.id, account);
        await _box.flush();
      });
    } catch (e) {
      throw StorageException('Failed to update account: $e');
    }
  }

  @override
  Future<void> updateBalance(String accountId, int deltaPaise) async {
    try {
      await AtomicWriter.instance.execute(() async {
        final acc = _box.get(accountId);
        if (acc == null) {
          throw ValidationException('Account $accountId does not exist.');
        }
        acc.balancePaise += deltaPaise;
        acc.updatedAt = DateTime.now();
        await acc.save();
        await _box.flush();
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw StorageException('Failed to update balance for $accountId: $e');
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
      throw StorageException('Failed to delete account: $e');
    }
  }

  @override
  Future<void> setArchived(String id, bool isArchived) async {
    try {
      await AtomicWriter.instance.execute(() async {
        final acc = _box.get(id);
        if (acc != null) {
          acc.isArchived = isArchived;
          acc.updatedAt = DateTime.now();
          await acc.save();
          await _box.flush();
        }
      });
    } catch (e) {
      throw StorageException('Failed to archive account $id: $e');
    }
  }

  @override
  int getNetWorthPaise({bool includeArchived = false}) {
    if (_injectedBox == null && !Hive.isBoxOpen(AppConstants.kAccountsBox)) {
      return 0;
    }
    // Under Universal Signed Net Equity, credit card balances are <= 0.
    // So Net Worth is simply the sum of all balancePaise with zero branching!
    int total = 0;
    for (final acc in _box.values) {
      if (includeArchived || !acc.isArchived) {
        total += acc.balancePaise;
      }
    }
    return total;
  }
}

