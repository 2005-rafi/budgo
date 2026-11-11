import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/repositories/transfer_repository.dart';
import 'package:expense/services/transfer_engine_service.dart';

class TransferProvider extends ChangeNotifier {
  final TransferRepository _repository;
  final TransferEngineService _engineService;
  StreamSubscription<void>? _boxSubscription;

  List<Transfer> _transfers = [];
  String? _activeWorkspaceId;
  bool _isLoading = false;
  String? _errorMessage;

  List<Transfer> get transfers => List.unmodifiable(_transfers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<List<Transfer>> getAllTransfers() => _repository.getAll();

  TransferProvider(this._repository, this._engineService);

  Future<void> initialize({String? initialWorkspaceId}) async {
    _activeWorkspaceId = initialWorkspaceId;
    _boxSubscription ??= _repository.watch().listen((_) => load());
    await load();
  }

  void setActiveWorkspace(String workspaceId) {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    load(workspaceId: workspaceId);
  }

  Future<void> load({String? workspaceId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final targetWs = workspaceId ?? _activeWorkspaceId;
      if (targetWs != null) {
        _transfers = await _repository.getByWorkspace(targetWs);
      } else {
        _transfers = await _repository.getAll();
      }
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

  Future<Transfer> executeTransfer({
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountPaise,
    int feePaise = 0,
    String? note,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final transfer = await _engineService.executeTransfer(
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        amountPaise: amountPaise,
        feePaise: feePaise,
        note: note,
      );
      await load();
      return transfer;
    } catch (e) {
      _errorMessage = AppErrorTranslator.translate(
        e,
        operation: FeedbackOperation.selfTransfer,
      ).title;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reverseTransfer(String transferId, {String? reason}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _engineService.reverseTransfer(transferId, reason: reason);
      await load();
    } catch (e) {
      _errorMessage = AppErrorTranslator.translate(
        e,
        operation: FeedbackOperation.selfTransfer,
      ).title;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }
}

