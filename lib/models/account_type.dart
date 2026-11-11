import 'package:hive/hive.dart';

part 'account_type.g.dart';

@HiveType(typeId: 10)
enum AccountType {
  @HiveField(0)
  cash,

  @HiveField(1)
  bankAccount,

  @HiveField(2)
  upi,

  @HiveField(3)
  creditCard,

  @HiveField(4)
  savings,

  @HiveField(5)
  other,
}

