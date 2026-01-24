import '../../repositories/activity_repository.dart';

class UpdateActivityUseCase {
  final ActivityRepository repository;

  UpdateActivityUseCase(this.repository);

  Future<void> execute(String id, {String? name, String? description}) async {
    final activity = await repository.getActivityById(id);
    if (activity != null) {
      final updatedActivity = activity.copyWith(name: name, description: description, updatedAt: DateTime.now());
      await repository.updateActivity(updatedActivity);
    }
  }
}
