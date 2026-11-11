/// Immutable data model representing a user-owned financial category.
/// Persisted in AppStateBox under `user_categories_v1` as typed JSON.
class UserCategory {
  final String id;
  final String name;
  final String iconId;
  final int colorValue;
  final bool isDefault;
  final bool isArchived;
  final int sortOrder;

  const UserCategory({
    required this.id,
    required this.name,
    required this.iconId,
    required this.colorValue,
    this.isDefault = false,
    this.isArchived = false,
    this.sortOrder = 0,
  });

  UserCategory copyWith({
    String? id,
    String? name,
    String? iconId,
    int? colorValue,
    bool? isDefault,
    bool? isArchived,
    int? sortOrder,
  }) {
    return UserCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconId: iconId ?? this.iconId,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconId': iconId,
    'colorValue': colorValue,
    'isDefault': isDefault,
    'isArchived': isArchived,
    'sortOrder': sortOrder,
  };

  factory UserCategory.fromJson(Map<String, dynamic> json) => UserCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    iconId: json['iconId'] as String,
    colorValue: json['colorValue'] as int,
    isDefault: json['isDefault'] as bool? ?? false,
    isArchived: json['isArchived'] as bool? ?? false,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

