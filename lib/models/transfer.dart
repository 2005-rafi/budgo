import 'package:hive/hive.dart';
import 'package:expense/models/transfer_status.dart';

part 'transfer.g.dart';

@HiveType(typeId: 11)
class Transfer extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sourceAccountId;

  @HiveField(2)
  final String destinationAccountId;

  @HiveField(3)
  final String sourceWorkspaceId;

  @HiveField(4)
  final String destinationWorkspaceId;

  @HiveField(5)
  final int amountPaise;

  @HiveField(6, defaultValue: 0)
  final int feePaise;

  @HiveField(7)
  final DateTime date;

  @HiveField(8)
  String? note;

  @HiveField(9)
  TransferStatus status;

  @HiveField(10)
  String? failureReason;

  Transfer({
    required this.id,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.sourceWorkspaceId,
    required this.destinationWorkspaceId,
    required this.amountPaise,
    this.feePaise = 0,
    required this.date,
    this.note,
    this.status = TransferStatus.pending,
    this.failureReason,
  });
}

