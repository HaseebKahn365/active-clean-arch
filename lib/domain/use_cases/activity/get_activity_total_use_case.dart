import '../../repositories/activity_repository.dart';

class GetActivityTotalUseCase {
  final ActivityRepository repository;

  GetActivityTotalUseCase(this.repository);

  Future<double> execute(String activityId) async {
    final records = await repository.getCountRecordsForActivity(activityId);
    return records.fold<double>(0.0, (sum, item) => sum + item.value);
  }
}
