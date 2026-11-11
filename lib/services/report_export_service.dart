import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/currency/currency_formatter.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/workspace.dart';
import 'package:expense/services/export_statement_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ExportWorkspaceScope { single, selective, combinedAll }

enum ExportFormat { pdf, csv }

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

class ExportCancelledError extends ExportError {
  const ExportCancelledError() : super('Export cancelled by user.');
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
  final int exportedCount;
  final bool wasTruncatedForPdfCap;

  ExportResult.success(
    this.value, {
    this.exportedCount = 0,
    this.wasTruncatedForPdfCap = false,
  }) : error = null,
       isSuccess = true;

  ExportResult.failure(this.error)
    : value = null,
      isSuccess = false,
      exportedCount = 0,
      wasTruncatedForPdfCap = false;

  String? get errorMessage => error?.message;
}

/// Cooperative cancellation controller for long-running background export isolates.
class ExportCancellationToken {
  bool _isCancelled = false;
  VoidCallback? _onCancel;

  bool get isCancelled => _isCancelled;

  void attach(VoidCallback callback) {
    _onCancel = callback;
    if (_isCancelled) {
      callback();
    }
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _onCancel?.call();
  }
}

class ExportRequest {
  final ExportWorkspaceScope scope;
  final List<Workspace> workspaces;
  final List<Expense> expenses;
  final List<Expense>? allExpensesForReconciliation;
  final List<Income> incomes;
  final List<Income>? allIncomesForReconciliation;
  final List<Transfer> transfers;
  final List<Transfer>? allTransfersForReconciliation;
  final List<Account> accounts;
  final List<SavingsVault> vaults;
  final Map<String, String> accountNames;
  final Map<String, String> allWorkspaceNames;
  final DateTimeRange range;
  final ExportFormat format;
  final bool includeArchived;
  final bool includeExpenses;
  final bool includeIncomes;
  final bool includeTransfers;
  final bool includeCharts;
  final String fallbackCurrencySymbol;
  final String? title;
  final ExportCancellationToken? cancellationToken;

  String get resolvedTitle => title ?? AppBrand.exportStatementTitle;

  const ExportRequest({
    required this.scope,
    required this.workspaces,
    required this.expenses,
    this.allExpensesForReconciliation,
    this.incomes = const [],
    this.allIncomesForReconciliation,
    this.transfers = const [],
    this.allTransfersForReconciliation,
    this.accounts = const [],
    this.vaults = const [],
    this.accountNames = const {},
    this.allWorkspaceNames = const {},
    required this.range,
    required this.format,
    this.includeArchived = false,
    this.includeExpenses = true,
    this.includeIncomes = true,
    this.includeTransfers = true,
    this.includeCharts = true,
    this.fallbackCurrencySymbol = '₹',
    this.title,
    this.cancellationToken,
  });
}

/// Sanitizes spreadsheet text cells against CSV Formula Injection (=, +, -, @, \t, \r).
String sanitizeCsvCell(String raw) {
  if (raw.isEmpty) return raw;
  final first = raw[0];
  if (first == '=' ||
      first == '+' ||
      first == '-' ||
      first == '@' ||
      first == '\t' ||
      first == '\r') {
    return "'$raw";
  }
  return raw;
}

/// Isolate-safe money formatter independent of main-isolate static fields.
String _formatPaiseWithSymbol(int paise, String symbol) {
  final isNeg = paise < 0;
  final absPaise = isNeg ? -paise : paise;
  final major = absPaise / 100.0;
  final locale = switch (symbol) {
    '₹' => 'en_IN',
    '€' => 'en_IE',
    _ => 'en_US',
  };
  final formatter = NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: 2,
  );
  final formatted = formatter.format(major);
  return isNeg ? '-$formatted' : formatted;
}

String _formatSignedPaise(int paise, String symbol) {
  if (paise > 0) return '+${_formatPaiseWithSymbol(paise, symbol)}';
  return _formatPaiseWithSymbol(paise, symbol);
}

String _formatCompactAxisAmount(num majorValue, String symbol) {
  final absVal = majorValue.abs();
  final sign = majorValue < 0 ? '-' : '';
  if (symbol == '₹') {
    if (absVal >= 10000000) {
      return '$sign$symbol${(absVal / 10000000).toStringAsFixed(1)}Cr';
    }
    if (absVal >= 100000) {
      return '$sign$symbol${(absVal / 100000).toStringAsFixed(1)}L';
    }
  } else {
    if (absVal >= 1000000) {
      return '$sign$symbol${(absVal / 1000000).toStringAsFixed(1)}M';
    }
  }
  if (absVal >= 1000) {
    return '$sign$symbol${(absVal / 1000).toStringAsFixed(absVal % 1000 == 0 ? 0 : 1)}k';
  }
  return '$sign$symbol${absVal.round()}';
}

String _buildAsciiBar(int value, int peak, {int maxWidth = 18}) {
  if (peak <= 0 || value <= 0) return '·';
  final units = ((value / peak) * maxWidth).round().clamp(1, maxWidth);
  return '█' * units;
}

class _MergedStreamNode {
  final List<Expense> list;
  int index;
  _MergedStreamNode(this.list, this.index);
  Expense get current => list[index];
}

// Top-level streaming CSV generator inside a spawned Isolate.
// Writes UTF-8 BOM + structured sections via IOSink for O(chunkSize) memory even at 250k+ rows.
Future<void> _streamCsvIsolate(Map<String, dynamic> params) async {
  final List<Map<String, dynamic>> rawEntries =
      List<Map<String, dynamic>>.from(params['entries'] as List);
  final List<Map<String, dynamic>> wsSummaries =
      List<Map<String, dynamic>>.from(params['wsSummaries'] as List);
  final List<Map<String, dynamic>> currencySummaries =
      List<Map<String, dynamic>>.from(params['currencySummaries'] as List);
  final List<Map<String, dynamic>> chartSeries =
      List<Map<String, dynamic>>.from(params['chartSeries'] as List);
  final bool includeCharts = params['includeCharts'] == true;
  final String outputPath = params['outputPath'] as String;
  final int chunkSize = params['chunkSize'] as int;
  final String title = params['title'] as String;
  final String brandUpper = params['brandUpper'] as String;
  final String brandTag = params['brandTag'] as String;
  final String scopeLabel = params['scopeLabel'] as String;
  final String periodLabel = params['periodLabel'] as String;
  final String generatedLabel = params['generatedLabel'] as String;
  final SendPort sendPort = params['sendPort'] as SendPort;

  IOSink? sink;
  try {
    final file = File(outputPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    sink = file.openWrite(mode: FileMode.writeOnly);

    // Prepend UTF-8 BOM so Excel / mobile spreadsheet apps render ₹, €, £ cleanly
    sink.add(const [0xEF, 0xBB, 0xBF]);

    const converter = ListToCsvConverter();
    final dateFmt = DateFormat('yyyy-MM-dd');

    // Section 1: Centered Brand Masthead & Metadata
    final headerBlock = <List<dynamic>>[
      ['', '', brandUpper, 'FINANCIAL TRACKING STATEMENT', '', '', ''],
      ['', '', 'App: ${sanitizeCsvCell(brandTag)}', 'Scope: ${sanitizeCsvCell(scopeLabel)}', 'Period: $periodLabel', 'Generated: $generatedLabel', ''],
      [],
      ['SUMMARY BY WORKSPACE', 'Currency', 'Opening Balance', 'Confirmed Income (+)', 'Total Expenses (-)', 'Net Transfers (+/-)', 'Closing Balance', 'Pending Income', 'Vault Locked', 'Expenses #', 'Incomes #', 'Transfers #'],
    ];

    for (final s in wsSummaries) {
      final cur = s['currency'] as String;
      headerBlock.add([
        sanitizeCsvCell(s['wsName'] as String),
        cur,
        _formatPaiseWithSymbol(s['openingBalancePaise'] as int, cur),
        _formatPaiseWithSymbol(s['confirmedIncomePaise'] as int, cur),
        _formatPaiseWithSymbol(s['totalExpensePaise'] as int, cur),
        _formatSignedPaise(s['netTransferPaise'] as int, cur),
        _formatPaiseWithSymbol(s['closingBalancePaise'] as int, cur),
        _formatPaiseWithSymbol(s['pendingIncomePaise'] as int, cur),
        _formatPaiseWithSymbol(s['vaultLockedPaise'] as int, cur),
        s['expenseCount'] as int,
        s['incomeCount'] as int,
        s['transferCount'] as int,
      ]);
    }

    if (currencySummaries.isNotEmpty) {
      headerBlock.add([]);
      headerBlock.add([
        'CONSOLIDATED BY CURRENCY',
        'Currency',
        'Opening Balance',
        'Confirmed Income (+)',
        'Total Expenses (-)',
        'Net Transfers (+/-)',
        'Closing Balance',
        'Pending Income',
        'Vault Locked',
        'Expenses #',
        'Incomes #',
        'Transfers #',
      ]);
      for (final c in currencySummaries) {
        final cur = c['currency'] as String;
        headerBlock.add([
          'All Selected ($cur)',
          cur,
          _formatPaiseWithSymbol(c['openingBalancePaise'] as int, cur),
          _formatPaiseWithSymbol(c['confirmedIncomePaise'] as int, cur),
          _formatPaiseWithSymbol(c['totalExpensePaise'] as int, cur),
          _formatSignedPaise(c['netTransferPaise'] as int, cur),
          _formatPaiseWithSymbol(c['closingBalancePaise'] as int, cur),
          _formatPaiseWithSymbol(c['pendingIncomePaise'] as int, cur),
          _formatPaiseWithSymbol(c['vaultLockedPaise'] as int, cur),
          c['expenseCount'] as int,
          c['incomeCount'] as int,
          c['transferCount'] as int,
        ]);
      }
    }

    if (includeCharts && chartSeries.isNotEmpty) {
      headerBlock.add([]);
      headerBlock.add([
        'EXPENSE VISUALIZATION SERIES',
        'Currency',
        'Granularity',
        'Period Bucket',
        'Expenses',
        'Cumulative Exp. Version',
        'Confirmed Income',
        'Avg Benchmark',
        'Visual Trend Bar',
        'Legend',
      ]);
      headerBlock.add([
        'LEGEND MARKING',
        '-',
        '-',
        'Chronological Axis',
        'Solid Expense Series',
        'Running Expense Total',
        'Confirmed Income Overlay',
        'Period Average Benchmark',
        '█ Proportional Spend Intensity',
        'Tip: Select Period + Expenses + Avg columns in Excel/Sheets -> Insert Line Chart',
      ]);

      for (final series in chartSeries) {
        final cur = series['currency'] as String;
        final gran = series['granularityLabel'] as String;
        final avgPaise = series['averagePerBucketPaise'] as int;
        final peakPaise = series['peakExpensePaise'] as int;
        final pts = List<Map<String, dynamic>>.from(series['points'] as List);
        for (final pt in pts) {
          final expP = pt['expensePaise'] as int;
          final cumP = pt['cumulativeExpensePaise'] as int;
          final incP = pt['incomePaise'] as int;
          headerBlock.add([
            '$cur Series',
            cur,
            gran,
            pt['label'] as String,
            (expP / 100.0).toStringAsFixed(2),
            (cumP / 100.0).toStringAsFixed(2),
            (incP / 100.0).toStringAsFixed(2),
            (avgPaise / 100.0).toStringAsFixed(2),
            _buildAsciiBar(expP, peakPaise),
            expP == peakPaise && peakPaise > 0 ? 'Peak' : '',
          ]);
        }
      }
    }

    headerBlock.add([]);
    headerBlock.add([
      'CHRONOLOGICAL FINANCIAL LEDGER (${sanitizeCsvCell(title)})',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);
    headerBlock.add([
      'Seq / Ver.',
      'Date',
      'Workspace',
      'Type',
      'Title / Description',
      'Category / Route',
      'Payment Method',
      'Account',
      'Currency',
      'Amount',
      'Balance Impact (+/-)',
      'Running Expense Total',
      'Running Net Balance',
      'Status',
    ]);

    sink.write('${converter.convert(headerBlock)}\r\n');
    await sink.flush();

    final totalCount = rawEntries.length;
    for (int i = 0; i < totalCount; i += chunkSize) {
      final end = (i + chunkSize) > totalCount ? totalCount : (i + chunkSize);
      final chunk = <List<dynamic>>[];
      for (int j = i; j < end; j++) {
        final e = rawEntries[j];
        final dt = DateTime.fromMillisecondsSinceEpoch(e['dateMs'] as int);
        final cur = e['currency'] as String;
        final amt = e['amountPaise'] as int;
        final delta = e['balanceDeltaPaise'] as int;
        final runExp = e['runningExpensePaise'] as int;
        final runBal = e['runningBalancePaise'] as int;
        chunk.add([
          e['seqLabel'] as String,
          dateFmt.format(dt),
          sanitizeCsvCell(e['wsName'] as String),
          e['typeLabel'] as String,
          sanitizeCsvCell(e['title'] as String),
          sanitizeCsvCell(e['categoryOrRoute'] as String),
          sanitizeCsvCell(e['paymentMethod'] as String),
          sanitizeCsvCell(e['accountName'] as String),
          cur,
          _formatPaiseWithSymbol(amt, cur),
          _formatSignedPaise(delta, cur),
          _formatPaiseWithSymbol(runExp, cur),
          _formatPaiseWithSymbol(runBal, cur),
          e['status'] as String,
        ]);
      }
      sink.write('${converter.convert(chunk)}\r\n');
      await sink.flush();
      sendPort.send(
        ((end / (totalCount > 0 ? totalCount : 1)) * 0.95).clamp(0.05, 0.95),
      );
    }

    await sink.flush();
    await sink.close();
    sink = null;

    sendPort.send(1.0);
    sendPort.send({'ok': true, 'path': outputPath});
  } catch (e) {
    try {
      await sink?.close();
      final f = File(outputPath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    sendPort.send({'ok': false, 'error': e.toString()});
  }
}

// Top-level Unicode, branded, chart-rich PDF generator inside a spawned Isolate.
Future<void> _buildPdfIsolate(Map<String, dynamic> params) async {
  final List<Map<String, dynamic>> rawEntries =
      List<Map<String, dynamic>>.from(params['entries'] as List);
  final List<Map<String, dynamic>> wsSummaries =
      List<Map<String, dynamic>>.from(params['wsSummaries'] as List);
  final List<Map<String, dynamic>> currencySummaries =
      List<Map<String, dynamic>>.from(params['currencySummaries'] as List);
  final List<Map<String, dynamic>> chartSeries =
      List<Map<String, dynamic>>.from(params['chartSeries'] as List);
  final bool includeCharts = params['includeCharts'] == true;
  final Uint8List? fontRegularBytes = params['fontRegular'] as Uint8List?;
  final Uint8List? fontBoldBytes = params['fontBold'] as Uint8List?;
  final Uint8List? logoBytes = params['logoBytes'] as Uint8List?;
  final DateTime start =
      DateTime.fromMillisecondsSinceEpoch(params['startMs'] as int);
  final DateTime end =
      DateTime.fromMillisecondsSinceEpoch(params['endMs'] as int);
  final String title = params['title'] as String;
  final String brandName = params['brandName'] as String;
  final String brandUpper = params['brandUpper'] as String;
  final String brandTag = params['brandTag'] as String;
  final String scopeLabel = params['scopeLabel'] as String;
  final String generatedLabel = params['generatedLabel'] as String;
  final int totalEntryCount = params['totalEntryCount'] as int;
  final int expenseCount = params['expenseCount'] as int;
  final int incomeCount = params['incomeCount'] as int;
  final int transferCount = params['transferCount'] as int;
  final bool wasTruncated = params['wasTruncated'] as bool;
  final SendPort sendPort = params['sendPort'] as SendPort;

  try {
    pw.ThemeData? themeData;
    if (fontRegularBytes != null && fontBoldBytes != null) {
      final baseFont = pw.Font.ttf(fontRegularBytes.buffer.asByteData());
      final boldFont = pw.Font.ttf(fontBoldBytes.buffer.asByteData());
      themeData = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      );
    }

    final pdf = pw.Document(
      theme: themeData,
      title: title,
      author: brandTag,
    );
    final pw.MemoryImage? logoImage =
        logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final dateFmt = DateFormat('yMMMd');
    final shortDateFmt = DateFormat('dd MMM yy');

    const brandGreen = PdfColor.fromInt(0xFF39693B);
    const brandGreenSoft = PdfColor.fromInt(0xFFEAF4E9);
    const surfaceWarm = PdfColor.fromInt(0xFFFBF7F0);
    const surfaceZebra = PdfColor.fromInt(0xFFF9F6F1);
    const inkDark = PdfColor.fromInt(0xFF1F1B13);
    const inkMuted = PdfColor.fromInt(0xFF5D5649);
    const creditTeal = PdfColor.fromInt(0xFF0F766E);
    const debitRed = PdfColor.fromInt(0xFFBA1A1A);
    const avgAmber = PdfColor.fromInt(0xFFD97706);
    const borderSoft = PdfColor.fromInt(0xFFDDD5C7);

    sendPort.send(0.2);

    pw.Widget buildLogoBadge() {
      if (logoImage != null) {
        return pw.Container(
          width: 40,
          height: 40,
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: brandGreen, width: 1),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 9,
            verticalRadius: 9,
            child: pw.Image(logoImage, fit: pw.BoxFit.cover),
          ),
        );
      }
      return pw.Container(
        width: 40,
        height: 40,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          color: brandGreen,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Text(
          'B',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    pw.Widget buildKpiBox(String label, String value, PdfColor accent) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: pw.BoxDecoration(
            color: surfaceWarm,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: borderSoft, width: 0.6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: const pw.TextStyle(fontSize: 6.8, color: inkMuted),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    pw.Widget buildChartSection(Map<String, dynamic> series) {
      final cur = series['currency'] as String;
      final gran = series['granularityLabel'] as String;
      final avgPaise = series['averagePerBucketPaise'] as int;
      final peakLabel = series['peakLabel'] as String;
      final peakPaise = series['peakExpensePaise'] as int;
      final totalIncomePaise = series['totalIncomePaise'] as int;
      final pts = List<Map<String, dynamic>>.from(series['points'] as List);
      final cats = List<Map<String, dynamic>>.from(series['categoryBreakdown'] as List);

      final xCount = pts.length;
      final bool isSinglePoint = xCount <= 1;
      final double xMax = isSinglePoint ? 1.0 : (xCount - 1).toDouble();

      int maxPaise = math.max(avgPaise, peakPaise);
      for (final p in pts) {
        final incP = p['incomePaise'] as int;
        if (incP > maxPaise) maxPaise = incP;
      }
      final double rawTopMajor = math.max(10.0, (maxPaise / 100.0) * 1.22);
      final double yStep = (rawTopMajor / 4).ceilToDouble();
      final double yTop = yStep * 4;

      final List<double> yTicks = [0.0, yStep, yStep * 2, yStep * 3, yTop];

      // Sparse X-axis tick indices (<= 7 labels) so labels remain spacious and legible
      final List<int> xTicks;
      if (isSinglePoint) {
        xTicks = [0, 1];
      } else if (xCount <= 7) {
        xTicks = List<int>.generate(xCount, (i) => i);
      } else {
        final step = ((xCount - 1) / 5).ceil();
        final set = <int>{0};
        for (int i = step; i < xCount - 1; i += step) {
          set.add(i);
        }
        set.add(xCount - 1);
        xTicks = set.toList()..sort();
      }

      final expSpots = isSinglePoint
          ? [
              pw.PointChartValue(
                0.5,
                (pts.first['expensePaise'] as int) / 100.0,
              ),
            ]
          : [
              for (int i = 0; i < xCount; i++)
                pw.PointChartValue(
                  i.toDouble(),
                  (pts[i]['expensePaise'] as int) / 100.0,
                ),
            ];

      final avgMajor = avgPaise / 100.0;
      final avgSpots = [
        pw.PointChartValue(0.0, avgMajor),
        pw.PointChartValue(xMax, avgMajor),
      ];

      final datasets = <pw.Dataset>[
        pw.LineDataSet<pw.PointChartValue>(
          legend: 'Expenses ($cur)',
          color: brandGreen,
          lineWidth: 1.8,
          isCurved: !isSinglePoint && xCount >= 4 && xCount <= 31,
          drawPoints: true,
          pointSize: 2.2,
          drawSurface: !isSinglePoint,
          surfaceOpacity: 0.14,
          data: expSpots,
        ),
        pw.LineDataSet<pw.PointChartValue>(
          legend: 'Avg (${_formatPaiseWithSymbol(avgPaise, cur)})',
          color: avgAmber,
          lineWidth: 1.2,
          drawPoints: false,
          data: avgSpots,
        ),
      ];

      if (totalIncomePaise > 0) {
        final incSpots = isSinglePoint
            ? [
                pw.PointChartValue(
                  0.5,
                  (pts.first['incomePaise'] as int) / 100.0,
                ),
              ]
            : [
                for (int i = 0; i < xCount; i++)
                  pw.PointChartValue(
                    i.toDouble(),
                    (pts[i]['incomePaise'] as int) / 100.0,
                  ),
              ];
        datasets.add(
          pw.LineDataSet<pw.PointChartValue>(
            legend: 'Income ($cur)',
            color: creditTeal,
            lineWidth: 1.3,
            isCurved: !isSinglePoint && xCount >= 4 && xCount <= 31,
            drawPoints: true,
            pointSize: 2.0,
            data: incSpots,
          ),
        );
      }

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: borderSoft, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Expense Visualization ($gran - $cur)',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: inkDark,
                  ),
                ),
                pw.Text(
                  'Peak: $peakLabel (${_formatPaiseWithSymbol(peakPaise, cur)})  •  Avg/bin: ${_formatPaiseWithSymbol(avgPaise, cur)}',
                  style: const pw.TextStyle(fontSize: 7.8, color: inkMuted),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.SizedBox(
              height: 150,
              child: pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis<int>(
                    xTicks,
                    textStyle: const pw.TextStyle(fontSize: 7, color: inkMuted),
                    format: (v) {
                      final idx = v.toInt();
                      if (isSinglePoint) {
                        return idx == 0 ? pts.first['label'] as String : '';
                      }
                      if (idx >= 0 && idx < pts.length) {
                        return pts[idx]['label'] as String;
                      }
                      return '';
                    },
                    marginStart: 8,
                    marginEnd: 8,
                  ),
                  yAxis: pw.FixedAxis<double>(
                    yTicks,
                    divisions: true,
                    divisionsDashed: true,
                    divisionsColor: PdfColors.grey300,
                    textStyle: const pw.TextStyle(fontSize: 7, color: inkMuted),
                    format: (v) => _formatCompactAxisAmount(v, cur),
                  ),
                ),
                overlay: pw.ChartLegend(
                  position: pw.Alignment.topRight,
                  direction: pw.Axis.horizontal,
                  textStyle: const pw.TextStyle(fontSize: 7.2, color: inkDark),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: borderSoft, width: 0.6),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                ),
                datasets: datasets,
              ),
            ),
            if (cats.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 8,
                runSpacing: 4,
                children: cats.take(6).map((c) {
                  final name = c['category'] as String;
                  final tot = c['totalPaise'] as int;
                  final pct = (c['pct'] as num).toDouble();
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: brandGreenSoft,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      '$name: ${_formatPaiseWithSymbol(tot, cur)} (${pct.toStringAsFixed(0)}%)',
                      style: const pw.TextStyle(fontSize: 7, color: brandGreen),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );
    }

    sendPort.send(0.45);

    final ledgerTableHeaders = [
      'Ver.',
      'Date',
      'Profile',
      'Type',
      'Description',
      'Category / Route',
      'Amount (+/-)',
      'Run. Exp.',
      'Net Balance',
    ];

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(32),
      1: const pw.FixedColumnWidth(48),
      2: const pw.FixedColumnWidth(52),
      3: const pw.FixedColumnWidth(46),
      4: const pw.FlexColumnWidth(2.1),
      5: const pw.FlexColumnWidth(1.5),
      6: const pw.FixedColumnWidth(68),
      7: const pw.FixedColumnWidth(68),
      8: const pw.FixedColumnWidth(72),
    };

    pw.TableRow buildLedgerHeaderRow() => pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: brandGreen),
          children: ledgerTableHeaders
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 3.5,
                    vertical: 4.5,
                  ),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontSize: 7.2,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              )
              .toList(),
        );

    pw.TableRow buildLedgerRow(int rowIdx, Map<String, dynamic> e) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e['dateMs'] as int);
      final cur = e['currency'] as String;
      final amt = e['amountPaise'] as int;
      final delta = e['balanceDeltaPaise'] as int;
      final runExp = e['runningExpensePaise'] as int;
      final runBal = e['runningBalancePaise'] as int;
      final typeName = e['typeName'] as String;
      final isIncome = typeName.startsWith('income');
      final isExpense = typeName == 'expense';

      final amtStr = isIncome
          ? '+${_formatPaiseWithSymbol(amt, cur)}'
          : isExpense
              ? '-${_formatPaiseWithSymbol(amt, cur)}'
              : delta != 0
                  ? _formatSignedPaise(delta, cur)
                  : _formatPaiseWithSymbol(amt, cur);

      final amtColor = isIncome
          ? creditTeal
          : isExpense
              ? debitRed
              : delta < 0
                  ? debitRed
                  : delta > 0
                      ? creditTeal
                      : inkMuted;

      return pw.TableRow(
        decoration: rowIdx.isOdd
            ? const pw.BoxDecoration(color: surfaceZebra)
            : null,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Text(
              e['seqLabel'] as String,
              style: pw.TextStyle(
                fontSize: 6.8,
                fontWeight: pw.FontWeight.bold,
                color: isExpense
                    ? brandGreen
                    : isIncome
                        ? creditTeal
                        : inkMuted,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Text(
              shortDateFmt.format(dt),
              style: const pw.TextStyle(fontSize: 7, color: inkDark),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Text(
              e['wsName'] as String,
              style: const pw.TextStyle(fontSize: 7, color: inkDark),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Text(
              e['typeLabel'] as String,
              style: const pw.TextStyle(fontSize: 6.8, color: inkMuted),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Text(
              e['title'] as String,
              style: const pw.TextStyle(fontSize: 7, color: inkDark),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Text(
              '${e['categoryOrRoute']} (${e['accountName']})',
              style: const pw.TextStyle(fontSize: 6.8, color: inkMuted),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                amtStr,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: amtColor,
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                _formatPaiseWithSymbol(runExp, cur),
                style: const pw.TextStyle(fontSize: 7, color: inkMuted),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                _formatPaiseWithSymbol(runBal, cur),
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: inkDark,
                ),
              ),
            ),
          ),
        ],
      );
    }

    pw.Widget buildRunningHeader() => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: borderSoft, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '$brandName Financial Statement  •  $scopeLabel',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: brandGreen,
                ),
              ),
              pw.Text(
                '${dateFmt.format(start)} – ${dateFmt.format(end)}',
                style: const pw.TextStyle(fontSize: 8, color: inkMuted),
              ),
            ],
          ),
        );

    pw.Widget buildPageFooter(String pageTag) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: borderSoft, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by $brandTag  •  $generatedLabel',
                style: const pw.TextStyle(fontSize: 7.5, color: inkMuted),
              ),
              pw.Text(
                pageTag,
                style: const pw.TextStyle(fontSize: 7.5, color: inkMuted),
              ),
            ],
          ),
        );

    final bool inlineSmallLedger = rawEntries.length <= 18;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 30),
        maxPages: 25,
        header: (pw.Context ctx) {
          if (ctx.pageNumber == 1) return pw.SizedBox.shrink();
          return buildRunningHeader();
        },
        footer: (pw.Context ctx) =>
            buildPageFooter('Summary • Page ${ctx.pageNumber} of ${ctx.pagesCount}'),
        build: (pw.Context ctx) {
          final widgets = <pw.Widget>[
            // Top-Center Professional Brand Masthead
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  buildLogoBadge(),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    brandUpper,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: brandGreen,
                      letterSpacing: 1.8,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: inkDark,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: brandGreenSoft,
                      borderRadius: pw.BorderRadius.all(
                        pw.Radius.circular(12),
                      ),
                    ),
                    child: pw.Text(
                      '$scopeLabel  •  ${dateFmt.format(start)} – ${dateFmt.format(end)}',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: brandGreen,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Statement Generated: $generatedLabel  •  $expenseCount Expenses · $incomeCount Incomes · $transferCount Transfers',
                    style: const pw.TextStyle(fontSize: 7.8, color: inkMuted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: brandGreen, thickness: 1.2),
            pw.SizedBox(height: 8),
          ];

          // Per-Currency Executive Balance Reconciliation Cards
          for (final c in currencySummaries) {
            final cur = c['currency'] as String;
            final opening = c['openingBalancePaise'] as int;
            final confInc = c['confirmedIncomePaise'] as int;
            final expTot = c['totalExpensePaise'] as int;
            final netTrf = c['netTransferPaise'] as int;
            final closing = c['closingBalancePaise'] as int;
            final pendInc = c['pendingIncomePaise'] as int;
            final vaultLock = c['vaultLockedPaise'] as int;

            widgets.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Balance Reconciliation ($cur)',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: inkDark,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      buildKpiBox(
                        'Opening Balance',
                        _formatPaiseWithSymbol(opening, cur),
                        inkDark,
                      ),
                      pw.SizedBox(width: 5),
                      buildKpiBox(
                        'Confirmed Income (+)',
                        '+${_formatPaiseWithSymbol(confInc, cur)}',
                        creditTeal,
                      ),
                      pw.SizedBox(width: 5),
                      buildKpiBox(
                        'Total Expenses (-)',
                        '-${_formatPaiseWithSymbol(expTot, cur)}',
                        debitRed,
                      ),
                      pw.SizedBox(width: 5),
                      buildKpiBox(
                        'Net Transfers',
                        _formatSignedPaise(netTrf, cur),
                        inkMuted,
                      ),
                      pw.SizedBox(width: 5),
                      buildKpiBox(
                        'Closing Balance',
                        _formatPaiseWithSymbol(closing, cur),
                        brandGreen,
                      ),
                    ],
                  ),
                  if (pendInc > 0 || vaultLock > 0) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      [
                        if (pendInc > 0)
                          'Pending Income (excluded from cash balance): ${_formatPaiseWithSymbol(pendInc, cur)}',
                        if (vaultLock > 0)
                          'Locked in Savings Vaults: ${_formatPaiseWithSymbol(vaultLock, cur)}',
                      ].join('  •  '),
                      style: const pw.TextStyle(fontSize: 7.2, color: inkMuted),
                    ),
                  ],
                  pw.SizedBox(height: 8),
                ],
              ),
            );
          }

          // Workspace Breakdown Table
          if (wsSummaries.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Workspace Breakdown',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: inkDark,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(color: borderSoft, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: brandGreenSoft),
                    children: [
                      'Workspace',
                      'Opening',
                      'Income (+)',
                      'Expenses (-)',
                      'Transfers',
                      'Closing',
                      'Entries',
                    ]
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4.5),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                fontSize: 7.8,
                                fontWeight: pw.FontWeight.bold,
                                color: brandGreen,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  ...wsSummaries.map((s) {
                    final cur = s['currency'] as String;
                    final cntSum = (s['expenseCount'] as int) +
                        (s['incomeCount'] as int) +
                        (s['transferCount'] as int);
                    return pw.TableRow(
                      children: [
                        '${s['wsName']} ($cur)',
                        _formatPaiseWithSymbol(s['openingBalancePaise'] as int, cur),
                        '+${_formatPaiseWithSymbol(s['confirmedIncomePaise'] as int, cur)}',
                        '-${_formatPaiseWithSymbol(s['totalExpensePaise'] as int, cur)}',
                        _formatSignedPaise(s['netTransferPaise'] as int, cur),
                        _formatPaiseWithSymbol(s['closingBalancePaise'] as int, cur),
                        '$cntSum',
                      ]
                          .map(
                            (v) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                v,
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: inkDark,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 10));
          }

          // Visual Expense Line Charts (one chart per currency in scope)
          if (includeCharts && chartSeries.isNotEmpty) {
            for (final series in chartSeries) {
              widgets.add(buildChartSection(series));
            }
          }

          if (inlineSmallLedger && rawEntries.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Chronological Financial Ledger (${rawEntries.length} of $totalEntryCount entries)',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: inkDark,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(color: borderSoft, width: 0.45),
                columnWidths: columnWidths,
                children: [
                  buildLedgerHeaderRow(),
                  for (int i = 0; i < rawEntries.length; i++)
                    buildLedgerRow(i, rawEntries[i]),
                ],
              ),
            );
          }

          return widgets;
        },
      ),
    );

    // O(N) Linear Chunked Pages for Large Chronological Ledgers (> 18 rows)
    // Avoids O(P*N) quadratic layout cost on 4,000-row datasets.
    if (!inlineSmallLedger && rawEntries.isNotEmpty) {
      const int rowsPerPage = 28;
      final int ledgerPageCount = (rawEntries.length / rowsPerPage).ceil();
      for (int p = 0; p < ledgerPageCount; p++) {
        final startIdx = p * rowsPerPage;
        final endIdx = math.min(startIdx + rowsPerPage, rawEntries.length);
        final isLastLedgerPage = p == ledgerPageCount - 1;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 26),
            build: (pw.Context ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildRunningHeader(),
                if (p == 0) ...[
                  pw.Text(
                    'Chronological Financial Ledger (${rawEntries.length} of $totalEntryCount entries)',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: inkDark,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                ],
                pw.Table(
                  border: pw.TableBorder.all(color: borderSoft, width: 0.45),
                  columnWidths: columnWidths,
                  children: [
                    buildLedgerHeaderRow(),
                    for (int i = startIdx; i < endIdx; i++)
                      buildLedgerRow(i, rawEntries[i]),
                  ],
                ),
                if (isLastLedgerPage && wasTruncated) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFFFFBEB),
                      border: pw.Border.all(color: PdfColors.amber),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Text(
                      'Note: PDF ledger detail is capped at the most recent ${rawEntries.length} of $totalEntryCount matched entries to protect device RAM. All Opening Balance, Running Expense Totals, Charts, and Closing Balances above still reflect the complete dataset. Use CSV Export for the full un-truncated ledger.',
                      style: const pw.TextStyle(fontSize: 7.8, color: inkDark),
                    ),
                  ),
                ],
                pw.Spacer(),
                buildPageFooter('Ledger ${p + 1} of $ledgerPageCount'),
              ],
            ),
          ),
        );

        sendPort.send(0.45 + 0.40 * ((p + 1) / ledgerPageCount));
      }
    }

    sendPort.send(0.9);
    final bytes = await pdf.save();
    sendPort.send(1.0);
    sendPort.send(bytes);
  } catch (e) {
    sendPort.send(e.toString());
  }
}

ExportError _classifyError(Object error) {
  final errStr = error.toString().toLowerCase();
  if (errStr.contains('cancelled')) {
    return const ExportCancelledError();
  } else if (errStr.contains('permission') || errStr.contains('access denied')) {
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
  static Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    try {
      final bd = await rootBundle.load(assetPath);
      return bd.buffer.asUint8List();
    } catch (_) {
      try {
        final file = File(assetPath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (_) {}
    }
    return null;
  }

  /// Merges multiple pre-sorted descending workspace expense lists in O(N log W)
  /// time using a max-date priority heap.
  static List<Expense> mergeSortedDescending(List<List<Expense>> sortedStreams) {
    final active = sortedStreams.where((s) => s.isNotEmpty).toList();
    if (active.isEmpty) return const [];
    if (active.length == 1) return active.first;

    final pq = HeapPriorityQueue<_MergedStreamNode>(
      (a, b) => b.current.date.compareTo(a.current.date),
    );
    int totalLen = 0;
    for (final list in active) {
      totalLen += list.length;
      pq.add(_MergedStreamNode(list, 0));
    }

    final merged = List<Expense>.filled(totalLen, active.first.first, growable: false);
    int writeIdx = 0;
    while (pq.isNotEmpty) {
      final node = pq.removeFirst();
      merged[writeIdx++] = node.current;
      node.index++;
      if (node.index < node.list.length) {
        pq.add(node);
      }
    }
    return merged;
  }

  /// Resolves managed temporary export directory and prunes stale artifacts (> 24h).
  static Future<Directory> prepareExportDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/${AppConstants.kExportSubdirName}');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    } else {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      await for (final entity in exportDir.list()) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoff)) {
              await entity.delete();
            }
          } catch (_) {}
        }
      }
    }
    return exportDir;
  }

  /// Builds a fully reconciled, chronological statement snapshot from [ExportRequest].
  static ExportStatementSnapshot buildStatement(ExportRequest request) {
    return ExportStatementBuilder.build(
      targetWorkspaces: request.workspaces,
      expenses: request.expenses,
      allExpensesForReconciliation: request.allExpensesForReconciliation,
      incomes: request.incomes,
      allIncomesForReconciliation: request.allIncomesForReconciliation,
      transfers: request.transfers,
      allTransfersForReconciliation: request.allTransfersForReconciliation,
      accounts: request.accounts,
      vaults: request.vaults,
      accountNames: request.accountNames,
      allWorkspaceNames: request.allWorkspaceNames,
      range: request.range,
      fallbackCurrencySymbol: request.fallbackCurrencySymbol,
      includeArchived: request.includeArchived,
      includeExpenses: request.includeExpenses,
      includeIncomes: request.includeIncomes,
      includeTransfers: request.includeTransfers,
    );
  }

  /// Unified multi-workspace, streaming export entrypoint returning saved [File]
  /// (CSV or PDF) inside managed temp storage.
  static Future<ExportResult<File>> exportReport(
    ExportRequest request, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final exportDir = await prepareExportDirectory();
      final dateFmt = DateFormat('yyyyMMdd');
      final startStr = dateFmt.format(request.range.start);
      final endStr = dateFmt.format(request.range.end);
      final epochMs = DateTime.now().millisecondsSinceEpoch;

      final scopeTag = switch (request.scope) {
        ExportWorkspaceScope.single => request.workspaces.length == 1
            ? request.workspaces.first.name
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            : 'single',
        ExportWorkspaceScope.selective => 'selected_${request.workspaces.length}ws',
        ExportWorkspaceScope.combinedAll => 'all_workspaces',
      };

      final ext = request.format == ExportFormat.csv ? 'csv' : 'pdf';
      final fileName =
          '${AppBrand.fileSlug}_${scopeTag}_${startStr}_${endStr}_$epochMs.$ext';
      final outputPath = '${exportDir.path}/$fileName';

      if (request.format == ExportFormat.csv) {
        return await _executeStreamingCsvExport(
          request: request,
          outputPath: outputPath,
          onProgress: onProgress,
        );
      } else {
        final bytesRes = await _executePdfExport(
          request: request,
          onProgress: onProgress,
        );
        if (!bytesRes.isSuccess || bytesRes.value == null) {
          return ExportResult.failure(bytesRes.error);
        }
        final outFile = File(outputPath);
        await outFile.writeAsBytes(bytesRes.value!);
        return ExportResult.success(
          outFile,
          exportedCount: bytesRes.exportedCount,
          wasTruncatedForPdfCap: bytesRes.wasTruncatedForPdfCap,
        );
      }
    } catch (e) {
      return ExportResult.failure(_classifyError(e));
    }
  }

  static Future<ExportResult<File>> _executeStreamingCsvExport({
    required ExportRequest request,
    required String outputPath,
    void Function(double progress)? onProgress,
  }) async {
    final progressPort = ReceivePort();
    final errorPort = ReceivePort();
    final completer = Completer<ExportResult<File>>();

    final snapshot = buildStatement(request);
    final serializedEntries = snapshot.entries.map((e) => e.toMap()).toList();
    final wsSummariesPayload =
        snapshot.workspaceSummaries.map((s) => s.toMap()).toList();
    final currencySummariesPayload =
        snapshot.currencySummaries.map((c) => c.toMap()).toList();
    final chartSeriesPayload =
        snapshot.chartSeries.map((c) => c.toMap()).toList();

    final scopeLabel = _buildScopeLabel(request);
    final periodFmt = DateFormat('yMMMd');
    final periodLabel =
        '${periodFmt.format(request.range.start)} - ${periodFmt.format(request.range.end)}';
    final generatedLabel = DateFormat('yMMMd, HH:mm').format(DateTime.now());

    final isolate = await Isolate.spawn(
      _streamCsvIsolate,
      {
        'entries': serializedEntries,
        'wsSummaries': wsSummariesPayload,
        'currencySummaries': currencySummariesPayload,
        'chartSeries': chartSeriesPayload,
        'includeCharts': request.includeCharts,
        'outputPath': outputPath,
        'chunkSize': AppConstants.kExportChunkSize,
        'title': request.resolvedTitle,
        'brandName': AppBrand.appName,
        'brandUpper': AppBrand.appNameUpper,
        'brandTag': AppBrand.fullProductTitle,
        'scopeLabel': scopeLabel,
        'periodLabel': periodLabel,
        'generatedLabel': generatedLabel,
        'sendPort': progressPort.sendPort,
      },
      onError: errorPort.sendPort,
    );

    void cleanupPorts() {
      progressPort.close();
      errorPort.close();
    }

    request.cancellationToken?.attach(() {
      isolate.kill(priority: Isolate.immediate);
      cleanupPorts();
      try {
        final f = File(outputPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.complete(ExportResult.failure(const ExportCancelledError()));
      }
    });

    errorPort.listen((err) {
      isolate.kill();
      cleanupPorts();
      if (!completer.isCompleted) {
        completer.complete(ExportResult.failure(_classifyError(err.toString())));
      }
    });

    progressPort.listen((msg) {
      if (msg is double) {
        onProgress?.call(msg);
      } else if (msg is Map) {
        isolate.kill();
        cleanupPorts();
        if (!completer.isCompleted) {
          if (msg['ok'] == true) {
            completer.complete(
              ExportResult.success(
                File(msg['path'] as String),
                exportedCount: snapshot.totalEntryCount,
              ),
            );
          } else {
            completer.complete(
              ExportResult.failure(_classifyError(msg['error'] ?? 'Unknown error')),
            );
          }
        }
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        isolate.kill();
        cleanupPorts();
        return ExportResult.failure(const UnknownExportError('CSV export timed out.'));
      },
    );
  }

  static Future<ExportResult<Uint8List>> _executePdfExport({
    required ExportRequest request,
    void Function(double progress)? onProgress,
  }) async {
    final progressPort = ReceivePort();
    final errorPort = ReceivePort();
    final completer = Completer<ExportResult<Uint8List>>();

    final snapshot = buildStatement(request);
    final totalMatched = snapshot.totalEntryCount;
    final bool wasTruncated = totalMatched > AppConstants.kMaxPdfDetailRows;

    // Preserve most recent chronological entries when capped so closing balance matches live state
    final detailList = wasTruncated
        ? snapshot.entries.sublist(totalMatched - AppConstants.kMaxPdfDetailRows)
        : snapshot.entries;

    final serializedEntries = detailList.map((e) => e.toMap()).toList();
    final wsSummariesPayload =
        snapshot.workspaceSummaries.map((s) => s.toMap()).toList();
    final currencySummariesPayload =
        snapshot.currencySummaries.map((c) => c.toMap()).toList();
    final chartSeriesPayload =
        snapshot.chartSeries.map((c) => c.toMap()).toList();

    final fontRegularBytes = await _loadAssetBytes(AppConstants.kPdfFontRegularAsset);
    final fontBoldBytes = await _loadAssetBytes(AppConstants.kPdfFontBoldAsset);
    final logoBytes = await _loadAssetBytes(AppConstants.kPdfLogoAsset);

    final generatedLabel = DateFormat('yMMMd, HH:mm').format(DateTime.now());

    final isolate = await Isolate.spawn(
      _buildPdfIsolate,
      {
        'entries': serializedEntries,
        'wsSummaries': wsSummariesPayload,
        'currencySummaries': currencySummariesPayload,
        'chartSeries': chartSeriesPayload,
        'includeCharts': request.includeCharts,
        'fontRegular': fontRegularBytes,
        'fontBold': fontBoldBytes,
        'logoBytes': logoBytes,
        'startMs': request.range.start.millisecondsSinceEpoch,
        'endMs': request.range.end.millisecondsSinceEpoch,
        'title': request.resolvedTitle,
        'brandName': AppBrand.appName,
        'brandUpper': AppBrand.appNameUpper,
        'brandTag': AppBrand.fullProductTitle,
        'scopeLabel': _buildScopeLabel(request),
        'generatedLabel': generatedLabel,
        'totalEntryCount': totalMatched,
        'expenseCount': snapshot.totalExpenseCount,
        'incomeCount': snapshot.totalIncomeCount,
        'transferCount': snapshot.totalTransferCount,
        'wasTruncated': wasTruncated,
        'sendPort': progressPort.sendPort,
      },
      onError: errorPort.sendPort,
    );

    void cleanupPorts() {
      progressPort.close();
      errorPort.close();
    }

    request.cancellationToken?.attach(() {
      isolate.kill(priority: Isolate.immediate);
      cleanupPorts();
      if (!completer.isCompleted) {
        completer.complete(ExportResult.failure(const ExportCancelledError()));
      }
    });

    errorPort.listen((error) {
      isolate.kill();
      cleanupPorts();
      if (!completer.isCompleted) {
        completer.complete(ExportResult.failure(UnknownExportError(error.toString())));
      }
    });

    progressPort.listen((msg) {
      if (msg is double) {
        onProgress?.call(msg);
      } else if (msg is Uint8List) {
        isolate.kill();
        cleanupPorts();
        if (!completer.isCompleted) {
          completer.complete(
            ExportResult.success(
              msg,
              exportedCount: totalMatched,
              wasTruncatedForPdfCap: wasTruncated,
            ),
          );
        }
      } else if (msg is String) {
        isolate.kill();
        cleanupPorts();
        if (!completer.isCompleted) {
          completer.complete(ExportResult.failure(UnknownExportError(msg)));
        }
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        isolate.kill();
        cleanupPorts();
        return ExportResult.failure(const UnknownExportError('PDF generation timed out.'));
      },
    );
  }

  static String _buildScopeLabel(ExportRequest request) {
    return switch (request.scope) {
      ExportWorkspaceScope.single => request.workspaces.length == 1
          ? 'Workspace: ${request.workspaces.first.name}'
          : 'Single Workspace',
      ExportWorkspaceScope.selective =>
        'Selected (${request.workspaces.map((w) => w.name).join(', ')})',
      ExportWorkspaceScope.combinedAll =>
        request.workspaces.isEmpty
            ? 'All Workspaces'
            : 'Combined (${request.workspaces.length} Workspaces)',
    };
  }

  // ---- Legacy Backward-Compatible Wrappers ----

  static Future<ExportResult<File>> exportExpensesCsv({
    required List<Expense> expenses,
    required DateTimeRange range,
  }) {
    return exportReport(
      ExportRequest(
        scope: ExportWorkspaceScope.single,
        workspaces: const [],
        expenses: expenses,
        range: range,
        format: ExportFormat.csv,
        fallbackCurrencySymbol: MoneyFormatter.symbol,
      ),
    );
  }

  static Future<ExportResult<Uint8List>> buildExpensesPdfBytes({
    required List<Expense> expenses,
    required DateTimeRange range,
    required String title,
    required void Function(double progress) onProgress,
  }) {
    return _executePdfExport(
      request: ExportRequest(
        scope: ExportWorkspaceScope.single,
        workspaces: const [],
        expenses: expenses,
        range: range,
        format: ExportFormat.pdf,
        fallbackCurrencySymbol: MoneyFormatter.symbol,
        title: title,
      ),
      onProgress: onProgress,
    );
  }
}
