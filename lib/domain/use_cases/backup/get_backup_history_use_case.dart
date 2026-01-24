import '../../entities/backup.dart';
import '../../repositories/backup_repository.dart';

class GetBackupHistoryUseCase {
  final BackupRepository repository;

  GetBackupHistoryUseCase(this.repository);

  Future<List<Backup>> execute(String userId) async {
    return await repository.getBackupHistory(userId);
  }
}
