import '../entities/activity.dart';
import '../entities/activity_event.dart';
import '../entities/count_record.dart';

enum SaveReason { immediate, periodic }

abstract class ActivityRepository {
  Future<List<Activity>> getAllActivities();
  Future<Activity?> getActivityById(String id);
  Future<void> saveActivity(Activity activity, {SaveReason reason = SaveReason.immediate, bool isRemoteUpdate = false});
  Future<void> deleteActivity(String id, {bool isRemoteUpdate = false});
  Future<void> updateActivity(Activity activity, {SaveReason reason = SaveReason.immediate, bool isRemoteUpdate = false});
  Future<void> saveEvent(ActivityEvent event, {SaveReason reason = SaveReason.immediate, bool isRemoteUpdate = false});
  Future<List<ActivityEvent>> getAllEvents();

  // Count Records
  Future<void> saveCountRecord(CountRecord record, {bool isRemoteUpdate = false});
  Future<List<CountRecord>> getAllCountRecords();
  Future<List<CountRecord>> getCountRecordsForActivity(String activityId);
  Future<void> deleteCountRecord(String id, {bool isRemoteUpdate = false});
  Future<void> clearAllData();
}
