import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/constants/app_input_limits.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/app_state_box.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/repositories/workspace_repository.dart';
import 'package:expense/services/data_lifecycle_service.dart';

class WorkspaceProvider extends ChangeNotifier {
  final WorkspaceRepository _repository;
  DataLifecycleService? _lifecycleService;
  StreamSubscription<void>? _boxSubscription;

  List<Workspace> _workspaces = [];
  Workspace? _activeWorkspace;
  bool _isLoading = false;
  String? _errorMessage;

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  Workspace? get activeWorkspace => _activeWorkspace;
  String get activeWorkspaceId => _activeWorkspace?.id ?? AppConstants.kDefaultWorkspaceId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Callback hooks for child providers to synchronize on workspace change
  void Function(String workspaceId)? onWorkspaceChanged;
  Future<void> Function()? onWorkspaceDeletedCascade;

  WorkspaceProvider(
    this._repository, {
    DataLifecycleService? lifecycleService,
  }) : _lifecycleService = lifecycleService;

  void attachLifecycleService(DataLifecycleService service) {
    _lifecycleService = service;
  }

  Future<void> initialize() async {
    _boxSubscription ??= _repository.watch().listen((_) => load());
    await load();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _workspaces = await _repository.getAll();
      final currentId = AppStateBox.activeWorkspaceId;
      _activeWorkspace = _workspaces.firstWhere(
        (w) => w.id == currentId,
        orElse: () => _workspaces.isNotEmpty ? _workspaces.first : _createFallbackWorkspace(),
      );
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

  Workspace _createFallbackWorkspace() {
    return Workspace(
      id: AppConstants.kDefaultWorkspaceId,
      name: 'Personal',
      type: WorkspaceType.personal,
      currency: '₹',
      initialBalance: 0,
      createdAt: DateTime.now(),
      iconCodePoint: 0xe491,
      colorValue: 0xFF2196F3,
      isDefault: true,
    );
  }

  Future<void> setActiveWorkspace(String workspaceId) async {
    if (_activeWorkspace?.id == workspaceId) return;

    final target = _workspaces.firstWhere(
      (w) => w.id == workspaceId,
      orElse: () => _activeWorkspace ?? _createFallbackWorkspace(),
    );

    _activeWorkspace = target;
    await AppStateBox.setActiveWorkspaceId(target.id);
    onWorkspaceChanged?.call(target.id);
    notifyListeners();
  }

  Future<Workspace> createWorkspace({
    required String name,
    required WorkspaceType type,
    String currency = '₹',
    int initialBalance = 0,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('Workspace name cannot be empty.');
    }
    if (trimmed.contains(' ')) {
      throw ValidationException(
        'Spaces are not allowed in workspace name.',
        guidance: 'Use CamelCase or underscores instead.',
      );
    }
    if (trimmed.characters.length > AppInputLimits.workspaceNameMax) {
      throw ValidationException(
        'Workspace name exceeds ${AppInputLimits.workspaceNameMax} characters.',
      );
    }

    final newWs = Workspace(
      id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      type: type,
      currency: currency,
      initialBalance: initialBalance,
      createdAt: DateTime.now(),
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      isDefault: false,
    );

    await _repository.add(newWs);
    await load();
    await setActiveWorkspace(newWs.id);
    return newWs;
  }

  Future<void> updateWorkspace(Workspace workspace) async {
    final trimmed = workspace.name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('Workspace name cannot be empty.');
    }
    if (trimmed.contains(' ')) {
      throw ValidationException(
        'Spaces are not allowed in workspace name.',
        guidance: 'Use CamelCase or underscores instead.',
      );
    }
    if (trimmed.characters.length > AppInputLimits.workspaceNameMax) {
      throw ValidationException(
        'Workspace name exceeds ${AppInputLimits.workspaceNameMax} characters.',
      );
    }

    workspace.name = trimmed;
    await _repository.update(workspace);
    await load();
  }

  Future<void> deleteWorkspace(String workspaceId, {required int remainingFundsPaise}) async {
    if (workspaceId == AppConstants.kDefaultWorkspaceId) {
      throw ValidationException(
        'The default primary workspace cannot be deleted.',
        guidance: 'You can rename it anytime by tapping the settings tune icon.',
      );
    }

    // Pre-Deletion Fund Sweep Gate (Ruling 4)
    if (remainingFundsPaise != 0) {
      throw ValidationException(
        'Cannot delete workspace while active funds remain.',
        guidance: 'Sweep the remaining balance to another workspace via Self-Transfer before deleting.',
      );
    }

    if (_lifecycleService != null) {
      await _lifecycleService!.clearWorkspaceData(
        workspaceIds: {workspaceId},
        deleteSecondaryWorkspaces: true,
      );
    } else {
      await _repository.delete(workspaceId);
    }
    await load();
    if (onWorkspaceDeletedCascade != null) {
      await onWorkspaceDeletedCascade!();
    }
    if (_activeWorkspace?.id == workspaceId) {
      await setActiveWorkspace(AppConstants.kDefaultWorkspaceId);
    }
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }
}
