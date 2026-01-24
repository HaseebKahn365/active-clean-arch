import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_event.dart';

class ActivityEventModel extends ActivityEvent {
  const ActivityEventModel({
    required super.id,
    required super.activityId,
    required super.timestamp,
    required super.durationDelta,
    required super.previousStatus,
    required super.nextStatus,
    super.oldParentId,
    super.newParentId,
    super.isSynced,
  });

  factory ActivityEventModel.fromMap(Map<String, dynamic> map) {
    return ActivityEventModel(
      id: map['id'] as String,
      activityId: map['activity_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      durationDelta: map['duration_delta'] as int,
      previousStatus: ActivityStatus.values.firstWhere((e) => e.toString() == (map['previous_status'] as String)),
      nextStatus: ActivityStatus.values.firstWhere((e) => e.toString() == (map['next_status'] as String)),
      oldParentId: map['old_parent_id'] as String?,
      newParentId: map['new_parent_id'] as String?,
      isSynced: (map['is_synced'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'timestamp': timestamp.toIso8601String(),
      'duration_delta': durationDelta,
      'previous_status': previousStatus.toString(),
      'next_status': nextStatus.toString(),
      'old_parent_id': oldParentId,
      'new_parent_id': newParentId,
      'is_synced': isSynced ? 1 : 0,
    };
  }
}
