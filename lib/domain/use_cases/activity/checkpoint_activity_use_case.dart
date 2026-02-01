import 'dart:developer' as dev;
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

    // Forward Behavior: Update an existing event instead of creating new ones
    // We fetch all events for this activity and find the latest one to update.
    final allEvents = await repository.getAllEvents();
    final activityEvents = allEvents.where((e) => e.activityId == activityId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final lastEvent = activityEvents.isNotEmpty ? activityEvents.first : null;

    if (lastEvent != null && lastEvent.nextStatus == ActivityStatus.running) {
      final updatedEvent = ActivityEvent(
        id: lastEvent.id, // Keep the same ID to update
        activityId: activityId,
        timestamp: lastEvent.timestamp, // Keep original start timestamp
        durationDelta: lastEvent.durationDelta + deltaSeconds,
        previousStatus: lastEvent.previousStatus,
        nextStatus: ActivityStatus.running,
        oldParentId: lastEvent.oldParentId,
        newParentId: lastEvent.newParentId,
        oldDuration: lastEvent.oldDuration,
        newDuration: lastEvent.newDuration,
      );

      await repository.saveEvent(updatedEvent);

      dev.log(
        'Periodic Update: Activity $activityId | Event ${lastEvent.id} | Increment +${deltaSeconds}s | New Total ${updatedEvent.durationDelta}s',
        name: 'PeriodicPersistence',
      );
    } else {
      // Fallback: Create a new event if none exists (should not happen with correct StartUseCase)
      await repository.saveEvent(
        ActivityEvent(
          id: const Uuid().v4(),
          activityId: activityId,
          timestamp: now,
          durationDelta: deltaSeconds,
          previousStatus: ActivityStatus.running,
          nextStatus: ActivityStatus.running,
        ),
      );
    }
  }
}
