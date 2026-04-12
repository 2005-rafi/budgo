import 'package:hive/hive.dart';

part 'future_expense.g.dart';

@HiveType(typeId: 2)
class FutureExpense extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double? estimatedCost;

  @HiveField(3)
  int priority;

  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5)
  bool isPurchased;

  @HiveField(6)
  String category;

  @HiveField(7)
  String? notes;

  // NEW: link to a real Expense created in expenses box (auto-increment key).
  @HiveField(8)
  int? linkedExpenseKey;

  // NEW: what user actually paid (can differ from estimate).
  @HiveField(9)
  double? purchasedAmount;

  // NEW: when it was purchased (defaults to now).
  @HiveField(10)
  DateTime? purchasedAt;

  FutureExpense({
    required this.id,
    required this.title,
    this.estimatedCost,
    this.priority = 1,
    this.dueDate,
    this.isPurchased = false,
    this.category = 'General',
    this.notes,
    this.linkedExpenseKey,
    this.purchasedAmount,
    this.purchasedAt,
  });
}
