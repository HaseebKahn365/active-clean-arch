import 'package:uuid/uuid.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';

class CreateActivityUseCase {
  final ActivityRepository repository;

  CreateActivityUseCase(this.repository);

  Future<void> execute(String name, {String? parentId}) async {
    final activity = Activity(
      id: const Uuid().v4(),
      name: name,
      status: ActivityStatus.idle,
      totalSeconds: 0,
      parentId: parentId,
      childrenIds: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.saveActivity(activity);
  }
}
