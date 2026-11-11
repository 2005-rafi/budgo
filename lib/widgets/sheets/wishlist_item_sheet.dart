import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/providers/future_expenses_provider.dart';

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

    final costText = _costController.text.trim();
    int? cost;
    if (costText.isNotEmpty) {
      final validation = InputValidators.validateAmount(
        costText,
        fieldLabel: 'Estimated cost',
      );
      if (!validation.isValid) {
        SnackbarFeedback.showError(context, validation.errorMessage!);
        return;
      }
      cost = validation.paise;
    }

    setState(() => _isSaving = true);
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
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.saveWishlist,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) {
          SnackbarFeedback.showInfo(context, 'Saving wishlist item...');
        }
      },
      child: BudgoBottomSheet(
        title: isEdit ? 'Edit Wishlist Item' : 'Add to Wishlist',
        icon: Icons.auto_awesome_outlined,
        footer: BudgoButton(
          label: isEdit ? 'Save Changes' : 'Add to Wishlist',
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
                BudgoTextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  inputPolicy: BudgoInputPolicy.wishlistTitle,
                  label: 'Item Name',
                  hint: BudgoInputGuidance.wishlistHint(),
                  prefixIcon: Icons.shopping_bag_outlined,
                  errorText: _titleError,
                  onChanged: (_) {
                    _titleTouched = true;
                    _validateTitle();
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                BudgoAmountField(
                  controller: _costController,
                  label: 'Estimated Cost (Optional)',
                ),
                const SizedBox(height: AppSpacing.md),

                BudgoTextField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  inputPolicy: BudgoInputPolicy.wishlistNotes,
                  label: 'Notes (Optional)',
                  hint: 'Model, store link, or target purchase context',
                  prefixIcon: Icons.notes_rounded,
                ),
                const SizedBox(height: AppSpacing.md),

                BudgoPickerField(
                  icon: Icons.calendar_today_rounded,
                  label: 'Target Date (Optional)',
                  value: _dueDate == null
                      ? 'Not set — tap to choose'
                      : DateFormat('MMMM d, yyyy').format(_dueDate!),
                  onTap: _pickDueDate,
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Priority',
                  style: AppTextStyles.labelMedium(context)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                BudgoSegmentedControl<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Low')),
                    ButtonSegment(value: 1, label: Text('Medium')),
                    ButtonSegment(value: 2, label: Text('High')),
                  ],
                  selected: _priority,
                  onSelected: (val) => setState(() => _priority = val),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Category',
                  style: AppTextStyles.labelMedium(context)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                BudgoChoiceGroup<String>(
                  selectedValue: _selectedCategory,
                  options: _categories
                      .map((cat) => BudgoChoiceOption(value: cat, label: cat))
                      .toList(),
                  onSelected: (cat) => setState(() => _selectedCategory = cat),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
