import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_event.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../infrastructure/database/sqlite_service.dart';
import '../models/activity_model.dart';
import '../models/activity_event_model.dart';
import 'package:sqflite/sqflite.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final SqliteService sqliteService;

  ActivityRepositoryImpl(this.sqliteService);

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
  Future<void> saveActivity(Activity activity) async {
    final db = await sqliteService.database;
    final model = ActivityModel.fromEntity(activity);
    await db.insert('activities', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteActivity(String id) async {
    final db = await sqliteService.database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    final db = await sqliteService.database;
    final model = ActivityModel.fromEntity(activity);
    await db.update('activities', model.toMap(), where: 'id = ?', whereArgs: [activity.id]);
  }

  @override
  Future<void> saveEvent(ActivityEvent event) async {
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
      isSynced: event.isSynced,
    );
    await db.insert('activity_events', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ActivityEvent>> getUnsyncedEvents() async {
    final db = await sqliteService.database;
    final maps = await db.query('activity_events', where: 'is_synced = 0');
    return maps.map((map) => ActivityEventModel.fromMap(map)).toList();
  }

  @override
  Future<void> markEventAsSynced(String id) async {
    final db = await sqliteService.database;
    await db.update('activity_events', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
