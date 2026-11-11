import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/budget_provider.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/future_expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/reports_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/services/data_lifecycle_service.dart';
import 'package:expense/services/storage_info_service.dart';

T? _tryReadProvider<T>(BuildContext ctx) {
  try {
    return ctx.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Synchronously & completely reloads every downstream provider after workspace wipes or factory resets.
Future<void> reloadAllAppProviders(
  BuildContext context, {
  bool includeCategories = false,
}) async {
  final wsProvider = _tryReadProvider<WorkspaceProvider>(context);
  final accProvider = _tryReadProvider<AccountProvider>(context);
  final trfProvider = _tryReadProvider<TransferProvider>(context);
  final vaultProvider = _tryReadProvider<SavingsVaultProvider>(context);
  final expProvider = _tryReadProvider<ExpensesProvider>(context);
  final incProvider = _tryReadProvider<IncomeProvider>(context);
  final futProvider = _tryReadProvider<FutureExpensesProvider>(context);
  final budgetProvider = _tryReadProvider<BudgetProvider>(context);
  final remProvider = _tryReadProvider<ReminderProvider>(context);
  final repProvider = _tryReadProvider<ReportsProvider>(context);
  final catProvider = _tryReadProvider<CategoryProvider>(context);

  if (wsProvider != null) {
    await wsProvider.load();
    final activeWsId = wsProvider.activeWorkspaceId;
    expProvider?.setActiveWorkspace(activeWsId);
    incProvider?.setActiveWorkspace(activeWsId);
    accProvider?.setActiveWorkspace(activeWsId);
    trfProvider?.setActiveWorkspace(activeWsId);
    vaultProvider?.setActiveWorkspace(activeWsId);
    remProvider?.setActiveWorkspace(activeWsId);
    await budgetProvider?.setActiveWorkspace(activeWsId);
    futProvider?.setActiveWorkspace(activeWsId);
    repProvider?.setActiveWorkspace(activeWsId);
  }

  await Future.wait([
    if (accProvider != null) accProvider.load(),
    if (trfProvider != null) trfProvider.load(),
    if (vaultProvider != null) vaultProvider.load(),
    if (expProvider != null) expProvider.load(),
    if (incProvider != null) incProvider.load(),
    if (futProvider != null) futProvider.load(),
    if (budgetProvider != null) budgetProvider.load(),
    if (remProvider != null) remProvider.load(),
  ]);

  if (expProvider != null) {
    await expProvider.deferredRebuild();
    repProvider?.onExpensesUpdated(expProvider);
  }
  if (includeCategories) {
    catProvider?.reload();
  }
}

/// Displays DB file size, per-workspace entity counts, and one-tap Hive compaction.
class StorageBreakdownSheet extends StatefulWidget {
  final VoidCallback? onChanged;
  const StorageBreakdownSheet({super.key, this.onChanged});

  static void show(BuildContext context, {VoidCallback? onChanged}) {
    BudgoBottomSheet.show(
      context,
      builder: (_) => StorageBreakdownSheet(onChanged: onChanged),
    );
  }

  @override
  State<StorageBreakdownSheet> createState() => _StorageBreakdownSheetState();
}

class _StorageBreakdownSheetState extends State<StorageBreakdownSheet> {
  StorageMetricsSnapshot? _snapshot;
  bool _isLoading = true;
  bool _isCompacting = false;

  @override
  void initState() {
    super.initState();
    _loadMetrics(forceRefresh: true);
  }

  Future<void> _loadMetrics({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final snap = await StorageInfoService.getDetailedMetrics(
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _snapshot = snap;
        _isLoading = false;
      });
    }
  }

  Future<void> _compact() async {
    setState(() => _isCompacting = true);
    try {
      final service =
          _tryReadProvider<DataLifecycleService>(context) ?? DataLifecycleService();
      await service.compactAllBoxes();
      await _loadMetrics(forceRefresh: true);
      widget.onChanged?.call();
      if (mounted) {
        SnackbarFeedback.showSuccess(
          context,
          'Database optimized and compacted.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.compactStorage,
        );
      }
    } finally {
      if (mounted) setState(() => _isCompacting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final snap = _snapshot;

    return BudgoBottomSheet(
      title: 'Storage Breakdown',
      subtitle: snap != null
          ? '${snap.formattedSize} • ${snap.totalRecords} total records'
          : 'Analyzing workspace footprint...',
      icon: Icons.storage_outlined,
      footer: BudgoButton(
        label: 'Optimize & Compact DB',
        icon: Icons.cleaning_services_outlined,
        isLoading: _isCompacting,
        onPressed: _isLoading ? null : _compact,
      ),
      child: _isLoading || snap == null
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: snap.workspaces.map((ws) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ws.workspaceName,
                                style: AppTextStyles.bodyMedium(context).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${ws.totalRecords} items',
                              style: AppTextStyles.labelMedium(context).copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Expenses: ${ws.activeExpenses} active, ${ws.archivedExpenses} archived • '
                          'Incomes: ${ws.incomes} • Accounts: ${ws.accounts} • '
                          'Vaults: ${ws.vaults} • Reminders: ${ws.reminders} • Transfers: ${ws.transfers}',
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

enum _LifecycleScope { active, selective, all }

/// Workspace-isolated Archive sheet letting users archive older expenses safely.
class WorkspaceArchiveSheet extends StatefulWidget {
  final VoidCallback? onCompleted;
  const WorkspaceArchiveSheet({super.key, this.onCompleted});

  static void show(BuildContext context, {VoidCallback? onCompleted}) {
    BudgoBottomSheet.show(
      context,
      builder: (_) => WorkspaceArchiveSheet(onCompleted: onCompleted),
    );
  }

  @override
  State<WorkspaceArchiveSheet> createState() => _WorkspaceArchiveSheetState();
}

class _WorkspaceArchiveSheetState extends State<WorkspaceArchiveSheet> {
  _LifecycleScope _scope = _LifecycleScope.active;
  final Set<String> _selectiveIds = {};
  int _months = 12;
  bool _isRunning = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wsProvider = _tryReadProvider<WorkspaceProvider>(context);
      final activeId =
          wsProvider?.activeWorkspaceId ?? AppConstants.kDefaultWorkspaceId;
      setState(() => _selectiveIds.add(activeId));
    });
  }

  Set<String> _targetIds(List<Workspace> workspaces, String activeId) {
    if (workspaces.isEmpty) return {activeId};
    return switch (_scope) {
      _LifecycleScope.active => {activeId},
      _LifecycleScope.selective => Set<String>.from(_selectiveIds),
      _LifecycleScope.all => workspaces.map((w) => w.id).toSet(),
    };
  }

  Future<void> _executeArchive(Set<String> ids, int count) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Archive $count Expenses?',
      message:
          'This marks matching records older than $_months months as archived to accelerate charts and lists. You can still include archived items in Exports.',
      confirmLabel: 'Archive Now',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isRunning = true;
      _progress = 0.05;
    });

    try {
      final service =
          _tryReadProvider<DataLifecycleService>(context) ?? DataLifecycleService();
      final archived = await service.archiveExpenses(
        workspaceIds: ids,
        olderThanMonths: _months,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      await reloadAllAppProviders(context);
      widget.onCompleted?.call();
      if (!mounted) return;
      Navigator.pop(context);
      SnackbarFeedback.showSuccess(
        context,
        archived > 0
            ? 'Archived $archived expense(s) successfully.'
            : 'No eligible older expenses needed archiving.',
      );
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.archiveData,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsProvider = _tryReadProvider<WorkspaceProvider>(context);
    final expProvider = context.watch<ExpensesProvider>();
    final workspaces = wsProvider?.workspaces ?? const <Workspace>[];
    final activeId =
        wsProvider?.activeWorkspaceId ?? expProvider.activeWorkspaceId;
    final targetIds = _targetIds(workspaces, activeId);
    final matchCount = expProvider.countOlderThan(_months, workspaceIds: targetIds);

    return BudgoBottomSheet(
      title: 'Archive Old Data',
      subtitle: 'Move aged expenses out of active lists per workspace',
      icon: Icons.archive_outlined,
      footer: BudgoButton(
        label: 'Archive $matchCount Eligible Item(s)',
        icon: Icons.archive_outlined,
        isLoading: _isRunning,
        onPressed: (targetIds.isEmpty || _isRunning)
            ? null
            : () => _executeArchive(targetIds, matchCount),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (workspaces.length > 1) ...[
              Text(
                'Workspace Scope',
                style: AppTextStyles.labelMedium(context)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              BudgoSegmentedControl<_LifecycleScope>(
                segments: const [
                  ButtonSegment(value: _LifecycleScope.active, label: Text('Active')),
                  ButtonSegment(value: _LifecycleScope.selective, label: Text('Selective')),
                  ButtonSegment(value: _LifecycleScope.all, label: Text('All')),
                ],
                selected: _scope,
                onSelected: (v) => setState(() => _scope = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_scope == _LifecycleScope.selective)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: workspaces.map((w) {
                    return BudgoChip(
                      label: w.name,
                      selected: _selectiveIds.contains(w.id),
                      accentColor: Color(w.colorValue),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectiveIds.add(w.id);
                          } else if (_selectiveIds.length > 1) {
                            _selectiveIds.remove(w.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: AppSpacing.md),
            ],

            Text(
              'Archive Expenses Older Than',
              style: AppTextStyles.labelMedium(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            BudgoSegmentedControl<int>(
              segments: const [
                ButtonSegment(value: 6, label: Text('6 Months')),
                ButtonSegment(value: 12, label: Text('12 Months')),
                ButtonSegment(value: 24, label: Text('24 Months')),
              ],
              selected: _months,
              onSelected: (v) => setState(() => _months = v),
            ),

            if (_isRunning) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            ],
          ],
        ),
      ),
    );
  }
}

/// Workspace-isolated data clearing sheet (Single or Selective workspaces).
class WorkspaceClearSheet extends StatefulWidget {
  final VoidCallback? onCompleted;
  const WorkspaceClearSheet({super.key, this.onCompleted});

  static void show(BuildContext context, {VoidCallback? onCompleted}) {
    BudgoBottomSheet.show(
      context,
      builder: (_) => WorkspaceClearSheet(onCompleted: onCompleted),
    );
  }

  @override
  State<WorkspaceClearSheet> createState() => _WorkspaceClearSheetState();
}

class _WorkspaceClearSheetState extends State<WorkspaceClearSheet> {
  final Set<String> _selectedIds = {};
  bool _deleteSecondaryProfiles = false;
  bool _isRunning = false;
  double _progress = 0.0;
  StorageMetricsSnapshot? _metrics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final wsProvider = _tryReadProvider<WorkspaceProvider>(context);
      final activeId =
          wsProvider?.activeWorkspaceId ?? AppConstants.kDefaultWorkspaceId;
      final snap = await StorageInfoService.getDetailedMetrics(forceRefresh: true);
      if (mounted) {
        setState(() {
          _selectedIds.add(activeId);
          _metrics = snap;
        });
      }
    });
  }

  Future<void> _executeClear(List<Workspace> selectedWorkspaces) async {
    final names = selectedWorkspaces.map((w) => w.name).join(', ');
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Clear Workspace Data?',
      message:
          'Permanently delete expenses, incomes, budgets, wishlist items, vaults, and scheduled reminders for: $names.\n\n'
          'Other workspaces and surviving cross-workspace transfers will NOT be touched.',
      confirmLabel: 'Wipe Selected',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isRunning = true;
      _progress = 0.05;
    });

    try {
      final service =
          _tryReadProvider<DataLifecycleService>(context) ?? DataLifecycleService();
      final summary = await service.clearWorkspaceData(
        workspaceIds: _selectedIds,
        deleteSecondaryWorkspaces: _deleteSecondaryProfiles,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      await reloadAllAppProviders(context);
      widget.onCompleted?.call();
      if (!mounted) return;
      Navigator.pop(context);
      SnackbarFeedback.showSuccess(
        context,
        'Cleared ${summary.totalRecordsAffected} record(s) across selected workspace(s).',
      );
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.wipeWorkspace,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wsProvider = _tryReadProvider<WorkspaceProvider>(context);
    final workspaces = wsProvider?.workspaces ?? const <Workspace>[];
    final selectedWs =
        workspaces.where((w) => _selectedIds.contains(w.id)).toList();
    final hasDeletableSecondary = selectedWs.any(
      (w) => !w.isDefault && w.id != AppConstants.kDefaultWorkspaceId,
    );

    final countMap = {
      for (final b in _metrics?.workspaces ?? const <WorkspaceStorageBreakdown>[])
        b.workspaceId: b,
    };

    return BudgoBottomSheet(
      title: 'Clear Workspace Data',
      subtitle: 'Wipe specific workspace(s) while isolating all others',
      icon: Icons.cleaning_services_rounded,
      iconColor: colorScheme.error,
      footer: BudgoButton(
        label: 'Clear Selected Workspace(s)',
        icon: Icons.delete_sweep_outlined,
        isLoading: _isRunning,
        onPressed: (_selectedIds.isEmpty || _isRunning)
            ? null
            : () => _executeClear(selectedWs),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Workspace(s) to Clear',
              style: AppTextStyles.labelMedium(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: workspaces.map((w) {
                final stats = countMap[w.id];
                final label = stats != null
                    ? '${w.name} (${stats.totalRecords})'
                    : w.name;
                return BudgoChip(
                  label: label,
                  icon: WorkspaceIcons.forType(w.type),
                  accentColor: Color(w.colorValue),
                  selected: _selectedIds.contains(w.id),
                  onSelected: _isRunning
                      ? null
                      : (sel) {
                          setState(() {
                            if (sel) {
                              _selectedIds.add(w.id);
                            } else {
                              _selectedIds.remove(w.id);
                            }
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            if (hasDeletableSecondary) ...[
              BudgoSwitchTile(
                title: 'Remove Secondary Workspace Profiles',
                subtitle:
                    'Also delete the empty secondary profile card (Primary Default is always kept)',
                value: _deleteSecondaryProfiles,
                onChanged: _isRunning
                    ? null
                    : (val) => setState(() => _deleteSecondaryProfiles = val),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            if (_isRunning) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            ],
          ],
        ),
      ),
    );
  }
}

/// Leak-free StatefulWidget dialog verifying full factory reset with "RESET".
class FactoryResetVerificationDialog extends StatefulWidget {
  const FactoryResetVerificationDialog({super.key});

  static Future<({bool confirmed, bool resetCategories})?> show(
    BuildContext context,
  ) {
    return showDialog<({bool confirmed, bool resetCategories})>(
      context: context,
      builder: (_) => const FactoryResetVerificationDialog(),
    );
  }

  @override
  State<FactoryResetVerificationDialog> createState() =>
      _FactoryResetVerificationDialogState();
}

class _FactoryResetVerificationDialogState
    extends State<FactoryResetVerificationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _resetCategories = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Final Verification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please type "RESET" in all caps to permanently erase all workspaces and local financial records.',
          ),
          const SizedBox(height: AppSpacing.md),
          BudgoTextField(
            controller: _controller,
            autofocus: true,
            inputPolicy: BudgoInputPolicy.resetConfirm,
            hint: 'Type "RESET" to confirm wipe',
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _resetCategories,
            onChanged: (val) =>
                setState(() => _resetCategories = val ?? false),
            title: const Text('Also reset custom categories to defaults'),
          ),
        ],
      ),
      actions: [
        BudgoButton(
          label: 'Cancel',
          variant: BudgoButtonVariant.text,
          expanded: false,
          height: 42,
          onPressed: () => Navigator.pop(context),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            return BudgoButton(
              label: 'RESET EVERYTHING',
              variant: BudgoButtonVariant.destructive,
              expanded: false,
              height: 42,
              onPressed: value.text == 'RESET'
                  ? () => Navigator.pop(
                        context,
                        (confirmed: true, resetCategories: _resetCategories),
                      )
                  : null,
            );
          },
        ),
      ],
    );
  }
}
