import 'package:hive/hive.dart';

part 'transfer_journal_entry.g.dart';

@HiveType(typeId: 13)
enum TransferJournalPhase {
  @HiveField(0)
  initiated,

  @HiveField(1)
  sourceDebited,

  @HiveField(2)
  destinationCredited,
}

@HiveType(typeId: 14)
class TransferJournalEntry extends HiveObject {
  @HiveField(0)
  final String transferId;

  @HiveField(1)
  final String sourceAccountId;

  @HiveField(2)
  final String destinationAccountId;

  @HiveField(3)
  final int amountPaise;

  @HiveField(4, defaultValue: 0)
  final int feePaise;

  @HiveField(5)
  final int sourceOriginalBalance;

  @HiveField(6)
  final int destOriginalBalance;

  @HiveField(7)
  TransferJournalPhase phase;

  @HiveField(8)
  final DateTime timestamp;

  TransferJournalEntry({
    required this.transferId,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.amountPaise,
    this.feePaise = 0,
    required this.sourceOriginalBalance,
    required this.destOriginalBalance,
    required this.phase,
    required this.timestamp,
  });
}

