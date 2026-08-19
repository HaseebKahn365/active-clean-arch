import 'package:flutter_test/flutter_test.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

void main() {
  group('Activity Model', () {
    test('serializes to map and deserializes from map correctly', () {
      final now = DateTime.now();
      final activity = Activity(
        id: 1,
        name: 'Pushups',
        type: ActivityType.count,
        createdAt: now,
      );

      final map = activity.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Pushups');
      expect(map['type'], 'count');
      expect(map['created_at'], now.toIso8601String());

      final restored = Activity.fromMap(map);
      expect(restored.id, activity.id);
      expect(restored.name, activity.name);
      expect(restored.type, activity.type);
    });

    test('copyWith updates fields as expected', () {
      const activity = Activity(
        name: 'Meditation',
        type: ActivityType.time,
      );

      final updated = activity.copyWith(id: 10, name: 'Deep Meditation');
      expect(updated.id, 10);
      expect(updated.name, 'Deep Meditation');
      expect(updated.type, ActivityType.time);
    });
  });

  group('ActivityRecord Model', () {
    test('serializes and deserializes record with quantity and foreign id', () {
      final timestamp = DateTime.now();
      final record = ActivityRecord(
        id: 1,
        activityId: 5,
        quantity: 25,
        timestamp: timestamp,
      );

      final map = record.toMap();
      expect(map['id'], 1);
      expect(map['activity_id'], 5);
      expect(map['quantity'], 25);
      expect(map['timestamp'], timestamp.toIso8601String());

      final restored = ActivityRecord.fromMap(map);
      expect(restored.id, record.id);
      expect(restored.activityId, record.activityId);
      expect(restored.quantity, record.quantity);
      expect(restored.timestamp.toIso8601String(), record.timestamp.toIso8601String());
    });
  });

  group('ActivityStats Model', () {
    test('computes entryCount, today, weekly, monthly, and yearly totals accurately including negative rectification', () {
      // 2026-08-19 is Wednesday
      final now = DateTime(2026, 8, 19, 11, 0, 0);

      final records = [
        // Today
        ActivityRecord(activityId: 1, quantity: 20, timestamp: DateTime(2026, 8, 19, 8, 0, 0)),
        ActivityRecord(activityId: 1, quantity: -5, timestamp: DateTime(2026, 8, 19, 9, 0, 0)), // Rectification
        ActivityRecord(activityId: 1, quantity: 15, timestamp: DateTime(2026, 8, 19, 10, 30, 0)),
        // Earlier this week (Monday 2026-08-17)
        ActivityRecord(activityId: 1, quantity: 10, timestamp: DateTime(2026, 8, 17, 12, 0, 0)),
        // Earlier this month (outside this week)
        ActivityRecord(activityId: 1, quantity: 50, timestamp: DateTime(2026, 8, 5, 9, 0, 0)),
        // Earlier this year (different month)
        ActivityRecord(activityId: 1, quantity: 100, timestamp: DateTime(2026, 3, 12, 14, 0, 0)),
        // Last year
        ActivityRecord(activityId: 1, quantity: 200, timestamp: DateTime(2025, 12, 1, 10, 0, 0)),
      ];

      final stats = ActivityStats.fromRecords(records, now);

      expect(stats.entryCount, 7);
      expect(stats.todayTotal, 30); // 20 - 5 + 15
      expect(stats.weekTotal, 40); // 30 + 10
      expect(stats.monthTotal, 90); // 40 + 50
      expect(stats.yearTotal, 190); // 90 + 100
      expect(stats.totalQuantity, 390); // 190 + 200
    });
  });
}
