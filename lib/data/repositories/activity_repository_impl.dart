import '../../../domain/entities/activity.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../data_sources/local/database_service.dart';
import '../models/activity_model.dart';
import 'package:sqflite/sqflite.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final DatabaseService databaseService;

  ActivityRepositoryImpl(this.databaseService);

  @override
  Future<List<Activity>> getAllActivities() async {
    final db = await databaseService.database;
    final maps = await db.query('activities');
    return maps.map((map) => ActivityModel.fromMap(map)).toList();
  }

  @override
  Future<Activity?> getActivityById(String id) async {
    final db = await databaseService.database;
    final maps = await db.query('activities', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return ActivityModel.fromMap(maps.first);
    } else {
      return null;
    }
  }

  @override
  Future<void> saveActivity(Activity activity) async {
    final db = await databaseService.database;
    final model = ActivityModel.fromEntity(activity);
    await db.insert('activities', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteActivity(String id) async {
    final db = await databaseService.database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    final db = await databaseService.database;
    final model = ActivityModel.fromEntity(activity);
    await db.update('activities', model.toMap(), where: 'id = ?', whereArgs: [activity.id]);
  }
}
