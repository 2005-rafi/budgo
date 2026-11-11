import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/registries/curated_icons_catalog.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/widgets/sheets/savings_vault_sheet.dart';

class VaultManagementSheet extends StatelessWidget {
  const VaultManagementSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VaultManagementSheet(),
    );
  }

  void _showDepositDialog(BuildContext context, SavingsVault vault) {
    showDialog(
      context: context,
      builder: (_) => _VaultAmountDialog(vault: vault, isDeposit: true),
    );
  }

  void _showWithdrawDialog(BuildContext context, SavingsVault vault) {
    showDialog(
      context: context,
      builder: (_) => _VaultAmountDialog(vault: vault, isDeposit: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vaultProvider = context.watch<SavingsVaultProvider>();
    final vaults = vaultProvider.activeVaults;

    return AppBottomSheetContainer(
      title: 'Savings Vaults & Goals',
      subtitle: '${vaults.length} active savings goals',
      trailing: FilledButton.tonalIcon(
        onPressed: () => SavingsVaultSheet.show(context),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('New Vault'),
      ),
      child: vaults.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.savings_outlined, size: 48, color: colorScheme.outline),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No Savings Vaults Yet',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Create goal envelopes to protect your emergency funds and savings.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => SavingsVaultSheet.show(context),
                      child: const Text('Create First Vault'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vaults.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final vault = vaults[index];
                final progress = vault.progressRatio;
                final vaultColor = Color(vault.colorValue);

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: vaultColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CuratedIconsCatalog.resolveCodePoint(vault.iconCodePoint),
                                  color: vaultColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vault.name,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    vault.targetDate != null
                                        ? 'Target: ${vault.targetDate!.day}/${vault.targetDate!.month}/${vault.targetDate!.year}'
                                        : 'No deadline',
                                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                SavingsVaultSheet.show(context, existingVault: vault);
                              } else if (val == 'delete') {
                                if (vault.currentPaise > 0) {
                                  SnackbarFeedback.showError(
                                    context,
                                    'Cannot delete "${vault.name}" while ${CurrencyFormatter.format(vault.currentPaise)} is locked inside.',
                                    guidance: 'Tap Withdraw to release the reserved funds back into your account before deleting.',
                                  );
                                  return;
                                }
                                final ok = await ConfirmationDialog.show(
                                  context,
                                  title: 'Delete Vault?',
                                  message: 'Are you sure you want to delete "${vault.name}"?',
                                  confirmLabel: 'Delete',
                                  isDestructive: true,
                                );
                                if (ok && context.mounted) {
                                  try {
                                    await vaultProvider.deleteVault(vault.id);
                                    if (context.mounted) {
                                      SnackbarFeedback.showSuccess(
                                        context,
                                        'Vault "${vault.name}" deleted.',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      SnackbarFeedback.showError(
                                        context,
                                        e,
                                        operation: FeedbackOperation.deleteVault,
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit Vault')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete Vault')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: vaultColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(vaultColor),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Balance labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${CurrencyFormatter.format(vault.currentPaise)} / ${CurrencyFormatter.format(vault.targetPaise)}',
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: vaultColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Action Chips: Deposit and Withdraw
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.arrow_upward, size: 14),
                            label: const Text('Withdraw'),
                            onPressed: vault.currentPaise > 0 ? () => _showWithdrawDialog(context, vault) : null,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.arrow_downward, size: 14),
                            label: const Text('Deposit'),
                            onPressed: () => _showDepositDialog(context, vault),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _VaultAmountDialog extends StatefulWidget {
  final SavingsVault vault;
  final bool isDeposit;

  const _VaultAmountDialog({
    required this.vault,
    required this.isDeposit,
  });

  @override
  State<_VaultAmountDialog> createState() => _VaultAmountDialogState();
}

class _VaultAmountDialogState extends State<_VaultAmountDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = InputValidators.validateAmount(
      _controller.text,
      fieldLabel: widget.isDeposit ? 'Deposit amount' : 'Withdrawal amount',
      maxPaiseLimit: widget.isDeposit ? null : widget.vault.currentPaise,
      maxPaiseLimitLabel: widget.isDeposit ? null : 'vault balance',
    );

    if (!result.isValid) {
      setState(() => _errorText = result.errorMessage);
      return;
    }

    final paise = result.paise!;
    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final provider = context.read<SavingsVaultProvider>();
    final ok = widget.isDeposit
        ? await provider.deposit(widget.vault.id, paise)
        : await provider.withdraw(widget.vault.id, paise);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      SnackbarFeedback.showSuccess(
        context,
        widget.isDeposit
            ? 'Deposited ${CurrencyFormatter.format(paise)} into "${widget.vault.name}".'
            : 'Released ${CurrencyFormatter.format(paise)} from "${widget.vault.name}" to spendable funds.',
      );
      Navigator.pop(context);
    } else {
      SnackbarFeedback.showError(
        context,
        provider.lastError ?? provider.errorMessage ?? 'Operation could not complete.',
        operation: widget.isDeposit
            ? FeedbackOperation.depositVault
            : FeedbackOperation.withdrawVault,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isDeposit
            ? 'Deposit to ${widget.vault.name}'
            : 'Withdraw from ${widget.vault.name}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isDeposit
                ? 'Reserve funds from your backing account into this vault.'
                : 'Release reserved funds back into your spendable balance.',
          ),
          const SizedBox(height: AppSpacing.md),
          BudgoAmountField(
            controller: _controller,
            autofocus: true,
            errorText: _errorText,
            helperText: widget.isDeposit
                ? null
                : 'Available: ${CurrencyFormatter.format(widget.vault.currentPaise)}',
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
        ],
      ),
      actions: [
        BudgoButton(
          label: 'Cancel',
          variant: BudgoButtonVariant.text,
          expanded: false,
          height: 44,
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        BudgoButton(
          label: widget.isDeposit ? 'Deposit' : 'Withdraw',
          expanded: false,
          height: 44,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
