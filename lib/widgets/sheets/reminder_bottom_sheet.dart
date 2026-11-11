import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/providers/reminder_provider.dart';
import 'package:expense/providers/workspace_provider.dart';

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
  String _selectedWorkspaceId = AppConstants.kDefaultWorkspaceId;

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
    try {
      final wsProvider = context.read<WorkspaceProvider>();
      _selectedWorkspaceId = wsProvider.activeWorkspaceId;
    } on ProviderNotFoundException {
      _selectedWorkspaceId = AppConstants.kDefaultWorkspaceId;
    }
    if (widget.existingReminder != null) {
      final r = widget.existingReminder!;
      _titleController.text = r.title;
      _notesController.text = r.notes ?? '';
      _selectedDateTime = r.scheduledAt;
      _recurrenceType = r.recurrenceType;
      _selectedCategory = r.category;
      if (r.workspaceId.isNotEmpty) {
        _selectedWorkspaceId = r.workspaceId;
      }
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
        'Scheduled time must be in the future.',
        guidance: 'Pick an upcoming date or time, or switch recurrence to Daily/Weekly/Monthly.',
      );
      return;
    }

    final amountText = _amountController.text.trim();
    int? amtPaise;
    if (amountText.isNotEmpty) {
      final validation = InputValidators.validateAmount(
        amountText,
        fieldLabel: 'Reminder amount',
      );
      if (!validation.isValid) {
        SnackbarFeedback.showError(context, validation.errorMessage!);
        return;
      }
      amtPaise = validation.paise;
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

    try {
      bool ok = false;
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
        r.workspaceId = _selectedWorkspaceId;

        ok = await provider.updateReminder(r);
        if (mounted && ok) {
          SnackbarFeedback.showSuccess(context, 'Reminder updated');
        }
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
          workspaceId: _selectedWorkspaceId,
        )..recurrenceRule = rule;

        ok = await provider.addReminder(r);
        if (mounted && ok) {
          SnackbarFeedback.showSuccess(context, 'Reminder scheduled');
        }
      }

      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        SnackbarFeedback.showError(
          context,
          provider.lastError ?? provider.errorMessage ?? 'Unable to save reminder.',
          operation: FeedbackOperation.saveReminder,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.saveReminder,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingReminder != null;
    List<Workspace> workspaces = const [];
    try {
      workspaces = context.watch<WorkspaceProvider>().workspaces;
    } on ProviderNotFoundException {
      workspaces = const [];
    }
    final validWorkspaceValue =
        workspaces.any((w) => w.id == _selectedWorkspaceId)
            ? _selectedWorkspaceId
            : (workspaces.isNotEmpty ? workspaces.first.id : null);

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) {
          SnackbarFeedback.showInfo(context, 'Scheduling reminder...');
        }
      },
      child: BudgoBottomSheet(
        title: isEdit ? 'Edit Payment Reminder' : 'Schedule Payment Reminder',
        icon: Icons.notifications_active_outlined,
        footer: BudgoButton(
          label: isEdit ? 'Save Changes' : 'Schedule Reminder',
          isLoading: _isSaving,
          onPressed: _save,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (workspaces.isNotEmpty) ...[
                BudgoDropdownField<String>(
                  label: 'Workspace / Account Profile',
                  value: validWorkspaceValue,
                  options: workspaces
                      .map(
                        (w) => BudgoDropdownItem<String>(
                          value: w.id,
                          label: w.name,
                          icon: WorkspaceIcons.forType(w.type),
                          iconColor: Color(w.colorValue),
                          trailingText:
                              w.isDefault ? 'Default' : null,
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedWorkspaceId = val);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              // Category Picker Carousel
              Text(
                'Payment Category',
                style: AppTextStyles.labelMedium(context)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              BudgoChoiceGroup<String>(
                allowHorizontalScroll: true,
                selectedValue: _selectedCategory,
                options: _paymentCategories
                    .map(
                      (cat) => BudgoChoiceOption<String>(
                        value: cat['name'] as String,
                        label: cat['name'] as String,
                        icon: cat['icon'] as IconData,
                      ),
                    )
                    .toList(),
                onSelected: (catName) {
                  setState(() {
                    _selectedCategory = catName;
                    if (_titleController.text.isEmpty ||
                        _paymentCategories.any(
                          (c) => _titleController.text == '${c['name']} Payment',
                        )) {
                      _titleController.text = '$catName Payment';
                      _titleTouched = true;
                      _validateTitle();
                    }
                  });
                },
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
                        Expanded(
                          flex: 4,
                          child: BudgoAmountField(
                            controller: _amountController,
                            label: 'Amount',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 6,
                          child: BudgoTextField(
                            controller: _titleController,
                            inputPolicy: BudgoInputPolicy.reminderTitle,
                            label: 'Reminder Title',
                            hint: BudgoInputGuidance.reminderHint(_recurrenceType != 'none'),
                            errorText: _titleError,
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
                    BudgoTextField(
                      controller: _notesController,
                      inputPolicy: BudgoInputPolicy.reminderNotes,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      label: 'Notes / Details (Optional)',
                      hint: 'Biller reference, account details, or instructions',
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Date & Time Picker Selector
                    Text(
                      'Schedule Date & Time',
                      style: AppTextStyles.labelMedium(context)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    BudgoChoiceGroup<String>(
                      allowHorizontalScroll: true,
                      selectedValue: _selectedShortcut,
                      options: const [
                        BudgoChoiceOption(
                          value: 'tomorrow_9am',
                          label: 'Tomorrow (9 AM)',
                        ),
                        BudgoChoiceOption(
                          value: 'tomorrow_6pm',
                          label: 'Tomorrow (6 PM)',
                        ),
                        BudgoChoiceOption(
                          value: 'next_monday',
                          label: 'Next Monday',
                        ),
                      ],
                      onSelected: _setShortcutTime,
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    BudgoPickerField(
                      icon: Icons.calendar_month_outlined,
                      label: _selectedDateTime == null
                          ? 'Schedule Time'
                          : DateFormat('EEEE, MMMM d, y')
                              .format(_selectedDateTime!),
                      value: _selectedDateTime == null
                          ? 'Tap to pick custom date & time'
                          : DateFormat('h:mm a').format(_selectedDateTime!),
                      onTap: _pickDateTime,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Recurrence Header
                    Text(
                      'Recurrence',
                      style: AppTextStyles.labelMedium(context)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    BudgoSegmentedControl<String>(
                      segments: const [
                        ButtonSegment(value: 'none', label: Text('None')),
                        ButtonSegment(value: 'daily', label: Text('Daily')),
                        ButtonSegment(value: 'weekly', label: Text('Weekly')),
                        ButtonSegment(value: 'monthly', label: Text('Monthly')),
                      ],
                      selected: _recurrenceType,
                      onSelected: (val) =>
                          setState(() => _recurrenceType = val),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
