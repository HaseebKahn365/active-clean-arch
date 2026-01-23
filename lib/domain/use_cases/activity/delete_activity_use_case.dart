import 'package:active/domain/repositories/activity_repository.dart';
import 'pause_activity_use_case.dart';

class DeleteActivityUseCase {
  final ActivityRepository repository;
  final PauseActivityUseCase pauseActivityUseCase;

  DeleteActivityUseCase(this.repository, this.pauseActivityUseCase);

  Future<void> execute(String activityId) async {
    // 0. Finalize time if running
    await pauseActivityUseCase.execute(activityId);

    final activityToDelete = await repository.getActivityById(activityId);
    if (activityToDelete == null) return;

    final String? parentId = activityToDelete.parentId;
    final List<String> childrenIds = activityToDelete.childrenIds;

    // 1. Update Parent if it exists
    if (parentId != null) {
      final parent = await repository.getActivityById(parentId);
      if (parent != null) {
        final updatedChildrenIds = List<String>.from(parent.childrenIds);
        updatedChildrenIds.remove(activityId);
        updatedChildrenIds.addAll(childrenIds);

        await repository.updateActivity(parent.copyWith(childrenIds: updatedChildrenIds));
      }
    }

    // 2. Update Children to point to the new parent (or null)
    for (final childId in childrenIds) {
      final child = await repository.getActivityById(childId);
      if (child != null) {
        await repository.updateActivity(child.copyWith(parentId: () => parentId));
      }
    }

    // 3. Delete the activity
    await repository.deleteActivity(activityId);
  }
}
