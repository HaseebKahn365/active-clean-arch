import 'package:uuid/uuid.dart';
import '../../entities/activity.dart';
import '../../entities/activity_event.dart';
import '../../repositories/activity_repository.dart';

class PauseActivityUseCase {
  final ActivityRepository repository;

  PauseActivityUseCase(this.repository);

  Future<void> execute(String activityId) async {
    final activity = await repository.getActivityById(activityId);
    if (activity == null || activity.status != ActivityStatus.running || activity.startedAt == null) {
      return;
    }

    final now = DateTime.now();
    final deltaSeconds = now.difference(activity.startedAt!).inSeconds;

    final updatedActivity = activity.copyWith(
      status: ActivityStatus.paused,
      startedAt: () => null,
      totalSeconds: activity.totalSeconds + deltaSeconds,
    );

    await repository.updateActivity(updatedActivity);

    // Terminal Event
    await repository.saveEvent(
      ActivityEvent(
        id: const Uuid().v4(),
        activityId: activityId,
        timestamp: now,
        durationDelta: deltaSeconds,
        previousStatus: activity.status,
        nextStatus: ActivityStatus.paused,
      ),
    );
  }
}
