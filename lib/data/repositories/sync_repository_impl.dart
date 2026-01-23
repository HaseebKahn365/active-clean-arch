import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/repositories/sync_repository.dart';
import '../models/activity_event_model.dart';

class SyncRepositoryImpl implements SyncRepository {
  final FirebaseFirestore firestore;

  SyncRepositoryImpl(this.firestore);

  @override
  Future<void> uploadEvent(String userId, ActivityEvent event) async {
    final model = ActivityEventModel(
      id: event.id,
      activityId: event.activityId,
      timestamp: event.timestamp,
      durationDelta: event.durationDelta,
      previousStatus: event.previousStatus,
      nextStatus: event.nextStatus,
      isSynced: true, // It's being synced now
    );

    await firestore.collection('users').doc(userId).collection('activity_events').doc(event.id).set(model.toMap());
  }
}
