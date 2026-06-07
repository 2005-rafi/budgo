import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/widgets/snackbar_feedback.dart';
import 'package:expense/widgets/common/app_filter_chip.dart';
import 'package:expense/core/money.dart';
import 'package:expense/core/app_constants.dart';

class ReminderBottomSheet extends StatefulWidget {
  final Reminder? existingReminder;

  const ReminderBottomSheet({super.key, this.existingReminder});

  static void show(BuildContext context, {Reminder? existingReminder}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ReminderBottomSheet(existingReminder: existingReminder),
    );
  }

  @override
  State<ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<ReminderBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime? _selectedDateTime;
  String _recurrenceType = 'none'; // 'none', 'daily', 'weekly', 'monthly'
  String? _selectedCategory;

  bool _titleTouched = false;
  String? _titleError;
  bool _isSaving = false;
  String? _selectedShortcut; // Track which date/time shortcut is selected

  final List<Map<String, dynamic>> _paymentCategories = const [
    {'name': 'Rent', 'icon': Icons.home_outlined},
    {'name': 'Utilities', 'icon': Icons.electric_bolt_outlined},
    {'name': 'Credit Card', 'icon': Icons.credit_card_outlined},
    {'name': 'Subscription', 'icon': Icons.subscriptions_outlined},
    {'name': 'Loan / EMI', 'icon': Icons.handshake_outlined},
    {'name': 'Insurance', 'icon': Icons.security_outlined},
    {'name': 'Other', 'icon': Icons.receipt_long_outlined},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingReminder != null) {
      final r = widget.existingReminder!;
      _titleController.text = r.title;
      _notesController.text = r.notes ?? '';
      _selectedDateTime = r.scheduledAt;
      _recurrenceType = r.recurrenceType;
      _selectedCategory = r.category;
      if (r.amount != null) {
        _amountController.text = (r.amount! / 100.0).toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _amountController.dispose();
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

  void _setShortcutTime(String shortcut) {
    final now = DateTime.now();
    DateTime dt;

    if (shortcut == 'tomorrow_9am') {
      dt = DateTime(now.year, now.month, now.day + 1, 9, 0);
    } else if (shortcut == 'tomorrow_6pm') {
      dt = DateTime(now.year, now.month, now.day + 1, 18, 0);
    } else if (shortcut == 'next_monday') {
      int daysDiff = DateTime.monday - now.weekday;
      if (daysDiff <= 0) daysDiff += 7;
      dt = DateTime(now.year, now.month, now.day + daysDiff, 9, 0);
    } else {
      return;
    }

    setState(() {
      _selectedShortcut = shortcut;
      _selectedDateTime = dt;
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now.add(const Duration(minutes: 15)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDateTime != null
            ? TimeOfDay.fromDateTime(_selectedDateTime!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedShortcut = 'custom';
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _save() async {
    setState(() {
      _titleTouched = true;
    });
    _validateTitle();

    if (_titleError != null) return;

    if (_selectedDateTime == null) {
      SnackbarFeedback.showError(context, 'Please select a date and time');
      return;
    }

    if (_recurrenceType == 'none' &&
        _selectedDateTime!.isBefore(DateTime.now())) {
      SnackbarFeedback.showError(
        context,
        'Scheduled time must be in the future',
      );
      return;
    }

    setState(() => _isSaving = true);

    final rule = _recurrenceType == 'none'
        ? null
        : RecurrenceRule(
            type: _recurrenceType == 'daily'
                ? RecurrenceType.daily
                : _recurrenceType == 'weekly'
                ? RecurrenceType.weekly
                : _recurrenceType == 'monthly'
                ? RecurrenceType.monthly
                : RecurrenceType.none,
            weekday: _recurrenceType == 'weekly'
                ? _selectedDateTime!.weekday
                : null,
            dayOfMonth: _recurrenceType == 'monthly'
                ? min(_selectedDateTime!.day, 28)
                : null,
            time: TimeOfDay.fromDateTime(_selectedDateTime!),
          );

    final provider = context.read<ReminderProvider>();

    final amountText = _amountController.text.trim();
    double? amtDouble;
    int? amtPaise;
    if (amountText.isNotEmpty) {
      amtDouble = double.tryParse(amountText);
      if (amtDouble == null || amtDouble <= 0) {
        SnackbarFeedback.showError(context, 'Please enter a valid positive amount');
        return;
      }
      if (amtDouble > AppConstants.kMaxAmount) {
        SnackbarFeedback.showError(context, 'Amount cannot exceed ${MoneyFormatter.symbol}10,00,000');
        return;
      }
      final parts = amountText.split('.');
      if (parts.length > 1 && parts[1].length > 2) {
        SnackbarFeedback.showError(context, 'Up to 2 decimal places allowed');
        return;
      }
      amtPaise = (amtDouble * 100).round();
    }

    try {
      if (widget.existingReminder != null) {
        final r = widget.existingReminder!;
        r.title = _titleController.text.trim();
        r.notes = _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null;
        r.scheduledAt = _selectedDateTime!;
        r.isRecurring = _recurrenceType != 'none';
        r.recurrenceType = _recurrenceType;
        r.recurrenceRule = rule;
        r.amount = amtPaise;
        r.category = _selectedCategory;

        await provider.updateReminder(r);

        if (mounted) SnackbarFeedback.showSuccess(context, 'Reminder updated');
      } else {
        final r = Reminder(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          scheduledAt: _selectedDateTime!,
          isRecurring: _recurrenceType != 'none',
          recurrenceType: _recurrenceType,
          isActive: true,
          amount: amtPaise,
          category: _selectedCategory,
        )..recurrenceRule = rule;

        await provider.addReminder(r);
        if (mounted) {
          SnackbarFeedback.showSuccess(context, 'Reminder scheduled');
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(context, 'Failed to save reminder: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existingReminder != null;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) {
          SnackbarFeedback.showInfo(context, 'Scheduling reminder...');
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
              // Header drag handle
              Center(
                child: Container(
                  width: 36.0,
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
                isEdit ? 'Edit Payment Reminder' : 'Schedule Payment Reminder',
                style: AppTextStyles.title(context).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Category Picker Carousel
              Text(
                'Payment Category',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _paymentCategories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _paymentCategories[index];
                    final isSelected = _selectedCategory == cat['name'];
                    return AppFilterChip(
                      icon: cat['icon'],
                      label: cat['name'],
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? cat['name'] : null;
                          // Auto-fill title if empty or matches previous category autofills
                          if (selected) {
                            if (_titleController.text.isEmpty ||
                                _paymentCategories.any((c) =>
                                    _titleController.text ==
                                    '${c['name']} Payment')) {
                              _titleController.text = '${cat['name']} Payment';
                              _titleTouched = true;
                              _validateTitle();
                            }
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount & Title Input Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount Field (40% width)
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              hintText: '0.00',
                              prefixText: '${MoneyFormatter.symbol} ',
                              prefixStyle: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title Field (60% width)
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Reminder Title',
                              hintText: 'e.g., Rent Payment',
                              errorText: _titleError,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              _titleTouched = true;
                              _validateTitle();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Notes input
                    TextFormField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Details (Optional)',
                        hintText: 'e.g., Account number, biller details...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Date & Time Picker Selector
                    Text(
                      'Schedule Date & Time',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),

                    // Shortcuts row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          AppFilterChip(
                            label: 'Tomorrow (9 AM)',
                            selected: _selectedShortcut == 'tomorrow_9am',
                            onSelected: (selected) {
                              if (selected) _setShortcutTime('tomorrow_9am');
                            },
                          ),
                          const SizedBox(width: 8),
                          AppFilterChip(
                            label: 'Tomorrow (6 PM)',
                            selected: _selectedShortcut == 'tomorrow_6pm',
                            onSelected: (selected) {
                              if (selected) _setShortcutTime('tomorrow_6pm');
                            },
                          ),
                          const SizedBox(width: 8),
                          AppFilterChip(
                            label: 'Next Monday',
                            selected: _selectedShortcut == 'next_monday',
                            onSelected: (selected) {
                              if (selected) _setShortcutTime('next_monday');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Display Selected Time / Custom Trigger
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedShortcut == 'custom'
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                            width: _selectedShortcut == 'custom' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDateTime == null
                                        ? 'Not Scheduled'
                                        : DateFormat('EEEE, MMMM d, y').format(
                                            _selectedDateTime!,
                                          ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedDateTime == null
                                        ? 'Tap to pick custom date'
                                        : DateFormat('h:mm a').format(
                                            _selectedDateTime!,
                                          ),
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Recurrence Header
                    Text(
                      'Recurrence',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),

                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'none', label: Text('None')),
                        ButtonSegment(value: 'daily', label: Text('Daily')),
                        ButtonSegment(value: 'weekly', label: Text('Weekly')),
                        ButtonSegment(value: 'monthly', label: Text('Monthly')),
                      ],
                      selected: {_recurrenceType},
                      onSelectionChanged: (val) {
                        setState(() => _recurrenceType = val.first);
                      },
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.base,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                          : Text(
                              isEdit ? 'Save Changes' : 'Schedule Reminder',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
