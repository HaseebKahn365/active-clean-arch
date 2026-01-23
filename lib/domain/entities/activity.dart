import 'package:equatable/equatable.dart';

enum ActivityStatus { idle, running, paused, completed }

class Activity extends Equatable {
  final String id;
  final String name;
  final String? parentId;
  final List<String> childrenIds;
  final ActivityStatus status;
  final DateTime? startedAt;
  final int totalSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Activity({
    required this.id,
    required this.name,
    this.parentId,
    required this.childrenIds,
    required this.status,
    this.startedAt,
    required this.totalSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  Activity copyWith({
    String? name,
    String? Function()? parentId,
    List<String>? childrenIds,
    ActivityStatus? status,
    DateTime? Function()? startedAt,
    int? totalSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id,
      name: name ?? this.name,
      parentId: parentId != null ? parentId() : this.parentId,
      childrenIds: childrenIds ?? this.childrenIds,
      status: status ?? this.status,
      startedAt: startedAt != null ? startedAt() : this.startedAt,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, parentId, childrenIds, status, startedAt, totalSeconds, createdAt, updatedAt];
}
