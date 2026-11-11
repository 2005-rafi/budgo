import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/repositories/savings_vault_repository.dart';
import 'package:expense/services/vault_allocation_service.dart';

class SavingsVaultProvider extends ChangeNotifier {
  final SavingsVaultRepository _repository;
  final VaultAllocationService _allocationService;
  StreamSubscription<void>? _boxSubscription;

  List<SavingsVault> _allVaults = [];
  List<SavingsVault> _activeVaults = [];
  String _activeWorkspaceId = AppConstants.kDefaultWorkspaceId;
  bool _isLoading = false;
  String? _errorMessage;
  Object? _lastError;

  List<SavingsVault> get allVaults => List.unmodifiable(_allVaults);
  List<SavingsVault> get activeVaults => List.unmodifiable(_activeVaults);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Object? get lastError => _lastError;

  int get totalAllocatedPaise {
    return _activeVaults.fold<int>(0, (sum, v) => sum + v.currentPaise);
  }

  int get totalTargetPaise {
    return _activeVaults.fold<int>(0, (sum, v) => sum + v.targetPaise);
  }

  SavingsVaultProvider({
    required SavingsVaultRepository repository,
    required VaultAllocationService allocationService,
  })  : _repository = repository,
        _allocationService = allocationService;

  Future<void> initialize({String? initialWorkspaceId}) async {
    if (initialWorkspaceId != null) {
      _activeWorkspaceId = initialWorkspaceId;
    }
    _boxSubscription ??= _repository.watch().listen((_) => load());
    await load();
  }

  void setActiveWorkspace(String workspaceId) {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    _filterActiveVaults();
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _lastError = null;
    notifyListeners();

    try {
      _allVaults = await _repository.getAll();
      _filterActiveVaults();
      _errorMessage = null;
      _lastError = null;
    } catch (e) {
      _lastError = e;
      _errorMessage = AppErrorTranslator.translate(e).title;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _filterActiveVaults() {
    _activeVaults = _allVaults
        .where((v) => v.workspaceId == _activeWorkspaceId && !v.isArchived)
        .toList();
    _activeVaults.sort((a, b) => a.priority.compareTo(b.priority));
  }

  int getAllocatedForAccount(String accountId) {
    return _activeVaults
        .where((v) => v.parentAccountId == accountId)
        .fold<int>(0, (sum, v) => sum + v.currentPaise);
  }

  List<SavingsVault> getVaultsForAccount(String accountId) {
    return _activeVaults.where((v) => v.parentAccountId == accountId).toList();
  }

  Future<void> addVault(SavingsVault vault) async {
    await _repository.add(vault);
    await load();
  }

  Future<void> updateVault(SavingsVault vault) async {
    await _repository.update(vault);
    await load();
  }

  Future<void> deleteVault(String id) async {
    await _repository.delete(id);
    await load();
  }

  Future<bool> deposit(String vaultId, int amountPaise) async {
    _errorMessage = null;
    _lastError = null;

    final vault = await _repository.getById(vaultId);
    if (vault == null) {
      final err = NotFoundException(
        'Selected savings vault no longer exists.',
        entityType: 'vault',
      );
      _lastError = err;
      _errorMessage = err.message;
      notifyListeners();
      return false;
    }

    final result = await _allocationService.executeBatchAllocation(
      sourceAccountId: vault.parentAccountId,
      vaultAllocations: {vaultId: amountPaise},
    );
    if (result.success) {
      await load();
      return true;
    }

    _lastError = result.error ?? result.errorMessage;
    _errorMessage = result.errorMessage ??
        'Could not reserve funds into "${vault.name}". Check your backing account balance.';
    notifyListeners();
    return false;
  }

  Future<bool> withdraw(String vaultId, int amountPaise) async {
    _errorMessage = null;
    _lastError = null;

    final result = await _allocationService.withdrawWithResult(
      vaultId: vaultId,
      amountPaise: amountPaise,
    );
    if (result.success) {
      await load();
      return true;
    }

    _lastError = result.error ?? result.errorMessage;
    _errorMessage = result.errorMessage ?? 'Could not release funds from this vault.';
    notifyListeners();
    return false;
  }

  Future<VaultAllocationResult> executeBatchAllocation({
    required String sourceAccountId,
    required Map<String, int> allocations,
  }) async {
    _errorMessage = null;
    _lastError = null;

    final result = await _allocationService.executeBatchAllocation(
      sourceAccountId: sourceAccountId,
      vaultAllocations: allocations,
    );
    if (result.success) {
      await load();
    } else {
      _lastError = result.error ?? result.errorMessage;
      _errorMessage = result.errorMessage;
      notifyListeners();
    }
    return result;
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }
}
