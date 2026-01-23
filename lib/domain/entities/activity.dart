enum ActivityStatus { running, paused, completed }

class Activity {
  final String id;
  final String name;
  final String? parentId;
  final List<String> childrenIds;
  final ActivityStatus status;
  final DateTime? startedAt;
  final int totalSeconds;

  const Activity({
    required this.id,
    required this.name,
    this.parentId,
    required this.childrenIds,
    required this.status,
    this.startedAt,
    required this.totalSeconds,
  });

  Activity copyWith({
    String? name,
    String? parentId,
    List<String>? childrenIds,
    ActivityStatus? status,
    DateTime? startedAt,
    int? totalSeconds,
  }) {
    return Activity(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      childrenIds: childrenIds ?? this.childrenIds,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      totalSeconds: totalSeconds ?? this.totalSeconds,
    );
  }
}
