import 'package:expense/core/atomic_writer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';
import 'package:expense/widgets/snackbar_feedback.dart';
import 'package:expense/widgets/common/app_filter_chip.dart';
import 'package:expense/core/money.dart';
import 'package:expense/core/app_constants.dart';

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
  String _selectedSource = 'Salary';
  bool _isConfirmed = true;

  String? _amountError;
  String? _nameError;
  bool _isSaving = false;

  final List<String> _categories = [
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Lend',
    'Entertainment',
    'Health',
    'Education',
    'Other',
  ];
  final List<String> _sources = ['Salary', 'Freelance', 'Gift', 'Other'];

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
      _selectedCategory = _categories.contains(e.category)
          ? e.category
          : 'Other';
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
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateAmount(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _amountError = 'Amount is required';
      } else {
        final parsed = double.tryParse(value);
        if (parsed == null || parsed <= 0) {
          _amountError = 'Enter a valid positive number';
        } else if ((parsed * 100).round() > AppConstants.kMaxAmount) {
          _amountError = 'Amount cannot exceed ${MoneyFormatter.symbol}10,00,000';
        } else {
          final parts = value.trim().split('.');
          if (parts.length > 1 && parts[1].length > 2) {
            _amountError = 'Up to 2 decimal places allowed';
          } else {
            _amountError = null;
          }
        }
      }
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

    try {
      await AtomicWriter.instance.execute(() async {
        if (widget.mode == TransactionMode.expense) {
          final expensesProvider = context.read<ExpensesProvider>();
          if (widget.existingExpense != null) {
            final updated = widget.existingExpense!;
            updated.productName = name;
            updated.amount = amount;
            updated.category = _selectedCategory;
            updated.date = _selectedDate;
            await expensesProvider.updateExpense(updated);
          } else {
            final expense = Expense(
              productName: name,
              amount: amount,
              category: _selectedCategory,
              date: _selectedDate,
            );
            await expensesProvider.addExpense(expense);
          }
        } else {
          final incomeProvider = context.read<IncomeProvider>();
          if (widget.existingIncome != null) {
            final updated = widget.existingIncome!;
            updated.source = _selectedSource;
            updated.amount = amount;
            updated.date = _selectedDate;
            updated.description = name;
            updated.isConfirmed = _isConfirmed;
            await incomeProvider.updateIncome(updated);
          } else {
            final income = Income(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              source: _selectedSource,
              amount: amount,
              date: _selectedDate,
              description: name,
              isConfirmed: _isConfirmed,
            );
            await incomeProvider.addIncome(income);
          }
        }
      });

      if (mounted) {
        SnackbarFeedback.showSuccess(context, 'Transaction saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(context, 'Failed to save transaction: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
      child: Container(
        decoration: BoxDecoration(
          color: BudgoColors.bottomSheetSurface(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        padding: EdgeInsets.only(
          left: AppSpacing.base,
          right: AppSpacing.base,
          top: AppSpacing.xl,
          bottom: AppSpacing.xl + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header line handle
                Center(
                  child: Container(
                    width: 32.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Title
                Text(
                  isEdit
                      ? 'Edit ${widget.mode == TransactionMode.expense ? 'Expense' : 'Income'}'
                      : 'Add ${widget.mode == TransactionMode.expense ? 'Expense' : 'Income'}',
                  style: AppTextStyles.headline(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold, fontSize: 20.0),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Amount Numeric Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !isEdit,
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount (${MoneyFormatter.symbol})',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: const OutlineInputBorder(),
                    errorText: _amountError,
                  ),
                  onChanged: _validateAmount,
                ),
                const SizedBox(height: AppSpacing.md),

                // Product Name or Source description Field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.mode == TransactionMode.expense
                        ? 'Expense Title (e.g. Uber Ride)'
                        : 'Description (e.g. Monthly Salary)',
                    prefixIcon: Icon(
                      widget.mode == TransactionMode.expense
                          ? Icons.shopping_bag_outlined
                          : Icons.description_outlined,
                    ),
                    border: const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                  onChanged: _validateName,
                ),
                const SizedBox(height: AppSpacing.md),

                // Date Picker Button Row
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Date: ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.base,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Mode Specific Content
                if (widget.mode == TransactionMode.expense) ...[
                  Text(
                    'Category',
                    style: AppTextStyles.label(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _categories.map((cat) {
                      final selected = _selectedCategory == cat;
                      return AppFilterChip(
                        label: cat,
                        selected: selected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                ] else ...[
                  Text(
                    'Income Source',
                    style: AppTextStyles.label(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _sources.map((src) {
                      final selected = _selectedSource == src;
                      return AppFilterChip(
                        label: src,
                        selected: selected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedSource = src);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    title: const Text('Confirm Immediately'),
                    subtitle: const Text('Include in active budget snapshot'),
                    value: _isConfirmed,
                    onChanged: (val) => setState(() => _isConfirmed = val),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),

                // Save Button
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.base,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20.0,
                          width: 20.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Add Transaction'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
