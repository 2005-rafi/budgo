import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/transfer_status.dart';
import 'package:expense/models/workspace.dart';

enum ExportLedgerEntryType {
  expense,
  incomeConfirmed,
  incomePending,
  transferOut,
  transferIn,
  transferSelf,
}

extension ExportLedgerEntryTypeX on ExportLedgerEntryType {
  String get label => switch (this) {
        ExportLedgerEntryType.expense => 'Expense',
        ExportLedgerEntryType.incomeConfirmed => 'Income',
        ExportLedgerEntryType.incomePending => 'Income (Pending)',
        ExportLedgerEntryType.transferOut => 'Transfer Out',
        ExportLedgerEntryType.transferIn => 'Transfer In',
        ExportLedgerEntryType.transferSelf => 'Self Transfer',
      };

  int get sortOrder => switch (this) {
        ExportLedgerEntryType.incomeConfirmed => 0,
        ExportLedgerEntryType.incomePending => 1,
        ExportLedgerEntryType.transferIn => 2,
        ExportLedgerEntryType.transferSelf => 3,
        ExportLedgerEntryType.expense => 4,
        ExportLedgerEntryType.transferOut => 5,
      };
}

class ExportLedgerEntry {
  final String seqLabel;
  final int? expenseVersion;
  final DateTime date;
  final String workspaceId;
  final String workspaceName;
  final String currency;
  final ExportLedgerEntryType type;
  final String title;
  final String categoryOrRoute;
  final String paymentMethod;
  final String accountName;
  final int amountPaise;
  final int balanceDeltaPaise;
  final int runningExpensePaise;
  final int runningBalancePaise;
  final String status;

  const ExportLedgerEntry({
    required this.seqLabel,
    this.expenseVersion,
    required this.date,
    required this.workspaceId,
    required this.workspaceName,
    required this.currency,
    required this.type,
    required this.title,
    required this.categoryOrRoute,
    required this.paymentMethod,
    required this.accountName,
    required this.amountPaise,
    required this.balanceDeltaPaise,
    required this.runningExpensePaise,
    required this.runningBalancePaise,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'seqLabel': seqLabel,
        'expenseVersion': expenseVersion,
        'dateMs': date.millisecondsSinceEpoch,
        'wsId': workspaceId,
        'wsName': workspaceName,
        'currency': currency,
        'typeName': type.name,
        'typeLabel': type.label,
        'title': title,
        'categoryOrRoute': categoryOrRoute,
        'paymentMethod': paymentMethod,
        'accountName': accountName,
        'amountPaise': amountPaise,
        'balanceDeltaPaise': balanceDeltaPaise,
        'runningExpensePaise': runningExpensePaise,
        'runningBalancePaise': runningBalancePaise,
        'status': status,
      };
}

class WorkspaceFinancialSummary {
  final String workspaceId;
  final String workspaceName;
  final String currency;
  final int openingBalancePaise;
  final int confirmedIncomePaise;
  final int pendingIncomePaise;
  final int totalExpensePaise;
  final int netTransferPaise;
  final int closingBalancePaise;
  final int currentLiveBalancePaise;
  final int vaultLockedPaise;
  final int expenseCount;
  final int incomeCount;
  final int transferCount;
  final int hiddenArchivedExpensePaise;
  final bool hasAccountSnapshot;

  const WorkspaceFinancialSummary({
    required this.workspaceId,
    required this.workspaceName,
    required this.currency,
    required this.openingBalancePaise,
    required this.confirmedIncomePaise,
    required this.pendingIncomePaise,
    required this.totalExpensePaise,
    required this.netTransferPaise,
    required this.closingBalancePaise,
    required this.currentLiveBalancePaise,
    required this.vaultLockedPaise,
    required this.expenseCount,
    required this.incomeCount,
    required this.transferCount,
    required this.hiddenArchivedExpensePaise,
    required this.hasAccountSnapshot,
  });

  Map<String, dynamic> toMap() => {
        'wsId': workspaceId,
        'wsName': workspaceName,
        'currency': currency,
        'openingBalancePaise': openingBalancePaise,
        'confirmedIncomePaise': confirmedIncomePaise,
        'pendingIncomePaise': pendingIncomePaise,
        'totalExpensePaise': totalExpensePaise,
        'netTransferPaise': netTransferPaise,
        'closingBalancePaise': closingBalancePaise,
        'currentLiveBalancePaise': currentLiveBalancePaise,
        'vaultLockedPaise': vaultLockedPaise,
        'expenseCount': expenseCount,
        'incomeCount': incomeCount,
        'transferCount': transferCount,
        'hiddenArchivedExpensePaise': hiddenArchivedExpensePaise,
        'hasAccountSnapshot': hasAccountSnapshot,
      };
}

class CurrencyFinancialSummary {
  final String currency;
  final int openingBalancePaise;
  final int confirmedIncomePaise;
  final int pendingIncomePaise;
  final int totalExpensePaise;
  final int netTransferPaise;
  final int closingBalancePaise;
  final int vaultLockedPaise;
  final int expenseCount;
  final int incomeCount;
  final int transferCount;

  const CurrencyFinancialSummary({
    required this.currency,
    required this.openingBalancePaise,
    required this.confirmedIncomePaise,
    required this.pendingIncomePaise,
    required this.totalExpensePaise,
    required this.netTransferPaise,
    required this.closingBalancePaise,
    required this.vaultLockedPaise,
    required this.expenseCount,
    required this.incomeCount,
    required this.transferCount,
  });

  int get netChangePaise =>
      confirmedIncomePaise - totalExpensePaise + netTransferPaise;

  Map<String, dynamic> toMap() => {
        'currency': currency,
        'openingBalancePaise': openingBalancePaise,
        'confirmedIncomePaise': confirmedIncomePaise,
        'pendingIncomePaise': pendingIncomePaise,
        'totalExpensePaise': totalExpensePaise,
        'netTransferPaise': netTransferPaise,
        'closingBalancePaise': closingBalancePaise,
        'vaultLockedPaise': vaultLockedPaise,
        'expenseCount': expenseCount,
        'incomeCount': incomeCount,
        'transferCount': transferCount,
      };
}

class ExportChartPoint {
  final int index;
  final String label;
  final int expensePaise;
  final int cumulativeExpensePaise;
  final int incomePaise;

  const ExportChartPoint({
    required this.index,
    required this.label,
    required this.expensePaise,
    required this.cumulativeExpensePaise,
    required this.incomePaise,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'label': label,
        'expensePaise': expensePaise,
        'cumulativeExpensePaise': cumulativeExpensePaise,
        'incomePaise': incomePaise,
      };
}

class ExportChartSeries {
  final String currency;
  final String granularityLabel;
  final List<ExportChartPoint> points;
  final int totalExpensePaise;
  final int totalIncomePaise;
  final int averagePerBucketPaise;
  final String peakLabel;
  final int peakExpensePaise;
  final List<Map<String, dynamic>> categoryBreakdown;

  const ExportChartSeries({
    required this.currency,
    required this.granularityLabel,
    required this.points,
    required this.totalExpensePaise,
    required this.totalIncomePaise,
    required this.averagePerBucketPaise,
    required this.peakLabel,
    required this.peakExpensePaise,
    required this.categoryBreakdown,
  });

  Map<String, dynamic> toMap() => {
        'currency': currency,
        'granularityLabel': granularityLabel,
        'points': points.map((p) => p.toMap()).toList(),
        'totalExpensePaise': totalExpensePaise,
        'totalIncomePaise': totalIncomePaise,
        'averagePerBucketPaise': averagePerBucketPaise,
        'peakLabel': peakLabel,
        'peakExpensePaise': peakExpensePaise,
        'categoryBreakdown': categoryBreakdown,
      };
}

class ExportStatementSnapshot {
  final List<ExportLedgerEntry> entries;
  final List<WorkspaceFinancialSummary> workspaceSummaries;
  final List<CurrencyFinancialSummary> currencySummaries;
  final List<ExportChartSeries> chartSeries;
  final int totalExpenseCount;
  final int totalIncomeCount;
  final int totalTransferCount;

  const ExportStatementSnapshot({
    required this.entries,
    required this.workspaceSummaries,
    required this.currencySummaries,
    required this.chartSeries,
    required this.totalExpenseCount,
    required this.totalIncomeCount,
    required this.totalTransferCount,
  });

  int get totalEntryCount => entries.length;
}

class _RawLedgerEvent {
  final DateTime date;
  final String workspaceId;
  final String workspaceName;
  final String currency;
  final ExportLedgerEntryType type;
  final String title;
  final String categoryOrRoute;
  final String paymentMethod;
  final String accountName;
  final int amountPaise;
  final int balanceDeltaPaise;
  final String status;

  const _RawLedgerEvent({
    required this.date,
    required this.workspaceId,
    required this.workspaceName,
    required this.currency,
    required this.type,
    required this.title,
    required this.categoryOrRoute,
    required this.paymentMethod,
    required this.accountName,
    required this.amountPaise,
    required this.balanceDeltaPaise,
    required this.status,
  });
}

/// Pure domain builder assembling reconciled opening/closing balances,
/// versioned cumulative expense totals (`E#1..N`), multi-entity chronological ledgers,
/// and per-currency expense trend series for CSV & PDF financial statements.
class ExportStatementBuilder {
  ExportStatementBuilder._();

  static String _normWs(String? id) =>
      (id == null || id.isEmpty) ? AppConstants.kDefaultWorkspaceId : id;

  static ExportStatementSnapshot build({
    required List<Workspace> targetWorkspaces,
    required List<Expense> expenses,
    List<Expense>? allExpensesForReconciliation,
    List<Income> incomes = const [],
    List<Income>? allIncomesForReconciliation,
    List<Transfer> transfers = const [],
    List<Transfer>? allTransfersForReconciliation,
    List<Account> accounts = const [],
    List<SavingsVault> vaults = const [],
    Map<String, String> accountNames = const {},
    Map<String, String> allWorkspaceNames = const {},
    required DateTimeRange range,
    String fallbackCurrencySymbol = '₹',
    bool includeArchived = false,
    bool includeExpenses = true,
    bool includeIncomes = true,
    bool includeTransfers = true,
  }) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    final Map<String, Workspace> wsMap = {
      for (final w in targetWorkspaces) _normWs(w.id): w,
    };

    String wsNameFor(String wsId) {
      final norm = _normWs(wsId);
      return wsMap[norm]?.name ??
          allWorkspaceNames[norm] ??
          (norm == AppConstants.kDefaultWorkspaceId ? 'Personal' : norm);
    }

    String currencyFor(String wsId) {
      final norm = _normWs(wsId);
      return wsMap[norm]?.currency ?? fallbackCurrencySymbol;
    }

    // Determine exact scope workspace IDs (supports legacy callers with empty targetWorkspaces)
    final Set<String> scopeIds = {
      for (final w in targetWorkspaces) _normWs(w.id),
    };
    if (scopeIds.isEmpty) {
      for (final e in expenses) {
        scopeIds.add(_normWs(e.workspaceId));
      }
      for (final i in incomes) {
        scopeIds.add(_normWs(i.workspaceId));
      }
      for (final t in transfers) {
        scopeIds.add(_normWs(t.sourceWorkspaceId));
        scopeIds.add(_normWs(t.destinationWorkspaceId));
      }
      if (scopeIds.isEmpty) {
        scopeIds.add(AppConstants.kDefaultWorkspaceId);
      }
    }

    // Build account & vault snapshots per scoped workspace
    final Map<String, String> resolvedAccountNames = Map.of(accountNames);
    final Map<String, int> liveBalanceByWs = {};
    final Map<String, bool> hasAccountSnapshotByWs = {};
    final Map<String, int> vaultLockedByWs = {};

    for (final a in accounts) {
      resolvedAccountNames[a.id] = a.name;
      final wsId = _normWs(a.workspaceId);
      if (!scopeIds.contains(wsId)) continue;
      hasAccountSnapshotByWs[wsId] = true;
      liveBalanceByWs[wsId] = (liveBalanceByWs[wsId] ?? 0) + a.balancePaise;
    }
    for (final v in vaults) {
      if (v.isArchived) continue;
      final wsId = _normWs(v.workspaceId);
      if (!scopeIds.contains(wsId)) continue;
      vaultLockedByWs[wsId] = (vaultLockedByWs[wsId] ?? 0) + v.currentPaise;
    }

    // Reconcile historical post-range and hidden-archived deltas
    final allExp = allExpensesForReconciliation ?? expenses;
    final allInc = allIncomesForReconciliation ?? incomes;
    final allTrf = allTransfersForReconciliation ?? transfers;

    final Map<String, int> postRangeDeltaByWs = {};
    final Map<String, int> inRangeHiddenArchivedExpByWs = {};

    for (final e in allExp) {
      final wsId = _normWs(e.workspaceId);
      if (!scopeIds.contains(wsId)) continue;
      if (e.date.isAfter(end)) {
        postRangeDeltaByWs[wsId] = (postRangeDeltaByWs[wsId] ?? 0) - e.amount;
      } else if (!e.date.isBefore(start) && e.isArchived && !includeArchived) {
        inRangeHiddenArchivedExpByWs[wsId] =
            (inRangeHiddenArchivedExpByWs[wsId] ?? 0) + e.amount;
      }
    }

    for (final i in allInc) {
      final wsId = _normWs(i.workspaceId);
      if (!scopeIds.contains(wsId) || !i.isConfirmed) continue;
      if (i.date.isAfter(end)) {
        postRangeDeltaByWs[wsId] = (postRangeDeltaByWs[wsId] ?? 0) + i.amount;
      }
    }

    for (final t in allTrf) {
      if (t.status != TransferStatus.completed) continue;
      final srcWs = _normWs(t.sourceWorkspaceId);
      final dstWs = _normWs(t.destinationWorkspaceId);
      if (t.date.isAfter(end)) {
        if (scopeIds.contains(srcWs)) {
          postRangeDeltaByWs[srcWs] =
              (postRangeDeltaByWs[srcWs] ?? 0) - (t.amountPaise + t.feePaise);
        }
        if (scopeIds.contains(dstWs)) {
          postRangeDeltaByWs[dstWs] =
              (postRangeDeltaByWs[dstWs] ?? 0) + t.amountPaise;
        }
      }
    }

    // Collect in-range raw events respecting user toggles & scope isolation
    final List<_RawLedgerEvent> rawEvents = [];
    final Map<String, int> wsConfIncome = {};
    final Map<String, int> wsPendIncome = {};
    final Map<String, int> wsExpTotal = {};
    final Map<String, int> wsNetTransfer = {};
    final Map<String, int> wsExpCnt = {};
    final Map<String, int> wsIncCnt = {};
    final Map<String, int> wsTrfCnt = {};
    final Map<String, List<Expense>> currencyExpenses = {};
    final Map<String, List<Income>> currencyConfirmedIncomes = {};

    if (includeExpenses) {
      for (final e in expenses) {
        final wsId = _normWs(e.workspaceId);
        if (!scopeIds.contains(wsId)) continue;
        if (!includeArchived && e.isArchived) continue;
        if (e.date.isBefore(start) || e.date.isAfter(end)) continue;

        final currency = currencyFor(wsId);
        final accName =
            resolvedAccountNames[e.accountId] ?? e.paymentMethod;
        rawEvents.add(
          _RawLedgerEvent(
            date: e.date,
            workspaceId: wsId,
            workspaceName: wsNameFor(wsId),
            currency: currency,
            type: ExportLedgerEntryType.expense,
            title: e.productName,
            categoryOrRoute: e.category,
            paymentMethod: e.paymentMethod,
            accountName: accName,
            amountPaise: e.amount,
            balanceDeltaPaise: -e.amount,
            status: e.isArchived ? 'Archived' : 'Active',
          ),
        );
        wsExpTotal[wsId] = (wsExpTotal[wsId] ?? 0) + e.amount;
        wsExpCnt[wsId] = (wsExpCnt[wsId] ?? 0) + 1;
        currencyExpenses.putIfAbsent(currency, () => []).add(e);
      }
    }

    if (includeIncomes) {
      for (final i in incomes) {
        final wsId = _normWs(i.workspaceId);
        if (!scopeIds.contains(wsId)) continue;
        if (i.date.isBefore(start) || i.date.isAfter(end)) continue;

        final currency = currencyFor(wsId);
        final accName = resolvedAccountNames[i.accountId] ?? 'Bank Account';
        final delta = i.isConfirmed ? i.amount : 0;
        rawEvents.add(
          _RawLedgerEvent(
            date: i.date,
            workspaceId: wsId,
            workspaceName: wsNameFor(wsId),
            currency: currency,
            type: i.isConfirmed
                ? ExportLedgerEntryType.incomeConfirmed
                : ExportLedgerEntryType.incomePending,
            title: i.source,
            categoryOrRoute: i.description?.trim().isNotEmpty == true
                ? i.description!.trim()
                : 'Income Credit',
            paymentMethod: 'Deposit',
            accountName: accName,
            amountPaise: i.amount,
            balanceDeltaPaise: delta,
            status: i.isConfirmed ? 'Confirmed' : 'Pending',
          ),
        );
        wsIncCnt[wsId] = (wsIncCnt[wsId] ?? 0) + 1;
        if (i.isConfirmed) {
          wsConfIncome[wsId] = (wsConfIncome[wsId] ?? 0) + i.amount;
          currencyConfirmedIncomes.putIfAbsent(currency, () => []).add(i);
        } else {
          wsPendIncome[wsId] = (wsPendIncome[wsId] ?? 0) + i.amount;
        }
      }
    }

    if (includeTransfers) {
      for (final t in transfers) {
        if (t.status != TransferStatus.completed) continue;
        if (t.date.isBefore(start) || t.date.isAfter(end)) continue;

        final srcWs = _normWs(t.sourceWorkspaceId);
        final dstWs = _normWs(t.destinationWorkspaceId);
        final srcInScope = scopeIds.contains(srcWs);
        final dstInScope = scopeIds.contains(dstWs);
        if (!srcInScope && !dstInScope) continue;

        final srcAcc = resolvedAccountNames[t.sourceAccountId] ?? 'Account';
        final dstAcc = resolvedAccountNames[t.destinationAccountId] ?? 'Account';
        final routeLabel = '$srcAcc -> $dstAcc';
        final noteText = (t.note != null && t.note!.trim().isNotEmpty)
            ? t.note!.trim()
            : routeLabel;

        if (srcInScope && dstInScope) {
          // Both source & destination are inside the exported scope: equity changes only by fee.
          final wsId = srcWs;
          final currency = currencyFor(wsId);
          final label = srcWs == dstWs
              ? 'Self-Transfer ($routeLabel)'
              : 'Internal (${wsNameFor(srcWs)} -> ${wsNameFor(dstWs)})';
          rawEvents.add(
            _RawLedgerEvent(
              date: t.date,
              workspaceId: wsId,
              workspaceName: wsNameFor(wsId),
              currency: currency,
              type: ExportLedgerEntryType.transferSelf,
              title: label,
              categoryOrRoute: noteText,
              paymentMethod: 'Transfer',
              accountName: '$srcAcc -> $dstAcc',
              amountPaise: t.amountPaise,
              balanceDeltaPaise: -t.feePaise,
              status: t.feePaise > 0 ? 'Fee Applied' : 'Completed',
            ),
          );
          wsNetTransfer[srcWs] =
              (wsNetTransfer[srcWs] ?? 0) - t.amountPaise - t.feePaise;
          wsNetTransfer[dstWs] = (wsNetTransfer[dstWs] ?? 0) + t.amountPaise;
          wsTrfCnt[wsId] = (wsTrfCnt[wsId] ?? 0) + 1;
        } else if (srcInScope) {
          final currency = currencyFor(srcWs);
          final delta = -(t.amountPaise + t.feePaise);
          rawEvents.add(
            _RawLedgerEvent(
              date: t.date,
              workspaceId: srcWs,
              workspaceName: wsNameFor(srcWs),
              currency: currency,
              type: ExportLedgerEntryType.transferOut,
              title: 'Transfer to ${wsNameFor(dstWs)}',
              categoryOrRoute: noteText,
              paymentMethod: 'Transfer',
              accountName: routeLabel,
              amountPaise: t.amountPaise,
              balanceDeltaPaise: delta,
              status: 'Completed',
            ),
          );
          wsNetTransfer[srcWs] = (wsNetTransfer[srcWs] ?? 0) + delta;
          wsTrfCnt[srcWs] = (wsTrfCnt[srcWs] ?? 0) + 1;
        } else if (dstInScope) {
          final currency = currencyFor(dstWs);
          final delta = t.amountPaise;
          rawEvents.add(
            _RawLedgerEvent(
              date: t.date,
              workspaceId: dstWs,
              workspaceName: wsNameFor(dstWs),
              currency: currency,
              type: ExportLedgerEntryType.transferIn,
              title: 'Transfer from ${wsNameFor(srcWs)}',
              categoryOrRoute: noteText,
              paymentMethod: 'Transfer',
              accountName: routeLabel,
              amountPaise: t.amountPaise,
              balanceDeltaPaise: delta,
              status: 'Completed',
            ),
          );
          wsNetTransfer[dstWs] = (wsNetTransfer[dstWs] ?? 0) + delta;
          wsTrfCnt[dstWs] = (wsTrfCnt[dstWs] ?? 0) + 1;
        }
      }
    }

    // Sort strictly ascending chronologically for coherent running balance & expense versioning
    rawEvents.sort((a, b) {
      final dateCmp = a.date.compareTo(b.date);
      if (dateCmp != 0) return dateCmp;
      return a.type.sortOrder.compareTo(b.type.sortOrder);
    });

    // Build per-workspace financial reconciliation summaries
    final List<WorkspaceFinancialSummary> wsSummaries = [];
    final Map<String, int> openingByCurrency = {};
    final Map<String, int> closingByCurrency = {};
    final Map<String, int> hiddenArchByCurrency = {};
    final Map<String, WorkspaceFinancialSummary> wsSummaryAcc = {};

    for (final wsId in scopeIds) {
      final cur = currencyFor(wsId);
      final confInc = wsConfIncome[wsId] ?? 0;
      final pendInc = wsPendIncome[wsId] ?? 0;
      final expTot = wsExpTotal[wsId] ?? 0;
      final netTrf = wsNetTransfer[wsId] ?? 0;
      final hiddenArch = inRangeHiddenArchivedExpByWs[wsId] ?? 0;
      final displayedDelta = confInc - expTot + netTrf;
      final actualRangeDelta = displayedDelta - hiddenArch;

      final hasSnapshot = hasAccountSnapshotByWs[wsId] ?? false;
      final liveBal = liveBalanceByWs[wsId] ?? 0;
      final closingBal = hasSnapshot
          ? (liveBal - (postRangeDeltaByWs[wsId] ?? 0))
          : displayedDelta;
      final openingBal = hasSnapshot
          ? (closingBal - actualRangeDelta)
          : 0;

      final summary = WorkspaceFinancialSummary(
        workspaceId: wsId,
        workspaceName: wsNameFor(wsId),
        currency: cur,
        openingBalancePaise: openingBal,
        confirmedIncomePaise: confInc,
        pendingIncomePaise: pendInc,
        totalExpensePaise: expTot,
        netTransferPaise: netTrf,
        closingBalancePaise: closingBal,
        currentLiveBalancePaise: hasSnapshot ? liveBal : closingBal,
        vaultLockedPaise: vaultLockedByWs[wsId] ?? 0,
        expenseCount: wsExpCnt[wsId] ?? 0,
        incomeCount: wsIncCnt[wsId] ?? 0,
        transferCount: wsTrfCnt[wsId] ?? 0,
        hiddenArchivedExpensePaise: hiddenArch,
        hasAccountSnapshot: hasSnapshot,
      );
      wsSummaries.add(summary);
      wsSummaryAcc[wsId] = summary;

      openingByCurrency[cur] = (openingByCurrency[cur] ?? 0) + openingBal;
      closingByCurrency[cur] = (closingByCurrency[cur] ?? 0) + closingBal;
      hiddenArchByCurrency[cur] = (hiddenArchByCurrency[cur] ?? 0) + hiddenArch;
    }

    // Chronological walk computing per-currency running Expense totals and running Balance
    final Map<String, int> runExpByCur = {};
    final Map<String, int> runBalByCur = Map.of(openingByCurrency);
    final Map<String, int> expSeqByCur = {};
    final Map<String, int> incSeqByCur = {};
    final Map<String, int> trfSeqByCur = {};

    final List<ExportLedgerEntry> entries = [];
    int totalExpCount = 0;
    int totalIncCount = 0;
    int totalTrfCount = 0;

    for (final ev in rawEvents) {
      final cur = ev.currency;
      String seqLabel;
      int? expVer;

      if (ev.type == ExportLedgerEntryType.expense) {
        final nextExp = (expSeqByCur[cur] ?? 0) + 1;
        expSeqByCur[cur] = nextExp;
        seqLabel = 'E#$nextExp';
        expVer = nextExp;
        runExpByCur[cur] = (runExpByCur[cur] ?? 0) + ev.amountPaise;
        totalExpCount++;
      } else if (ev.type == ExportLedgerEntryType.incomeConfirmed ||
          ev.type == ExportLedgerEntryType.incomePending) {
        final nextInc = (incSeqByCur[cur] ?? 0) + 1;
        incSeqByCur[cur] = nextInc;
        seqLabel = 'I#$nextInc';
        totalIncCount++;
      } else {
        final nextTrf = (trfSeqByCur[cur] ?? 0) + 1;
        trfSeqByCur[cur] = nextTrf;
        seqLabel = 'T#$nextTrf';
        totalTrfCount++;
      }

      final nextBal = (runBalByCur[cur] ?? 0) + ev.balanceDeltaPaise;
      runBalByCur[cur] = nextBal;

      entries.add(
        ExportLedgerEntry(
          seqLabel: seqLabel,
          expenseVersion: expVer,
          date: ev.date,
          workspaceId: ev.workspaceId,
          workspaceName: ev.workspaceName,
          currency: cur,
          type: ev.type,
          title: ev.title,
          categoryOrRoute: ev.categoryOrRoute,
          paymentMethod: ev.paymentMethod,
          accountName: ev.accountName,
          amountPaise: ev.amountPaise,
          balanceDeltaPaise: ev.balanceDeltaPaise,
          runningExpensePaise: runExpByCur[cur] ?? 0,
          runningBalancePaise: nextBal,
          status: ev.status,
        ),
      );
    }

    // Build consolidated per-currency financial summaries
    final Map<String, List<WorkspaceFinancialSummary>> byCurWs = {};
    for (final s in wsSummaries) {
      byCurWs.putIfAbsent(s.currency, () => []).add(s);
    }
    final List<CurrencyFinancialSummary> currencySummaries = [];
    for (final entry in byCurWs.entries) {
      final cur = entry.key;
      final list = entry.value;
      final opening = list.fold<int>(0, (s, w) => s + w.openingBalancePaise);
      final confInc = list.fold<int>(0, (s, w) => s + w.confirmedIncomePaise);
      final pendInc = list.fold<int>(0, (s, w) => s + w.pendingIncomePaise);
      final totExp = list.fold<int>(0, (s, w) => s + w.totalExpensePaise);
      final closing = list.fold<int>(0, (s, w) => s + w.closingBalancePaise);
      final vaultTot = list.fold<int>(0, (s, w) => s + w.vaultLockedPaise);
      final expCnt = list.fold<int>(0, (s, w) => s + w.expenseCount);
      final incCnt = list.fold<int>(0, (s, w) => s + w.incomeCount);
      final trfCnt = list.fold<int>(0, (s, w) => s + w.transferCount);

      // For combined currency view, internal transfers across selected same-currency
      // workspaces cancel out in closing balance; reflect net closing minus flow equation.
      final netExternalTransfer =
          entries
              .where((e) =>
                  e.currency == cur &&
                  (e.type == ExportLedgerEntryType.transferOut ||
                      e.type == ExportLedgerEntryType.transferIn ||
                      e.type == ExportLedgerEntryType.transferSelf))
              .fold<int>(0, (s, e) => s + e.balanceDeltaPaise);

      currencySummaries.add(
        CurrencyFinancialSummary(
          currency: cur,
          openingBalancePaise: opening,
          confirmedIncomePaise: confInc,
          pendingIncomePaise: pendInc,
          totalExpensePaise: totExp,
          netTransferPaise: netExternalTransfer,
          closingBalancePaise: closing,
          vaultLockedPaise: vaultTot,
          expenseCount: expCnt,
          incomeCount: incCnt,
          transferCount: trfCnt,
        ),
      );
    }

    // Build expense visualization line chart series per currency
    final List<ExportChartSeries> chartSeries = [];
    for (final cur in byCurWs.keys) {
      chartSeries.add(
        _buildChartSeriesForCurrency(
          currency: cur,
          expenses: currencyExpenses[cur] ?? const [],
          incomes: currencyConfirmedIncomes[cur] ?? const [],
          rangeStart: start,
          rangeEnd: end,
        ),
      );
    }

    return ExportStatementSnapshot(
      entries: entries,
      workspaceSummaries: wsSummaries,
      currencySummaries: currencySummaries,
      chartSeries: chartSeries,
      totalExpenseCount: totalExpCount,
      totalIncomeCount: totalIncCount,
      totalTransferCount: totalTrfCount,
    );
  }

  static ExportChartSeries _buildChartSeriesForCurrency({
    required String currency,
    required List<Expense> expenses,
    required List<Income> incomes,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    DateTime domainStart = rangeStart;
    DateTime domainEnd = rangeEnd;

    // For wide historical presets (e.g. All Time starting year 2000), focus X-domain onto actual activity
    final rawSpan = rangeEnd.difference(rangeStart).inDays;
    if (rawSpan > 120 && (expenses.isNotEmpty || incomes.isNotEmpty)) {
      DateTime? minD;
      DateTime? maxD;
      for (final e in expenses) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        if (minD == null || d.isBefore(minD)) minD = d;
        if (maxD == null || d.isAfter(maxD)) maxD = d;
      }
      for (final i in incomes) {
        final d = DateTime(i.date.year, i.date.month, i.date.day);
        if (minD == null || d.isBefore(minD)) minD = d;
        if (maxD == null || d.isAfter(maxD)) maxD = d;
      }
      if (minD != null && maxD != null) {
        domainStart = minD;
        domainEnd = maxD;
      }
    }

    final spanDays = math.max(1, domainEnd.difference(domainStart).inDays + 1);
    final List<({DateTime start, DateTime end, String label})> bins = [];

    if (spanDays <= AppConstants.kMaxChartBins) {
      final fmt = DateFormat('MMM d');
      for (int i = 0; i < spanDays; i++) {
        final day = DateTime(
          domainStart.year,
          domainStart.month,
          domainStart.day + i,
        );
        bins.add((start: day, end: day, label: fmt.format(day)));
      }
    } else if (spanDays <= 365) {
      final stepDays = math.max(2, (spanDays / 24).ceil());
      final fmt = DateFormat('MMM d');
      DateTime cursor = domainStart;
      while (!cursor.isAfter(domainEnd)) {
        var binEnd = DateTime(
          cursor.year,
          cursor.month,
          cursor.day + stepDays - 1,
        );
        if (binEnd.isAfter(domainEnd)) binEnd = domainEnd;
        bins.add((start: cursor, end: binEnd, label: fmt.format(cursor)));
        cursor = DateTime(binEnd.year, binEnd.month, binEnd.day + 1);
      }
    } else {
      final fmt = DateFormat('MMM yy');
      DateTime cursor = DateTime(domainStart.year, domainStart.month, 1);
      final lastMonth = DateTime(domainEnd.year, domainEnd.month, 1);
      while (!cursor.isAfter(lastMonth)) {
        final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
        bins.add((start: cursor, end: monthEnd, label: fmt.format(cursor)));
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
      // If > 31 months, downsample linearly to <= 28 bins by grouping adjacent months
      if (bins.length > AppConstants.kMaxChartBins) {
        final groupSize = (bins.length / 24).ceil();
        final grouped = <({DateTime start, DateTime end, String label})>[];
        for (int i = 0; i < bins.length; i += groupSize) {
          final endIdx = math.min(i + groupSize - 1, bins.length - 1);
          grouped.add((
            start: bins[i].start,
            end: bins[endIdx].end,
            label: bins[i].label,
          ));
        }
        bins
          ..clear()
          ..addAll(grouped);
      }
    }

    final int binCount = math.max(1, bins.length);
    final List<int> binExp = List<int>.filled(binCount, 0);
    final List<int> binInc = List<int>.filled(binCount, 0);
    final Map<String, int> catTotals = {};

    int findBinIdx(DateTime dt) {
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d.isBefore(bins.first.start)) return 0;
      if (d.isAfter(bins.last.end)) return binCount - 1;
      int lo = 0;
      int hi = binCount - 1;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        final b = bins[mid];
        if (!d.isBefore(b.start) && !d.isAfter(b.end)) {
          return mid;
        } else if (d.isBefore(b.start)) {
          hi = mid - 1;
        } else {
          lo = mid + 1;
        }
      }
      return binCount - 1;
    }

    int totalExp = 0;
    for (final e in expenses) {
      final idx = findBinIdx(e.date);
      binExp[idx] += e.amount;
      totalExp += e.amount;
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }

    int totalInc = 0;
    for (final i in incomes) {
      final idx = findBinIdx(i.date);
      binInc[idx] += i.amount;
      totalInc += i.amount;
    }

    final List<ExportChartPoint> points = [];
    int cumulative = 0;
    int peakVal = -1;
    String peakLabel = bins.first.label;

    for (int i = 0; i < binCount; i++) {
      cumulative += binExp[i];
      if (binExp[i] > peakVal) {
        peakVal = binExp[i];
        peakLabel = bins[i].label;
      }
      points.add(
        ExportChartPoint(
          index: i,
          label: bins[i].label,
          expensePaise: binExp[i],
          cumulativeExpensePaise: cumulative,
          incomePaise: binInc[i],
        ),
      );
    }

    final avgPerBucket = binCount > 0 ? (totalExp / binCount).round() : 0;
    final granularityLabel = spanDays <= AppConstants.kMaxChartBins
        ? 'Daily Trend'
        : spanDays <= 365
            ? 'Interval Trend'
            : 'Monthly Trend';

    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryBreakdown = sortedCats
        .map((e) => {
              'category': e.key,
              'totalPaise': e.value,
              'pct': totalExp > 0 ? (e.value / totalExp * 100) : 0.0,
            })
        .toList();

    return ExportChartSeries(
      currency: currency,
      granularityLabel: granularityLabel,
      points: points,
      totalExpensePaise: totalExp,
      totalIncomePaise: totalInc,
      averagePerBucketPaise: avgPerBucket,
      peakLabel: peakLabel,
      peakExpensePaise: math.max(0, peakVal),
      categoryBreakdown: categoryBreakdown,
    );
  }
}

