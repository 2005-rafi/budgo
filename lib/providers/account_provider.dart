import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:expense/design/tokens/entity_icons.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/repositories/account_repository.dart';

class AccountProvider extends ChangeNotifier {
  final AccountRepository _repository;
  StreamSubscription<void>? _boxSubscription;

  List<Account> _allAccounts = [];
  List<Account> _activeAccounts = [];
  String _activeWorkspaceId = AppConstants.kDefaultWorkspaceId;
  bool _isLoading = false;
  String? _errorMessage;

  List<Account> get allAccounts => List.unmodifiable(_allAccounts);
  List<Account> get activeAccounts => List.unmodifiable(_activeAccounts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Global Net Worth in paise: under Universal Signed Net Equity,
  /// credit card balances are non-positive, so this is simply sum(balancePaise).
  int get netWorthPaise => _repository.getNetWorthPaise();

  /// Total equity balance in the active workspace.
  int get activeWorkspaceBalancePaise {
    return _activeAccounts.fold<int>(0, (sum, a) => sum + a.balancePaise);
  }

  /// Total physical liquid assets in active workspace (Cash + Bank + UPI).
  int get activeWorkspaceLiquidPaise {
    return _activeAccounts
        .where((a) =>
            a.type == AccountType.cash ||
            a.type == AccountType.bankAccount ||
            a.type == AccountType.upi)
        .fold<int>(0, (sum, a) => sum + a.balancePaise);
  }

  /// List of active credit cards in workspace with outstanding debt (balance < 0).
  List<Account> get activeCreditCardsWithDebt {
    return _activeAccounts
        .where((a) => a.type == AccountType.creditCard && a.balancePaise < 0)
        .toList();
  }

  /// Default account for the active workspace.
  Account? get defaultAccount {
    if (_activeAccounts.isEmpty) return null;
    return _activeAccounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => _activeAccounts.first,
    );
  }

  AccountProvider(this._repository);

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
    _filterActiveAccounts();
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allAccounts = await _repository.getAll();
      _filterActiveAccounts();
      _errorMessage = null;
    } on StorageException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = AppErrorTranslator.translate(e).title;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortAccounts(List<Account> list) {
    list.sort((a, b) {
      if (a.isDefault) return -1;
      if (b.isDefault) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  void _filterActiveAccounts() {
    _activeAccounts = _allAccounts
        .where((a) => a.workspaceId == _activeWorkspaceId && !a.isArchived)
        .toList();
    _sortAccounts(_activeAccounts);
  }

  /// Returns all non-archived accounts belonging to [workspaceId], sorted with default first.
  List<Account> getAccountsForWorkspace(String workspaceId) {
    final list = _allAccounts
        .where((a) => a.workspaceId == workspaceId && !a.isArchived)
        .toList();
    _sortAccounts(list);
    return list;
  }

  /// Ensures a workspace has the foundational triad: Cash Wallet, Bank Account, and UPI / GPay.
  Future<void> ensureStandardAccountsForWorkspace(
    String workspaceId, {
    int initialCashPaise = 0,
    String cashAccountName = 'Cash Wallet',
  }) async {
    final existing = _allAccounts.where((a) => a.workspaceId == workspaceId).toList();
    bool changed = false;
    final now = DateTime.now();

    final hasCash = existing.any((a) => a.type == AccountType.cash);
    final hasBank = existing.any((a) => a.type == AccountType.bankAccount);
    final hasUpi = existing.any((a) => a.type == AccountType.upi);

    if (!hasCash) {
      await _repository.add(Account(
        id: 'acc_${const Uuid().v4()}',
        workspaceId: workspaceId,
        name: cashAccountName,
        type: AccountType.cash,
        balancePaise: initialCashPaise,
        iconCodePoint: AccountIcons.forType(AccountType.cash).codePoint,
        colorValue: AccountIcons.defaultColorForType(AccountType.cash).toARGB32(),
        isDefault: existing.isEmpty,
        createdAt: now,
        updatedAt: now,
      ));
      changed = true;
    }

    if (!hasBank) {
      await _repository.add(Account(
        id: 'acc_${const Uuid().v4()}',
        workspaceId: workspaceId,
        name: 'Bank Account',
        type: AccountType.bankAccount,
        balancePaise: 0,
        iconCodePoint: AccountIcons.forType(AccountType.bankAccount).codePoint,
        colorValue: AccountIcons.defaultColorForType(AccountType.bankAccount).toARGB32(),
        isDefault: false,
        createdAt: now.add(const Duration(milliseconds: 1)),
        updatedAt: now,
      ));
      changed = true;
    }

    if (!hasUpi) {
      await _repository.add(Account(
        id: 'acc_${const Uuid().v4()}',
        workspaceId: workspaceId,
        name: 'UPI / GPay',
        type: AccountType.upi,
        balancePaise: 0,
        iconCodePoint: AccountIcons.forType(AccountType.upi).codePoint,
        colorValue: AccountIcons.defaultColorForType(AccountType.upi).toARGB32(),
        isDefault: false,
        createdAt: now.add(const Duration(milliseconds: 2)),
        updatedAt: now,
      ));
      changed = true;
    }

    if (changed) {
      await load();
    }
  }

  int getWorkspaceBalancePaise(String workspaceId) {
    return _allAccounts
        .where((a) => a.workspaceId == workspaceId)
        .fold<int>(0, (sum, a) => sum + a.balancePaise);
  }

  Account? getById(String id) {
    try {
      return _allAccounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Account> createAccount({
    required String name,
    required AccountType type,
    required int initialBalancePaise,
    int creditLimitPaise = 0,
    String? accountNumberLast4,
    required int iconCodePoint,
    required int colorValue,
    bool isDefault = false,
    String? targetWorkspaceId,
  }) async {
    final wsId = targetWorkspaceId ?? _activeWorkspaceId;
    final now = DateTime.now();

    // Under Signed Net Equity, credit cards cannot have positive starting balance
    final normalizedBalance = type == AccountType.creditCard
        ? (initialBalancePaise > 0 ? -initialBalancePaise : initialBalancePaise)
        : initialBalancePaise;

    final account = Account(
      id: 'acc_${const Uuid().v4()}',
      workspaceId: wsId,
      name: name.trim(),
      type: type,
      balancePaise: normalizedBalance,
      creditLimitPaise: creditLimitPaise,
      accountNumberLast4: accountNumberLast4,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      isDefault: isDefault,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.add(account);
    await load();
    return account;
  }

  Future<void> updateAccount(Account account) async {
    await _repository.update(account);
    await load();
  }

  Future<void> updateBalance(String accountId, int deltaPaise) async {
    await _repository.updateBalance(accountId, deltaPaise);
    await load();
  }

  Future<void> deleteAccount(String accountId) async {
    final acc = getById(accountId);
    if (acc != null && acc.balancePaise != 0) {
      throw ValidationException('Cannot delete an account with non-zero balance.');
    }
    await _repository.delete(accountId);
    await load();
  }

  Future<void> setArchived(String accountId, bool isArchived) async {
    await _repository.setArchived(accountId, isArchived);
    await load();
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }
}

