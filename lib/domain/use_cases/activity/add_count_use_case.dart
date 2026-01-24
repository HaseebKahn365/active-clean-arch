import 'package:uuid/uuid.dart';
import '../../entities/count_record.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';

class AddCountUseCase {
  final ActivityRepository repository;

  AddCountUseCase(this.repository);

  Future<void> execute(String activityId, double value) async {
    final activity = await repository.getActivityById(activityId);
    if (activity == null) throw Exception('Activity not found');
    if (activity.type != ActivityType.countBased) {
      throw Exception('Activity is not count-based');
    }

    final record = CountRecord(id: const Uuid().v4(), activityId: activityId, timestamp: DateTime.now(), value: value);

    await repository.saveCountRecord(record);

    // Note: SyncController notification will be handled by the Controller/Provider
  }
}
