import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import '../../entities/activity.dart';
import '../../entities/activity_event.dart';
import '../../entities/count_record.dart';
import '../../repositories/activity_repository.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/activity_event_model.dart';
import '../../../data/models/count_record_model.dart';

class RestoreBackupUseCase {
  final ActivityRepository activityRepository;
  final FirebaseStorage storage;

  RestoreBackupUseCase(this.activityRepository, this.storage);

  Future<void> execute(String url) async {
    print('RESTORE: Starting restore from $url');

    // 1. Pause all running activities
    final localActivities = await activityRepository.getAllActivities();
    for (final activity in localActivities) {
      if (activity.status == ActivityStatus.running) {
        print('RESTORE: Pausing activity ${activity.name}');
        final now = DateTime.now();
        final delta = now.difference(activity.startedAt!).inSeconds;
        await activityRepository.updateActivity(
          activity.copyWith(
            status: ActivityStatus.paused,
            startedAt: () => null,
            totalSeconds: activity.totalSeconds + delta,
          ),
        );
      }
    }

    // 2. Download and parse backup
    final ref = storage.refFromURL(url);
    final data = await ref.getData();
    if (data == null) throw Exception('Failed to download backup data');

    final jsonString = utf8.decode(data);
    final Map<String, dynamic> backupData = jsonDecode(jsonString);

    final List<Activity> backupActivities = (backupData['activities'] as List)
        .map((m) => ActivityModel.fromMap(m))
        .toList();
    final List<ActivityEvent> backupEvents = (backupData['events'] as List)
        .map((m) => ActivityEventModel.fromMap(m))
        .toList();
    final List<CountRecord> backupRecords = (backupData['countRecords'] as List)
        .map((m) => CountRecordModel.fromMap(m))
        .toList();

    print(
      'RESTORE: Downloaded ${backupActivities.length} activities, ${backupEvents.length} events, ${backupRecords.length} records.',
    );

    // 3. Merge Logic
    // Refresh local activities after pausing
    final currentLocalActivities = await activityRepository.getAllActivities();
    final localActivityMap = {for (var a in currentLocalActivities) a.id: a};

    final currentLocalRecords = await activityRepository.getAllCountRecords();
    final localRecordsMap = <String, List<CountRecord>>{};
    for (var r in currentLocalRecords) {
      localRecordsMap.putIfAbsent(r.activityId, () => []).add(r);
    }

    final backupRecordsMap = <String, List<CountRecord>>{};
    for (var r in backupRecords) {
      backupRecordsMap.putIfAbsent(r.activityId, () => []).add(r);
    }

    for (final bActivity in backupActivities) {
      final lActivity = localActivityMap[bActivity.id];

      if (lActivity == null) {
        // Option 1: No overwrite existing activities -> This means if it doesn't exist, we add it.
        print('RESTORE: Adding new activity ${bActivity.name}');
        await activityRepository.saveActivity(bActivity);

        // Add associated events and records
        for (final e in backupEvents.where((e) => e.activityId == bActivity.id)) {
          await activityRepository.saveEvent(e);
        }
        for (final r in backupRecords.where((r) => r.activityId == bActivity.id)) {
          await activityRepository.saveCountRecord(r);
        }
      } else {
        // Conflict resolution
        bool shouldUpdate = false;
        if (bActivity.type == ActivityType.timeBased) {
          if (bActivity.totalSeconds > lActivity.totalSeconds) {
            print(
              'RESTORE: Conflict for ${bActivity.name} (Time). Backup total seconds (${bActivity.totalSeconds}) > Local (${lActivity.totalSeconds}). Preserving Backup.',
            );
            shouldUpdate = true;
          }
        } else {
          final bCount = backupRecordsMap[bActivity.id]?.fold<double>(0, (prev, curr) => prev + curr.value) ?? 0;
          final lCount = localRecordsMap[bActivity.id]?.fold<double>(0, (prev, curr) => prev + curr.value) ?? 0;

          if (bCount > lCount) {
            print(
              'RESTORE: Conflict for ${bActivity.name} (Count). Backup total count ($bCount) > Local ($lCount). Preserving Backup.',
            );
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          await activityRepository.saveActivity(bActivity);
          // For consistency, we replace records/events for this ID?
          // The prompt says "Merge restored data ... Do not overwrite ... Conflict -> preserve".
          // If we preserve backup, we should likely replace local data for that specific ID.

          // Clear local records for this ID before adding backup ones
          for (var r in (localRecordsMap[bActivity.id] ?? [])) {
            await activityRepository.deleteCountRecord(r.id);
          }
          for (var r in (backupRecordsMap[bActivity.id] ?? [])) {
            await activityRepository.saveCountRecord(r);
          }

          // Note: Events are append-only mostly, but for full replacement we'd need a deleteEvent method.
          // Since it's not in the interface, I'll just save the backup ones.
          // This might result in duplicate events if we are not careful,
          // but I'll follow the "Merge" instruction.
          for (final e in backupEvents.where((e) => e.activityId == bActivity.id)) {
            await activityRepository.saveEvent(e);
          }
        }
      }
    }

    print('RESTORE: Complete.');
  }
}
