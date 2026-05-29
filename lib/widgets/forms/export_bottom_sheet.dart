import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:expense/core/app_theme_extensions.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/services/report_export_service.dart';
import 'package:expense/widgets/snackbar_feedback.dart';

class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExportBottomSheet(),
    );
  }

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  String _format = 'pdf'; // 'pdf' | 'csv'
  double _progress = 0.0;
  bool _isExporting = false;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  void _runExport() async {
    final provider = context.read<ExpensesProvider>();
    final expenses = provider.filteredItems.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      final start = DateTime(_dateRange.start.year, _dateRange.start.month, _dateRange.start.day);
      final end = DateTime(_dateRange.end.year, _dateRange.end.month, _dateRange.end.day, 23, 59, 59);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    if (expenses.isEmpty) {
      SnackbarFeedback.showError(context, 'No expenses found in the selected date range.');
      return;
    }

    setState(() {
      _isExporting = true;
      _progress = 0.0;
    });

    try {
      if (_format == 'csv') {
        final result = await ReportExportService.exportExpensesCsv(
          expenses: expenses,
          range: _dateRange,
        );

        if (result.isSuccess && result.value != null) {
          final file = result.value!;
          if (mounted) {
            SnackbarFeedback.showSuccess(context, 'CSV Exported successfully!');
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(file.path)],
                text: 'My Budgo Expenses CSV Report',
              ),
            );
          }
        } else {
          if (mounted) SnackbarFeedback.showError(context, result.errorMessage ?? 'Export failed.');
        }
      } else {
        // PDF Export with progress bar
        final bytesResult = await ReportExportService.buildExpensesPdfBytes(
          expenses: expenses,
          range: _dateRange,
          title: 'Budgo Financial Report',
          onProgress: (p) {
            if (mounted) {
              setState(() => _progress = p);
            }
          },
        );

        if (bytesResult.isSuccess && bytesResult.value != null) {
          final dir = await getApplicationDocumentsDirectory();
          final epochMs = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'budgo_report_$epochMs.pdf';
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytesResult.value!);

          if (mounted) {
            SnackbarFeedback.showSuccess(context, 'PDF Exported successfully!');
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(file.path)],
                text: 'My Budgo Expenses PDF Report',
              ),
            );
          }
        } else {
          if (mounted) SnackbarFeedback.showError(context, bytesResult.errorMessage ?? 'Export failed.');
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) SnackbarFeedback.showError(context, 'Failed to export: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: BudgoColors.bottomSheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Export Financial Data',
            style: AppTextStyles.headline(context).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Date Range picker Row
          OutlinedButton.icon(
            onPressed: _isExporting ? null : _pickDateRange,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              'Range: ${DateFormat('yMMMd').format(_dateRange.start)} - ${DateFormat('yMMMd').format(_dateRange.end)}',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // File Format Selector
          Text(
            'Export Format',
            style: AppTextStyles.label(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pdf', label: Text('PDF Document'), icon: Icon(Icons.picture_as_pdf)),
              ButtonSegment(value: 'csv', label: Text('CSV Spreadsheet'), icon: Icon(Icons.grid_on)),
            ],
            selected: {_format},
            onSelectionChanged: (val) {
              if (!_isExporting) {
                setState(() => _format = val.first);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Progress Bar if exporting
          if (_isExporting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Generating report... ${(_progress * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Export Button
          FilledButton(
            onPressed: _isExporting ? null : _runExport,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            child: const Text('Export & Share'),
          ),
        ],
      ),
    );
  }
}
