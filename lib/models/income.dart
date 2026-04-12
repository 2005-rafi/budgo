import 'package:hive/hive.dart';

part 'income.g.dart';

@HiveType(typeId: 1)
class Income extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String source; // Salary, Freelance, Gift, Other

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String? description;

  @HiveField(5)
  bool isConfirmed; // For confirmation before adding to budget

  Income({
    required this.id,
    required this.source,
    required this.amount,
    required this.date,
    this.description,
    this.isConfirmed = false,
  });
}
