import '../../repositories/activity_repository.dart';

class TogglePinUseCase {
  final ActivityRepository repository;

  TogglePinUseCase(this.repository);

  Future<void> execute(String id) async {
    final activity = await repository.getActivityById(id);
    if (activity != null) {
      final updatedActivity = activity.copyWith(isPinned: !activity.isPinned, updatedAt: DateTime.now());
      await repository.updateActivity(updatedActivity);
    }
  }
}
