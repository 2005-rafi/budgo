import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_journal_entry.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/repositories/account_repository.dart';
import 'package:expense/repositories/transfer_repository.dart';

class TransferEngineService {
  final AccountRepository _accountRepo;
  final TransferRepository _transferRepo;
  final Box<TransferJournalEntry>? _injectedJournalBox;

  TransferEngineService(
    this._accountRepo,
    this._transferRepo, [
    this._injectedJournalBox,
  ]);

  Box<TransferJournalEntry> get _journalBox =>
      _injectedJournalBox ??
      Hive.box<TransferJournalEntry>(AppConstants.kTransferJournalBox);

  Future<Transfer> executeTransfer({
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountPaise,
    int feePaise = 0,
    String? note,
  }) async {
    return await AtomicWriter.instance.execute(() async {
      // 1. FRESH SNAPSHOT: Authoritative State Read within Mutex
      final source = await _accountRepo.getById(sourceAccountId);
      final dest = await _accountRepo.getById(destinationAccountId);

      if (source == null || dest == null) {
        throw ValidationException('One or both accounts do not exist.');
      }
      if (source.id == dest.id) {
        throw ValidationException('Source and destination accounts must be distinct.');
      }
      if (amountPaise <= 0) {
        throw ValidationException('Transfer amount must be strictly greater than zero.');
      }

      final totalDeduction = amountPaise + feePaise;

      // Invariant checks inside mutex zone (TOCTOU Guard)
      if (source.isCredit) {
        final availableCredit = source.creditLimitPaise + source.balancePaise;
        if (availableCredit < totalDeduction) {
          final maxAllowed = availableCredit > 0 ? availableCredit : 0;
          throw InsufficientFundsException(
            'Transfer exceeds available credit limit of ${source.name}.',
            availablePaise: maxAllowed,
            requestedPaise: totalDeduction,
            accountName: source.name,
            alternativeHint:
                'Reduce amount to ${CurrencyFormatter.formatPaise(maxAllowed)} or transfer from another account.',
          );
        }
      } else {
        // For asset accounts, self-transfers require available funds
        if (source.balancePaise < totalDeduction) {
          final maxAllowed = source.balancePaise > 0 ? source.balancePaise : 0;
          throw InsufficientFundsException(
            'Insufficient funds in ${source.name} for transfer.',
            availablePaise: maxAllowed,
            requestedPaise: totalDeduction,
            accountName: source.name,
            alternativeHint:
                'Transfer up to ${CurrencyFormatter.formatPaise(maxAllowed)} or choose a funded source account.',
          );
        }
      }

      final transferId = const Uuid().v4();
      final now = DateTime.now();

      final transfer = Transfer(
        id: transferId,
        sourceAccountId: source.id,
        destinationAccountId: dest.id,
        sourceWorkspaceId: source.workspaceId,
        destinationWorkspaceId: dest.workspaceId,
        amountPaise: amountPaise,
        feePaise: feePaise,
        date: now,
        note: note,
        status: TransferStatus.pending,
      );

      final journal = TransferJournalEntry(
        transferId: transferId,
        sourceAccountId: source.id,
        destinationAccountId: dest.id,
        amountPaise: amountPaise,
        feePaise: feePaise,
        sourceOriginalBalance: source.balancePaise,
        destOriginalBalance: dest.balancePaise,
        phase: TransferJournalPhase.initiated,
        timestamp: now,
      );

      // 2. Write WAL Journal Entry & Pending Transfer
      await _journalBox.put(transferId, journal);
      await _transferRepo.recordTransfer(transfer);
      await _journalBox.flush();

      try {
        // 3. Step 1: Debit Source Account
        await _accountRepo.updateBalance(source.id, -totalDeduction);
        journal.phase = TransferJournalPhase.sourceDebited;
        await _journalBox.put(transferId, journal);
        await _journalBox.flush();

        try {
          // 4. Step 2: Credit Destination Account
          await _accountRepo.updateBalance(dest.id, amountPaise);
          journal.phase = TransferJournalPhase.destinationCredited;
          await _journalBox.put(transferId, journal);

          // 5. Finalize Transfer & Clear Journal
          transfer.status = TransferStatus.completed;
          await _transferRepo.updateStatus(transferId, TransferStatus.completed);
          await _journalBox.delete(transferId);
          await _journalBox.flush();

          return transfer;
        } catch (creditError) {
          // Compensating Transaction: Rollback Source Debit
          await _accountRepo.updateBalance(source.id, totalDeduction);
          transfer.status = TransferStatus.rolledBack;
          transfer.failureReason = 'Destination credit failed: $creditError';
          await _transferRepo.updateStatus(
            transferId,
            TransferStatus.rolledBack,
            failureReason: transfer.failureReason,
          );
          await _journalBox.delete(transferId);
          await _journalBox.flush();
          rethrow;
        }
      } catch (e) {
        if (journal.phase == TransferJournalPhase.initiated) {
          transfer.status = TransferStatus.failed;
          transfer.failureReason = 'Source debit failed: $e';
          await _transferRepo.updateStatus(
            transferId,
            TransferStatus.failed,
            failureReason: transfer.failureReason,
          );
          await _journalBox.delete(transferId);
          await _journalBox.flush();
        }
        if (e is AppException) {
          rethrow;
        }
        throw StorageException(
          'Transfer was cancelled and safely rolled back.',
          guidance: 'No balances changed. Please try the transfer again.',
          reason: e.toString(),
        );
      }
    });
  }

  /// Reverses an already completed transfer via a compensating ledger transaction.
  Future<Transfer> reverseTransfer(String transferId, {String? reason}) async {
    return await AtomicWriter.instance.execute(() async {
      final transfer = await _transferRepo.getById(transferId);
      if (transfer == null) {
        throw ValidationException('Transfer does not exist.');
      }
      if (transfer.status != TransferStatus.completed) {
        throw ValidationException('Only completed transfers can be reversed.');
      }

      final source = await _accountRepo.getById(transfer.sourceAccountId);
      final dest = await _accountRepo.getById(transfer.destinationAccountId);

      if (source == null || dest == null) {
        throw ValidationException('One or both accounts involved in this transfer no longer exist.');
      }

      // Compensating reversal: Debit destination by amountPaise, Credit source by total deduction
      final totalRefund = transfer.amountPaise + transfer.feePaise;
      await _accountRepo.updateBalance(dest.id, -transfer.amountPaise);
      await _accountRepo.updateBalance(source.id, totalRefund);

      transfer.status = TransferStatus.rolledBack;
      transfer.failureReason = reason ?? 'Manually reversed by user';
      await _transferRepo.updateStatus(
        transferId,
        TransferStatus.rolledBack,
        failureReason: transfer.failureReason,
      );

      return transfer;
    });
  }
}
