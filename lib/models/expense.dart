import 'package:hive/hive.dart';

part 'expense.g.dart';

// SCHEMA VERSION: 2
// Version 1: fields 0-3 (original)
// Version 2: added field 4 (isArchived, default false) - backward compatible
@HiveType(typeId: 0)
class Expense extends HiveObject {
  @HiveField(0)
  String productName;

  @HiveField(1)
  int amount;

  @HiveField(2)
  String category;

  @HiveField(3)
  DateTime date;

  @HiveField(4, defaultValue: false)
  bool isArchived;

  Expense({
    required this.productName,
    required this.amount,
    required this.category,
    required this.date,
    this.isArchived = false,
  });
}
