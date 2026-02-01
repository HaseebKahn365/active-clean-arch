import 'dart:developer' as dev;
import '../../../domain/entities/activity_event.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../infrastructure/database/sqlite_service.dart';
import '../models/activity_event_model.dart';
import 'package:sqflite/sqflite.dart';

class EventCompressionMigration {
  final ActivityRepository repository;
  final SqliteService sqliteService;

  EventCompressionMigration(this.repository, this.sqliteService);

  Future<void> run() async {
    dev.log('Starting Event Compression Migration', name: 'Migration');

    final db = await sqliteService.database;
    final allEvents = await repository.getAllEvents();

    dev.log('Analysis Phase:', name: 'Migration');
    dev.log('Total event count: ${allEvents.length}', name: 'Migration');

    if (allEvents.isEmpty) {
      dev.log('No events to migrate.', name: 'Migration');
      return;
    }

    // Group by activity
    final groupedEvents = <String, List<ActivityEvent>>{};
    for (var e in allEvents) {
      groupedEvents.putIfAbsent(e.activityId, () => []).add(e);
    }

    int redundantCount = 0;
    int totalDurationBefore = allEvents.fold(0, (sum, e) => sum + e.durationDelta);

    final toDelete = <String>[];
    final toUpdate = <ActivityEvent>[];

    final List<Map<String, dynamic>> logData = [];
    int identifiedGroups = 0;

    for (var activityId in groupedEvents.keys) {
      final events = groupedEvents[activityId]!;
      events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      ActivityEvent? currentSegmentStart;
      int collapsedInCurrent = 0;
      int originalDurationSum = 0;

      for (int i = 0; i < events.length; i++) {
        final e = events[i];

        if (currentSegmentStart == null) {
          currentSegmentStart = e;
          collapsedInCurrent = 1;
          originalDurationSum = e.durationDelta;
        } else {
          // Identify redundant record: part of the same status segment
          // We collapse if the transition is continuous (prev == last.next)
          if (e.previousStatus == currentSegmentStart.nextStatus) {
            redundantCount++;
            collapsedInCurrent++;
            originalDurationSum += e.durationDelta;

            // Collapse into currentSegmentStart
            currentSegmentStart = ActivityEvent(
              id: currentSegmentStart.id,
              activityId: currentSegmentStart.activityId,
              timestamp: currentSegmentStart.timestamp,
              durationDelta: currentSegmentStart.durationDelta + e.durationDelta,
              previousStatus: currentSegmentStart.previousStatus,
              nextStatus: e.nextStatus,
              oldDuration: currentSegmentStart.oldDuration,
              newDuration: e.newDuration,
              oldParentId: currentSegmentStart.oldParentId,
              newParentId: e.newParentId,
            );

            toDelete.add(e.id);
          } else {
            // New segment starts, save old one
            toUpdate.add(currentSegmentStart);
            if (collapsedInCurrent > 1) {
              identifiedGroups++;
              logData.add({
                'activityId': activityId,
                'collapsed': collapsedInCurrent,
                'original': originalDurationSum,
                'result': currentSegmentStart.durationDelta,
              });
            }

            // Next segment
            currentSegmentStart = e;
            collapsedInCurrent = 1;
            originalDurationSum = e.durationDelta;
          }
        }
      }
      if (currentSegmentStart != null) {
        toUpdate.add(currentSegmentStart);
        if (collapsedInCurrent > 1) {
          identifiedGroups++;
          logData.add({
            'activityId': activityId,
            'collapsed': collapsedInCurrent,
            'original': originalDurationSum,
            'result': currentSegmentStart.durationDelta,
          });
        }
      }
    }

    dev.log('Number of redundant records detected: $redundantCount', name: 'Migration');
    dev.log('Groups identified for collapsing: $identifiedGroups', name: 'Migration');
    dev.log('Transformation Phase:', name: 'Migration');

    for (var log in logData) {
      dev.log(
        'Collapsed Group: Activity ${log['activityId']} | Records: ${log['collapsed']} | Original Sum: ${log['original']}s | Resulting: ${log['result']}s',
        name: 'Migration',
      );
    }

    if (toUpdate.isEmpty && toDelete.isEmpty) {
      dev.log('No transformations needed.', name: 'Migration');
    } else {
      await db.transaction((txn) async {
        for (var e in toUpdate) {
          final model = ActivityEventModel(
            id: e.id,
            activityId: e.activityId,
            timestamp: e.timestamp,
            durationDelta: e.durationDelta,
            previousStatus: e.previousStatus,
            nextStatus: e.nextStatus,
            oldDuration: e.oldDuration,
            newDuration: e.newDuration,
            oldParentId: e.oldParentId,
            newParentId: e.newParentId,
          );
          await txn.insert('activity_events', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        if (toDelete.isNotEmpty) {
          for (var i = 0; i < toDelete.length; i += 500) {
            final chunk = toDelete.sublist(i, i + 500 > toDelete.length ? toDelete.length : i + 500);
            await txn.delete(
              'activity_events',
              where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
              whereArgs: chunk,
            );
          }
        }
      });
    }

    final eventsAfter = await repository.getAllEvents();
    int totalDurationAfter = eventsAfter.fold(0, (sum, e) => sum + e.durationDelta);

    dev.log('Verification Phase:', name: 'Migration');
    dev.log('Event count before: ${allEvents.length} vs after: ${eventsAfter.length}', name: 'Migration');
    dev.log('Duration totals before: $totalDurationBefore vs after: $totalDurationAfter', name: 'Migration');

    if (totalDurationBefore != totalDurationAfter) {
      dev.log('ERROR: Duration mismatch! Before: $totalDurationBefore, After: $totalDurationAfter', name: 'Migration');
    } else {
      dev.log('Migration successful. Durations match.', name: 'Migration');
    }
  }
}
