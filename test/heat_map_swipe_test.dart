import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/stats/widgets/monthly_heat_map.dart';

void main() {
  group('MonthlyHeatMap swipe navigation', () {
    // A month safely in the past so forward navigation is allowed.
    final pastMonth = DateTime(2025, 6, 1);

    Future<DateTime?> pumpAndSwipe(
      WidgetTester tester, {
      required DateTime month,
      required Offset offset,
    }) async {
      DateTime? changedTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyHeatMap(
                currentMonth: month,
                dailyTotals: const {5: 20, 12: 40},
                activityType: ActivityType.count,
                onMonthChanged: (m) => changedTo = m,
              ),
            ),
          ),
        ),
      );

      await tester.fling(find.byType(MonthlyHeatMap), offset, 800);
      await tester.pumpAndSettle();
      return changedTo;
    }

    testWidgets('swiping right goes to the previous month', (tester) async {
      final result = await pumpAndSwipe(
        tester,
        month: pastMonth,
        offset: const Offset(300, 0),
      );

      expect(result, isNotNull);
      expect(result!.year, 2025);
      expect(result.month, 5); // May
    });

    testWidgets('swiping left goes to the next month', (tester) async {
      final result = await pumpAndSwipe(
        tester,
        month: pastMonth,
        offset: const Offset(-300, 0),
      );

      expect(result, isNotNull);
      expect(result!.year, 2025);
      expect(result.month, 7); // July
    });

    testWidgets('swiping right across a year boundary', (tester) async {
      final result = await pumpAndSwipe(
        tester,
        month: DateTime(2025, 1, 1),
        offset: const Offset(300, 0),
      );

      expect(result!.year, 2024);
      expect(result.month, 12);
    });

    testWidgets('swiping left is blocked on the current month', (tester) async {
      // The chevron is disabled for the current month; the swipe must honour
      // the same rule rather than navigating into the future.
      final now = DateTime.now();
      final result = await pumpAndSwipe(
        tester,
        month: DateTime(now.year, now.month, 1),
        offset: const Offset(-300, 0),
      );

      expect(result, isNull);
    });

    testWidgets('swiping right still works on the current month', (
      tester,
    ) async {
      final now = DateTime.now();
      final result = await pumpAndSwipe(
        tester,
        month: DateTime(now.year, now.month, 1),
        offset: const Offset(300, 0),
      );

      expect(result, isNotNull);
    });

    testWidgets('a small hesitant drag does not change month', (tester) async {
      DateTime? changedTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyHeatMap(
                currentMonth: pastMonth,
                dailyTotals: const {5: 20},
                activityType: ActivityType.count,
                onMonthChanged: (m) => changedTo = m,
              ),
            ),
          ),
        ),
      );

      // Drag slowly: a deliberate flick is required.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MonthlyHeatMap)),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedTo, isNull);
    });

    testWidgets('chevron buttons still work alongside the gesture', (
      tester,
    ) async {
      DateTime? changedTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyHeatMap(
                currentMonth: pastMonth,
                dailyTotals: const {5: 20},
                activityType: ActivityType.count,
                onMonthChanged: (m) => changedTo = m,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(changedTo, isNotNull);
      expect(changedTo!.month, 5);
    });
  });
}
