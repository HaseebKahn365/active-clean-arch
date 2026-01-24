import 'package:uuid/uuid.dart';
import '../../entities/activity_event.dart';
import '../../repositories/activity_repository.dart';

class MoveActivityUseCase {
  final ActivityRepository repository;

  MoveActivityUseCase(this.repository);

  Future<void> execute(String activityId, String? newParentId) async {
    if (activityId == newParentId) return; // Cannot move into itself

    final activity = await repository.getActivityById(activityId);
    if (activity == null) return;

    final oldParentId = activity.parentId;
    if (oldParentId == newParentId) return; // No change

    // Cycle Prevention: Cannot move into its own descendants
    if (newParentId != null) {
      if (await _isDescendant(activityId, newParentId)) {
        throw Exception("Cycle detected: Cannot move an activity into its own descendant.");
      }
    }

    // 1. Remove from old parent if exists
    if (oldParentId != null) {
      final oldParent = await repository.getActivityById(oldParentId);
      if (oldParent != null) {
        final updatedChildren = oldParent.childrenIds.where((id) => id != activityId).toList();
        await repository.updateActivity(oldParent.copyWith(childrenIds: updatedChildren, updatedAt: DateTime.now()));
      }
    }

    // 2. Add to new parent if exists
    if (newParentId != null) {
      final newParent = await repository.getActivityById(newParentId);
      if (newParent != null) {
        final updatedChildren = [...newParent.childrenIds, activityId];
        await repository.updateActivity(newParent.copyWith(childrenIds: updatedChildren, updatedAt: DateTime.now()));
      }
    }

    // 3. Update the activity itself
    await repository.updateActivity(activity.copyWith(parentId: () => newParentId, updatedAt: DateTime.now()));

    // 4. Generate relocation event
    final event = ActivityEvent(
      id: const Uuid().v4(),
      activityId: activityId,
      timestamp: DateTime.now(),
      durationDelta: 0,
      previousStatus: activity.status,
      nextStatus: activity.status,
      oldParentId: oldParentId,
      newParentId: newParentId,
    );
    await repository.saveEvent(event);
  }

  Future<bool> _isDescendant(String ancestorId, String targetId) async {
    final ancestor = await repository.getActivityById(ancestorId);
    if (ancestor == null) return false;

    if (ancestor.childrenIds.contains(targetId)) return true;

    for (final childId in ancestor.childrenIds) {
      if (await _isDescendant(childId, targetId)) return true;
    }
    return false;
  }
}
