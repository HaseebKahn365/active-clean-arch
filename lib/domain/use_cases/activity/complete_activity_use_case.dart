import 'package:uuid/uuid.dart';
import '../../entities/activity.dart';
import '../../entities/activity_event.dart';
import '../../repositories/activity_repository.dart';
import 'pause_activity_use_case.dart';

class CompleteActivityUseCase {
  final ActivityRepository repository;
  final PauseActivityUseCase pauseActivityUseCase;

  CompleteActivityUseCase(this.repository, this.pauseActivityUseCase);

  Future<void> execute(String activityId) async {
    final activity = await repository.getActivityById(activityId);
    if (activity == null || activity.status == ActivityStatus.completed) return;

    // If running, pause first to calculate final total_seconds and log transition to paused
    if (activity.status == ActivityStatus.running) {
      await pauseActivityUseCase.execute(activityId);
    }

    // Reload to get updated total_seconds and current status
    final currentActivity = await repository.getActivityById(activityId);
    if (currentActivity == null) return;

    final now = DateTime.now();
    final updatedActivity = currentActivity.copyWith(status: ActivityStatus.completed, startedAt: () => null);

    await repository.updateActivity(updatedActivity);

    // Terminal Event for completion
    await repository.saveEvent(
      ActivityEvent(
        id: const Uuid().v4(),
        activityId: activityId,
        timestamp: now,
        durationDelta: 0, // Delta was already handled by Pause if it was running
        previousStatus: currentActivity.status,
        nextStatus: ActivityStatus.completed,
      ),
    );
  }
}
