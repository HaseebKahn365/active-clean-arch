import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/agent/models/pending_action.dart';
import 'package:active/presentation/pages/agent/services/agent_tools.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AgentTools write operations', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late AgentTools tools;

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
      // The analytical tool would otherwise open the real on-disk database.
      dbHelper.debugSetReadOnlyDatabase(db);
      tools = AgentTools(db: dbHelper);
    });

    tearDown(() async {
      await db.close();
    });

    test('create_activity inserts a new count activity', () async {
      final result = await tools.dispatch(FunctionCall('create_activity', {
        'name': 'Bicep Curls',
        'type': 'count',
      }));

      expect(result['created'], isTrue);
      expect(result['activity_name'], 'Bicep Curls');
      expect(result['unit'], 'count');

      final stored = await dbHelper.getActivities();
      expect(stored, hasLength(1));
      expect(stored.first.name, 'Bicep Curls');
      expect(stored.first.type, ActivityType.count);
    });

    test('create_activity maps "time" to a minutes activity', () async {
      await tools.dispatch(FunctionCall('create_activity', {
        'name': 'Meditation',
        'type': 'time',
      }));

      final stored = await dbHelper.getActivities();
      expect(stored.first.type, ActivityType.time);
    });

    test('create_activity refuses to duplicate an existing name', () async {
      await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );

      final result = await tools.dispatch(FunctionCall('create_activity', {
        'name': 'pushups',
        'type': 'count',
      }));

      expect(result['created'], isFalse);
      expect(result['reason'], contains('already exists'));
      expect(await dbHelper.getActivities(), hasLength(1));
    });

    test('log_record appends an entry and reports the new total', () async {
      await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );

      final result = await tools.dispatch(FunctionCall('log_record', {
        'activity_name': 'Pushups',
        'quantity': 20,
      }));

      expect(result['logged'], isTrue);
      expect(result['quantity'], 20);
      expect(result['new_total'], 20);
    });

    test('log_record accepts a negative quantity as a correction', () async {
      final activity = await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );
      await dbHelper.insertRecord(ActivityRecord(
        activityId: activity.id!,
        quantity: 50,
        timestamp: DateTime.now(),
      ));

      final result = await tools.dispatch(FunctionCall('log_record', {
        'activity_name': 'Pushups',
        'quantity': -10,
      }));

      expect(result['logged'], isTrue);
      expect(result['new_total'], 40);
    });

    test('log_record rejects a zero quantity', () async {
      await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );

      final result = await tools.dispatch(FunctionCall('log_record', {
        'activity_name': 'Pushups',
        'quantity': 0,
      }));

      expect(result['error'], contains('zero'));
    });

    test('log_record against a missing activity guides the model', () async {
      final result = await tools.dispatch(FunctionCall('log_record', {
        'activity_name': 'Swimming',
        'quantity': 10,
      }));

      expect(result['error'], contains('create_activity'));
    });

    test('log_record honours an explicit past date', () async {
      final activity = await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );

      await tools.dispatch(FunctionCall('log_record', {
        'activity_name': 'Pushups',
        'quantity': 15,
        'date': '2026-08-10',
      }));

      final records = await dbHelper.getRecordsForActivity(activity.id!);
      expect(records, hasLength(1));
      expect(records.first.timestamp.year, 2026);
      expect(records.first.timestamp.month, 8);
      expect(records.first.timestamp.day, 10);
    });

    test('request_delete_activity does NOT delete, only proposes', () async {
      final activity = await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );
      await dbHelper.insertRecord(ActivityRecord(
        activityId: activity.id!,
        quantity: 5,
        timestamp: DateTime.now(),
      ));

      final result = await tools.dispatch(
        FunctionCall('request_delete_activity', {'activity_name': 'Pushups'}),
      );

      expect(result['confirmation_required'], isTrue);
      expect(result['records_that_would_be_deleted'], 1);

      // Critically: still present.
      expect(await dbHelper.getActivities(), hasLength(1));

      expect(tools.pendingAction, isNotNull);
      expect(tools.pendingAction!.kind, PendingActionKind.deleteActivity);
      expect(tools.pendingAction!.targetId, activity.id);
      expect(tools.pendingAction!.recordCount, 1);
    });

    test('run_analytical_query returns rows for a valid SELECT', () async {
      final activity = await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );
      await dbHelper.insertRecord(ActivityRecord(
        activityId: activity.id!,
        quantity: 25,
        timestamp: DateTime(2026, 8, 18, 9),
      ));

      final result = await tools.dispatch(FunctionCall('run_analytical_query', {
        'sql': 'SELECT SUM(quantity) AS total FROM records',
        'purpose': 'lifetime total',
      }));

      expect(result['error'], isNull);
      expect(result['row_count'], 1);
      expect((result['rows'] as List).first, containsPair('total', 25));
    });

    test('run_analytical_query refuses a mutation', () async {
      await dbHelper.insertActivity(
        Activity(name: 'Pushups', type: ActivityType.count),
      );

      final result = await tools.dispatch(FunctionCall('run_analytical_query', {
        'sql': 'DELETE FROM activities',
        'purpose': 'cleanup',
      }));

      expect(result['error'], contains('rejected'));
      // Data untouched.
      expect(await dbHelper.getActivities(), hasLength(1));
    });
  });
}
