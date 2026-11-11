import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_journal_entry.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/transfer_repository.dart';
import 'package:expense/services/transfer_engine_service.dart';

class InMemoryAccountRepository implements AccountRepository {
  final Map<String, Account> _data = {};
  bool failNextCredit = false;

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
  Future<Account?> getDefault(String workspaceId) async =>
      _data.values.firstWhere((a) => a.workspaceId == workspaceId && a.isDefault, orElse: () => _data.values.first);

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
    if (failNextCredit && accountId == 'acc_cash' && deltaPaise > 0) {
      failNextCredit = false;
      throw StorageException('Simulated destination credit disk failure');
    }
    final acc = _data[accountId];
    if (acc == null) throw ValidationException('Account not found');
    acc.balancePaise += deltaPaise;
    acc.updatedAt = DateTime.now();
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

class InMemoryTransferRepository implements TransferRepository {
  final Map<String, Transfer> _transfers = {};

  @override
  Future<List<Transfer>> getAll() async => _transfers.values.toList();

  @override
  Future<List<Transfer>> getByAccount(String accountId) async =>
      _transfers.values.where((t) => t.sourceAccountId == accountId || t.destinationAccountId == accountId).toList();

  @override
  Future<List<Transfer>> getByWorkspace(String workspaceId) async =>
      _transfers.values.where((t) => t.sourceWorkspaceId == workspaceId || t.destinationWorkspaceId == workspaceId).toList();

  @override
  Future<Transfer?> getById(String id) async => _transfers[id];

  @override
  Future<void> recordTransfer(Transfer transfer) async => _transfers[transfer.id] = transfer;

  @override
  Future<void> updateStatus(String transferId, TransferStatus status, {String? failureReason}) async {
    final t = _transfers[transferId];
    if (t != null) {
      t.status = status;
      t.failureReason = failureReason;
    }
  }

  @override
  Stream<void> watch() => const Stream.empty();
}

class MockJournalBox implements Box<TransferJournalEntry> {
  final Map<dynamic, TransferJournalEntry> _box = {};

  @override
  Future<void> put(dynamic key, TransferJournalEntry value) async => _box[key] = value;

  @override
  Future<void> delete(dynamic key) async => _box.remove(key);

  @override
  TransferJournalEntry? get(dynamic key, {TransferJournalEntry? defaultValue}) =>
      _box[key] ?? defaultValue;

  @override
  Iterable<TransferJournalEntry> get values => _box.values;

  @override
  Future<void> flush() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryAccountRepository accountRepo;
  late InMemoryTransferRepository transferRepo;
  late MockJournalBox journalBox;
  late TransferEngineService transferEngine;

  setUp(() {
    accountRepo = InMemoryAccountRepository();
    transferRepo = InMemoryTransferRepository();
    journalBox = MockJournalBox();
    transferEngine = TransferEngineService(accountRepo, transferRepo, journalBox);

    // Seed test accounts
    accountRepo.add(Account(
      id: 'acc_bank',
      workspaceId: 'default_personal',
      name: 'Bank Account',
      type: AccountType.bankAccount,
      balancePaise: 1000000, // ₹10,000
      iconCodePoint: 0,
      colorValue: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    accountRepo.add(Account(
      id: 'acc_cash',
      workspaceId: 'default_personal',
      name: 'Cash Wallet',
      type: AccountType.cash,
      balancePaise: 200000, // ₹2,000
      iconCodePoint: 0,
      colorValue: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    accountRepo.add(Account(
      id: 'acc_cc',
      workspaceId: 'default_personal',
      name: 'Credit Card',
      type: AccountType.creditCard,
      balancePaise: -300000, // -₹3,000 debt
      creditLimitPaise: 5000000, // ₹50,000 limit
      iconCodePoint: 0,
      colorValue: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  });

  group('TransferEngineService ACID Tests', () {
    test('TEST-ACID-01: Transfer completes atomically with debited source and credited destination', () async {
      final transfer = await transferEngine.executeTransfer(
        sourceAccountId: 'acc_bank',
        destinationAccountId: 'acc_cash',
        amountPaise: 50000, // ₹500
      );

      expect(transfer.status, TransferStatus.completed);

      final bank = await accountRepo.getById('acc_bank');
      final cash = await accountRepo.getById('acc_cash');

      // Bank debited: 10,000 - 500 = 9,500
      expect(bank!.balancePaise, 950000);
      // Cash credited: 2,000 + 500 = 2,500
      expect(cash!.balancePaise, 250000);
      // Journal entry deleted upon completion
      expect(journalBox.values.isEmpty, isTrue);
    });

    test('TEST-ACID-02: Destination failure triggers compensating rollback on source', () async {
      accountRepo.failNextCredit = true;

      await expectLater(
        transferEngine.executeTransfer(
          sourceAccountId: 'acc_bank',
          destinationAccountId: 'acc_cash',
          amountPaise: 50000,
        ),
        throwsA(isA<StorageException>()),
      );

      final bank = await accountRepo.getById('acc_bank');
      final cash = await accountRepo.getById('acc_cash');

      // Bank restored to original balance (compensating rollback executed)
      expect(bank!.balancePaise, 1000000);
      // Cash never credited
      expect(cash!.balancePaise, 200000);

      // Recorded transfer marked rolledBack
      final recorded = (await transferRepo.getAll()).first;
      expect(recorded.status, TransferStatus.rolledBack);
    });

    test('TEST-ACID-03: Insufficient funds exception thrown if balance is exhausted', () async {
      await expectLater(
        transferEngine.executeTransfer(
          sourceAccountId: 'acc_cash', // Balance: ₹2,000
          destinationAccountId: 'acc_bank',
          amountPaise: 300000, // Request: ₹3,000
        ),
        throwsA(isA<InsufficientFundsException>()),
      );

      final cash = await accountRepo.getById('acc_cash');
      expect(cash!.balancePaise, 200000); // Intact
    });

    test('Paying Credit Card bill reduces negative debt and leaves Net Worth constant', () async {
      final netWorthBefore = accountRepo.getNetWorthPaise();

      // Pay ₹2,000 from Bank towards Credit Card
      await transferEngine.executeTransfer(
        sourceAccountId: 'acc_bank',
        destinationAccountId: 'acc_cc',
        amountPaise: 200000,
      );

      final bank = await accountRepo.getById('acc_bank');
      final cc = await accountRepo.getById('acc_cc');

      // Bank: 10,000 - 2,000 = 8,000
      expect(bank!.balancePaise, 800000);
      // CC: -3,000 + 2,000 = -1,000 (Debt reduced from ₹3k to ₹1k)
      expect(cc!.balancePaise, -100000);
      expect(cc.outstandingDebtPaise, 100000);

      final netWorthAfter = accountRepo.getNetWorthPaise();
      // Internal transfer does NOT change global net worth
      expect(netWorthAfter, netWorthBefore);
    });

    test('reverseTransfer executes compensating reversal atomically', () async {
      // 1. Execute initial transfer: Bank -> Cash ₹2,000
      final transfer = await transferEngine.executeTransfer(
        sourceAccountId: 'acc_bank',
        destinationAccountId: 'acc_cash',
        amountPaise: 200000,
      );

      var bank = await accountRepo.getById('acc_bank');
      var cash = await accountRepo.getById('acc_cash');
      expect(bank!.balancePaise, 800000); // 10k - 2k
      expect(cash!.balancePaise, 400000); // 2k + 2k

      // 2. Reverse the transfer
      final reversed = await transferEngine.reverseTransfer(transfer.id, reason: 'Test reversal');
      expect(reversed.status, TransferStatus.rolledBack);

      bank = await accountRepo.getById('acc_bank');
      cash = await accountRepo.getById('acc_cash');
      expect(bank!.balancePaise, 1000000); // restored to 10k
      expect(cash!.balancePaise, 200000);  // restored to 2k
    });
  });
}
