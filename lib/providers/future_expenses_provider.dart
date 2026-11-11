import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense/repositories/future_expense_repository.dart';
import 'package:expense/repositories/expense_repository.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/storage/atomic_writer.dart';
import 'package:expense/models/job_record.dart';
import 'package:expense/core/storage/finance_boxes.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/providers/expenses_provider.dart';

enum PurchaseState {
  idle,
  creatingExpense,
  markingPurchased,
  committed,
  rolledBack,
}

class FutureExpensesProvider extends ChangeNotifier {
  final FutureExpenseRepository _repository;
  final ExpenseRepository _expenseRepository;
  List<FutureExpense> _items = [];
  StreamSubscription<void>? _boxSubscription;
  final Set<String> _purchasingInProgress = {};
  PurchaseState _purchaseState = PurchaseState.idle;

  String _activeWorkspaceId = 'default_personal';
  bool _isLoading = false;
  String? _errorMessage;

  ExpensesProvider? _expensesProvider;

  // Startup orphan recovery fields
  FutureExpense? _orphanedItem;
  Expense? _orphanedExpense;

  String get activeWorkspaceId => _activeWorkspaceId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  PurchaseState get purchaseState => _purchaseState;

  FutureExpense? get orphanedItem => _orphanedItem;
  Expense? get orphanedExpense => _orphanedExpense;

  FutureExpensesProvider(this._repository, this._expenseRepository);

  String _normWs(String wsId) => wsId.isEmpty ? 'default_personal' : wsId;

  Future<void> initialize({String? initialWorkspaceId}) async {
    if (initialWorkspaceId != null && initialWorkspaceId.isNotEmpty) {
      _activeWorkspaceId = _normWs(initialWorkspaceId);
    }
    _boxSubscription ??= _repository.watch().listen((_) => load());
    await load();
    await checkOrphanedPurchases();
  }

  void setActiveWorkspace(String workspaceId) {
    final norm = _normWs(workspaceId);
    if (_activeWorkspaceId == norm) return;
    _activeWorkspaceId = norm;
    notifyListeners();
  }

  void attachExpenses(ExpensesProvider expensesProvider) {
    _expensesProvider = expensesProvider;
  }

  /// Complete global planned items across all workspaces (used for export/lifecycle).
  List<FutureExpense> get allItems => List.unmodifiable(_items);

  /// Planned items strictly isolated to the active workspace.
  List<FutureExpense> get items => List.unmodifiable(
        _items.where((e) => _normWs(e.workspaceId) == _activeWorkspaceId),
      );

  List<FutureExpense> get planned =>
      items.where((e) => !e.isPurchased).toList();

  List<FutureExpense> get purchased =>
      items.where((e) => e.isPurchased).toList();

  int get totalPlannedEstimated =>
      planned.fold<int>(0, (sum, e) => sum + (e.estimatedCost ?? 0));

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _repository.getAll();
      _errorMessage = null;
    } on StorageException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = AppErrorTranslator.translate(e).title;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFutureExpense(FutureExpense item) async {
    if (item.workspaceId.isEmpty) {
      item.workspaceId = _activeWorkspaceId;
    }
    await AtomicWriter.instance.execute(() async {
      await _repository.add(item);
    });
    await load();
  }

  Future<void> updateFutureExpense(FutureExpense item) async {
    await AtomicWriter.instance.execute(() async {
      await _repository.update(item);
    });
    await load();
  }

  /// Converts a wishlist item into a real Expense and marks as purchased using a durable two-phase commit.
  FutureExpense? getLinkedFutureExpense(int expenseKey) {
    try {
      return _items.firstWhere((f) => f.isPurchased && f.linkedExpenseKey == expenseKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> purchase(
    FutureExpense item, {
    required int amount,
    DateTime? purchasedAt,
  }) async {
    if (_purchasingInProgress.contains(item.id)) return;
    _purchasingInProgress.add(item.id);
    _purchaseState = PurchaseState.creatingExpense;
    _errorMessage = null;
    notifyListeners();

    int? expenseKey;
    final originalIsPurchased = item.isPurchased;
    final originalLinkedExpenseKey = item.linkedExpenseKey;
    final originalPurchasedAmount = item.purchasedAmount;
    final originalPurchasedAt = item.purchasedAt;

    final jobUuid = 'purchase_${item.id}_${DateTime.now().millisecondsSinceEpoch}';
    final job = JobRecord(
      id: jobUuid,
      type: 'purchase',
      state: 'pending',
      payload: {
        'plannedItemKey': item.id,
        'amount': amount,
        'productName': item.title,
        'category': item.category,
        'date': (purchasedAt ?? DateTime.now()).toIso8601String(),
      },
    );

    try {
      await AtomicWriter.instance.execute(() async {
        // Step 0: Write Job Record
        final jobsBox = FinanceBoxes.jobs;
        await jobsBox.put(job.id, job);
        await jobsBox.flush();

        // Step 1: Write Expense scoped cleanly to the planned item's workspace
        final targetWs = _normWs(item.workspaceId.isEmpty ? _activeWorkspaceId : item.workspaceId);
        final expense = Expense(
          productName: item.title,
          amount: amount,
          category: item.category,
          date: purchasedAt ?? DateTime.now(),
          workspaceId: targetWs,
        );
        expenseKey = await _expenseRepository.add(expense);

        // Step 2: Update Planned Item
        _purchaseState = PurchaseState.markingPurchased;
        item.isPurchased = true;
        item.linkedExpenseKey = expenseKey;
        item.purchasedAmount = amount;
        item.purchasedAt = purchasedAt ?? DateTime.now();
        await _repository.update(item);

        // Step 3: Flip job state to complete
        job.state = 'complete';
        await job.save();
        await jobsBox.flush();
      });

      _purchaseState = PurchaseState.committed;
      if (_expensesProvider != null) {
        await _expensesProvider!.load(isWatchEvent: true);
      }
    } catch (e) {
      _purchaseState = PurchaseState.rolledBack;
      _errorMessage = AppErrorTranslator.translate(
        e,
        operation: FeedbackOperation.purchaseWishlist,
      ).title;

      // Step 4: Rollback
      await AtomicWriter.instance.execute(() async {
        if (expenseKey != null) {
          try {
            await _expenseRepository.delete(expenseKey!);
          } catch (_) {}
        }
        item.isPurchased = originalIsPurchased;
        item.linkedExpenseKey = originalLinkedExpenseKey;
        item.purchasedAmount = originalPurchasedAmount;
        item.purchasedAt = originalPurchasedAt;
        try {
          await _repository.update(item);
        } catch (_) {}

        if (job.isInBox) {
          job.state = 'failed';
          await job.save();
        }
      });
      
      notifyListeners();
    } finally {
      _purchasingInProgress.remove(item.id);
    }
  }

  Future<void> unpurchase(FutureExpense future) async {
    await undoPurchase(future);
  }

  /// Startup integrity check for orphaned purchases.
  Future<void> checkOrphanedPurchases() async {
    // Left for safety checking, but mostly handled by JobReconciler.
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenses = await _expenseRepository.getAll();

      for (var item in _items) {
        if (!item.isPurchased) {
          final attemptStr = prefs.getString('lastAttempt_${item.id}');
          if (attemptStr != null) {
            final attemptTime = DateTime.parse(attemptStr);
            final orphan = expenses.firstWhereOrNull((exp) =>
                exp.productName == item.title &&
                (exp.date.difference(attemptTime).abs().inSeconds <= 30));

            if (orphan != null) {
              _orphanedItem = item;
              _orphanedExpense = orphan;
              notifyListeners();
              break; 
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Resolves the orphaned purchase.
  Future<void> resolveOrphan(bool completePurchase) async {
    final item = _orphanedItem;
    final expense = _orphanedExpense;
    if (item == null || expense == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastAttempt_${item.id}');

      await AtomicWriter.instance.execute(() async {
        if (completePurchase) {
          item.isPurchased = true;
          item.linkedExpenseKey = expense.key as int?;
          item.purchasedAmount = expense.amount;
          item.purchasedAt = expense.date;
          await _repository.update(item);
        } else {
          if (expense.key != null) {
            await _expenseRepository.delete(expense.key as int);
          }
        }
      });
    } catch (_) {} finally {
      _orphanedItem = null;
      _orphanedExpense = null;
      await load();
      if (_expensesProvider != null) {
        await _expensesProvider!.load(isWatchEvent: true);
      }
    }
  }

  /// Optional: Undo purchase (also deletes linked Expense to keep data consistent).
  Future<void> undoPurchase(FutureExpense item) async {
    await AtomicWriter.instance.execute(() async {
      final key = item.linkedExpenseKey;
      if (key != null) {
        await _expenseRepository.delete(key);
      }

      item.isPurchased = false;
      item.linkedExpenseKey = null;
      item.purchasedAmount = null;
      item.purchasedAt = null;

      await _repository.update(item);
    });
    await load();
    if (_expensesProvider != null) {
      await _expensesProvider!.load(isWatchEvent: true);
    }
  }

  /// Deletes a wishlist item. If it has been purchased and has a linked
  /// expense, cascades the deletion to the expenses box first to prevent orphaned records.
  Future<void> deleteFutureExpense(FutureExpense item) async {
    await AtomicWriter.instance.execute(() async {
      if (item.linkedExpenseKey != null) {
        await _expenseRepository.delete(item.linkedExpenseKey!);
      }
      await _repository.delete(item);
    });
    await load();
    if (_expensesProvider != null) {
      await _expensesProvider!.load();
    }
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }
}
