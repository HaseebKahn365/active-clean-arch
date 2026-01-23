import '../entities/activity.dart';
import '../entities/activity_event.dart';

abstract class ActivityRepository {
  Future<List<Activity>> getAllActivities();
  Future<Activity?> getActivityById(String id);
  Future<void> saveActivity(Activity activity);
  Future<void> deleteActivity(String id);
  Future<void> updateActivity(Activity activity);
  Future<void> saveEvent(ActivityEvent event);
  Future<List<ActivityEvent>> getUnsyncedEvents();
  Future<void> markEventAsSynced(String id);
}
