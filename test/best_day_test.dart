import 'package:flutter_test/flutter_test.dart';

import 'package:active/presentation/pages/home/models/activity.dart';

void main() {
  ActivityRecord rec(DateTime when, int qty) =>
      ActivityRecord(activityId: 1, quantity: qty, timestamp: when);

  group('ActivityStats.bestDayTotal', () {
    test('is zero when there are no records', () {
      final stats = ActivityStats.fromRecords([]);
      expect(stats.bestDayTotal, 0);
      expect(stats.bestDay, isNull);
    });

    test('is the single entry when only one exists', () {
      final stats = ActivityStats.fromRecords([
        rec(DateTime(2026, 8, 10, 9), 40),
      ]);
      expect(stats.bestDayTotal, 40);
      expect(stats.bestDay, DateTime(2026, 8, 10));
    });

    test('sums multiple entries on the same day', () {
      // Five sets of 20 should beat a single entry of 90.
      final stats = ActivityStats.fromRecords([
        rec(DateTime(2026, 8, 10, 7), 20),
        rec(DateTime(2026, 8, 10, 9), 20),
        rec(DateTime(2026, 8, 10, 12), 20),
        rec(DateTime(2026, 8, 10, 17), 20),
        rec(DateTime(2026, 8, 10, 21), 20),
        rec(DateTime(2026, 8, 11, 9), 90),
      ]);

      expect(stats.bestDayTotal, 100);
      expect(stats.bestDay, DateTime(2026, 8, 10));
    });

    test('picks the highest day across many days', () {
      final stats = ActivityStats.fromRecords([
        rec(DateTime(2026, 8, 1, 9), 30),
        rec(DateTime(2026, 8, 5, 9), 75),
        rec(DateTime(2026, 8, 9, 9), 50),
      ]);

      expect(stats.bestDayTotal, 75);
      expect(stats.bestDay, DateTime(2026, 8, 5));
    });

    test('treats entries at different times of day as one day', () {
      final stats = ActivityStats.fromRecords([
        rec(DateTime(2026, 8, 10, 0, 1), 10),
        rec(DateTime(2026, 8, 10, 23, 59), 10),
      ]);

      expect(stats.bestDayTotal, 20);
    });

    test('nets corrections against the same day', () {
      // Logged 100 then corrected by -30; that day counts as 70.
      final stats = ActivityStats.fromRecords([
        rec(DateTime(2026, 8, 10, 9), 100),
        rec(DateTime(2026, 8, 10, 10), -30),
        rec(DateTime(2026, 8, 11, 9), 80),
      ]);

      expect(stats.bestDayTotal, 80);
      expect(stats.bestDay, DateTime(2026, 8, 11));
    });

    test('never reports a net-negative day as a best', () {
      final stats = ActivityStats.fromRecords([
        rec(DateTime(2026, 8, 10, 9), 10),
        rec(DateTime(2026, 8, 10, 10), -25),
      ]);

      expect(stats.bestDayTotal, 0);
      expect(stats.bestDay, isNull);
    });

    test('is independent of the lifetime total', () {
      // Many small days accumulate a large total but a modest best.
      final stats = ActivityStats.fromRecords([
        for (var day = 1; day <= 20; day++) rec(DateTime(2026, 8, day, 9), 50),
      ]);

      expect(stats.totalQuantity, 1000);
      expect(stats.bestDayTotal, 50);
    });
  });
}
