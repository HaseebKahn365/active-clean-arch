import 'package:uuid/uuid.dart';
import '../../entities/activity.dart';
import '../../entities/activity_event.dart';
import '../../repositories/activity_repository.dart';

class CheckpointActivityUseCase {
  final ActivityRepository repository;

  CheckpointActivityUseCase(this.repository);

  Future<void> execute(String activityId) async {
    final activity = await repository.getActivityById(activityId);
    if (activity == null || activity.status != ActivityStatus.running || activity.startedAt == null) {
      return;
    }

    final now = DateTime.now();
    final deltaSeconds = now.difference(activity.startedAt!).inSeconds;

    // Checkpoint strategy: Update total_seconds but stay 'running' with a new started_at
    final updatedActivity = activity.copyWith(totalSeconds: activity.totalSeconds + deltaSeconds, startedAt: () => now);

    await repository.updateActivity(updatedActivity, reason: SaveReason.periodic);

    // Also log an event if required by audit trail, though Step 13 says "Checkpoint"
    // to ensure zero data loss. We'll log it as a checkpoint event.
    await repository.saveEvent(
      ActivityEvent(
        id: const Uuid().v4(),
        activityId: activityId,
        timestamp: now,
        durationDelta: deltaSeconds,
        previousStatus: ActivityStatus.running,
        nextStatus: ActivityStatus.running, // Status stays the same
      ),
    );
  }
}
