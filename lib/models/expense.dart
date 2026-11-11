import 'package:hive/hive.dart';

part 'expense.g.dart';

// SCHEMA VERSION: 3
// Version 1: fields 0-3 (original)
// Version 2: added field 4 (isArchived, default false), field 5 (paymentMethod) - backward compatible
// Version 3: added field 6 (workspaceId, default 'default_personal'), field 7 (accountId, default 'acc_default_cash')
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

  @HiveField(5, defaultValue: 'Cash')
  String paymentMethod;

  @HiveField(6, defaultValue: 'default_personal')
  String workspaceId;

  @HiveField(7, defaultValue: 'acc_default_cash')
  String accountId;

  Expense({
    required this.productName,
    required this.amount,
    required this.category,
    required this.date,
    this.isArchived = false,
    this.paymentMethod = 'Cash',
    this.workspaceId = 'default_personal',
    this.accountId = 'acc_default_cash',
  });
}
