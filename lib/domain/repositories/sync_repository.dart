import '../entities/activity_event.dart';

abstract class SyncRepository {
  Future<void> uploadEvent(String userId, ActivityEvent event);
  // Future<List<ActivityEvent>> fetchLatestSnapshot(String userId); // Reserved for reconstruction
}
