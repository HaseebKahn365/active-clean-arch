import 'package:equatable/equatable.dart';
import '../entities/activity.dart';

class ActivityEvent extends Equatable {
  final String id;
  final String activityId;
  final DateTime timestamp;
  final int durationDelta;
  final ActivityStatus previousStatus;
  final ActivityStatus nextStatus;
  final String? oldParentId;
  final String? newParentId;
  final int? oldDuration;
  final int? newDuration;

  const ActivityEvent({
    required this.id,
    required this.activityId,
    required this.timestamp,
    required this.durationDelta,
    required this.previousStatus,
    required this.nextStatus,
    this.oldParentId,
    this.newParentId,
    this.oldDuration,
    this.newDuration,
  });

  @override
  List<Object?> get props => [
    id,
    activityId,
    timestamp,
    durationDelta,
    previousStatus,
    nextStatus,
    oldParentId,
    newParentId,
    oldDuration,
    newDuration,
  ];
}
