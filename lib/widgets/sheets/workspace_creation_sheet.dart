import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/workspace_provider.dart';

class WorkspaceCreationSheet extends StatefulWidget {
  const WorkspaceCreationSheet({super.key});

  @override
  State<WorkspaceCreationSheet> createState() => _WorkspaceCreationSheetState();
}

class _WorkspaceCreationSheetState extends State<WorkspaceCreationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _initialBalanceController = TextEditingController(text: '0');

  WorkspaceType _selectedType = WorkspaceType.personal;
  String _selectedCurrency = '₹';
  int _selectedColor = 0xFF2196F3;
  int _selectedIcon = 0xe491;

  final List<String> _currencies = ['₹', '\$', '€', '£'];

  final List<int> _colors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFFE91E63, // Pink
    0xFF009688, // Teal
    0xFF607D8B, // Blue Grey
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  void _onTypeChanged(WorkspaceType type) {
    setState(() {
      _selectedType = type;
      if (type == WorkspaceType.trip) {
        _initialBalanceController.text = '0';
      }
      _selectedIcon = WorkspaceIcons.forType(type).codePoint;
      _selectedColor = WorkspaceIcons.defaultColorForType(type).toARGB32();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final name = _nameController.text.trim();
      final double enteredVal = double.tryParse(_initialBalanceController.text.trim()) ?? 0.0;
      final int initialPaise = (enteredVal * 100).round();

      final newWs = await context.read<WorkspaceProvider>().createWorkspace(
        name: name,
        type: _selectedType,
        currency: _selectedCurrency,
        initialBalance: initialPaise,
        iconCodePoint: _selectedIcon,
        colorValue: _selectedColor,
      );

      // Provision standard accounts (Cash Wallet / Trip Wallet, Bank Account, UPI / GPay)
      final accName = _selectedType == WorkspaceType.trip ? 'Trip Cash Wallet' : 'Cash Wallet';
      if (mounted) {
        await context.read<AccountProvider>().ensureStandardAccountsForWorkspace(
          newWs.id,
          initialCashPaise: initialPaise,
          cashAccountName: accName,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        SnackbarFeedback.showSuccess(context, 'Workspace "$name" created.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.createWorkspace,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BudgoBottomSheet(
      title: 'New Workspace',
      subtitle: 'Create a separate financial profile',
      icon: WorkspaceIcons.forType(_selectedType),
      iconColor: Color(_selectedColor),
      footer: BudgoButton(
        label: 'Create Workspace',
        icon: Icons.add_rounded,
        onPressed: _submit,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BudgoTextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                label: 'Workspace Name',
                hint: BudgoInputGuidance.workspaceHint(_selectedType),
                inputPolicy: BudgoInputPolicy.workspaceName,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a workspace name';
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
              const SizedBox(height: AppSpacing.base),

              // Workspace Type selector
              Text('Workspace Type', style: AppTextStyles.labelMedium(context)),
              const SizedBox(height: AppSpacing.xs),
              BudgoChoiceGroup<WorkspaceType>(
                selectedValue: _selectedType,
                options: WorkspaceType.values
                    .map(
                      (type) => BudgoChoiceOption<WorkspaceType>(
                        value: type,
                        label: type.name[0].toUpperCase() +
                            type.name.substring(1),
                        icon: WorkspaceIcons.forType(type),
                      ),
                    )
                    .toList(),
                onSelected: _onTypeChanged,
              ),

              if (_selectedType == WorkspaceType.trip) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: colorScheme.tertiary),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Trip Mode: Starts with zero funds. Unspent balances can be swept back when the trip ends.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.base),

              // Initial / Starting Balance Input
              BudgoTextField(
                controller: _initialBalanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                maxLength: AppInputLimits.amountInputMaxChars,
                showCounter: false,
                inputFormatters: AppInputLimits.decimalAmountFormatters,
                label: 'Initial / Starting Balance',
                hint: 'Enter opening balance (leave 0 if unfunded)',
                prefixText: '$_selectedCurrency ',
                helperText: _selectedType == WorkspaceType.trip
                    ? 'Trip profiles usually start at 0 and are funded via Self-Transfer.'
                    : 'Initial opening capital for this profile.',
                prefixIcon: Icons.account_balance_wallet_outlined,
              ),

              const SizedBox(height: AppSpacing.base),

              // Currency Selector
              Text('Currency', style: AppTextStyles.labelMedium(context)),
              const SizedBox(height: AppSpacing.xs),
              BudgoChoiceGroup<String>(
                selectedValue: _selectedCurrency,
                options: _currencies
                    .map((c) => BudgoChoiceOption(value: c, label: c))
                    .toList(),
                onSelected: (curr) => setState(() => _selectedCurrency = curr),
              ),

              const SizedBox(height: AppSpacing.base),

              // Color Palette
              Text('Profile Color', style: AppTextStyles.labelMedium(context)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colors.map((c) {
                  final isSelected = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: colorScheme.onSurface, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
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
