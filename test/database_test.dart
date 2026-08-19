import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper SQLite Activities & Records Tables', () {
    late Database db;
    late DatabaseHelper dbHelper;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      await db.execute('''
        CREATE TABLE activities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          activity_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
        )
      ''');
      dbHelper = DatabaseHelper(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts activities and logs records with foreign key relationship', () async {
      final act1 = await dbHelper.insertActivity(
        Activity(
          name: 'Pushups',
          type: ActivityType.count,
          createdAt: DateTime.parse('2026-08-19T10:00:00.000Z'),
        ),
      );
      final act2 = await dbHelper.insertActivity(
        Activity(
          name: 'Running',
          type: ActivityType.time,
          createdAt: DateTime.parse('2026-08-19T11:00:00.000Z'),
        ),
      );

      expect(act1.id, isNotNull);
      expect(act2.id, isNotNull);

      // Add count-based records for Pushups
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act1.id!,
          quantity: 20,
          timestamp: DateTime.parse('2026-08-19T10:05:00.000Z'),
        ),
      );
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act1.id!,
          quantity: 15,
          timestamp: DateTime.parse('2026-08-19T10:10:00.000Z'),
        ),
      );

      // Add time-based record for Running (30 minutes)
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act2.id!,
          quantity: 30,
          timestamp: DateTime.parse('2026-08-19T11:30:00.000Z'),
        ),
      );

      // Check records for Pushups
      final pushupRecords = await dbHelper.getRecordsForActivity(act1.id!);
      expect(pushupRecords.length, 2);

      // Check total quantities
      final pushupTotal = await dbHelper.getTotalQuantityForActivity(act1.id!);
      expect(pushupTotal, 35); // 20 + 15

      final runningTotal = await dbHelper.getTotalQuantityForActivity(act2.id!);
      expect(runningTotal, 30); // 30 minutes

      final allTotals = await dbHelper.getTotalQuantities();
      expect(allTotals[act1.id!], 35);
      expect(allTotals[act2.id!], 30);
    });

    test('retrieves activity stats with period breakdown', () async {
      final act = await dbHelper.insertActivity(
        const Activity(name: 'Swimming', type: ActivityType.time),
      );

      final now = DateTime.now();
      await dbHelper.insertRecord(
        ActivityRecord(activityId: act.id!, quantity: 20, timestamp: now),
      );
      await dbHelper.insertRecord(
        ActivityRecord(activityId: act.id!, quantity: 25, timestamp: now),
      );

      final stats = await dbHelper.getActivityStats(act.id!);
      expect(stats.entryCount, 2);
      expect(stats.todayTotal, 45);
      expect(stats.monthTotal, 45);
      expect(stats.yearTotal, 45);
      expect(stats.totalQuantity, 45);

      final allStats = await dbHelper.getAllActivityStats();
      expect(allStats[act.id!]?.entryCount, 2);
    });

    test('computes getWeeklyDailyTotals accurately for trailing 7 days ending on today', () async {
      final act = await dbHelper.insertActivity(
        const Activity(name: 'Walking', type: ActivityType.count),
      );

      // Wednesday 2026-08-19
      final now = DateTime(2026, 8, 19, 12, 0, 0);

      // Thursday 6 days ago (index 0: 2026-08-13)
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act.id!,
          quantity: 500,
          timestamp: DateTime(2026, 8, 13, 10, 0, 0),
        ),
      );
      // Monday 2 days ago (index 4: 2026-08-17)
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act.id!,
          quantity: 1000,
          timestamp: DateTime(2026, 8, 17, 10, 0, 0),
        ),
      );
      // Today Wednesday (index 6: 2026-08-19)
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act.id!,
          quantity: 2500,
          timestamp: DateTime(2026, 8, 19, 14, 0, 0),
        ),
      );

      final weekly = await dbHelper.getWeeklyDailyTotals(now);
      // Index 0: 500, Index 1-3: 0, Index 4: 1000, Index 5: 0, Index 6 (Today): 2500
      expect(weekly[act.id!], [500.0, 0.0, 0.0, 0.0, 1000.0, 0.0, 2500.0]);
    });

    test('computes getMonthlyDailyTotals for a specific month', () async {
      final act = await dbHelper.insertActivity(
        const Activity(name: 'Reading', type: ActivityType.time),
      );

      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act.id!,
          quantity: 30,
          timestamp: DateTime(2026, 8, 1, 10, 0, 0),
        ),
      );
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act.id!,
          quantity: 45,
          timestamp: DateTime(2026, 8, 15, 14, 0, 0),
        ),
      );
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act.id!,
          quantity: -10,
          timestamp: DateTime(2026, 8, 15, 16, 0, 0),
        ),
      );

      final monthly = await dbHelper.getMonthlyDailyTotals(act.id!, 2026, 8);
      expect(monthly[1], 30);
      expect(monthly[15], 35); // 45 - 10
    });

    test('supports pagination with getPaginatedRecords and getRecordCountForActivity', () async {
      final act = await dbHelper.insertActivity(
        const Activity(name: 'Squats', type: ActivityType.count),
      );

      for (int i = 1; i <= 25; i++) {
        await dbHelper.insertRecord(
          ActivityRecord(
            activityId: act.id!,
            quantity: i * 5,
            timestamp: DateTime(2026, 8, 1, 10, 0, 0).add(Duration(minutes: i)),
          ),
        );
      }

      final count = await dbHelper.getRecordCountForActivity(act.id!);
      expect(count, 25);

      final page1 = await dbHelper.getPaginatedRecords(act.id!, limit: 10, offset: 0);
      expect(page1.length, 10);
      expect(page1.first.quantity, 125); // 25 * 5 (most recent)

      final page2 = await dbHelper.getPaginatedRecords(act.id!, limit: 10, offset: 10);
      expect(page2.length, 10);

      final page3 = await dbHelper.getPaginatedRecords(act.id!, limit: 10, offset: 20);
      expect(page3.length, 5);
    });

    test('deleting an activity cascades to delete its records', () async {
      final act = await dbHelper.insertActivity(
        const Activity(name: 'Cycling', type: ActivityType.time),
      );

      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act.id!,
          quantity: 45,
          timestamp: DateTime.now(),
        ),
      );

      expect((await dbHelper.getRecordsForActivity(act.id!)).length, 1);

      await dbHelper.deleteActivity(act.id!);

      expect((await dbHelper.getActivities()).length, 0);
      expect((await dbHelper.getRecordsForActivity(act.id!)).length, 0);
    });
  });
}
