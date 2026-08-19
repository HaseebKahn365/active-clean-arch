import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/agent/services/agent_tools.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AgentTools', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late AgentTools tools;

    // Fixed reference point so range assertions stay deterministic.
    final today = DateTime(2026, 8, 19);
    final yesterday = today.subtract(const Duration(days: 1));

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
      tools = AgentTools(db: dbHelper);
    });

    tearDown(() async {
      await db.close();
    });

    Future<Activity> seedPushups() async {
      final activity = await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count, createdAt: today),
      );
      // 30 yesterday (two entries), 10 today.
      await dbHelper.insertRecord(ActivityRecord(
        activityId: activity.id!,
        quantity: 20,
        timestamp: yesterday.add(const Duration(hours: 9)),
      ));
      await dbHelper.insertRecord(ActivityRecord(
        activityId: activity.id!,
        quantity: 10,
        timestamp: yesterday.add(const Duration(hours: 18)),
      ));
      await dbHelper.insertRecord(ActivityRecord(
        activityId: activity.id!,
        quantity: 10,
        timestamp: today.add(const Duration(hours: 8)),
      ));
      return activity;
    }

    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    test('list_activities returns activities with totals', () async {
      await seedPushups();

      final result = await tools.dispatch(
        const FunctionCall('list_activities', {}),
      );

      final activities = result['activities'] as List;
      expect(activities, hasLength(1));
      expect(activities.first, {
        'name': 'Pushups',
        'type': 'count',
        'total_logged': 40,
      });
    });

    test('get_activity_summary scopes totals to an exclusive end date', () async {
      await seedPushups();

      final result = await tools.dispatch(FunctionCall('get_activity_summary', {
        'activity_name': 'Pushups',
        'start_date': iso(yesterday),
        'end_date': iso(today), // exclusive -> yesterday only
        'label': 'yesterday',
      }));

      expect(result['activity_name'], 'Pushups');
      expect(result['total'], 30);
      expect(result['entry_count'], 2);
      expect(result['unit'], 'count');
      expect(result['label'], 'yesterday');
    });

    test('get_activity_records returns individual entries in range', () async {
      await seedPushups();

      final result = await tools.dispatch(FunctionCall('get_activity_records', {
        'activity_name': 'Pushups',
        'start_date': iso(yesterday),
        'end_date': iso(today.add(const Duration(days: 1))),
      }));

      final records = result['records'] as List;
      expect(records, hasLength(3));
      expect(result['total'], 40);
      expect(records.first, containsPair('quantity', 20));
    });

    test('resolves activity names case-insensitively and by partial match', () async {
      await seedPushups();

      final result = await tools.dispatch(FunctionCall('get_activity_summary', {
        'activity_name': 'push',
        'start_date': iso(yesterday),
        'end_date': iso(today.add(const Duration(days: 1))),
        'label': 'recent',
      }));

      expect(result['activity_name'], 'Pushups');
      expect(result['total'], 40);
    });

    test('reports an error for an unknown activity instead of throwing', () async {
      await seedPushups();

      final result = await tools.dispatch(FunctionCall('get_activity_summary', {
        'activity_name': 'Swimming',
        'start_date': iso(yesterday),
        'end_date': iso(today),
        'label': 'yesterday',
      }));

      expect(result['error'], contains('Swimming'));
    });

    test('empty range returns a zero total rather than an error', () async {
      await seedPushups();

      final result = await tools.dispatch(FunctionCall('get_activity_summary', {
        'activity_name': 'Pushups',
        'start_date': '2026-01-01',
        'end_date': '2026-01-08',
        'label': 'first week of January',
      }));

      expect(result['error'], isNull);
      expect(result['total'], 0);
      expect(result['entry_count'], 0);
    });

    test('compare_activities returns a row per activity, marking missing ones', () async {
      await seedPushups();
      final reading = await dbHelper.insertActivity(
        Activity(name: 'Reading', type: ActivityType.time, createdAt: today),
      );
      await dbHelper.insertRecord(ActivityRecord(
        activityId: reading.id!,
        quantity: 45,
        timestamp: yesterday.add(const Duration(hours: 20)),
      ));

      final result = await tools.dispatch(FunctionCall('compare_activities', {
        'activity_names': ['Pushups', 'Reading', 'Yoga'],
        'start_date': iso(yesterday),
        'end_date': iso(today),
        'label': 'yesterday',
      }));

      final comparison = result['comparison'] as List;
      expect(comparison, hasLength(3));
      expect(comparison[0], {
        'activity_name': 'Pushups',
        'unit': 'count',
        'total': 30,
      });
      expect(comparison[1], {
        'activity_name': 'Reading',
        'unit': 'min',
        'total': 45,
      });
      expect(comparison[2], containsPair('error', 'not found'));
    });

    test('invalid dates surface an error result', () async {
      await seedPushups();

      final result = await tools.dispatch(FunctionCall('get_activity_summary', {
        'activity_name': 'Pushups',
        'start_date': 'last tuesday',
        'end_date': 'today',
        'label': 'whenever',
      }));

      expect(result['error'], contains('YYYY-MM-DD'));
    });

    test('unknown tool name is reported, not thrown', () async {
      final result = await tools.dispatch(const FunctionCall('drop_database', {}));
      expect(result['error'], contains('Unknown tool'));
    });
  });
}
