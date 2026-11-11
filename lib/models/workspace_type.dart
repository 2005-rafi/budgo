import 'package:hive/hive.dart';

part 'workspace_type.g.dart';

@HiveType(typeId: 8)
enum WorkspaceType {
  @HiveField(0)
  personal,

  @HiveField(1)
  business,

  @HiveField(2)
  trip,

  @HiveField(3)
  project,

  @HiveField(4)
  savingsPool,
}

