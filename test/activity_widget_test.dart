import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/home/widgets/activity_list_item.dart';
import 'package:active/presentation/pages/home/widgets/create_activity_field.dart';

void main() {
  group('CreateActivityField Widget', () {
    testWidgets('allows entering activity name and selecting type without count field', (tester) async {
      String? submittedName;
      ActivityType? submittedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateActivityField(
              onCreate: (name, type) {
                submittedName = name;
                submittedType = type;
              },
            ),
          ),
        ),
      );

      // Only one TextField should exist (the Activity name)
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Pull-ups');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(submittedName, 'Pull-ups');
      expect(submittedType, ActivityType.count);
    });

    testWidgets('switches to time mode and submits', (tester) async {
      String? submittedName;
      ActivityType? submittedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateActivityField(
              onCreate: (name, type) {
                submittedName = name;
                submittedType = type;
              },
            ),
          ),
        ),
      );

      // Tap on Time segment (schedule icon)
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Meditation');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(submittedName, 'Meditation');
      expect(submittedType, ActivityType.time);
    });
  });

  group('ActivityListItem ExpansionTile Widget', () {
    testWidgets('displays count-based activity and expands to show Today, Weekly, Monthly, Yearly cards and allows negative rectifications', (tester) async {
      int? addedQuantity;
      const activity = Activity(
        id: 1,
        name: 'Jumping Jacks',
        type: ActivityType.count,
      );

      const stats = ActivityStats(
        entryCount: 4,
        todayTotal: 25,
        weekTotal: 50,
        monthTotal: 75,
        yearTotal: 150,
        totalQuantity: 150,
        bestDayTotal: 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityListItem(
                activity: activity,
                stats: stats,
                onAddRecord: (qty) => addedQuantity = qty,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Jumping Jacks'), findsOneWidget);
      // The chip shows the personal best to beat, not the lifetime total.
      expect(find.text('Best: 60 count'), findsOneWidget);

      // Tap ExpansionTile to expand
      await tester.tap(find.text('Jumping Jacks'));
      await tester.pumpAndSettle();

      // Check entries count and segmented cards
      expect(find.text('4 record entries · 150 count total'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('150'), findsOneWidget); // Yearly card value

      // Enter a negative record to rectify mistakes
      await tester.enterText(find.byType(TextField), '-10');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(addedQuantity, -10);
    });

    testWidgets('displays time-based activity with minutes in segmented cards and logs positive minutes', (tester) async {
      int? addedQuantity;
      const activity = Activity(
        id: 2,
        name: 'Cycling',
        type: ActivityType.time,
      );

      const stats = ActivityStats(
        entryCount: 2,
        todayTotal: 30,
        weekTotal: 60,
        monthTotal: 90,
        yearTotal: 180,
        totalQuantity: 180,
        bestDayTotal: 45,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityListItem(
                activity: activity,
                stats: stats,
                onAddRecord: (qty) => addedQuantity = qty,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text('Best: 45 min'), findsOneWidget);

      // Expand tile
      await tester.tap(find.text('Cycling'));
      await tester.pumpAndSettle();

      expect(find.text('2 record entries · 180 min total'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('180'), findsOneWidget);

      // Enter record in minutes
      await tester.enterText(find.byType(TextField), '45');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(addedQuantity, 45);
    });

    testWidgets('triggers onDelete callback when delete button is tapped', (tester) async {
      bool deleted = false;
      const activity = Activity(
        id: 3,
        name: 'Rowing',
        type: ActivityType.time,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityListItem(
                activity: activity,
                stats: const ActivityStats(),
                onAddRecord: (_) {},
                onDelete: () => deleted = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(deleted, isTrue);
    });
  });
}
