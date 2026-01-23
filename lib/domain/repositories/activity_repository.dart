import '../entities/activity.dart';

abstract class ActivityRepository {
  Future<List<Activity>> getAllActivities();
  Future<Activity?> getActivityById(String id);
  Future<void> saveActivity(Activity activity);
  Future<void> deleteActivity(String id);
  Future<void> updateActivity(Activity activity);
}
