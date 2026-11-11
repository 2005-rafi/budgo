import 'package:hive/hive.dart';

part 'income.g.dart';

// SCHEMA VERSION: 2
// Version 1: fields 0-5 (original)
// Version 2: added field 6 (workspaceId, default 'default_personal'), field 7 (accountId, default 'acc_default_bank')
@HiveType(typeId: 1)
class Income extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String source; // Salary, Freelance, Gift, Other

  @HiveField(2)
  int amount;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String? description;

  @HiveField(5)
  bool isConfirmed; // For confirmation before adding to budget

  @HiveField(6, defaultValue: 'default_personal')
  String workspaceId;

  @HiveField(7, defaultValue: 'acc_default_bank')
  String accountId;

  Income({
    required this.id,
    required this.source,
    required this.amount,
    required this.date,
    this.description,
    this.isConfirmed = false,
    this.workspaceId = 'default_personal',
    this.accountId = 'acc_default_bank',
  });
}
