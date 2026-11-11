import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/storage/finance_boxes.dart';
import 'package:expense/models/account.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/models/savings_vault.dart';
import 'package:expense/models/transfer.dart';
import 'package:expense/models/workspace.dart';

/// Per-workspace entity footprint summary used by Settings storage & deletion dialogs.
class WorkspaceStorageBreakdown {
  final String workspaceId;
  final String workspaceName;
  final int activeExpenses;
  final int archivedExpenses;
  final int incomes;
  final int reminders;
  final int plannedItems;
  final int accounts;
  final int vaults;
  final int transfers;
  final int budgets;

  const WorkspaceStorageBreakdown({
    required this.workspaceId,
    required this.workspaceName,
    this.activeExpenses = 0,
    this.archivedExpenses = 0,
    this.incomes = 0,
    this.reminders = 0,
    this.plannedItems = 0,
    this.accounts = 0,
    this.vaults = 0,
    this.transfers = 0,
    this.budgets = 0,
  });

  int get totalExpenses => activeExpenses + archivedExpenses;

  int get totalRecords =>
      totalExpenses +
      incomes +
      reminders +
      plannedItems +
      accounts +
      vaults +
      transfers +
      budgets;
}

class StorageMetricsSnapshot {
  final int totalBytes;
  final String formattedSize;
  final List<WorkspaceStorageBreakdown> workspaces;

  const StorageMetricsSnapshot({
    required this.totalBytes,
    required this.formattedSize,
    required this.workspaces,
  });

  int get totalRecords =>
      workspaces.fold<int>(0, (sum, w) => sum + w.totalRecords);
}

class StorageInfoService {
  static String? _cachedDescription;
  static StorageMetricsSnapshot? _cachedSnapshot;
  static DateTime? _lastFetched;
  static const _ttl = Duration(minutes: 5);

  static void invalidate() {
    _cachedDescription = null;
    _cachedSnapshot = null;
    _lastFetched = null;
  }

  static String formatBytes(int totalBytes) {
    if (totalBytes < 1024) {
      return 'Database: ${totalBytes.toStringAsFixed(0)} B';
    } else if (totalBytes < 1024 * 1024) {
      final kb = totalBytes / 1024;
      return 'Database: ${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = totalBytes / (1024 * 1024);
      return 'Database: ${mb.toStringAsFixed(1)} MB';
    }
  }

  static Future<String> getBoxSizeDescription() async {
    final now = DateTime.now();
    if (_cachedDescription != null &&
        _lastFetched != null &&
        now.difference(_lastFetched!) < _ttl) {
      return _cachedDescription!;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final totalBytes = await compute(_calculateSizeInIsolate, dir.path);
      final description = formatBytes(totalBytes);

      _cachedDescription = description;
      _lastFetched = now;
      return description;
    } catch (_) {
      return _cachedDescription ?? 'Database: Unknown size';
    }
  }

  /// Computes physical disk usage + per-workspace entity counts in a single linear pass.
  static Future<StorageMetricsSnapshot> getDetailedMetrics({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedSnapshot != null &&
        _lastFetched != null &&
        now.difference(_lastFetched!) < _ttl) {
      return _cachedSnapshot!;
    }

    int totalBytes = 0;
    try {
      final dir = await getApplicationDocumentsDirectory();
      totalBytes = await compute(_calculateSizeInIsolate, dir.path);
    } catch (_) {}

    final formatted = formatBytes(totalBytes);
    final breakdown = _computeWorkspaceBreakdown();

    final snapshot = StorageMetricsSnapshot(
      totalBytes: totalBytes,
      formattedSize: formatted,
      workspaces: breakdown,
    );

    _cachedDescription = formatted;
    _cachedSnapshot = snapshot;
    _lastFetched = now;
    return snapshot;
  }

  static String _normWs(String? wsId) =>
      (wsId == null || wsId.isEmpty) ? AppConstants.kDefaultWorkspaceId : wsId;

  static List<WorkspaceStorageBreakdown> _computeWorkspaceBreakdown() {
    final Map<String, String> names = {};
    if (Hive.isBoxOpen(FinanceBoxes.workspacesBoxName)) {
      for (final ws in Hive.box<Workspace>(FinanceBoxes.workspacesBoxName).values) {
        names[ws.id] = ws.name;
      }
    }
    names.putIfAbsent(AppConstants.kDefaultWorkspaceId, () => 'Personal');

    final activeExp = <String, int>{};
    final archivedExp = <String, int>{};
    final incomes = <String, int>{};
    final reminders = <String, int>{};
    final planned = <String, int>{};
    final accounts = <String, int>{};
    final vaults = <String, int>{};
    final transfers = <String, int>{};
    final budgets = <String, int>{};

    void ensureWs(String wsId) {
      names.putIfAbsent(wsId, () => wsId == AppConstants.kDefaultWorkspaceId ? 'Personal' : 'Workspace ($wsId)');
    }

    if (Hive.isBoxOpen(FinanceBoxes.expensesBoxName)) {
      for (final e in Hive.box<Expense>(FinanceBoxes.expensesBoxName).values) {
        final ws = _normWs(e.workspaceId);
        ensureWs(ws);
        if (e.isArchived) {
          archivedExp[ws] = (archivedExp[ws] ?? 0) + 1;
        } else {
          activeExp[ws] = (activeExp[ws] ?? 0) + 1;
        }
      }
    }

    if (Hive.isBoxOpen(FinanceBoxes.incomesBoxName)) {
      for (final i in Hive.box<Income>(FinanceBoxes.incomesBoxName).values) {
        final ws = _normWs(i.workspaceId);
        ensureWs(ws);
        incomes[ws] = (incomes[ws] ?? 0) + 1;
      }
    }

    if (Hive.isBoxOpen(FinanceBoxes.remindersBoxName)) {
      for (final r in Hive.box<Reminder>(FinanceBoxes.remindersBoxName).values) {
        final ws = _normWs(r.workspaceId);
        ensureWs(ws);
        reminders[ws] = (reminders[ws] ?? 0) + 1;
      }
    }

    if (Hive.isBoxOpen(FinanceBoxes.futureExpensesBoxName)) {
      for (final f in Hive.box<FutureExpense>(FinanceBoxes.futureExpensesBoxName).values) {
        final ws = _normWs(f.workspaceId);
        ensureWs(ws);
        planned[ws] = (planned[ws] ?? 0) + 1;
      }
    }

    if (Hive.isBoxOpen(FinanceBoxes.accountsBoxName)) {
      for (final a in Hive.box<Account>(FinanceBoxes.accountsBoxName).values) {
        final ws = _normWs(a.workspaceId);
        ensureWs(ws);
        accounts[ws] = (accounts[ws] ?? 0) + 1;
      }
    }

    if (Hive.isBoxOpen(FinanceBoxes.vaultsBoxName)) {
      for (final v in Hive.box<SavingsVault>(FinanceBoxes.vaultsBoxName).values) {
        final ws = _normWs(v.workspaceId);
        ensureWs(ws);
        vaults[ws] = (vaults[ws] ?? 0) + 1;
      }
    }

    if (Hive.isBoxOpen(FinanceBoxes.transfersBoxName)) {
      for (final t in Hive.box<Transfer>(FinanceBoxes.transfersBoxName).values) {
        final src = _normWs(t.sourceWorkspaceId);
        final dst = _normWs(t.destinationWorkspaceId);
        ensureWs(src);
        transfers[src] = (transfers[src] ?? 0) + 1;
        if (dst != src) {
          ensureWs(dst);
          transfers[dst] = (transfers[dst] ?? 0) + 1;
        }
      }
    }

    if (Hive.isBoxOpen(FinanceBoxes.budgetsBoxName)) {
      for (final b in Hive.box<Budget>(FinanceBoxes.budgetsBoxName).values) {
        final ws = _normWs(b.workspaceId);
        ensureWs(ws);
        budgets[ws] = (budgets[ws] ?? 0) + 1;
      }
    }

    final result = names.entries.map((entry) {
      final ws = entry.key;
      return WorkspaceStorageBreakdown(
        workspaceId: ws,
        workspaceName: entry.value,
        activeExpenses: activeExp[ws] ?? 0,
        archivedExpenses: archivedExp[ws] ?? 0,
        incomes: incomes[ws] ?? 0,
        reminders: reminders[ws] ?? 0,
        plannedItems: planned[ws] ?? 0,
        accounts: accounts[ws] ?? 0,
        vaults: vaults[ws] ?? 0,
        transfers: transfers[ws] ?? 0,
        budgets: budgets[ws] ?? 0,
      );
    }).toList();

    result.sort((a, b) {
      if (a.workspaceId == AppConstants.kDefaultWorkspaceId) return -1;
      if (b.workspaceId == AppConstants.kDefaultWorkspaceId) return 1;
      return a.workspaceName.compareTo(b.workspaceName);
    });
    return result;
  }
}

int _calculateSizeInIsolate(String dirPath) {
  final boxNames = FinanceBoxes.allBoxNames;
  int totalBytes = 0;
  for (final name in boxNames) {
    for (final ext in const ['.hive', '.hivec']) {
      final file = File('$dirPath/$name$ext');
      if (file.existsSync()) {
        totalBytes += file.lengthSync();
      }
    }
  }
  return totalBytes;
}
