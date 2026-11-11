import 'package:flutter_test/flutter_test.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/savings_vault_repository.dart';
import 'package:expense/services/vault_allocation_service.dart';

class InMemoryAccountRepo implements AccountRepository {
  final Map<String, Account> _data = {};

  @override
  Future<void> add(Account account) async => _data[account.id] = account;

  @override
  Future<void> delete(String id) async => _data.remove(id);

  @override
  Future<List<Account>> getAll({bool includeArchived = false}) async =>
      _data.values.where((a) => includeArchived || !a.isArchived).toList();

  @override
  Future<Account?> getById(String id) async => _data[id];

  @override
  Future<List<Account>> getByWorkspace(String workspaceId, {bool includeArchived = false}) async =>
      _data.values.where((a) => a.workspaceId == workspaceId && (includeArchived || !a.isArchived)).toList();

  @override
  Future<Account?> getDefault(String workspaceId) async => _data.values.first;

  @override
  int getNetWorthPaise({bool includeArchived = false}) =>
      _data.values.where((a) => includeArchived || !a.isArchived).fold<int>(0, (sum, a) => sum + a.balancePaise);

  @override
  Future<void> setArchived(String id, bool isArchived) async {
    final acc = _data[id];
    if (acc != null) acc.isArchived = isArchived;
  }

  @override
  Future<void> update(Account account) async => _data[account.id] = account;

  @override
  Future<void> updateBalance(String accountId, int deltaPaise) async {
    final acc = _data[accountId];
    if (acc != null) acc.balancePaise += deltaPaise;
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

class InMemoryVaultRepo implements SavingsVaultRepository {
  final Map<String, SavingsVault> _data = {};

  @override
  Future<void> add(SavingsVault vault) async => _data[vault.id] = vault;

  @override
  Future<void> delete(String id) async => _data.remove(id);

  @override
  Future<List<SavingsVault>> getAll({bool includeArchived = false}) async =>
      _data.values.where((v) => includeArchived || !v.isArchived).toList();

  @override
  Future<SavingsVault?> getById(String id) async => _data[id];

  @override
  Future<List<SavingsVault>> getByParentAccount(String parentAccountId, {bool includeArchived = false}) async =>
      _data.values.where((v) => v.parentAccountId == parentAccountId && (includeArchived || !v.isArchived)).toList();

  @override
  Future<List<SavingsVault>> getByWorkspace(String workspaceId, {bool includeArchived = false}) async =>
      _data.values.where((v) => v.workspaceId == workspaceId && (includeArchived || !v.isArchived)).toList();

  @override
  Future<void> setArchived(String id, bool isArchived) async {
    final v = _data[id];
    if (v != null) v.isArchived = isArchived;
  }

  @override
  Future<void> update(SavingsVault vault) async => _data[vault.id] = vault;

  @override
  Future<void> updateCurrentAmount(String vaultId, int deltaPaise) async {
    final v = _data[vaultId];
    if (v != null) v.currentPaise += deltaPaise;
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

void main() {
  group('VaultAllocationService Tests', () {
    late InMemoryAccountRepo accountRepo;
    late InMemoryVaultRepo vaultRepo;
    late VaultAllocationService service;

    setUp(() {
      accountRepo = InMemoryAccountRepo();
      vaultRepo = InMemoryVaultRepo();
      service = VaultAllocationService(
        accountRepository: accountRepo,
        vaultRepository: vaultRepo,
      );

      // Seed bank account with ₹50,000
      accountRepo.add(Account(
        id: 'acc_bank',
        workspaceId: 'default_personal',
        name: 'Salary Bank',
        type: AccountType.bankAccount,
        balancePaise: 5000000,
        iconCodePoint: 0xe040,
        colorValue: 0xFF2196F3,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      // Seed two vaults
      vaultRepo.add(SavingsVault(
        id: 'v_emergency',
        workspaceId: 'default_personal',
        parentAccountId: 'acc_bank',
        name: 'Emergency Fund',
        targetPaise: 5000000, // ₹50,000 target
        currentPaise: 0,
        iconCodePoint: 0xe571,
        colorValue: 0xFF4CAF50,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      vaultRepo.add(SavingsVault(
        id: 'v_insurance',
        workspaceId: 'default_personal',
        parentAccountId: 'acc_bank',
        name: 'Bike Insurance',
        targetPaise: 400000, // ₹4,000 target
        currentPaise: 0,
        iconCodePoint: 0xe571,
        colorValue: 0xFFFF9800,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));
    });

    test('All-or-nothing batch allocation succeeds when funds are sufficient', () async {
      final result = await service.executeBatchAllocation(
        sourceAccountId: 'acc_bank',
        vaultAllocations: {
          'v_emergency': 400000, // ₹4,000
          'v_insurance': 100000, // ₹1,000
        },
      );

      expect(result.success, isTrue);
      expect(result.totalAllocatedPaise, equals(500000)); // ₹5,000 total

      final vEmg = await vaultRepo.getById('v_emergency');
      final vIns = await vaultRepo.getById('v_insurance');
      expect(vEmg?.currentPaise, equals(400000));
      expect(vIns?.currentPaise, equals(100000));
    });

    test('Rejects batch allocation when requested amount exceeds free spendable balance', () async {
      // Bank has ₹50,000. Try to allocate ₹60,000.
      final result = await service.executeBatchAllocation(
        sourceAccountId: 'acc_bank',
        vaultAllocations: {
          'v_emergency': 6000000, // ₹60,000
        },
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Insufficient free spendable funds'));

      final vEmg = await vaultRepo.getById('v_emergency');
      expect(vEmg?.currentPaise, equals(0)); // Untouched
    });

    test('Withdrawal releases funds back into spendable bank pool', () async {
      // First deposit ₹3,000
      await service.executeBatchAllocation(
        sourceAccountId: 'acc_bank',
        vaultAllocations: {'v_emergency': 300000},
      );

      // Now withdraw ₹1,000
      final ok = await service.withdrawFromVault(
        vaultId: 'v_emergency',
        amountPaise: 100000,
      );

      expect(ok, isTrue);
      final vEmg = await vaultRepo.getById('v_emergency');
      expect(vEmg?.currentPaise, equals(200000)); // ₹2,000 remaining
    });
  });
}

