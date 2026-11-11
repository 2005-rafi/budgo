import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/savings_vault_provider.dart';
import 'package:expense/providers/workspace_provider.dart';

class SavingsVaultSheet extends StatefulWidget {
  final SavingsVault? existingVault;

  const SavingsVaultSheet({super.key, this.existingVault});

  static void show(BuildContext context, {SavingsVault? existingVault}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavingsVaultSheet(existingVault: existingVault),
    );
  }

  @override
  State<SavingsVaultSheet> createState() => _SavingsVaultSheetState();
}

class _SavingsVaultSheetState extends State<SavingsVaultSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();

  String? _selectedParentAccountId;
  DateTime? _selectedTargetDate;
  int _selectedColorValue = 0xFF4CAF50;
  int _selectedIconCodePoint = Icons.savings_outlined.codePoint;
  bool _isSaving = false;

  static const List<int> _colorPalette = [
    0xFF4CAF50, // Green
    0xFF2196F3, // Blue
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFFE91E63, // Pink
    0xFF009688, // Teal
    0xFF3F51B5, // Indigo
    0xFF795548, // Brown
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingVault != null) {
      final v = widget.existingVault!;
      _nameController.text = v.name;
      _targetController.text = (v.targetPaise / 100.0).toStringAsFixed(0);
      _selectedParentAccountId = v.parentAccountId;
      _selectedTargetDate = v.targetDate;
      _selectedColorValue = v.colorValue;
      _selectedIconCodePoint = v.iconCodePoint;
    } else {
      final accProvider = context.read<AccountProvider>();
      final bank = accProvider.activeAccounts.firstWhereOrNull((a) => a.type == AccountType.bankAccount) ??
          accProvider.defaultAccount;
      _selectedParentAccountId = bank?.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParentAccountId == null) {
      SnackbarFeedback.showError(
        context,
        'Please select a backing account.',
        guidance: 'Choose which account this vault reserves funds from.',
      );
      return;
    }

    final amountValidation = InputValidators.validateAmount(
      _targetController.text,
      fieldLabel: 'Target amount',
    );
    if (!amountValidation.isValid) {
      SnackbarFeedback.showError(context, amountValidation.errorMessage!);
      return;
    }
    final targetPaise = amountValidation.paise!;

    setState(() => _isSaving = true);

    try {
      final wsId = context.read<WorkspaceProvider>().activeWorkspaceId;
      final vaultProvider = context.read<SavingsVaultProvider>();

      if (widget.existingVault != null) {
        final updated = widget.existingVault!.copyWith(
          name: _nameController.text.trim(),
          parentAccountId: _selectedParentAccountId,
          targetPaise: targetPaise,
          targetDate: _selectedTargetDate,
          colorValue: _selectedColorValue,
          iconCodePoint: _selectedIconCodePoint,
        );
        await vaultProvider.updateVault(updated);
      } else {
        final newVault = SavingsVault(
          id: const Uuid().v4(),
          workspaceId: wsId,
          parentAccountId: _selectedParentAccountId!,
          name: _nameController.text.trim(),
          targetPaise: targetPaise,
          currentPaise: 0,
          targetDate: _selectedTargetDate,
          iconCodePoint: _selectedIconCodePoint,
          colorValue: _selectedColorValue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await vaultProvider.addVault(newVault);
      }

      if (mounted) {
        SnackbarFeedback.showSuccess(
          context,
          widget.existingVault != null ? 'Vault updated.' : 'Savings vault created.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(context, e, operation: FeedbackOperation.saveVault);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accProvider = context.watch<AccountProvider>();
    final eligibleAccounts = accProvider.activeAccounts
        .where((a) =>
            a.type == AccountType.bankAccount ||
            a.type == AccountType.cash ||
            a.type == AccountType.upi)
        .toList();

    return BudgoBottomSheet(
      title: widget.existingVault != null ? 'Edit Savings Vault' : 'New Savings Vault',
      subtitle: 'Earmark reserve funds toward your goals',
      icon: Icons.savings_outlined,
      footer: BudgoButton(
        label: widget.existingVault != null ? 'Update Vault' : 'Create Vault',
        isLoading: _isSaving,
        onPressed: _save,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              BudgoTextField(
                controller: _nameController,
                inputPolicy: BudgoInputPolicy.vaultName,
                label: 'Vault Name',
                hint: BudgoInputGuidance.vaultHint(widget.existingVault?.isLocked ?? false),
                prefixIcon: Icons.label_outline_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Enter a vault name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              BudgoAmountField(
                controller: _targetController,
                label: 'Target Goal Amount',
                validator: (val) {
                  final n = double.tryParse(val ?? '');
                  if (n == null || n <= 0) return 'Enter a valid target amount';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'Backing Account (Funds reserved from)',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              BudgoDropdownField<String>(
                value: _selectedParentAccountId,
                options: eligibleAccounts
                    .map(
                      (a) => BudgoDropdownItem<String>(
                        value: a.id,
                        label: a.name,
                        icon: AccountIcons.forType(a.type),
                        iconColor: Color(a.colorValue),
                        trailingText:
                            'Free: ${CurrencyFormatter.formatCompact(a.balancePaise)}',
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedParentAccountId = val);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),

              BudgoPickerField(
                icon: Icons.calendar_today_outlined,
                label: 'Target Deadline',
                value: _selectedTargetDate != null
                    ? '${_selectedTargetDate!.day}/${_selectedTargetDate!.month}/${_selectedTargetDate!.year}'
                    : 'No deadline set — tap to choose',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedTargetDate ??
                        DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setState(() => _selectedTargetDate = picked);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'Vault Color',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: _colorPalette.map((c) {
                  final selected = _selectedColorValue == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorValue = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Color(c).withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
