import 'package:uuid/uuid.dart';
import '../../entities/activity.dart';
import '../../entities/activity_event.dart';
import '../../repositories/activity_repository.dart';

class UpdateActivityDurationUseCase {
  final ActivityRepository repository;

  UpdateActivityDurationUseCase(this.repository);

  Future<void> execute(String id, int newDurationInSeconds) async {
    final activity = await repository.getActivityById(id);
    if (activity == null) return;

    // Constraint: Editing is only permitted when paused or completed
    if (activity.status == ActivityStatus.running) {
      throw Exception('Editing is only permitted when the activity is Paused or Completed.');
    }

    if (newDurationInSeconds < 0) {
      throw Exception('Duration cannot be negative.');
    }

    final oldDuration = activity.totalSeconds;
    final updatedActivity = activity.copyWith(totalSeconds: newDurationInSeconds, updatedAt: DateTime.now());

    await repository.updateActivity(updatedActivity);

    // Generate Correction Event
    final event = ActivityEvent(
      id: const Uuid().v4(),
      activityId: id,
      timestamp: DateTime.now(),
      durationDelta: newDurationInSeconds - oldDuration,
      previousStatus: activity.status,
      nextStatus: activity.status,
      oldDuration: oldDuration,
      newDuration: newDurationInSeconds,
    );

    await repository.saveEvent(event);
  }
}
