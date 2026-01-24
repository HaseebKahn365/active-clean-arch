import 'dart:convert';
import '../../../domain/entities/activity.dart';

class ActivityModel extends Activity {
  const ActivityModel({
    required super.id,
    required super.name,
    super.description = '',
    super.parentId,
    required super.childrenIds,
    required super.status,
    super.startedAt,
    required super.totalSeconds,
    super.goalSeconds = 0,
    super.type = ActivityType.timeBased,
    required super.createdAt,
    required super.updatedAt,
    super.isPinned = false,
  });

  factory ActivityModel.fromEntity(Activity entity) {
    return ActivityModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      parentId: entity.parentId,
      childrenIds: entity.childrenIds,
      status: entity.status,
      startedAt: entity.startedAt,
      totalSeconds: entity.totalSeconds,
      goalSeconds: entity.goalSeconds,
      type: entity.type,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isPinned: entity.isPinned,
    );
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      parentId: map['parent_id'],
      childrenIds: List<String>.from(jsonDecode(map['children_ids'])),
      status: ActivityStatus.values.firstWhere((e) => e.toString() == map['status']),
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
      totalSeconds: map['total_seconds'],
      goalSeconds: map['goal_seconds'] ?? 0,
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == (map['type'] ?? ActivityType.timeBased.toString()),
        orElse: () => ActivityType.timeBased,
      ),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      isPinned: map['is_pinned'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'parent_id': parentId,
      'children_ids': jsonEncode(childrenIds),
      'status': status.toString(),
      'started_at': startedAt?.toIso8601String(),
      'total_seconds': totalSeconds,
      'goal_seconds': goalSeconds,
      'type': type.toString(),
      'is_pinned': isPinned ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
