enum ActivityType { count, time }

class Activity {
  const Activity({
    this.id,
    required this.name,
    required this.type,
    this.createdAt,
  });

  final int? id;
  final String name;
  final ActivityType type;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'type': type.name,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: ActivityType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ActivityType.count,
      ),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Activity copyWith({
    int? id,
    String? name,
    ActivityType? type,
    DateTime? createdAt,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      createdAt.hashCode;
}

class ActivityRecord {
  const ActivityRecord({
    this.id,
    required this.activityId,
    required this.quantity,
    required this.timestamp,
  });

  final int? id;
  final int activityId;
  final int quantity;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'activity_id': activityId,
      'quantity': quantity,
      'timestamp': timestamp.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory ActivityRecord.fromMap(Map<String, dynamic> map) {
    return ActivityRecord(
      id: map['id'] as int?,
      activityId: map['activity_id'] as int,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  ActivityRecord copyWith({
    int? id,
    int? activityId,
    int? quantity,
    DateTime? timestamp,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      quantity: quantity ?? this.quantity,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          activityId == other.activityId &&
          quantity == other.quantity &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      id.hashCode ^
      activityId.hashCode ^
      quantity.hashCode ^
      timestamp.hashCode;
}

class ActivityStats {
  const ActivityStats({
    this.entryCount = 0,
    this.todayTotal = 0,
    this.weekTotal = 0,
    this.monthTotal = 0,
    this.yearTotal = 0,
    this.totalQuantity = 0,
    this.bestDayTotal = 0,
    this.bestDay,
  });

  final int entryCount;
  final int todayTotal;
  final int weekTotal;
  final int monthTotal;
  final int yearTotal;
  final int totalQuantity;

  /// Highest single-day total ever recorded — the user's personal best.
  /// Summed per calendar day, so many small entries and one large entry on
  /// the same day count equally.
  final int bestDayTotal;

  /// The day [bestDayTotal] was achieved, or null if there is no record yet.
  final DateTime? bestDay;

  factory ActivityStats.fromRecords(List<ActivityRecord> records, [DateTime? now]) {
    final current = now ?? DateTime.now();
    final startOfWeek = DateTime(current.year, current.month, current.day)
        .subtract(Duration(days: current.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    int today = 0;
    int week = 0;
    int month = 0;
    int year = 0;
    int total = 0;
    final perDay = <DateTime, int>{};

    for (final r in records) {
      total += r.quantity;

      final day = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
      perDay[day] = (perDay[day] ?? 0) + r.quantity;

      if (!r.timestamp.isBefore(startOfWeek) && r.timestamp.isBefore(endOfWeek)) {
        week += r.quantity;
      }

      if (r.timestamp.year == current.year) {
        year += r.quantity;
        if (r.timestamp.month == current.month) {
          month += r.quantity;
          if (r.timestamp.day == current.day) {
            today += r.quantity;
          }
        }
      }
    }

    // Only positive days count as a best; a day left net-negative by
    // corrections is not an achievement.
    DateTime? bestDay;
    int bestDayTotal = 0;
    for (final entry in perDay.entries) {
      if (entry.value > bestDayTotal) {
        bestDayTotal = entry.value;
        bestDay = entry.key;
      }
    }

    return ActivityStats(
      entryCount: records.length,
      todayTotal: today,
      weekTotal: week,
      monthTotal: month,
      yearTotal: year,
      totalQuantity: total,
      bestDayTotal: bestDayTotal,
      bestDay: bestDay,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityStats &&
          runtimeType == other.runtimeType &&
          entryCount == other.entryCount &&
          todayTotal == other.todayTotal &&
          weekTotal == other.weekTotal &&
          monthTotal == other.monthTotal &&
          yearTotal == other.yearTotal &&
          totalQuantity == other.totalQuantity &&
          bestDayTotal == other.bestDayTotal &&
          bestDay == other.bestDay;

  @override
  int get hashCode =>
      entryCount.hashCode ^
      todayTotal.hashCode ^
      weekTotal.hashCode ^
      monthTotal.hashCode ^
      yearTotal.hashCode ^
      totalQuantity.hashCode ^
      bestDayTotal.hashCode ^
      bestDay.hashCode;
}
