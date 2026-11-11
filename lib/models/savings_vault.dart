import 'package:hive/hive.dart';

part 'savings_vault.g.dart';

@HiveType(typeId: 15)
class SavingsVault extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String workspaceId;

  @HiveField(2)
  String parentAccountId;

  @HiveField(3)
  String name;

  @HiveField(4)
  int targetPaise;

  @HiveField(5)
  int currentPaise;

  @HiveField(6)
  DateTime? targetDate;

  @HiveField(7, defaultValue: false)
  bool isLocked;

  @HiveField(8, defaultValue: 1)
  int priority;

  @HiveField(9)
  int iconCodePoint;

  @HiveField(10)
  int colorValue;

  @HiveField(11, defaultValue: false)
  bool isArchived;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  DateTime updatedAt;

  SavingsVault({
    required this.id,
    required this.workspaceId,
    required this.parentAccountId,
    required this.name,
    required this.targetPaise,
    this.currentPaise = 0,
    this.targetDate,
    this.isLocked = false,
    this.priority = 1,
    required this.iconCodePoint,
    required this.colorValue,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progressRatio {
    if (targetPaise <= 0) return 1.0;
    return (currentPaise / targetPaise).clamp(0.0, 1.0);
  }

  int get remainingPaise {
    final rem = targetPaise - currentPaise;
    return rem > 0 ? rem : 0;
  }

  bool get isGoalReached => targetPaise > 0 && currentPaise >= targetPaise;

  SavingsVault copyWith({
    String? name,
    String? parentAccountId,
    int? targetPaise,
    int? currentPaise,
    DateTime? targetDate,
    bool? isLocked,
    int? priority,
    int? iconCodePoint,
    int? colorValue,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return SavingsVault(
      id: id,
      workspaceId: workspaceId,
      parentAccountId: parentAccountId ?? this.parentAccountId,
      name: name ?? this.name,
      targetPaise: targetPaise ?? this.targetPaise,
      currentPaise: currentPaise ?? this.currentPaise,
      targetDate: targetDate ?? this.targetDate,
      isLocked: isLocked ?? this.isLocked,
      priority: priority ?? this.priority,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

