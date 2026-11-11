import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/transfer_provider.dart';
import 'package:expense/providers/workspace_provider.dart';

class SelfTransferBottomSheet extends StatefulWidget {
  final String? initialSourceAccountId;
  final String? initialDestAccountId;
  final String? initialSourceWorkspaceId;
  final int? initialAmountPaise;

  const SelfTransferBottomSheet({
    super.key,
    this.initialSourceAccountId,
    this.initialDestAccountId,
    this.initialSourceWorkspaceId,
    this.initialAmountPaise,
  });

  @override
  State<SelfTransferBottomSheet> createState() => _SelfTransferBottomSheetState();
}

class _SelfTransferBottomSheetState extends State<SelfTransferBottomSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _sourceWorkspaceId;
  String? _sourceAccountId;
  String? _destWorkspaceId;
  String? _destAccountId;
  bool _isSubmitting = false;
  double _swapAngle = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initEndpoints();
    });
  }

  void _initEndpoints() {
    final accountProvider = context.read<AccountProvider>();
    final workspaceProvider = context.read<WorkspaceProvider>();
    final allAccounts = accountProvider.allAccounts;
    final workspaces = workspaceProvider.workspaces;

    if (allAccounts.isEmpty) return;

    setState(() {
      // 1. Resolve Source Workspace & Source Account
      if (widget.initialSourceAccountId != null) {
        final srcAcc = accountProvider.getById(widget.initialSourceAccountId!);
        _sourceAccountId = srcAcc?.id;
        _sourceWorkspaceId = srcAcc?.workspaceId;
      } else if (widget.initialSourceWorkspaceId != null) {
        _sourceWorkspaceId = widget.initialSourceWorkspaceId;
        final wsAccounts = accountProvider.getAccountsForWorkspace(_sourceWorkspaceId!);
        _sourceAccountId = wsAccounts.isNotEmpty ? wsAccounts.first.id : null;
      } else {
        _sourceWorkspaceId = workspaceProvider.activeWorkspaceId;
        final wsAccounts = accountProvider.getAccountsForWorkspace(_sourceWorkspaceId!);
        final fundedAccount = wsAccounts.firstWhereOrNull((a) => a.balancePaise > 0);
        _sourceAccountId = fundedAccount?.id ??
            accountProvider.defaultAccount?.id ??
            (wsAccounts.isNotEmpty ? wsAccounts.first.id : allAccounts.first.id);
      }

      // 2. Resolve Destination Workspace & Destination Account
      if (widget.initialDestAccountId != null) {
        final destAcc = accountProvider.getById(widget.initialDestAccountId!);
        _destAccountId = destAcc?.id;
        _destWorkspaceId = destAcc?.workspaceId;
      } else {
        final otherWorkspace = workspaces.firstWhereOrNull(
          (w) => w.id != _sourceWorkspaceId && accountProvider.getAccountsForWorkspace(w.id).isNotEmpty,
        );
        _destWorkspaceId = otherWorkspace?.id ?? _sourceWorkspaceId;

        final destWsAccounts = _destWorkspaceId != null
            ? accountProvider.getAccountsForWorkspace(_destWorkspaceId!)
            : allAccounts;
        final preferredDest = destWsAccounts.firstWhereOrNull((a) => a.id != _sourceAccountId) ??
            allAccounts.firstWhereOrNull((a) => a.id != _sourceAccountId);
        _destAccountId = preferredDest?.id;
        if (_destAccountId != null && preferredDest != null) {
          _destWorkspaceId = preferredDest.workspaceId;
        }
      }

      if (widget.initialAmountPaise != null && widget.initialAmountPaise! > 0) {
        _amountController.text = (widget.initialAmountPaise! / 100.0).toStringAsFixed(2);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onSourceWorkspaceChanged(String? newWsId) {
    if (newWsId == null) return;
    final wsAccounts = context.read<AccountProvider>().getAccountsForWorkspace(newWsId);
    setState(() {
      _sourceWorkspaceId = newWsId;
      _sourceAccountId = wsAccounts.firstWhereOrNull((a) => a.id != _destAccountId)?.id ??
          (wsAccounts.isNotEmpty ? wsAccounts.first.id : null);
    });
  }

  void _onDestWorkspaceChanged(String? newWsId) {
    if (newWsId == null) return;
    final wsAccounts = context.read<AccountProvider>().getAccountsForWorkspace(newWsId);
    setState(() {
      _destWorkspaceId = newWsId;
      _destAccountId = wsAccounts.firstWhereOrNull((a) => a.id != _sourceAccountId)?.id ??
          (wsAccounts.isNotEmpty ? wsAccounts.first.id : null);
    });
  }

  void _swapEndpoints() {
    setState(() {
      _swapAngle += math.pi;
      final tempWs = _sourceWorkspaceId;
      _sourceWorkspaceId = _destWorkspaceId;
      _destWorkspaceId = tempWs;

      final tempAcc = _sourceAccountId;
      _sourceAccountId = _destAccountId;
      _destAccountId = tempAcc;
    });
  }

  void _addAmount(double rupees) {
    final current = double.tryParse(_amountController.text) ?? 0.0;
    final updated = current + rupees;
    _amountController.text = updated.toStringAsFixed(updated.truncateToDouble() == updated ? 0 : 2);
  }

  void _setFullBalance() {
    if (_sourceAccountId == null) return;
    final account = context.read<AccountProvider>().getById(_sourceAccountId!);
    if (account == null) return;
    if (account.balancePaise > 0) {
      _amountController.text = (account.balancePaise / 100.0).toStringAsFixed(2);
    } else {
      SnackbarFeedback.showInfo(
        context,
        '${account.name} has ₹0.00 available.',
        guidance: 'Pick another funded workspace/account from the FROM card above.',
      );
    }
  }

  Future<void> _executeTransfer() async {
    if (_sourceAccountId == null || _destAccountId == null) {
      SnackbarFeedback.showError(
        context,
        'Please select both source and destination accounts.',
        guidance: 'Choose where to send money FROM and where to receive it TO.',
      );
      return;
    }

    if (_sourceAccountId == _destAccountId) {
      SnackbarFeedback.showError(
        context,
        'Source and destination accounts cannot be the same.',
        guidance: 'Pick a different account or switch to another destination workspace.',
      );
      return;
    }

    final validation = InputValidators.validateAmount(
      _amountController.text,
      fieldLabel: 'Transfer amount',
    );
    if (!validation.isValid) {
      SnackbarFeedback.showError(context, validation.errorMessage!);
      return;
    }

    final amountPaise = validation.paise!;

    setState(() => _isSubmitting = true);

    try {
      final transferProvider = context.read<TransferProvider>();
      final accountProvider = context.read<AccountProvider>();

      final transfer = await transferProvider.executeTransfer(
        sourceAccountId: _sourceAccountId!,
        destinationAccountId: _destAccountId!,
        amountPaise: amountPaise,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      // Refresh account balances across all workspaces
      await accountProvider.load();

      if (mounted) {
        Navigator.pop(context);
        SnackbarFeedback.showSuccess(
          context,
          'Transferred ${CurrencyFormatter.formatPaise(transfer.amountPaise)} successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.selfTransfer,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildEndpointSelectorCard({
    required String directionLabel,
    required String? selectedWorkspaceId,
    required String? selectedAccountId,
    required List<Workspace> workspaces,
    required List<Account> workspaceAccounts,
    required ValueChanged<String?> onWorkspaceChanged,
    required ValueChanged<String?> onAccountChanged,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final safeWorkspaceValue = workspaces.any((w) => w.id == selectedWorkspaceId)
        ? selectedWorkspaceId
        : (workspaces.isNotEmpty ? workspaces.first.id : null);

    final safeAccountValue = workspaceAccounts.any((a) => a.id == selectedAccountId)
        ? selectedAccountId
        : (workspaceAccounts.isNotEmpty ? workspaceAccounts.first.id : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Direction Label + Workspace Selector Pill
          Row(
            children: [
              Text(
                directionLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (workspaces.isNotEmpty)
                Expanded(
                  child: BudgoDropdownField<String>(
                    value: safeWorkspaceValue,
                    isDense: true,
                    fillColor:
                        colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                    options: workspaces
                        .map(
                          (ws) => BudgoDropdownItem<String>(
                            value: ws.id,
                            label: ws.name,
                            icon: WorkspaceIcons.forType(ws.type),
                            iconColor: Color(ws.colorValue),
                            trailingText: ws.isDefault ? 'Default' : null,
                          ),
                        )
                        .toList(),
                    onChanged: onWorkspaceChanged,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Account Selector within Chosen Workspace
          BudgoDropdownField<String>(
            value: safeAccountValue,
            options: workspaceAccounts.map((a) {
              final balanceText = a.isCredit
                  ? 'Limit: ${CurrencyFormatter.formatPaise(a.availableCreditPaise)}'
                  : 'Bal: ${CurrencyFormatter.formatPaise(a.balancePaise)}';
              return BudgoDropdownItem<String>(
                value: a.id,
                label: a.name,
                icon: AccountIcons.forType(a.type),
                iconColor: Color(a.colorValue),
                trailingText: balanceText,
              );
            }).toList(),
            onChanged: onAccountChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountProvider = context.watch<AccountProvider>();
    final workspaceProvider = context.watch<WorkspaceProvider>();

    final allAccounts = accountProvider.allAccounts;
    final workspaces = workspaceProvider.workspaces;

    final effectiveSourceWs = _sourceWorkspaceId ?? workspaceProvider.activeWorkspaceId;
    final effectiveDestWs = _destWorkspaceId ?? workspaceProvider.activeWorkspaceId;

    final sourceWsAccounts = accountProvider.getAccountsForWorkspace(effectiveSourceWs);
    final destWsAccounts = accountProvider.getAccountsForWorkspace(effectiveDestWs);

    // Fallback to allAccounts only if workspace filtering yielded nothing in edge test fixtures
    final resolvedSourceAccounts = sourceWsAccounts.isNotEmpty ? sourceWsAccounts : allAccounts;
    final resolvedDestAccounts = destWsAccounts.isNotEmpty ? destWsAccounts : allAccounts;

    return AppBottomSheetContainer(
      title: 'Self-Transfer',
      subtitle: 'Move funds across workspaces or accounts',
      child: allAccounts.length < 2
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'You need at least 2 accounts to make a self-transfer.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Source Endpoint Card (Workspace -> Account)
                  _buildEndpointSelectorCard(
                    directionLabel: 'FROM',
                    selectedWorkspaceId: _sourceWorkspaceId,
                    selectedAccountId: _sourceAccountId,
                    workspaces: workspaces,
                    workspaceAccounts: resolvedSourceAccounts,
                    onWorkspaceChanged: _onSourceWorkspaceChanged,
                    onAccountChanged: (val) => setState(() => _sourceAccountId = val),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),

                  // Animated Swap Button
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: IconButton.filledTonal(
                        onPressed: _swapEndpoints,
                        icon: AnimatedRotation(
                          turns: _swapAngle / (2 * math.pi),
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(Icons.swap_vert_rounded),
                        ),
                        tooltip: 'Swap Source & Destination',
                      ),
                    ),
                  ),

                  // Destination Endpoint Card (Workspace -> Account)
                  _buildEndpointSelectorCard(
                    directionLabel: 'TO',
                    selectedWorkspaceId: _destWorkspaceId,
                    selectedAccountId: _destAccountId,
                    workspaces: workspaces,
                    workspaceAccounts: resolvedDestAccounts,
                    onWorkspaceChanged: _onDestWorkspaceChanged,
                    onAccountChanged: (val) => setState(() => _destAccountId = val),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Cash Flow Clarification Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'UPI & Bank share the same underlying bank balance, while Cash Wallet tracks physical cash. Transfer between workspaces to track trip cash vs digital UPI safety.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Amount Input & Quick Presets
                  BudgoAmountField(
                    controller: _amountController,
                    quickPresetsPaise: const [50000, 100000, 500000],
                    onPresetSelected: (paise) => _addAmount(paise / 100.0),
                    showFullBalanceAction: true,
                    onFullBalanceTap: _setFullBalance,
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Note Field
                  BudgoTextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    inputPolicy: BudgoInputPolicy.transferNote,
                    label: 'Transfer Note (Optional)',
                    hint: 'Purpose or reason for moving funds',
                    prefixIcon: Icons.edit_note_rounded,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Execute Button
                  BudgoButton(
                    label: _isSubmitting ? 'Transferring...' : 'Transfer Now',
                    icon: Icons.send_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _executeTransfer,
                  ),
                ],
              ),
            ),
    );
  }
}
