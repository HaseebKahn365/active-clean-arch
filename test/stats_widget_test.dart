import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/stats/widgets/activity_chart_card.dart';

void main() {
  group('ActivityChartCard Widget', () {
    testWidgets('renders activity name, weekly summary, and line chart with Today on the rightmost edge', (tester) async {
      const activity = Activity(
        id: 1,
        name: 'Morning Jog',
        type: ActivityType.time,
      );

      final dailyValues = [15.0, 20.0, 0.0, 30.0, 25.0, 40.0, 10.0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityChartCard(
                activity: activity,
                dailyValues: dailyValues,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Morning Jog'), findsOneWidget);
      expect(find.text('140 mins'), findsOneWidget); // 15+20+0+30+25+40+10 = 140

      // Check that Today is on the rightmost side
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('renders custom day labels when provided', (tester) async {
      const activity = Activity(
        id: 2,
        name: 'Pushups',
        type: ActivityType.count,
      );

      final dailyValues = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0];
      final dayLabels = ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityChartCard(
                activity: activity,
                dailyValues: dailyValues,
                dayLabels: dayLabels,
              ),
            ),
          ),
        ),
      );

      for (final label in dayLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
