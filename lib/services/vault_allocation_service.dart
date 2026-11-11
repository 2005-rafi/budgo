import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/savings_vault_repository.dart';

class VaultAllocationResult {
  final bool success;
  final int totalAllocatedPaise;
  final int vaultsCount;
  final String? errorMessage;
  final Object? error;

  const VaultAllocationResult({
    required this.success,
    required this.totalAllocatedPaise,
    required this.vaultsCount,
    this.errorMessage,
    this.error,
  });
}

class VaultAllocationService {
  final AccountRepository accountRepository;
  final SavingsVaultRepository vaultRepository;

  VaultAllocationService({
    required this.accountRepository,
    required this.vaultRepository,
  });

  /// Executes all-or-nothing batch allocation into target savings vaults
  /// using [AtomicWriter] to guarantee ACID transactional integrity.
  Future<VaultAllocationResult> executeBatchAllocation({
    required String sourceAccountId,
    required Map<String, int> vaultAllocations,
  }) async {
    if (vaultAllocations.isEmpty) {
      return const VaultAllocationResult(
        success: true,
        totalAllocatedPaise: 0,
        vaultsCount: 0,
      );
    }

    final totalToAllocate = vaultAllocations.values.fold<int>(0, (sum, val) => sum + val);
    if (totalToAllocate <= 0) {
      final err = ValidationException(
        'Allocation amount must be greater than zero.',
        guidance: 'Enter a positive rupee amount to reserve into your vault.',
      );
      return VaultAllocationResult(
        success: false,
        totalAllocatedPaise: 0,
        vaultsCount: 0,
        errorMessage: err.message,
        error: err,
      );
    }

    try {
      await AtomicWriter.instance.execute(() async {
        final sourceAccount = await accountRepository.getById(sourceAccountId);
        if (sourceAccount == null) {
          throw NotFoundException(
            'The backing account linked to this vault no longer exists.',
            entityType: 'account',
            guidance: 'Edit the vault in Settings and select a valid account.',
          );
        }

        // Digital pool unification: Bank Account and UPI share the same underlying
        // bank liquidity, so vault availability inspects the combined Bank + UPI pool.
        final isDigitalPool =
            sourceAccount.type == AccountType.bankAccount ||
            sourceAccount.type == AccountType.upi;

        final workspaceAccounts = await accountRepository.getByWorkspace(sourceAccount.workspaceId);
        final List<Account> poolAccounts = isDigitalPool
            ? workspaceAccounts
                .where((a) => a.type == AccountType.bankAccount || a.type == AccountType.upi)
                .toList()
            : <Account>[sourceAccount];

        if (poolAccounts.isEmpty || !poolAccounts.any((a) => a.id == sourceAccount.id)) {
          poolAccounts.add(sourceAccount);
        }

        int poolBalance = 0;
        int currentlyAllocated = 0;
        final checkedIds = <String>{};

        for (final acc in poolAccounts) {
          checkedIds.add(acc.id);
          poolBalance += acc.balancePaise;
          final vaultsForAcc = await vaultRepository.getByParentAccount(acc.id);
          currentlyAllocated += vaultsForAcc.fold<int>(0, (sum, v) => sum + v.currentPaise);
        }

        final freeSpendable = poolBalance - currentlyAllocated;

        if (freeSpendable < totalToAllocate) {
          final fundedOther = workspaceAccounts
              .where((a) => !checkedIds.contains(a.id) && a.balancePaise > 0)
              .toList();

          final String alternativeHint;
          if (fundedOther.isNotEmpty) {
            alternativeHint =
                'Your ${fundedOther.first.name} holds ${CurrencyFormatter.formatPaise(fundedOther.first.balancePaise)}. Transfer funds into ${sourceAccount.name} via Self-Transfer or lower the amount.';
          } else if (currentlyAllocated > 0) {
            alternativeHint =
                '${CurrencyFormatter.formatPaise(currentlyAllocated)} is already reserved in active vaults. Enter up to ${CurrencyFormatter.formatPaise(freeSpendable > 0 ? freeSpendable : 0)}.';
          } else {
            alternativeHint =
                'Add confirmed income to ${sourceAccount.name} or choose an amount within your available balance.';
          }

          final poolLabel = isDigitalPool ? 'Bank & UPI pool' : sourceAccount.name;
          throw InsufficientFundsException(
            'Insufficient free spendable funds in $poolLabel. Free: ${CurrencyFormatter.formatPaise(freeSpendable)}, Requested: ${CurrencyFormatter.formatPaise(totalToAllocate)}',
            availablePaise: freeSpendable > 0 ? freeSpendable : 0,
            requestedPaise: totalToAllocate,
            accountName: poolLabel,
            alternativeHint: alternativeHint,
          );
        }

        // Apply allocations to all vaults atomically
        for (final entry in vaultAllocations.entries) {
          final vaultId = entry.key;
          final amount = entry.value;
          if (amount <= 0) continue;

          final vault = await vaultRepository.getById(vaultId);
          if (vault == null) {
            throw NotFoundException(
              'Savings vault no longer exists.',
              entityType: 'vault',
              guidance: 'Refresh the list and create or select an active vault.',
            );
          }
          if (vault.isArchived) {
            throw ValidationException(
              'Vault "${vault.name}" is archived and cannot receive deposits.',
              guidance: 'Create a new active vault to reserve new savings.',
            );
          }

          vault.currentPaise += amount;
          vault.updatedAt = DateTime.now();
          await vaultRepository.update(vault);
        }
      });

      return VaultAllocationResult(
        success: true,
        totalAllocatedPaise: totalToAllocate,
        vaultsCount: vaultAllocations.length,
      );
    } catch (e) {
      return VaultAllocationResult(
        success: false,
        totalAllocatedPaise: 0,
        vaultsCount: 0,
        errorMessage: e.toString(),
        error: e,
      );
    }
  }

  /// Withdraws funds from a vault back into the parent account's free spendable pool,
  /// returning rich error context on failure.
  Future<VaultAllocationResult> withdrawWithResult({
    required String vaultId,
    required int amountPaise,
  }) async {
    if (amountPaise <= 0) {
      final err = ValidationException(
        'Withdrawal amount must be greater than zero.',
        guidance: 'Enter a positive rupee amount to release from the vault.',
      );
      return VaultAllocationResult(
        success: false,
        totalAllocatedPaise: 0,
        vaultsCount: 0,
        errorMessage: err.message,
        error: err,
      );
    }

    try {
      await AtomicWriter.instance.execute(() async {
        final vault = await vaultRepository.getById(vaultId);
        if (vault == null) {
          throw NotFoundException(
            'Savings vault no longer exists.',
            entityType: 'vault',
          );
        }
        if (vault.currentPaise < amountPaise) {
          throw InsufficientFundsException(
            'Cannot withdraw more than current vault balance.',
            availablePaise: vault.currentPaise,
            requestedPaise: amountPaise,
            accountName: vault.name,
            alternativeHint:
                'Maximum available to withdraw from "${vault.name}" is ${CurrencyFormatter.formatPaise(vault.currentPaise)}.',
          );
        }

        vault.currentPaise -= amountPaise;
        vault.updatedAt = DateTime.now();
        await vaultRepository.update(vault);
      });
      return VaultAllocationResult(
        success: true,
        totalAllocatedPaise: amountPaise,
        vaultsCount: 1,
      );
    } catch (e) {
      return VaultAllocationResult(
        success: false,
        totalAllocatedPaise: 0,
        vaultsCount: 0,
        errorMessage: e.toString(),
        error: e,
      );
    }
  }

  /// Backward-compatible boolean withdrawal API.
  Future<bool> withdrawFromVault({
    required String vaultId,
    required int amountPaise,
  }) async {
    final result = await withdrawWithResult(vaultId: vaultId, amountPaise: amountPaise);
    return result.success;
  }
}
