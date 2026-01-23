import 'package:active/domain/repositories/activity_repository.dart';

class DeleteActivityUseCase {
  final ActivityRepository repository;

  DeleteActivityUseCase(this.repository);

  Future<void> execute(String activityId) async {
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
        await repository.updateActivity(child.copyWith(parentId: parentId));
      }
    }

    // 3. Delete the activity
    await repository.deleteActivity(activityId);
  }
}
