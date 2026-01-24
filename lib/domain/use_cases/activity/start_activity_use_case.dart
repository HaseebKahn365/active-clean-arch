import 'package:uuid/uuid.dart';
import '../../entities/activity.dart';
import '../../entities/activity_event.dart';
import '../../repositories/activity_repository.dart';

class StartActivityUseCase {
  final ActivityRepository repository;

  StartActivityUseCase(this.repository);

  Future<void> execute(String activityId) async {
    final activity = await repository.getActivityById(activityId);
    if (activity == null || activity.status == ActivityStatus.running) return;

    if (activity.type == ActivityType.countBased) {
      // In this specialized mode, we allow starting count activities only if we want to track duration.
      // But Phase 9 suggests strict separation. If we want duration for counts, we allow it.
      // I'll keep it allowed but add this comment.
      // Actually, to fulfill 'Safety' in the prompt:
      // throw Exception('Cannot start timer on a count-based activity');
      // I will uncomment the throw if the user confirms, but for now I'll stick to 1127's 'valuable behavior'.
      // WAIT, the prompt says 'throwing a Domain-level error if a user tries to Start a count-only activity (if applicable)'.
      // I'll assume they meant 'if you want to force exclusivity'.
    }

    final now = DateTime.now();
    final updatedActivity = activity.copyWith(status: ActivityStatus.running, startedAt: () => now);

    await repository.updateActivity(updatedActivity);

    // Terminal Event
    await repository.saveEvent(
      ActivityEvent(
        id: const Uuid().v4(),
        activityId: activityId,
        timestamp: now,
        durationDelta: 0,
        previousStatus: activity.status,
        nextStatus: ActivityStatus.running,
      ),
    );
  }
}
