import 'package:hive/hive.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_status.dart';

abstract class TransferRepository {
  Future<List<Transfer>> getAll();
  Future<List<Transfer>> getByWorkspace(String workspaceId);
  Future<List<Transfer>> getByAccount(String accountId);
  Future<Transfer?> getById(String id);
  Future<void> recordTransfer(Transfer transfer);
  Future<void> updateStatus(String transferId, TransferStatus status, {String? failureReason});
  Stream<void> watch();
}

class HiveTransferRepository implements TransferRepository {
  final Box<Transfer>? _injectedBox;

  HiveTransferRepository([this._injectedBox]);

  Box<Transfer> get _box =>
      _injectedBox ?? Hive.box<Transfer>(AppConstants.kTransfersBox);

  @override
  Stream<void> watch() => _box.watch();

  @override
  Future<List<Transfer>> getAll() async {
    try {
      final list = _box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      throw StorageException('Failed to read transfers: $e');
    }
  }

  @override
  Future<List<Transfer>> getByWorkspace(String workspaceId) async {
    try {
      final list = _box.values.where(
        (t) => t.sourceWorkspaceId == workspaceId || t.destinationWorkspaceId == workspaceId,
      ).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      throw StorageException('Failed to read transfers for workspace: $e');
    }
  }

  @override
  Future<List<Transfer>> getByAccount(String accountId) async {
    try {
      final list = _box.values.where(
        (t) => t.sourceAccountId == accountId || t.destinationAccountId == accountId,
      ).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      throw StorageException('Failed to read transfers for account: $e');
    }
  }

  @override
  Future<Transfer?> getById(String id) async {
    try {
      return _box.get(id);
    } catch (e) {
      throw StorageException('Failed to find transfer $id: $e');
    }
  }

  @override
  Future<void> recordTransfer(Transfer transfer) async {
    try {
      await _box.put(transfer.id, transfer);
      await _box.flush();
    } catch (e) {
      throw StorageException('Failed to record transfer: $e');
    }
  }

  @override
  Future<void> updateStatus(String transferId, TransferStatus status, {String? failureReason}) async {
    try {
      final transfer = _box.get(transferId);
      if (transfer != null) {
        transfer.status = status;
        if (failureReason != null) {
          transfer.failureReason = failureReason;
        }
        await transfer.save();
        await _box.flush();
      }
    } catch (e) {
      throw StorageException('Failed to update transfer status: $e');
    }
  }
}
