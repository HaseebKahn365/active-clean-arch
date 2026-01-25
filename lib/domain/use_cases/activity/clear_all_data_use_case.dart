import '../../repositories/activity_repository.dart';

class ClearAllDataUseCase {
  final ActivityRepository repository;

  ClearAllDataUseCase(this.repository);

  Future<void> execute() async {
    await repository.clearAllData();
  }
}
