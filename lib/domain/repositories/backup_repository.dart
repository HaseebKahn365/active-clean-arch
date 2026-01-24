import '../entities/backup.dart';

abstract class BackupRepository {
  Future<String> uploadBackup(String userId, List<int> data, String fileName);
  Future<void> saveBackupMetadata(String userId, Backup backup);
  Future<List<Backup>> getBackupHistory(String userId);
}
