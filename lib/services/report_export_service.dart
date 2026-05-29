import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:expense/models/expense.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:expense/core/money.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

sealed class ExportError {
  final String message;
  const ExportError(this.message);
}

class StoragePermissionDenied extends ExportError {
  const StoragePermissionDenied()
    : super('Storage access denied. Please grant file permission in Settings.');
}

class DiskSpaceFull extends ExportError {
  const DiskSpaceFull()
    : super('Not enough storage space. Free up space and try again.');
}

class UnknownExportError extends ExportError {
  final String details;
  const UnknownExportError(this.details)
    : super('Export failed. Please try again.');
}

class ExportResult<T> {
  final T? value;
  final ExportError? error;
  final bool isSuccess;

  ExportResult.success(this.value) : error = null, isSuccess = true;

  ExportResult.failure(this.error) : value = null, isSuccess = false;

  String? get errorMessage => error?.message;
}

// Top-level function for CSV compute isolate
String _buildCsvIsolate(List<List<dynamic>> rows) {
  return const ListToCsvConverter().convert(rows);
}

// Top-level function for PDF spawn isolate
void _buildPdfIsolate(Map<String, dynamic> params) async {
  final List<Map<String, dynamic>> rawExpenses =
      List<Map<String, dynamic>>.from(params['expenses']);
  final range = params['range'] as DateTimeRange;
  final title = params['title'] as String;
  final sendPort = params['sendPort'] as SendPort;

  try {
    final pdf = pw.Document();
    final dateFmt = DateFormat('yMMMd');
    final total = rawExpenses.fold<int>(0, (s, e) => s + (e['amount'] as int));
    final avg = rawExpenses.isEmpty ? 0.0 : total / rawExpenses.length;

    final tableHeaders = ['Date', 'Product', 'Category', 'Amount'];
    const int chunkSize = 40;
    final int pageCount = rawExpenses.isEmpty
        ? 1
        : (rawExpenses.length / chunkSize).ceil();

    for (int chunkIndex = 0; chunkIndex < pageCount; chunkIndex++) {
      final chunkStart = chunkIndex * chunkSize;
      final chunkEnd = (chunkStart + chunkSize) > rawExpenses.length
          ? rawExpenses.length
          : (chunkStart + chunkSize);

      final chunkExpenses = rawExpenses.sublist(chunkStart, chunkEnd);
      final isLastPage = chunkIndex == pageCount - 1;

      final tableRows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFE0E7FF),
          ),
          children: tableHeaders
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              )
              .toList(),
        ),

        ...chunkExpenses.map((e) {
          final date = DateTime.parse(e['date']);
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  dateFmt.format(date),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  e['productName'] as String,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  e['category'] as String,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  (e['amount'] as int).format(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        }),
      ];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (chunkIndex == 0) ...[
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Period: ${dateFmt.format(range.start)} - ${dateFmt.format(range.end)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Spent: ${total.format()}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Average/Exp: ${avg.round().format()}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: tableRows,
              ),
              if (isLastPage) ...[
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 0.5, color: PdfColors.grey),
                pw.SizedBox(height: 10),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Generated by Budgo Expense Tracker',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      sendPort.send(((chunkIndex + 1) / pageCount).toDouble());
    }

    final bytes = await pdf.save();
    sendPort.send(bytes);
  } catch (e) {
    sendPort.send(e.toString());
  }
}

ExportError _classifyError(Object error) {
  final errStr = error.toString().toLowerCase();
  if (errStr.contains('permission') || errStr.contains('access denied')) {
    return const StoragePermissionDenied();
  } else if (errStr.contains('disk full') ||
      errStr.contains('no space') ||
      errStr.contains('enospc')) {
    return const DiskSpaceFull();
  } else {
    return UnknownExportError(error.toString());
  }
}

class ReportExportService {
  static Future<ExportResult<File>> exportExpensesCsv({
    required List<Expense> expenses,
    required DateTimeRange range,
  }) async {
    try {
      final dateFmt = DateFormat('yyyy-MM-dd');
      final total = expenses.fold<int>(0, (s, e) => s + e.amount);

      // Serialise to primitive rows
      final List<List<dynamic>> rows = [
        ['Date', 'Product', 'Category', 'Amount'],
        ...expenses.map(
          (e) => [
            dateFmt.format(e.date),
            e.productName,
            e.category,
            (e.amount / 100.0).toStringAsFixed(2),
          ],
        ),
        ['', '', '', ''],
        ['', 'TOTAL', '', (total / 100.0).toStringAsFixed(2)],
      ];

      final csv = await compute(_buildCsvIsolate, rows);

      final dir = await getApplicationDocumentsDirectory();
      final startStr = DateFormat('yyyyMMdd').format(range.start);
      final endStr = DateFormat('yyyyMMdd').format(range.end);
      final epochMs = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'budgo_expenses_${startStr}_${endStr}_$epochMs.csv';

      final file = File('${dir.path}/$fileName');
      final savedFile = await file.writeAsString(csv);
      return ExportResult.success(savedFile);
    } catch (e) {
      return ExportResult.failure(_classifyError(e));
    }
  }

  static Future<ExportResult<Uint8List>> buildExpensesPdfBytes({
    required List<Expense> expenses,
    required DateTimeRange range,
    required String title,
    required void Function(double progress) onProgress,
  }) async {
    try {
      final progressPort = ReceivePort();
      final completer = Completer<ExportResult<Uint8List>>();

      // Serialise expenses to Map
      final List<Map<String, dynamic>> serialisedExpenses = expenses
          .map(
            (e) => {
              'date': e.date.toIso8601String(),
              'productName': e.productName,
              'category': e.category,
              'amount': e.amount,
            },
          )
          .toList();

      final isolate = await Isolate.spawn(_buildPdfIsolate, {
        'expenses': serialisedExpenses,
        'range': range,
        'title': title,
        'sendPort': progressPort.sendPort,
      });

      progressPort.listen((msg) {
        if (msg is double) {
          onProgress(msg);
        } else if (msg is Uint8List) {
          isolate.kill();
          progressPort.close();
          completer.complete(ExportResult.success(msg));
        } else if (msg is String) {
          isolate.kill();
          progressPort.close();
          completer.complete(ExportResult.failure(UnknownExportError(msg)));
        }
      });

      return completer.future;
    } catch (e) {
      return ExportResult.failure(_classifyError(e));
    }
  }
}
