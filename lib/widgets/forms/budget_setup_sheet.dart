import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/provider/budget_provider.dart';
import 'package:expense/widgets/snackbar_feedback.dart';
import 'package:expense/core/money.dart';
import 'package:expense/core/app_constants.dart';

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
      _limitController.text = (activeBudget.limit / 100.0).toStringAsFixed(0);
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

    final limitRupees = double.tryParse(_limitController.text);
    if (limitRupees == null || limitRupees <= 0) {
      SnackbarFeedback.showError(
        context,
        'Please enter a valid positive budget limit.',
      );
      return;
    }

    final limit = (limitRupees * 100).round();

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
        SnackbarFeedback.showError(context, 'Failed to save budget: $e');
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Budget Goal?'),
        content: const Text(
          'Are you sure you want to delete your active spending limit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await provider.clearBudget();
        if (mounted) {
          SnackbarFeedback.showSuccess(context, 'Budget limit cleared.');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          SnackbarFeedback.showError(context, 'Failed to clear budget: $e');
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
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final activeBudget = context.watch<BudgetProvider>().activeBudget;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaving) {
          SnackbarFeedback.showInfo(context, 'Saving budget...');
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
          top: AppSpacing.base,
          bottom: AppSpacing.base + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Set Budget Goal',
                  style: AppTextStyles.headline(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Set a spending limit for your preferred timeframe.',
                  style: AppTextStyles.bodySecondary(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Budget Limit Field
                TextFormField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: AppTextStyles.headline(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Limit Amount',
                    prefixText: '${MoneyFormatter.symbol} ',
                    prefixStyle: AppTextStyles.headline(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainer,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a budget limit';
                    }
                    final val = double.tryParse(value);
                    if (val == null || val <= 0) {
                      return 'Enter a valid number greater than 0';
                    }
                    if (val > AppConstants.kMaxAmount) {
                      return 'Amount cannot exceed ${MoneyFormatter.symbol}10,00,000';
                    }
                    final parts = value.trim().split('.');
                    if (parts.length > 1 && parts[1].length > 2) {
                      return 'Up to 2 decimal places allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Timeframe Selector
                Text(
                  'Timeframe Plan',
                  style: AppTextStyles.label(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _buildPeriodOption('daily', 'Daily'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildPeriodOption('weekly', 'Weekly'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildPeriodOption('monthly', 'Monthly'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildPeriodOption('yearly', 'Yearly'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Warning Threshold Slider
                Text(
                  'Warning Threshold: ${(_warningThreshold * 100).toInt()}%',
                  style: AppTextStyles.label(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
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
                const SizedBox(height: AppSpacing.xxl),

                // Action Buttons
                Row(
                  children: [
                    if (activeBudget != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _clearBudget,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.base,
                            ),
                            side: BorderSide(color: colorScheme.error),
                            foregroundColor: colorScheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: const Text('Clear Limit'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _submit,
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
                            : const Text('Save Limit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodOption(String value, String label) {
    final isSelected = _selectedPeriod == value;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainer,
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.label(context).copyWith(
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
