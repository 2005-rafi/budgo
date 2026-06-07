import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/widgets/inline_validation_message.dart';
import 'package:expense/widgets/snackbar_feedback.dart';
import 'package:expense/widgets/common/app_filter_chip.dart';
import 'package:expense/core/money.dart';
import 'package:expense/core/app_constants.dart';

class WishlistItemSheet extends StatefulWidget {
  final FutureExpense? existingItem;

  const WishlistItemSheet({super.key, this.existingItem});

  static void show(BuildContext context, {FutureExpense? existingItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WishlistItemSheet(existingItem: existingItem),
    );
  }

  @override
  State<WishlistItemSheet> createState() => _WishlistItemSheetState();
}

class _WishlistItemSheetState extends State<WishlistItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dueDate;
  int _priority = 1; // 0 = low, 1 = medium, 2 = high
  String _selectedCategory = 'Food';

  bool _titleTouched = false;
  String? _titleError;
  bool _isSaving = false;

  final List<String> _categories = [
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Entertainment',
    'Health',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _titleController.text = item.title;
      if (item.estimatedCost != null) {
        final val = item.estimatedCost! / 100.0;
        _costController.text = val % 1 == 0
            ? val.toInt().toString()
            : val.toString();
      } else {
        _costController.text = '';
      }
      _notesController.text = item.notes ?? '';
      _dueDate = item.dueDate;
      _priority = item.priority;
      _selectedCategory = _categories.contains(item.category)
          ? item.category
          : 'Other';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateTitle() {
    if (!_titleTouched) return;
    setState(() {
      if (_titleController.text.trim().isEmpty) {
        _titleError = 'Title is required';
      } else {
        _titleError = null;
      }
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _save() async {
    setState(() {
      _titleTouched = true;
    });
    _validateTitle();

    if (_titleError != null) return;

    setState(() => _isSaving = true);

    final costText = _costController.text.trim();
    double? costRupees;
    int? cost;
    if (costText.isNotEmpty) {
      costRupees = double.tryParse(costText);
      if (costRupees == null || costRupees <= 0) {
        SnackbarFeedback.showError(context, 'Please enter a valid positive amount');
        return;
      }
      if (costRupees > AppConstants.kMaxAmount) {
        SnackbarFeedback.showError(context, 'Amount cannot exceed ${MoneyFormatter.symbol}10,00,000');
        return;
      }
      final parts = costText.split('.');
      if (parts.length > 1 && parts[1].length > 2) {
        SnackbarFeedback.showError(context, 'Up to 2 decimal places allowed');
        return;
      }
      cost = (costRupees * 100).round();
    }
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim().isNotEmpty
        ? _notesController.text.trim()
        : null;

    final provider = context.read<FutureExpensesProvider>();

    try {
      if (widget.existingItem != null) {
        final item = widget.existingItem!;
        item.title = title;
        item.estimatedCost = cost;
        item.priority = _priority;
        item.dueDate = _dueDate;
        item.category = _selectedCategory;
        item.notes = notes;

        await provider.updateFutureExpense(item);
        if (mounted) {
          SnackbarFeedback.showSuccess(context, 'Wishlist item updated');
        }
      } else {
        final item = FutureExpense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          estimatedCost: cost,
          priority: _priority,
          dueDate: _dueDate,
          category: _selectedCategory,
          notes: notes,
        );

        await provider.addFutureExpense(item);
        if (mounted) {
          SnackbarFeedback.showSuccess(context, 'Item added to wishlist');
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(context, 'Failed to save wishlist item: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existingItem != null;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) {
          SnackbarFeedback.showInfo(context, 'Saving wishlist item...');
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
              Text(
                isEdit ? 'Edit Wishlist Item' : 'Add to Wishlist',
                style: AppTextStyles.headline(
                  context,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Item Name (e.g. New Headphones)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        _titleTouched = true;
                        _validateTitle();
                      },
                    ),
                    InlineValidationMessage(message: _titleError),
                    const SizedBox(height: AppSpacing.md),

                    TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Estimated Cost (${MoneyFormatter.symbol}, optional)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    TextFormField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Due Date
                    OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _dueDate == null
                            ? 'Set Target Date (optional)'
                            : 'Target Date: ${DateFormat('MMMM d, yyyy').format(_dueDate!)}',
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

                    // Priority Selector
                    Text(
                      'Priority',
                      style: AppTextStyles.label(
                        context,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Low')),
                        ButtonSegment(value: 1, label: Text('Medium')),
                        ButtonSegment(value: 2, label: Text('High')),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (val) {
                        setState(() => _priority = val.first);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Category Selector
                    Text(
                      'Category',
                      style: AppTextStyles.label(
                        context,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
                    const SizedBox(height: AppSpacing.xxl),

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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEdit ? 'Save Changes' : 'Add to Wishlist'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
