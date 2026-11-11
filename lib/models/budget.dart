import 'package:hive/hive.dart';

part 'budget.g.dart';

// SCHEMA VERSION: 2
// Version 1: fields 0-6 (original)
// Version 2: added field 7 (workspaceId, default 'default_personal')
@HiveType(typeId: 3)
class Budget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int limit;

  @HiveField(2)
  String period; // 'weekly' or 'monthly'

  @HiveField(3)
  DateTime startDate;

  @HiveField(4)
  DateTime endDate;

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  double warningThreshold; // Percentage (e.g., 0.9 for 90%)

  @HiveField(7, defaultValue: 'default_personal')
  String workspaceId;

  Budget({
    required this.id,
    required this.limit,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.warningThreshold = 0.9,
    this.workspaceId = 'default_personal',
  });
}
