import 'package:hive/hive.dart';
import 'package:expense/models/workspace_type.dart';

part 'workspace.g.dart';

@HiveType(typeId: 7)
class Workspace extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  WorkspaceType type;

  @HiveField(3)
  String currency;

  @HiveField(4, defaultValue: 0)
  int initialBalance;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  int iconCodePoint;

  @HiveField(7)
  int colorValue;

  @HiveField(8, defaultValue: false)
  bool isDefault;

  @HiveField(9, defaultValue: false)
  bool isArchived;

  Workspace({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.initialBalance = 0,
    required this.createdAt,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
    this.isArchived = false,
  });
}

