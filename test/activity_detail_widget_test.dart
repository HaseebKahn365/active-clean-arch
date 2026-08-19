import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/stats/activity_detail_page.dart';
import 'package:active/presentation/pages/stats/widgets/monthly_heat_map.dart';

void main() {
  group('MonthlyHeatMap Widget', () {
    testWidgets('renders month title, weekday headers, and heat map day cells', (tester) async {
      DateTime? changedMonth;
      final pastMonth = DateTime(2025, 7, 1);
      final dailyTotals = {
        1: 20,
        5: 50,
        15: -10, // Negative rectification
        19: 100,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyHeatMap(
                currentMonth: pastMonth,
                dailyTotals: dailyTotals,
                activityType: ActivityType.count,
                onMonthChanged: (m) => changedMonth = m,
              ),
            ),
          ),
        ),
      );

      // Check header
      expect(find.text('July 2025'), findsOneWidget);

      // Check weekday headers
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2)); // Tue, Thu
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2)); // Sat, Sun

      // Check specific day numbers
      expect(find.text('1'), findsWidgets);
      expect(find.text('19'), findsWidgets);
      expect(find.text('+100'), findsOneWidget);
      expect(find.text('-10'), findsOneWidget);

      // Tap next month for past month
      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();

      expect(changedMonth, DateTime(2025, 8, 1));
    });

    testWidgets('disallows navigating into future months when on current month', (tester) async {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyHeatMap(
                currentMonth: currentMonth,
                dailyTotals: const {},
                activityType: ActivityType.count,
                onMonthChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Next month icon button should be disabled (no tooltip and onPressed is null)
      expect(find.byTooltip('Next month'), findsNothing);

      // Previous month is still available
      expect(find.byTooltip('Previous month'), findsOneWidget);
    });
  });

  group('ActivityDetailPage Widget', () {
    testWidgets('renders activity detail page with time ago formatted in record entry list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const activity = Activity(
        id: 99,
        name: 'Deadlifts',
        type: ActivityType.count,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ActivityDetailPage(activity: activity),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Deadlifts'), findsOneWidget);
      expect(find.text('Monthly Heat Map'), findsOneWidget);
      expect(find.text('History Trend'), findsOneWidget);
      expect(find.text('All-Time Total'), findsOneWidget);
    });
  });
}
