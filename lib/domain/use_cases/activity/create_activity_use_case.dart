import 'package:uuid/uuid.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';

class CreateActivityUseCase {
  final ActivityRepository repository;

  CreateActivityUseCase(this.repository);

  Future<void> execute(
    String name, {
    String? parentId,
    String description = '',
    int goalSeconds = 0,
    ActivityType type = ActivityType.timeBased,
  }) async {
    final newActivityId = const Uuid().v4();

    // 1. If there's a parent, update it first
    if (parentId != null) {
      final parent = await repository.getActivityById(parentId);
      if (parent != null) {
        final updatedParent = parent.copyWith(
          childrenIds: [...parent.childrenIds, newActivityId],
          updatedAt: DateTime.now(),
        );
        await repository.saveActivity(updatedParent);
      }
    }

    // 2. Create and save the new activity
    final activity = Activity(
      id: newActivityId,
      name: name,
      description: description,
      status: ActivityStatus.idle,
      totalSeconds: 0,
      goalSeconds: goalSeconds,
      type: type,
      parentId: parentId,
      childrenIds: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.saveActivity(activity);
  }
}
