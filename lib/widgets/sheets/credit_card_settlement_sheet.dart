import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/transfer_provider.dart';

class CreditCardSettlementSheet extends StatefulWidget {
  final Account creditCard;

  const CreditCardSettlementSheet({
    super.key,
    required this.creditCard,
  });

  static void show(BuildContext context, Account creditCard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreditCardSettlementSheet(creditCard: creditCard),
    );
  }

  @override
  State<CreditCardSettlementSheet> createState() => _CreditCardSettlementSheetState();
}

class _CreditCardSettlementSheetState extends State<CreditCardSettlementSheet> {
  final _amountController = TextEditingController();
  String? _selectedSourceAccountId;
  bool _isPaying = false;
  int _selectedOption = 0; // 0: Full, 1: Available, 2: Custom

  int get _outstandingDebt => widget.creditCard.balancePaise.abs();

  @override
  void initState() {
    super.initState();
    final accProvider = context.read<AccountProvider>();
    final bank = accProvider.activeAccounts.firstWhereOrNull((a) => a.type == AccountType.bankAccount) ??
        accProvider.defaultAccount;
    _selectedSourceAccountId = bank?.id;

    _amountController.text = (_outstandingDebt / 100.0).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onOptionSelected(int option, int bankBalance) {
    setState(() {
      _selectedOption = option;
      if (option == 0) {
        _amountController.text = (_outstandingDebt / 100.0).toStringAsFixed(2);
      } else if (option == 1) {
        final amount = bankBalance > 0 ? (bankBalance > _outstandingDebt ? _outstandingDebt : bankBalance) : 0;
        _amountController.text = (amount / 100.0).toStringAsFixed(2);
      }
    });
  }

  void _executeSettlement() async {
    final validation = InputValidators.validateAmount(
      _amountController.text,
      fieldLabel: 'Payment amount',
    );
    if (!validation.isValid) {
      SnackbarFeedback.showError(context, validation.errorMessage!);
      return;
    }

    final amountPaise = validation.paise!;
    if (_selectedSourceAccountId == null) {
      SnackbarFeedback.showError(
        context,
        'Please select a funding account.',
        guidance: 'Choose a Bank, UPI, or Cash account to pay this credit card bill.',
      );
      return;
    }

    setState(() => _isPaying = true);

    try {
      final transferProvider = context.read<TransferProvider>();
      await transferProvider.executeTransfer(
        sourceAccountId: _selectedSourceAccountId!,
        destinationAccountId: widget.creditCard.id,
        amountPaise: amountPaise,
        note: 'Credit Card Bill Settlement (${widget.creditCard.name})',
      );

      if (!mounted) return;

      SnackbarFeedback.showSuccess(
        context,
        'Settled ${CurrencyFormatter.format(amountPaise)} towards ${widget.creditCard.name}.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.settleCreditCard,
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accProvider = context.watch<AccountProvider>();

    final liquidAccounts = accProvider.activeAccounts
        .where((a) => a.id != widget.creditCard.id && a.type != AccountType.creditCard)
        .toList();

    final sourceAccount = liquidAccounts.firstWhereOrNull((a) => a.id == _selectedSourceAccountId);
    final sourceBalance = sourceAccount?.balancePaise ?? 0;

    return AppBottomSheetContainer(
      title: 'Pay Credit Card Bill',
      subtitle: widget.creditCard.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Outstanding Debt Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Balance',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(_outstandingDebt),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.credit_card_rounded,
                  color: colorScheme.onErrorContainer,
                  size: 36,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Funding Source Dropdown
          Text(
            'Pay From',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          BudgoDropdownField<String>(
            value: _selectedSourceAccountId,
            options: liquidAccounts
                .map(
                  (a) => BudgoDropdownItem<String>(
                    value: a.id,
                    label: a.name,
                    icon: AccountIcons.forType(a.type),
                    iconColor: Color(a.colorValue),
                    trailingText: CurrencyFormatter.format(a.balancePaise),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedSourceAccountId = val);
              }
            },
          ),
          const SizedBox(height: AppSpacing.base),

          // Triage Settlement Options
          Text(
            'Settlement Options',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          BudgoChoiceGroup<int>(
            selectedValue: _selectedOption,
            options: [
              const BudgoChoiceOption(value: 0, label: 'Total Due'),
              if (sourceBalance < _outstandingDebt && sourceBalance > 0)
                BudgoChoiceOption(
                  value: 1,
                  label: 'Pay Available (${CurrencyFormatter.format(sourceBalance)})',
                ),
              const BudgoChoiceOption(value: 2, label: 'Custom Amount'),
            ],
            onSelected: (opt) {
              if (opt == 2) {
                setState(() => _selectedOption = 2);
              } else {
                _onOptionSelected(opt, sourceBalance);
              }
            },
          ),
          const SizedBox(height: AppSpacing.base),

          // Custom/Editable Amount Input
          BudgoAmountField(
            controller: _amountController,
            label: 'Payment Amount',
            readOnly: _selectedOption != 2,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Action Button
          BudgoButton(
            label: _isPaying ? 'Processing...' : 'Pay Bill Now',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isPaying,
            onPressed: _executeSettlement,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
