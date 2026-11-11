import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/registries/category_registry.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/account_type.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/providers/account_provider.dart';
import 'package:expense/providers/app_preferences_provider.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/providers/expenses_provider.dart';
import 'package:expense/providers/income_provider.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/core/constants/app_constants.dart';

enum TransactionMode { expense, income }

class TransactionBottomSheet extends StatefulWidget {
  final TransactionMode mode;
  final Expense? existingExpense;
  final Income? existingIncome;

  const TransactionBottomSheet({
    super.key,
    required this.mode,
    this.existingExpense,
    this.existingIncome,
  });

  static void show(
    BuildContext context, {
    required TransactionMode mode,
    Expense? existingExpense,
    Income? existingIncome,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionBottomSheet(
        mode: mode,
        existingExpense: existingExpense,
        existingIncome: existingIncome,
      ),
    );
  }

  @override
  State<TransactionBottomSheet> createState() => _TransactionBottomSheetState();
}

class _TransactionBottomSheetState extends State<TransactionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'UPI';
  String _selectedSource = 'Salary';
  String? _selectedAccountId;
  bool _isConfirmed = true;

  String? _amountError;
  String? _nameError;
  bool _isSaving = false;

  late final List<String> _categories =
      CategoryRegistry.allExpenses.map((c) => c.label).toList();
  late final List<String> _sources =
      CategoryRegistry.allIncomes.map((c) => c.label).toList();

  @override
  void initState() {
    super.initState();
    if (widget.mode == TransactionMode.expense &&
        widget.existingExpense != null) {
      final e = widget.existingExpense!;
      final val = e.amount / 100.0;
      _amountController.text = val % 1 == 0
          ? val.toInt().toString()
          : val.toString();
      _nameController.text = e.productName;
      _selectedDate = e.date;
      _selectedCategory = e.category;
      _selectedPaymentMethod = e.paymentMethod;
      _selectedAccountId = e.accountId;
    } else if (widget.mode == TransactionMode.income &&
        widget.existingIncome != null) {
      final i = widget.existingIncome!;
      final val = i.amount / 100.0;
      _amountController.text = val % 1 == 0
          ? val.toInt().toString()
          : val.toString();
      _nameController.text = i.description ?? '';
      _selectedDate = i.date;
      _selectedSource = _sources.contains(i.source) ? i.source : 'Other';
      _isConfirmed = i.isConfirmed;
      _selectedAccountId = i.accountId;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final catProvider = context.read<CategoryProvider>();
        final activeCategories = catProvider.categories.map((c) => c.name).toList();
        if (activeCategories.isNotEmpty && widget.existingExpense == null) {
          setState(() {
            _selectedCategory = activeCategories.first;
          });
        }

        if (_selectedAccountId == null) {
          final accountProvider = context.read<AccountProvider>();
          final accounts = accountProvider.activeAccounts;
          Account? match;

          if (widget.mode == TransactionMode.income) {
            match = accounts.firstWhereOrNull((a) => a.type == AccountType.bankAccount) ??
                accounts.firstWhereOrNull((a) => a.type == AccountType.upi);
          } else {
            final prefsProvider = context.read<AppPreferencesProvider>();
            final preferred = prefsProvider.defaultPaymentMethod.toLowerCase();
            if (preferred.contains('upi')) {
              match = accounts.firstWhereOrNull((a) => a.type == AccountType.upi);
            } else if (preferred.contains('bank')) {
              match = accounts.firstWhereOrNull((a) => a.type == AccountType.bankAccount);
            } else if (preferred.contains('cash')) {
              match = accounts.firstWhereOrNull((a) => a.type == AccountType.cash);
            }
          }

          final target = match ?? accountProvider.defaultAccount ?? (accounts.isNotEmpty ? accounts.first : null);

          if (target != null) {
            setState(() {
              _selectedAccountId = target.id;
              _selectedPaymentMethod = target.type == AccountType.upi
                  ? 'UPI'
                  : (target.type == AccountType.cash ? 'Cash' : 'Bank');
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateAmount(String value) {
    final result = InputValidators.validateAmount(value);
    setState(() {
      _amountError = result.errorMessage;
    });
  }

  void _validateName(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _nameError = widget.mode == TransactionMode.expense
            ? 'Product name is required'
            : 'Description is required';
      } else {
        _nameError = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  void _save() async {
    _validateAmount(_amountController.text);
    _validateName(_nameController.text);

    if (_amountError != null || _nameError != null) return;

    setState(() => _isSaving = true);

    final amountRupees = double.parse(_amountController.text);
    final amount = (amountRupees * 100).round();
    final name = _nameController.text.trim();

    final wsProvider = context.read<WorkspaceProvider>();
    final accountProvider = context.read<AccountProvider>();
    final expensesProvider = context.read<ExpensesProvider>();
    final incomeProvider = context.read<IncomeProvider>();
    final wsId = wsProvider.activeWorkspaceId;
    final accId = _selectedAccountId ?? AppConstants.kCashAccountId;
    final selectedAcc = accountProvider.activeAccounts.firstWhereOrNull((a) => a.id == accId);
    final derivedPaymentMethod = selectedAcc != null
        ? (selectedAcc.type == AccountType.upi
            ? 'UPI'
            : (selectedAcc.type == AccountType.cash ? 'Cash' : 'Bank'))
        : _selectedPaymentMethod;

    try {
      await AtomicWriter.instance.execute(() async {
        if (widget.mode == TransactionMode.expense) {
          if (widget.existingExpense != null) {
            final updated = widget.existingExpense!;
            final oldAmount = updated.amount;
            final oldAccId = updated.accountId;

            updated.productName = name;
            updated.amount = amount;
            updated.category = _selectedCategory;
            updated.date = _selectedDate;
            updated.paymentMethod = derivedPaymentMethod;
            updated.accountId = accId;
            await expensesProvider.updateExpense(updated);

            // Adjust account balances
            if (oldAccId == accId) {
              await accountProvider.updateBalance(accId, oldAmount - amount);
            } else {
              await accountProvider.updateBalance(oldAccId, oldAmount);
              await accountProvider.updateBalance(accId, -amount);
            }
          } else {
            final expense = Expense(
              productName: name,
              amount: amount,
              category: _selectedCategory,
              date: _selectedDate,
              paymentMethod: derivedPaymentMethod,
              workspaceId: wsId,
              accountId: accId,
            );
            await expensesProvider.addExpense(expense);
            await accountProvider.updateBalance(accId, -amount);
          }
        } else {
          final incomeAccId = _selectedAccountId ?? AppConstants.kBankAccountId;
          if (widget.existingIncome != null) {
            final updated = widget.existingIncome!;
            final oldAmount = updated.amount;
            final oldConfirmed = updated.isConfirmed;
            final oldAccId = updated.accountId;

            updated.source = _selectedSource;
            updated.amount = amount;
            updated.date = _selectedDate;
            updated.description = name;
            updated.isConfirmed = _isConfirmed;
            updated.accountId = incomeAccId;
            await incomeProvider.updateIncome(updated);

            // Balance adjustment if confirmed
            if (oldConfirmed && !_isConfirmed) {
              await accountProvider.updateBalance(oldAccId, -oldAmount);
            } else if (!oldConfirmed && _isConfirmed) {
              await accountProvider.updateBalance(incomeAccId, amount);
            } else if (_isConfirmed) {
              if (oldAccId == incomeAccId) {
                await accountProvider.updateBalance(incomeAccId, amount - oldAmount);
              } else {
                await accountProvider.updateBalance(oldAccId, -oldAmount);
                await accountProvider.updateBalance(incomeAccId, amount);
              }
            }
          } else {
            final income = Income(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              source: _selectedSource,
              amount: amount,
              date: _selectedDate,
              description: name,
              isConfirmed: _isConfirmed,
              workspaceId: wsId,
              accountId: incomeAccId,
            );
            await incomeProvider.addIncome(income);
            if (_isConfirmed) {
              await accountProvider.updateBalance(incomeAccId, amount);
            }
          }
        }
      });

      if (mounted) {
        SnackbarFeedback.showSuccess(context, 'Transaction saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.saveTransaction,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAccountSelectorSection(BuildContext context, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium(context)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Consumer<AccountProvider>(
          builder: (context, accProvider, _) {
            final accounts = accProvider.activeAccounts.take(4).toList();
            if (accounts.isEmpty) return const SizedBox.shrink();
            return BudgoChoiceGroup<String>(
              selectedValue: _selectedAccountId,
              options: accounts.map((acc) {
                return BudgoChoiceOption<String>(
                  value: acc.id,
                  label: acc.name,
                  icon: AccountIcons.forType(acc.type),
                  accentColor: Color(acc.colorValue),
                );
              }).toList(),
              onSelected: (accountId) {
                final acc = accounts.firstWhere((a) => a.id == accountId);
                setState(() {
                  _selectedAccountId = acc.id;
                  _selectedPaymentMethod = acc.type == AccountType.upi
                      ? 'UPI'
                      : (acc.type == AccountType.cash ? 'Cash' : 'Bank');
                });
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit =
        widget.existingExpense != null || widget.existingIncome != null;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) {
          SnackbarFeedback.showInfo(context, 'Saving in progress...');
        }
      },
      child: BudgoBottomSheet(
        title: isEdit
            ? 'Edit ${widget.mode == TransactionMode.expense ? 'Expense' : 'Income'}'
            : 'Add ${widget.mode == TransactionMode.expense ? 'Expense' : 'Income'}',
        icon: widget.mode == TransactionMode.expense
            ? Icons.shopping_bag_outlined
            : Icons.south_west_rounded,
        footer: BudgoButton(
          label: isEdit ? 'Save Changes' : 'Add Transaction',
          isLoading: _isSaving,
          onPressed: _save,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount Numeric Field
                BudgoAmountField(
                  controller: _amountController,
                  autofocus: !isEdit,
                  errorText: _amountError,
                  onChanged: _validateAmount,
                ),
                const SizedBox(height: AppSpacing.md),

                // Product Name or Source description Field
                BudgoTextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  inputPolicy: BudgoInputPolicy.transactionTitle,
                  label: widget.mode == TransactionMode.expense
                      ? 'Expense Title'
                      : 'Income Source / Title',
                  hint: widget.mode == TransactionMode.expense
                      ? BudgoInputGuidance.expenseHint(_selectedCategory)
                      : BudgoInputGuidance.incomeHint(_selectedSource),
                  prefixIcon: widget.mode == TransactionMode.expense
                      ? Icons.shopping_bag_outlined
                      : Icons.description_outlined,
                  errorText: _nameError,
                  onChanged: _validateName,
                ),
                const SizedBox(height: AppSpacing.md),

                // Date Picker Field
                BudgoPickerField(
                  icon: Icons.calendar_today_rounded,
                  label: 'Transaction Date',
                  value: DateFormat('MMMM d, yyyy').format(_selectedDate),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Mode Specific Content
                if (widget.mode == TransactionMode.expense) ...[
                  Text(
                    'Category',
                    style: AppTextStyles.labelMedium(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Consumer<CategoryProvider>(
                    builder: (context, catProvider, _) {
                      final allCats =
                          catProvider.categories.map((c) => c.name).toList();
                      final categoriesList =
                          allCats.isNotEmpty ? allCats : _categories;

                      return BudgoChoiceGroup<String>(
                        selectedValue: _selectedCategory,
                        maxVisibleCount: 4,
                        options: categoriesList.map((cat) {
                          return BudgoChoiceOption<String>(
                            value: cat,
                            label: cat,
                            icon: cat.categoryStateIcon(isSelected: false),
                            selectedIcon:
                                cat.categoryStateIcon(isSelected: true),
                          );
                        }).toList(),
                        onSelected: (cat) =>
                            setState(() => _selectedCategory = cat),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildAccountSelectorSection(context, 'Payment Method'),
                ] else ...[
                  Text(
                    'Income Source',
                    style: AppTextStyles.labelMedium(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BudgoChoiceGroup<String>(
                    selectedValue: _selectedSource,
                    options: _sources.map((src) {
                      return BudgoChoiceOption<String>(
                        value: src,
                        label: src,
                        icon: src.categoryIcon,
                      );
                    }).toList(),
                    onSelected: (src) => setState(() => _selectedSource = src),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildAccountSelectorSection(context, 'Deposit To Account'),
                  const SizedBox(height: AppSpacing.md),
                  BudgoSwitchTile(
                    title: 'Confirm Immediately',
                    subtitle: 'Include in active budget snapshot',
                    icon: Icons.verified_outlined,
                    value: _isConfirmed,
                    onChanged: (val) => setState(() => _isConfirmed = val),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
