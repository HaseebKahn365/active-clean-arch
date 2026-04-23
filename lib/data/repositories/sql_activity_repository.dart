import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_event.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../infrastructure/database/sqlite_service.dart';
import '../models/activity_model.dart';
import '../models/activity_event_model.dart';
import '../models/count_record_model.dart';
import '../../../domain/entities/count_record.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/di/injection_container.dart';
import '../../infrastructure/services/firestore_sync_service.dart';

class SqlActivityRepository implements ActivityRepository {
  final SqliteService sqliteService;

  SqlActivityRepository(this.sqliteService);

  @override
  Future<List<Activity>> getAllActivities() async {
    final db = await sqliteService.database;
    final maps = await db.query('activities');
    return maps.map((map) => ActivityModel.fromMap(map)).toList();
  }

  @override
  Future<Activity?> getActivityById(String id) async {
    final db = await sqliteService.database;
    final maps = await db.query('activities', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return ActivityModel.fromMap(maps.first);
    } else {
      return null;
    }
  }

  @override
  Future<void> saveActivity(Activity activity, {SaveReason reason = SaveReason.immediate, bool isRemoteUpdate = false}) async {
    debugPrint('SQL_SAVE: ${reason.name.toUpperCase()} | Activity: ${activity.id}');
    final db = await sqliteService.database;
    final model = ActivityModel.fromEntity(activity);
    await db.insert('activities', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    if (reason == SaveReason.periodic) {
      dev.log("SYNC BLOCKED: periodic update");
      return;
    }

    if (!isRemoteUpdate) {
      sl<FirestoreSyncService>().pushActivity(activity);
    } else {
      dev.log("SYNC SKIP: Remote update ignored for re-sync | id=${activity.id}");
    }
  }

  @override
  Future<void> deleteActivity(String id, {bool isRemoteUpdate = false}) async {
    debugPrint('SQL_SAVE: IMMEDIATE | Delete Activity: $id');
    final db = await sqliteService.database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);

    if (!isRemoteUpdate) {
      final dummyActivity = Activity(id: id, name: '', status: ActivityStatus.idle, createdAt: DateTime.now(), totalSeconds: 0, childrenIds: [], updatedAt: DateTime.now());
      sl<FirestoreSyncService>().pushActivity(dummyActivity, isDelete: true);
    } else {
      dev.log("SYNC SKIP: Remote update ignored for re-sync | id=$id (deleted)");
    }
  }

  @override
  Future<void> updateActivity(Activity activity, {SaveReason reason = SaveReason.immediate, bool isRemoteUpdate = false}) async {
    debugPrint('SQL_SAVE: ${reason.name.toUpperCase()} | Activity: ${activity.id}');
    final db = await sqliteService.database;
    final model = ActivityModel.fromEntity(activity);
    await db.update('activities', model.toMap(), where: 'id = ?', whereArgs: [activity.id]);

    if (reason == SaveReason.periodic) {
      dev.log("SYNC BLOCKED: periodic update");
      return;
    }

    if (!isRemoteUpdate) {
      sl<FirestoreSyncService>().pushActivity(activity);
    } else {
      dev.log("SYNC SKIP: Remote update ignored for re-sync | id=${activity.id}");
    }
  }

  @override
  Future<void> saveEvent(ActivityEvent event, {SaveReason reason = SaveReason.immediate, bool isRemoteUpdate = false}) async {
    debugPrint('SQL_SAVE: IMMEDIATE | Event Activity: ${event.activityId}');

    final db = await sqliteService.database;
    final model = ActivityEventModel(
      id: event.id,
      activityId: event.activityId,
      timestamp: event.timestamp,
      durationDelta: event.durationDelta,
      previousStatus: event.previousStatus,
      nextStatus: event.nextStatus,
      oldParentId: event.oldParentId,
      newParentId: event.newParentId,
      oldDuration: event.oldDuration,
      newDuration: event.newDuration,
    );
    await db.insert('activity_events', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    if (reason == SaveReason.periodic) {
      dev.log("SYNC BLOCKED: periodic update (event)");
      return;
    }

    if (!isRemoteUpdate) {
      sl<FirestoreSyncService>().pushEvent(event);
    } else {
      dev.log("SYNC SKIP: Remote update ignored for re-sync | event_id=${event.id}");
    }
  }

  @override
  Future<List<ActivityEvent>> getAllEvents() async {
    final db = await sqliteService.database;
    final maps = await db.query('activity_events');
    return maps.map((map) => ActivityEventModel.fromMap(map)).toList();
  }

  @override
  Future<void> saveCountRecord(CountRecord record, {bool isRemoteUpdate = false}) async {
    debugPrint('SQL_SAVE: IMMEDIATE | Count Activity: ${record.activityId}');

    final db = await sqliteService.database;
    final model = CountRecordModel.fromEntity(record);
    await db.insert('count_records', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    if (!isRemoteUpdate) {
      sl<FirestoreSyncService>().pushCountRecord(record);
    } else {
      dev.log("SYNC SKIP: Remote update ignored for re-sync | record_id=${record.id}");
    }
  }

  @override
  Future<List<CountRecord>> getAllCountRecords() async {
    final db = await sqliteService.database;
    final maps = await db.query('count_records');
    return maps.map((map) => CountRecordModel.fromMap(map)).toList();
  }

  @override
  Future<List<CountRecord>> getCountRecordsForActivity(String activityId) async {
    final db = await sqliteService.database;
    final maps = await db.query('count_records', where: 'activity_id = ?', whereArgs: [activityId]);
    return maps.map((map) => CountRecordModel.fromMap(map)).toList();
  }

  @override
  Future<void> deleteCountRecord(String id, {bool isRemoteUpdate = false}) async {
    final db = await sqliteService.database;
    await db.delete('count_records', where: 'id = ?', whereArgs: [id]);

    if (!isRemoteUpdate) {
      final dummyRecord = CountRecord(id: id, activityId: '', value: 0, timestamp: DateTime.now());
      sl<FirestoreSyncService>().pushCountRecord(dummyRecord, isDelete: true);
    } else {
      dev.log("SYNC SKIP: Remote update ignored for re-sync | record_id=$id (deleted)");
    }
  }

  @override
  Future<void> clearAllData() async {
    debugPrint('SQL_SAVE: IMMEDIATE | Clear All Data');
    final db = await sqliteService.database;
    await db.delete('activities');
    await db.delete('activity_events');
    await db.delete('count_records');
  }
}
