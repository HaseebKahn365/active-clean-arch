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
