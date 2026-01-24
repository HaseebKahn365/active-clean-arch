import '../../../domain/entities/count_record.dart';

class CountRecordModel extends CountRecord {
  const CountRecordModel({
    required super.id,
    required super.activityId,
    required super.timestamp,
    required super.value,
  });

  factory CountRecordModel.fromEntity(CountRecord entity) {
    return CountRecordModel(
      id: entity.id,
      activityId: entity.activityId,
      timestamp: entity.timestamp,
      value: entity.value,
    );
  }

  factory CountRecordModel.fromMap(Map<String, dynamic> map) {
    return CountRecordModel(
      id: map['id'],
      activityId: map['activity_id'],
      timestamp: DateTime.parse(map['timestamp']),
      value: map['value'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'activity_id': activityId, 'timestamp': timestamp.toIso8601String(), 'value': value};
  }
}
