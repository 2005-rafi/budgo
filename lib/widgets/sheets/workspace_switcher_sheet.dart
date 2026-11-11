import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/widgets/sheets/workspace_creation_sheet.dart';
import 'package:expense/widgets/sheets/self_transfer_bottom_sheet.dart';

class WorkspaceSwitcherSheet extends StatelessWidget {
  const WorkspaceSwitcherSheet({super.key});

  void _showFundSweepDialog(BuildContext context, Workspace ws, int balancePaise) {
    final accounts = context.read<AccountProvider>().allAccounts.where(
      (a) => a.workspaceId != ws.id,
    ).toList();
    final workspaces = context.read<WorkspaceProvider>().workspaces;

    if (accounts.isEmpty) {
      SnackbarFeedback.showError(context, 'No available destination accounts to sweep funds into.');
      return;
    }

    String selectedDestAccountId = accounts.first.id;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Remaining Funds Detected'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workspace "${ws.name}" holds ${CurrencyFormatter.formatPaise(balancePaise)} in unspent funds. '
                    'To protect your net worth, sweep these funds to an active account before closing.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BudgoDropdownField<String>(
                    value: selectedDestAccountId,
                    label: 'Sweep Remaining Funds To',
                    options: accounts.map((a) {
                      final wsName = workspaces
                              .firstWhereOrNull((w) => w.id == a.workspaceId)
                              ?.name ??
                          '';
                      final label =
                          wsName.isNotEmpty ? '[$wsName] ${a.name}' : a.name;
                      return BudgoDropdownItem<String>(
                        value: a.id,
                        label: label,
                        icon: AccountIcons.forType(a.type),
                        iconColor: Color(a.colorValue),
                        trailingText: CurrencyFormatter.formatPaise(a.balancePaise),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedDestAccountId = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                BudgoButton(
                  label: 'Cancel',
                  variant: BudgoButtonVariant.text,
                  expanded: false,
                  height: 42,
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
                BudgoButton(
                  label: 'Sweep Funds',
                  expanded: false,
                  height: 42,
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    // Open self-transfer sheet pre-configured
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SelfTransferBottomSheet(
                        initialSourceWorkspaceId: ws.id,
                        initialDestAccountId: selectedDestAccountId,
                        initialAmountPaise: balancePaise,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditWorkspaceDialog(BuildContext context, Workspace ws) {
    showDialog(
      context: context,
      builder: (_) => _EditWorkspaceDialog(workspace: ws),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workspaceProvider = context.watch<WorkspaceProvider>();
    final accountProvider = context.watch<AccountProvider>();

    final workspaces = workspaceProvider.workspaces;
    final activeId = workspaceProvider.activeWorkspaceId;
    final netWorth = accountProvider.netWorthPaise;

    return AppBottomSheetContainer(
      title: 'Workspaces',
      subtitle: 'Switch or manage financial profiles',
      trailing: FilledButton.tonalIcon(
        onPressed: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const WorkspaceCreationSheet(),
          );
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('New'),
      ),
      child: Column(
        children: [
          // Net Worth Summary Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.base),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Net Worth',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatPaise(netWorth),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: netWorth >= 0 ? colorScheme.primary : colorScheme.error,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ],
            ),
          ),

          // Workspace List
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: workspaces.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final ws = workspaces[index];
                final isActive = ws.id == activeId;
                final wsBalance = accountProvider.getWorkspaceBalancePaise(ws.id);

                return Material(
                  color: isActive
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: isActive
                          ? BorderSide(color: colorScheme.primary, width: 1.5)
                          : BorderSide.none,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Color(ws.colorValue).withValues(alpha: 0.2),
                      foregroundColor: Color(ws.colorValue),
                      child: Icon(WorkspaceIcons.forType(ws.type), size: 20),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            ws.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ws.isDefault) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              'Default',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                        if (ws.type == WorkspaceType.trip) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              'Trip',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      'Balance: ${CurrencyFormatter.formatPaise(wsBalance)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 20),
                          tooltip: 'Edit Name & Balance',
                          onPressed: () => _showEditWorkspaceDialog(context, ws),
                        ),
                        if (isActive)
                          Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                        else if (!ws.isDefault)
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                            tooltip: 'Delete Workspace',
                            onPressed: () async {
                              if (wsBalance > 0) {
                                _showFundSweepDialog(context, ws, wsBalance);
                              } else {
                                final confirm = await ConfirmationDialog.show(
                                  context,
                                  title: 'Delete "${ws.name}"?',
                                  message: 'Are you sure you want to delete this workspace?',
                                  confirmLabel: 'Delete',
                                  isDestructive: true,
                                );
                                if (confirm && context.mounted) {
                                  try {
                                    await context.read<WorkspaceProvider>().deleteWorkspace(
                                      ws.id,
                                      remainingFundsPaise: wsBalance,
                                    );
                                    if (context.mounted) {
                                      SnackbarFeedback.showSuccess(context, 'Workspace deleted.');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      SnackbarFeedback.showError(
                                        context,
                                        e,
                                        operation: FeedbackOperation.deleteWorkspace,
                                      );
                                    }
                                  }
                                }
                              }
                            },
                          ),
                      ],
                    ),
                    onTap: () async {
                      await context.read<WorkspaceProvider>().setActiveWorkspace(ws.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditWorkspaceDialog extends StatefulWidget {
  final Workspace workspace;

  const _EditWorkspaceDialog({required this.workspace});

  @override
  State<_EditWorkspaceDialog> createState() => _EditWorkspaceDialogState();
}

class _EditWorkspaceDialogState extends State<_EditWorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final int _currentPaise;

  @override
  void initState() {
    super.initState();
    final accountProvider = context.read<AccountProvider>();
    _currentPaise = accountProvider.getWorkspaceBalancePaise(widget.workspace.id);
    _nameController = TextEditingController(text: widget.workspace.name);
    _balanceController = TextEditingController(text: (_currentPaise / 100.0).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Workspace: ${widget.workspace.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BudgoTextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              inputPolicy: BudgoInputPolicy.workspaceName,
              label: 'Workspace Name',
              hint: BudgoInputGuidance.workspaceHint(widget.workspace.type),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Workspace name cannot be empty';
                }
                if (val.contains(' ')) {
                  return 'Spaces are not allowed in workspace name';
                }
                if (val.trim().length > AppInputLimits.workspaceNameMax) {
                  return 'Name cannot exceed ${AppInputLimits.workspaceNameMax} characters';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Starting / current liquid balance (adjusts primary account):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.xs),
            BudgoTextField(
              controller: _balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              maxLength: AppInputLimits.amountInputMaxChars,
              showCounter: false,
              inputFormatters: AppInputLimits.decimalAmountFormatters,
              label: 'Balance (${widget.workspace.currency})',
              hint: 'Enter adjusted liquid balance',
              prefixText: '${widget.workspace.currency} ',
            ),
          ],
        ),
      ),
      actions: [
        BudgoButton(
          label: 'Cancel',
          variant: BudgoButtonVariant.text,
          expanded: false,
          height: 42,
          onPressed: () => Navigator.pop(context),
        ),
        BudgoButton(
          label: 'Save',
          expanded: false,
          height: 42,
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;

            final accountProvider = context.read<AccountProvider>();
            final workspaceProvider = context.read<WorkspaceProvider>();
            final defaultAcc = accountProvider.allAccounts.firstWhereOrNull(
              (a) => a.workspaceId == widget.workspace.id && a.isDefault,
            ) ?? accountProvider.allAccounts.firstWhereOrNull((a) => a.workspaceId == widget.workspace.id);

            try {
              final newName = _nameController.text.trim();
              if (newName != widget.workspace.name) {
                widget.workspace.name = newName;
                await workspaceProvider.updateWorkspace(widget.workspace);
                if (context.mounted) {
                  try {
                    await context
                        .read<ReminderProvider>()
                        .syncWorkspaceNotificationStyles(widget.workspace.id);
                  } on ProviderNotFoundException {
                    // Optional in isolated workspace-only tests.
                  }
                }
              }

              final newAmount = double.tryParse(_balanceController.text.trim()) ?? 0.0;
              final newPaise = (newAmount * 100).round();
              final delta = newPaise - _currentPaise;
              if (defaultAcc != null && delta != 0) {
                await accountProvider.updateBalance(defaultAcc.id, delta);
              }

              if (!context.mounted) return;
              SnackbarFeedback.showSuccess(context, 'Workspace "$newName" updated.');
              Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                SnackbarFeedback.showError(
                  context,
                  e,
                  operation: FeedbackOperation.renameWorkspace,
                );
              }
            }
          },
        ),
      ],
    );
  }
}
