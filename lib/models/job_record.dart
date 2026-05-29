import 'package:hive/hive.dart';

part 'job_record.g.dart';

@HiveType(typeId: 5)
class JobRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'purchase', 'archive', 'reset', 'export'

  @HiveField(2)
  String state; // 'pending', 'complete', 'failed'

  @HiveField(3)
  final Map<dynamic, dynamic> payload;

  JobRecord({
    required this.id,
    required this.type,
    this.state = 'pending',
    required this.payload,
  });
}
