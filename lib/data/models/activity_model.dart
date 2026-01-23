import 'dart:convert';
import '../../../domain/entities/activity.dart';

class ActivityModel extends Activity {
  const ActivityModel({
    required super.id,
    required super.name,
    super.parentId,
    required super.childrenIds,
    required super.status,
    super.startedAt,
    required super.totalSeconds,
  });

  factory ActivityModel.fromEntity(Activity entity) {
    return ActivityModel(
      id: entity.id,
      name: entity.name,
      parentId: entity.parentId,
      childrenIds: entity.childrenIds,
      status: entity.status,
      startedAt: entity.startedAt,
      totalSeconds: entity.totalSeconds,
    );
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      id: map['id'],
      name: map['name'],
      parentId: map['parent_id'],
      childrenIds: List<String>.from(jsonDecode(map['children_ids'])),
      status: ActivityStatus.values.firstWhere((e) => e.toString() == map['status']),
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
      totalSeconds: map['total_seconds'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'children_ids': jsonEncode(childrenIds),
      'status': status.toString(),
      'started_at': startedAt?.toIso8601String(),
      'total_seconds': totalSeconds,
    };
  }
}
