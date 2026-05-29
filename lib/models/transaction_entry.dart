import 'package:flutter/foundation.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/future_expense.dart';

@immutable
sealed class TransactionEntry {
  final String id;
  final DateTime date;
  final int amount;
  final String displayName;
  final String category;
  final String? notes;

  const TransactionEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.displayName,
    required this.category,
    this.notes,
  });
}

class ExpenseEntry extends TransactionEntry {
  final Expense rawExpense;

  const ExpenseEntry({
    required super.id,
    required super.date,
    required super.amount,
    required super.displayName,
    required super.category,
    super.notes,
    required this.rawExpense,
  });
}

class IncomeEntry extends TransactionEntry {
  final bool isConfirmed;
  final Income rawIncome;

  const IncomeEntry({
    required super.id,
    required super.date,
    required super.amount,
    required super.displayName,
    required super.category,
    super.notes,
    required this.isConfirmed,
    required this.rawIncome,
  });
}

class PlannedEntry extends TransactionEntry {
  final String priority; // 'high' | 'medium' | 'low'
  final DateTime? dueDate;
  final FutureExpense rawFuture;

  const PlannedEntry({
    required super.id,
    required super.date,
    required super.amount,
    required super.displayName,
    required super.category,
    super.notes,
    required this.priority,
    this.dueDate,
    required this.rawFuture,
  });
}
