import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/count_record.dart';
import '../../domain/repositories/activity_repository.dart';

class InMemoryActivityRepository implements ActivityRepository {
  final Map<String, Activity> _activities = {};
  final List<ActivityEvent> _events = [];
  final List<CountRecord> _countRecords = [];

  InMemoryActivityRepository({List<Activity>? initialActivities}) {
    if (initialActivities != null) {
      for (final activity in initialActivities) {
        _activities[activity.id] = activity;
      }
    }
  }

  @override
  Future<List<Activity>> getAllActivities() async {
    // Simulate network/disk delay
    await Future.delayed(const Duration(milliseconds: 50));
    return _activities.values.toList();
  }

  @override
  Future<Activity?> getActivityById(String id) async {
    return _activities[id];
  }

  @override
  Future<void> saveActivity(Activity activity) async {
    _activities[activity.id] = activity;
  }

  @override
  Future<void> deleteActivity(String id) async {
    _activities.remove(id);
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    if (_activities.containsKey(activity.id)) {
      _activities[activity.id] = activity;
    }
  }

  @override
  Future<void> saveEvent(ActivityEvent event) async {
    _events.add(event);
  }

  @override
  Future<List<ActivityEvent>> getUnsyncedEvents() async {
    return List.from(_events); // Return a copy to avoid concurrent modification
  }

  @override
  Future<void> markEventAsSynced(String id) async {
    // No-op for in-memory
  }

  @override
  Future<void> saveCountRecord(CountRecord record) async {
    _countRecords.add(record);
  }

  @override
  Future<List<CountRecord>> getCountRecordsForActivity(String activityId) async {
    return _countRecords.where((r) => r.activityId == activityId).toList();
  }

  @override
  Future<void> deleteCountRecord(String id) async {
    _countRecords.removeWhere((r) => r.id == id);
  }
}
