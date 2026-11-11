import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/core/utils/input_validators.dart';
import 'package:expense/providers/budget_provider.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/core/constants/app_constants.dart';

class BudgetSetupSheet extends StatefulWidget {
  const BudgetSetupSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BudgetSetupSheet(),
    );
  }

  @override
  State<BudgetSetupSheet> createState() => _BudgetSetupSheetState();
}

class _BudgetSetupSheetState extends State<BudgetSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();
  String _selectedPeriod =
      'monthly'; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  double _warningThreshold = 0.8;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final activeBudget = context.read<BudgetProvider>().activeBudget;
    if (activeBudget != null) {
      final val = activeBudget.limit / 100.0;
      _limitController.text = val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(2);
      _warningThreshold = activeBudget.warningThreshold;
      if ([
        'daily',
        'weekly',
        'monthly',
        'yearly',
      ].contains(activeBudget.period)) {
        _selectedPeriod = activeBudget.period;
      }
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  DateTime _getStartOfWeek(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final validation = InputValidators.validateAmount(
      _limitController.text,
      fieldLabel: 'Budget limit',
    );
    if (!validation.isValid) {
      SnackbarFeedback.showError(context, validation.errorMessage!);
      return;
    }

    final limit = validation.paise!;

    setState(() => _isSaving = true);
    final provider = context.read<BudgetProvider>();
    final now = DateTime.now();
    final id = '${_selectedPeriod}_${now.millisecondsSinceEpoch}';

    try {
      switch (_selectedPeriod) {
        case 'daily':
          await provider.setDailyBudget(id: id, limit: limit, date: now, warningThreshold: _warningThreshold);
          break;
        case 'weekly':
          await provider.setWeeklyBudget(
            id: id,
            limit: limit,
            weekStart: _getStartOfWeek(now),
            warningThreshold: _warningThreshold,
          );
          break;
        case 'monthly':
          await provider.setMonthlyBudget(
            id: id,
            limit: limit,
            anyDayInMonth: now,
            warningThreshold: _warningThreshold,
          );
          break;
        case 'yearly':
          await provider.setYearlyBudget(
            id: id,
            limit: limit,
            anyDayInYear: now,
            warningThreshold: _warningThreshold,
          );
          break;
      }
      if (mounted) {
        SnackbarFeedback.showSuccess(
          context,
          'Budget goal saved successfully.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.saveBudget,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _clearBudget() async {
    final provider = context.read<BudgetProvider>();
    if (provider.activeBudget == null) return;

    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Remove Budget Goal?',
      message: 'Are you sure you want to delete your active spending limit?',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (confirm) {
      setState(() => _isSaving = true);
      try {
        await provider.clearBudget();
        if (mounted) {
          SnackbarFeedback.showSuccess(context, 'Budget limit cleared.');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          SnackbarFeedback.showError(
            context,
            e,
            operation: FeedbackOperation.clearBudget,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBudget = context.watch<BudgetProvider>().activeBudget;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) {
          SnackbarFeedback.showInfo(context, 'Saving budget...');
        }
      },
      child: BudgoBottomSheet(
        title: 'Set Budget Goal',
        subtitle: 'Set a spending limit for your preferred timeframe.',
        icon: Icons.track_changes_rounded,
        footer: Row(
          children: [
            if (activeBudget != null) ...[
              Expanded(
                child: BudgoButton(
                  label: 'Clear Limit',
                  variant: BudgoButtonVariant.outlined,
                  isLoading: _isSaving,
                  onPressed: _clearBudget,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: BudgoButton(
                label: 'Save Limit',
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BudgoAmountField(
                  controller: _limitController,
                  label: 'Limit Amount',
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a budget limit';
                    }
                    final val = double.tryParse(value);
                    if (val == null || val <= 0) {
                      return 'Enter a valid number greater than 0';
                    }
                    if (val > AppConstants.kMaxAmountRupees) {
                      return 'Amount cannot exceed ${MoneyFormatter.symbol}1,00,00,000';
                    }
                    final parts = value.trim().split('.');
                    if (parts.length > 1 && parts[1].length > 2) {
                      return 'Up to 2 decimal places allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Timeframe Plan',
                  style: AppTextStyles.labelMedium(context)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                BudgoSegmentedControl<String>(
                  segments: const [
                    ButtonSegment(value: 'daily', label: Text('Daily')),
                    ButtonSegment(value: 'weekly', label: Text('Weekly')),
                    ButtonSegment(value: 'monthly', label: Text('Monthly')),
                    ButtonSegment(value: 'yearly', label: Text('Yearly')),
                  ],
                  selected: _selectedPeriod,
                  onSelected: (val) => setState(() => _selectedPeriod = val),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Warning Threshold: ${(_warningThreshold * 100).toInt()}%',
                  style: AppTextStyles.labelMedium(context)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Slider(
                  value: _warningThreshold,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(_warningThreshold * 100).toInt()}%',
                  onChanged: (val) {
                    setState(() {
                      _warningThreshold = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
