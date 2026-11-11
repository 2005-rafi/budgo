import 'package:hive/hive.dart';

part 'transfer_status.g.dart';

@HiveType(typeId: 12)
enum TransferStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  completed,

  @HiveField(2)
  failed,

  @HiveField(3)
  rolledBack,
}

