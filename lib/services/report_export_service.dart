import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:expense/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportExportService {
  static String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');

  static Future<File> exportExpensesCsv({
    required List<Expense> expenses,
    required DateTimeRange range,
  }) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final rows = <List<dynamic>>[
      ['Date', 'Product', 'Category', 'Amount'],
      ...expenses.map((e) => [
            dateFmt.format(e.date),
            e.productName,
            e.category,
            e.amount.toStringAsFixed(2),
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        _safeFileName('expenses_${dateFmt.format(range.start)}_${dateFmt.format(range.end)}.csv');

    final file = File('${dir.path}/$fileName');
    return file.writeAsString(csv);
  }

  static Future<Uint8List> buildExpensesPdfBytes({
    required List<Expense> expenses,
    required DateTimeRange range,
    required String title,
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('yMMMd');
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final avg = expenses.isEmpty ? 0 : total / expenses.length;

    final rows = expenses
        .take(200)
        .map((e) => [
              dateFmt.format(e.date),
              e.productName,
              e.category,
              currencyFmt.format(e.amount),
            ])
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Range: ${dateFmt.format(range.start)} → ${dateFmt.format(range.end)}'),
          pw.SizedBox(height: 10),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total: ${currencyFmt.format(total)}'),
              pw.Text('Count: ${expenses.length}'),
              pw.Text('Avg: ${currencyFmt.format(avg)}'),
            ],
          ),
          pw.SizedBox(height: 12),

          pw.Table.fromTextArray(
            headers: const ['Date', 'Product', 'Category', 'Amount'],
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(2.6),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.1),
            },
          ),

          if (expenses.length > 200) ...[
            pw.SizedBox(height: 8),
            pw.Text('Showing first 200 rows (export CSV for full list).',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ],
      ),
    );

    return pdf.save();
  }
}
