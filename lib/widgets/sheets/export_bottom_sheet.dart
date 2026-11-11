import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/services/report_export_service.dart';

class ExportBottomSheet extends StatefulWidget {
  final DateTimeRange? initialRange;
  final ExportWorkspaceScope initialScope;
  final String? initialWorkspaceId;

  const ExportBottomSheet({
    super.key,
    this.initialRange,
    this.initialScope = ExportWorkspaceScope.single,
    this.initialWorkspaceId,
  });

  static void show(
    BuildContext context, {
    DateTimeRange? initialRange,
    ExportWorkspaceScope initialScope = ExportWorkspaceScope.single,
    String? initialWorkspaceId,
  }) {
    BudgoBottomSheet.show(
      context,
      builder: (context) => ExportBottomSheet(
        initialRange: initialRange,
        initialScope: initialScope,
        initialWorkspaceId: initialWorkspaceId,
      ),
    );
  }

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  late DateTimeRange _dateRange;
  late ExportWorkspaceScope _scope;
  String? _singleWorkspaceId;
  final Set<String> _selectiveWorkspaceIds = {};

  ExportFormat _format = ExportFormat.pdf;
  bool _includeArchived = false;
  bool _includeExpenses = true;
  bool _includeIncomes = true;
  bool _includeTransfers = true;
  bool _includeCharts = true;

  bool _isExporting = false;
  double _progress = 0.0;
  ExportCancellationToken? _cancelToken;

  List<Expense> _previewExpenses = const [];
  int _previewIncomeCount = 0;
  int _previewTransferCount = 0;
  List<Transfer> _cachedAllTransfers = const [];
  bool _isCounting = false;

  String _normWs(String? id) =>
      (id == null || id.isEmpty) ? AppConstants.kDefaultWorkspaceId : id;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = widget.initialRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    _scope = widget.initialScope;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wsProvider = _tryRead<WorkspaceProvider>(context);
      final expProvider = _tryRead<ExpensesProvider>(context);
      final activeId = widget.initialWorkspaceId ??
          wsProvider?.activeWorkspaceId ??
          expProvider?.activeWorkspaceId ??
          AppConstants.kDefaultWorkspaceId;

      setState(() {
        _singleWorkspaceId = activeId;
        _selectiveWorkspaceIds.add(activeId);
      });
      _refreshPreview();
    });
  }

  T? _tryRead<T>(BuildContext ctx) {
    try {
      return ctx.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  T? _tryWatch<T>(BuildContext ctx) {
    try {
      return ctx.watch<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Set<String> _resolveTargetWorkspaceIds(List<Workspace> allWorkspaces) {
    if (allWorkspaces.isEmpty) {
      return {_singleWorkspaceId ?? AppConstants.kDefaultWorkspaceId};
    }
    return switch (_scope) {
      ExportWorkspaceScope.single => {
          _singleWorkspaceId ?? allWorkspaces.first.id,
        },
      ExportWorkspaceScope.selective => Set<String>.from(_selectiveWorkspaceIds),
      ExportWorkspaceScope.combinedAll => allWorkspaces.map((w) => w.id).toSet(),
    };
  }

  DateTimeRange _normalizedBounds() => DateTimeRange(
        start: DateTime(_dateRange.start.year, _dateRange.start.month, _dateRange.start.day),
        end: DateTime(_dateRange.end.year, _dateRange.end.month, _dateRange.end.day, 23, 59, 59, 999),
      );

  Future<void> _refreshPreview() async {
    final expProvider = _tryRead<ExpensesProvider>(context);
    final wsProvider = _tryRead<WorkspaceProvider>(context);
    final incProvider = _tryRead<IncomeProvider>(context);
    final trfProvider = _tryRead<TransferProvider>(context);

    final workspaces = wsProvider?.workspaces ?? const <Workspace>[];
    final targetIds = _resolveTargetWorkspaceIds(workspaces);
    if (targetIds.isEmpty) {
      if (mounted) {
        setState(() {
          _previewExpenses = const [];
          _previewIncomeCount = 0;
          _previewTransferCount = 0;
        });
      }
      return;
    }

    setState(() => _isCounting = true);
    try {
      final bounds = _normalizedBounds();
      final normTargetIds = targetIds.map(_normWs).toSet();

      final list = (_includeExpenses && expProvider != null)
          ? await expProvider.getExpensesForWorkspaces(
              normTargetIds,
              range: _dateRange,
              includeArchived: _includeArchived,
            )
          : const <Expense>[];

      int incCnt = 0;
      if (_includeIncomes && incProvider != null) {
        for (final i in incProvider.allIncomes) {
          if (normTargetIds.contains(_normWs(i.workspaceId)) &&
              !i.date.isBefore(bounds.start) &&
              !i.date.isAfter(bounds.end)) {
            incCnt++;
          }
        }
      }

      int trfCnt = 0;
      if (_includeTransfers && trfProvider != null) {
        _cachedAllTransfers = await trfProvider.getAllTransfers();
        for (final t in _cachedAllTransfers) {
          if (t.status != TransferStatus.completed) continue;
          if (t.date.isBefore(bounds.start) || t.date.isAfter(bounds.end)) {
            continue;
          }
          if (normTargetIds.contains(_normWs(t.sourceWorkspaceId)) ||
              normTargetIds.contains(_normWs(t.destinationWorkspaceId))) {
            trfCnt++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _previewExpenses = list;
          _previewIncomeCount = incCnt;
          _previewTransferCount = trfCnt;
          _isCounting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCounting = false);
    }
  }

  int get _totalPreviewCount =>
      (_includeExpenses ? _previewExpenses.length : 0) +
      (_includeIncomes ? _previewIncomeCount : 0) +
      (_includeTransfers ? _previewTransferCount : 0);

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
      await _refreshPreview();
    }
  }

  void _applyQuickPreset(String preset) {
    final now = DateTime.now();
    late DateTimeRange range;
    if (preset == 'month') {
      range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    } else if (preset == 'year') {
      range = DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    } else {
      range = DateTimeRange(start: DateTime(2000, 1, 1), end: now);
    }
    setState(() => _dateRange = range);
    _refreshPreview();
  }

  void _cancelExport() {
    _cancelToken?.cancel();
  }

  Future<void> _runExport() async {
    final wsProvider = _tryRead<WorkspaceProvider>(context);
    final expProvider = _tryRead<ExpensesProvider>(context);
    final incProvider = _tryRead<IncomeProvider>(context);
    final trfProvider = _tryRead<TransferProvider>(context);
    final accProvider = _tryRead<AccountProvider>(context);
    final vaultProvider = _tryRead<SavingsVaultProvider>(context);

    final allWorkspaces = wsProvider?.workspaces ?? const <Workspace>[];
    final targetIds = _resolveTargetWorkspaceIds(allWorkspaces);
    final normTargetIds = targetIds.map(_normWs).toSet();

    if (normTargetIds.isEmpty) {
      SnackbarFeedback.showWarning(
        context,
        'No workspace selected for export.',
        guidance: 'Select at least one workspace to continue.',
      );
      return;
    }

    if (!_includeExpenses && !_includeIncomes && !_includeTransfers) {
      SnackbarFeedback.showWarning(
        context,
        'No statement sections selected.',
        guidance: 'Enable at least one data section (Expenses, Income, or Transfers).',
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _progress = 0.05;
    });

    final token = ExportCancellationToken();
    _cancelToken = token;

    try {
      final bounds = _normalizedBounds();

      // Gather sorted expense partitions per workspace and merge via O(N log W) K-Way Heap
      List<Expense> expensesToExport = const [];
      List<Expense>? allExpForRecon;
      if (expProvider != null) {
        if (_includeExpenses) {
          final streams = <List<Expense>>[];
          for (final wsId in normTargetIds) {
            final part = await expProvider.getExpensesForWorkspaces(
              {wsId},
              range: _dateRange,
              includeArchived: _includeArchived,
            );
            if (part.isNotEmpty) {
              streams.add(part);
            }
          }
          expensesToExport = ReportExportService.mergeSortedDescending(streams);
        }
        allExpForRecon = await expProvider.getAllExpenses();
      } else {
        expensesToExport = _includeExpenses ? _previewExpenses : const [];
      }

      final allIncomes = incProvider?.allIncomes ?? const <Income>[];
      final inRangeIncomes = _includeIncomes
          ? allIncomes
              .where(
                (i) =>
                    normTargetIds.contains(_normWs(i.workspaceId)) &&
                    !i.date.isBefore(bounds.start) &&
                    !i.date.isAfter(bounds.end),
              )
              .toList()
          : const <Income>[];

      final allTransfers = trfProvider != null
          ? (_cachedAllTransfers.isNotEmpty
              ? _cachedAllTransfers
              : await trfProvider.getAllTransfers())
          : const <Transfer>[];
      final inRangeTransfers = _includeTransfers
          ? allTransfers
              .where(
                (t) =>
                    t.status == TransferStatus.completed &&
                    !t.date.isBefore(bounds.start) &&
                    !t.date.isAfter(bounds.end) &&
                    (normTargetIds.contains(_normWs(t.sourceWorkspaceId)) ||
                        normTargetIds.contains(_normWs(t.destinationWorkspaceId))),
              )
              .toList()
          : const <Transfer>[];

      if (expensesToExport.isEmpty &&
          inRangeIncomes.isEmpty &&
          inRangeTransfers.isEmpty) {
        if (mounted) {
          SnackbarFeedback.showWarning(
            context,
            'No financial records matched your export filter.',
            guidance: 'Try widening the date range, enabling archived expenses, or choosing another workspace.',
          );
        }
        return;
      }

      final selectedWorkspaces = allWorkspaces
          .where((w) => normTargetIds.contains(_normWs(w.id)))
          .toList();

      final allWorkspaceNames = {
        for (final w in allWorkspaces) _normWs(w.id): w.name,
      };

      final accountNames = <String, String>{
        for (final a in accProvider?.allAccounts ?? const []) a.id: a.name,
      };

      final result = await ReportExportService.exportReport(
        ExportRequest(
          scope: _scope,
          workspaces: selectedWorkspaces,
          expenses: expensesToExport,
          allExpensesForReconciliation: allExpForRecon,
          incomes: inRangeIncomes,
          allIncomesForReconciliation: allIncomes,
          transfers: inRangeTransfers,
          allTransfersForReconciliation: allTransfers,
          accounts: accProvider?.allAccounts ?? const [],
          vaults: vaultProvider?.allVaults ?? const [],
          accountNames: accountNames,
          allWorkspaceNames: allWorkspaceNames,
          range: _dateRange,
          format: _format,
          includeArchived: _includeArchived,
          includeExpenses: _includeExpenses,
          includeIncomes: _includeIncomes,
          includeTransfers: _includeTransfers,
          includeCharts: _includeCharts,
          fallbackCurrencySymbol: MoneyFormatter.symbol,
          cancellationToken: token,
        ),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;

      if (result.isSuccess && result.value != null) {
        final file = result.value!;
        final formatLabel = _format == ExportFormat.csv ? 'CSV' : 'PDF';
        final suffix = result.wasTruncatedForPdfCap
            ? ' (PDF ledger capped at ${AppConstants.kMaxPdfDetailRows} items — use CSV for full ledger)'
            : '';

        SnackbarFeedback.showSuccess(
          context,
          '$formatLabel statement ready (${result.exportedCount} entries)$suffix',
        );

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: '${AppBrand.appName} $formatLabel Financial Statement',
            text:
                '${AppBrand.appName} Financial Statement (${result.exportedCount} entries)',
          ),
        );
        if (mounted) Navigator.pop(context);
      } else if (result.error is ExportCancelledError) {
        SnackbarFeedback.showInfo(context, 'Export cancelled cleanly.');
      } else {
        SnackbarFeedback.showError(
          context,
          result.errorMessage ?? 'Unable to generate export file.',
          operation: _format == ExportFormat.csv
              ? FeedbackOperation.exportCsv
              : FeedbackOperation.exportPdf,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: _format == ExportFormat.csv
              ? FeedbackOperation.exportCsv
              : FeedbackOperation.exportPdf,
        );
      }
    } finally {
      _cancelToken = null;
      if (mounted) {
        setState(() {
          _isExporting = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wsProvider = _tryWatch<WorkspaceProvider>(context);
    final workspaces = wsProvider?.workspaces ?? const <Workspace>[];

    final targetIds = _resolveTargetWorkspaceIds(workspaces);
    final selectedWsObjects =
        workspaces.where((w) => targetIds.contains(w.id)).toList();
    final distinctCurrencies =
        selectedWsObjects.map((w) => w.currency).toSet();
    final hasMixedCurrencies = distinctCurrencies.length > 1;
    final previewCount = _totalPreviewCount;
    final exceedsPdfCap = previewCount > AppConstants.kMaxPdfDetailRows;

    return BudgoBottomSheet(
      title: 'Export Financial Statement',
      subtitle: 'Branded ledger with charts, income & balance changes',
      icon: Icons.file_download_outlined,
      footer: _isExporting
          ? BudgoButton(
              label: 'Cancel Export',
              icon: Icons.close_rounded,
              variant: BudgoButtonVariant.tonal,
              onPressed: _cancelExport,
            )
          : BudgoButton(
              label: _isCounting
                  ? 'Counting records...'
                  : 'Export $previewCount Record(s)',
              icon: Icons.ios_share_rounded,
              onPressed: _isCounting ? null : _runExport,
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
              BudgoSegmentedControl<ExportWorkspaceScope>(
                segments: const [
                  ButtonSegment(
                    value: ExportWorkspaceScope.single,
                    label: Text('Single'),
                  ),
                  ButtonSegment(
                    value: ExportWorkspaceScope.selective,
                    label: Text('Selective'),
                  ),
                  ButtonSegment(
                    value: ExportWorkspaceScope.combinedAll,
                    label: Text('All'),
                  ),
                ],
                selected: _scope,
                onSelected: (val) {
                  if (_isExporting) return;
                  setState(() => _scope = val);
                  _refreshPreview();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (_scope == ExportWorkspaceScope.single)
                BudgoDropdownField<String>(
                  label: 'Workspace Profile',
                  value: _singleWorkspaceId ?? workspaces.first.id,
                  options: workspaces
                      .map(
                        (w) => BudgoDropdownItem<String>(
                          value: w.id,
                          label: w.name,
                          icon: WorkspaceIcons.forType(w.type),
                          iconColor: Color(w.colorValue),
                          trailingText: w.currency,
                        ),
                      )
                      .toList(),
                  onChanged: _isExporting
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _singleWorkspaceId = val);
                            _refreshPreview();
                          }
                        },
                )
              else if (_scope == ExportWorkspaceScope.selective) ...[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: workspaces.map((w) {
                    final selected = _selectiveWorkspaceIds.contains(w.id);
                    return BudgoChip(
                      label: '${w.name} (${w.currency})',
                      icon: WorkspaceIcons.forType(w.type),
                      accentColor: Color(w.colorValue),
                      selected: selected,
                      onSelected: _isExporting
                          ? null
                          : (isSel) {
                              setState(() {
                                if (isSel) {
                                  _selectiveWorkspaceIds.add(w.id);
                                } else if (_selectiveWorkspaceIds.length > 1) {
                                  _selectiveWorkspaceIds.remove(w.id);
                                }
                              });
                              _refreshPreview();
                            },
                    );
                  }).toList(),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Combined export consolidates all ${workspaces.length} workspaces with opening/closing balances and cumulative running totals.',
                          style: AppTextStyles.bodySmall(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasMixedCurrencies) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'Multi-currency workspaces detected (${distinctCurrencies.join(', ')}). Charts & balances are partitioned cleanly per currency.',
                    style: AppTextStyles.labelSmall(context).copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],

            BudgoPickerField(
              icon: Icons.date_range_rounded,
              label: 'Export Date Range',
              value:
                  '${DateFormat('yMMMd').format(_dateRange.start)} – ${DateFormat('yMMMd').format(_dateRange.end)}',
              onTap: _isExporting ? null : _pickDateRange,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ActionChip(
                  label: const Text('This Month'),
                  onPressed: _isExporting ? null : () => _applyQuickPreset('month'),
                ),
                ActionChip(
                  label: const Text('This Year'),
                  onPressed: _isExporting ? null : () => _applyQuickPreset('year'),
                ),
                ActionChip(
                  label: const Text('All Time'),
                  onPressed: _isExporting ? null : () => _applyQuickPreset('all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            Text(
              'Statement Content',
              style: AppTextStyles.labelMedium(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                BudgoChip(
                  label: 'Expenses',
                  icon: Icons.receipt_long_outlined,
                  selected: _includeExpenses,
                  onSelected: _isExporting
                      ? null
                      : (v) {
                          setState(() => _includeExpenses = v);
                          _refreshPreview();
                        },
                ),
                BudgoChip(
                  label: 'Income',
                  icon: Icons.trending_up_rounded,
                  selected: _includeIncomes,
                  onSelected: _isExporting
                      ? null
                      : (v) {
                          setState(() => _includeIncomes = v);
                          _refreshPreview();
                        },
                ),
                BudgoChip(
                  label: 'Transfers',
                  icon: Icons.swap_horiz_rounded,
                  selected: _includeTransfers,
                  onSelected: _isExporting
                      ? null
                      : (v) {
                          setState(() => _includeTransfers = v);
                          _refreshPreview();
                        },
                ),
                BudgoChip(
                  label: 'Line Charts',
                  icon: Icons.show_chart_rounded,
                  selected: _includeCharts,
                  onSelected: _isExporting
                      ? null
                      : (v) => setState(() => _includeCharts = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            BudgoSwitchTile(
              title: 'Include Archived Records',
              subtitle: 'Include expenses previously archived in Settings',
              value: _includeArchived,
              onChanged: _isExporting
                  ? null
                  : (val) {
                      setState(() => _includeArchived = val);
                      _refreshPreview();
                    },
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Export Format',
              style: AppTextStyles.labelMedium(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            BudgoSegmentedControl<ExportFormat>(
              segments: const [
                ButtonSegment(
                  value: ExportFormat.pdf,
                  label: Text('PDF (Visual Report)'),
                  icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ExportFormat.csv,
                  label: Text('CSV (Spreadsheet)'),
                  icon: Icon(Icons.grid_on_rounded, size: 18),
                ),
              ],
              selected: _format,
              onSelected: (val) {
                if (!_isExporting) setState(() => _format = val);
              },
            ),

            if (_format == ExportFormat.pdf && exceedsPdfCap) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$previewCount records matched. PDF detail ledger caps at ${AppConstants.kMaxPdfDetailRows} most recent rows to protect device memory; choose CSV for the full raw dump.',
                  style: AppTextStyles.labelSmall(context).copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],

            if (_isExporting) ...[
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor:
                      colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Generating ${_format == ExportFormat.csv ? "streaming CSV" : "branded PDF statement"}... ${(_progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
