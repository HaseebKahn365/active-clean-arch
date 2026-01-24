import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../entities/backup.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/backup_repository.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/activity_event_model.dart';
import '../../../data/models/count_record_model.dart';

class CreateBackupUseCase {
  final ActivityRepository activityRepository;
  final BackupRepository backupRepository;

  CreateBackupUseCase(this.activityRepository, this.backupRepository);

  Future<void> execute(String userId) async {
    // 1. Fetch all data
    final activities = await activityRepository.getAllActivities();
    final events = await activityRepository.getAllEvents();
    final countRecords = await activityRepository.getAllCountRecords();

    // 2. Serialize to JSON

    final Map<String, dynamic> backupData = {
      'activities': activities.map((a) => ActivityModel.fromEntity(a).toMap()).toList(),
      'events': events
          .map(
            (e) =>
                (e is ActivityEventModel
                        ? e
                        : ActivityEventModel(
                            id: e.id,
                            activityId: e.activityId,
                            timestamp: e.timestamp,
                            durationDelta: e.durationDelta,
                            previousStatus: e.previousStatus,
                            nextStatus: e.nextStatus,
                            oldParentId: e.oldParentId,
                            newParentId: e.newParentId,
                            oldDuration: e.oldDuration,
                            newDuration: e.newDuration,
                            isSynced: e.isSynced,
                          ))
                    .toMap(),
          )
          .toList(),
      'countRecords': countRecords.map((c) => CountRecordModel.fromEntity(c).toMap()).toList(),
      'version': 1,
    };

    final jsonString = jsonEncode(backupData);
    final data = utf8.encode(jsonString);
    final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';

    // 3. Upload file
    final url = await backupRepository.uploadBackup(userId, data, fileName);

    // 4. Save metadata
    final backup = Backup(id: const Uuid().v4(), url: url, timestamp: DateTime.now(), fileName: fileName);
    await backupRepository.saveBackupMetadata(userId, backup);
  }
}
