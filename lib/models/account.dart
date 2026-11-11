import 'package:hive/hive.dart';
import 'package:expense/models/account_type.dart';

part 'account.g.dart';

@HiveType(typeId: 9)
class Account extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String workspaceId;

  @HiveField(2)
  String name;

  @HiveField(3)
  AccountType type;

  /// Stored in integer paise.
  /// For Asset accounts (Cash, Bank, UPI, Savings): >= 0 represents liquid funds.
  /// For Liability accounts (Credit Card): Signed Net Equity (<= 0 represents outstanding debt).
  @HiveField(4)
  int balancePaise;

  /// Approved credit limit for credit instruments (in paise).
  @HiveField(5, defaultValue: 0)
  int creditLimitPaise;

  @HiveField(6)
  String? accountNumberLast4;

  @HiveField(7)
  int iconCodePoint;

  @HiveField(8)
  int colorValue;

  @HiveField(9, defaultValue: false)
  bool isArchived;

  @HiveField(10, defaultValue: false)
  bool isDefault;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  Account({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.type,
    required this.balancePaise,
    this.creditLimitPaise = 0,
    this.accountNumberLast4,
    required this.iconCodePoint,
    required this.colorValue,
    this.isArchived = false,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCredit => type == AccountType.creditCard;

  /// For credit instruments: outstanding debt expressed as positive paise.
  int get outstandingDebtPaise => isCredit && balancePaise < 0 ? -balancePaise : 0;

  /// For credit instruments: available credit limit in paise.
  /// For asset accounts: current liquid balance.
  int get availableCreditPaise => isCredit ? creditLimitPaise + balancePaise : balancePaise;
}

