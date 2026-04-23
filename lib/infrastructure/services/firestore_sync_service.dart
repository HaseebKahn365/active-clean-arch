import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/count_record.dart';
import '../../data/models/activity_model.dart';
import '../../data/models/activity_event_model.dart';
import '../../data/models/count_record_model.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../presentation/providers/activity_manager_provider.dart';
import '../../core/di/injection_container.dart';

enum SyncStatus { idle, syncing, success, error }

class FirestoreSyncService {
  final ValueNotifier<SyncStatus> syncStatus = ValueNotifier(SyncStatus.idle);
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final ActivityRepository localRepository;

  StreamSubscription? _activitiesSub;
  StreamSubscription? _eventsSub;
  StreamSubscription? _countsSub;

  FirestoreSyncService({
    required this.firestore,
    required this.auth,
    required this.localRepository,
  }) {
    auth.authStateChanges().listen((user) {
      if (user != null) {
        startListening();
      } else {
        stopListening();
      }
    });
  }

  String? get currentUserId => auth.currentUser?.uid;

  void startListening() {
    final userId = currentUserId;
    if (userId == null) return;

    _activitiesSub?.cancel();
    _activitiesSub = firestore
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(_onActivitiesUpdate);

    _eventsSub?.cancel();
    _eventsSub = firestore
        .collection('activity_events')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(_onEventsUpdate);

    _countsSub?.cancel();
    _countsSub = firestore
        .collection('count_records')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(_onCountsUpdate);
  }

  void stopListening() {
    _activitiesSub?.cancel();
    _eventsSub?.cancel();
    _countsSub?.cancel();
  }

  // --- Sync Status Helper ---
  void _setStatus(SyncStatus status) {
    syncStatus.value = status;
    if (status == SyncStatus.success || status == SyncStatus.error) {
      Future.delayed(const Duration(seconds: 2), () {
        if (syncStatus.value == status) {
          syncStatus.value = SyncStatus.idle;
        }
      });
    }
  }

  // --- Push Methods (Local -> Remote) ---
  
  Future<void> pushActivity(Activity activity, {bool isDelete = false}) async {
    final userId = currentUserId;
    if (userId == null) return;

    _setStatus(SyncStatus.syncing);
    dev.log("SYNC PUSH: Activity Updated | id=${activity.id}");

    try {
      final docRef = firestore.collection('activities').doc(activity.id);
      if (isDelete) {
        await docRef.delete();
        _setStatus(SyncStatus.success);
        return;
      }

      final data = ActivityModel.fromEntity(activity).toMap();
      data['userId'] = userId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      _setStatus(SyncStatus.success);
    } catch (e) {
      dev.log("SYNC ERROR: Failed to push activity: $e");
      _setStatus(SyncStatus.error);
    }
  }

  Future<void> pushEvent(ActivityEvent event) async {
    final userId = currentUserId;
    if (userId == null) return;

    _setStatus(SyncStatus.syncing);
    dev.log("SYNC PUSH: Event Updated | id=${event.id}");

    try {
      final data = ActivityEventModel(
        id: event.id,
        activityId: event.activityId,
        timestamp: event.timestamp,
        durationDelta: event.durationDelta,
        previousStatus: event.previousStatus,
        nextStatus: event.nextStatus,
        oldParentId: event.oldParentId,
        newParentId: event.newParentId,
        oldDuration: event.oldDuration,
        newDuration: event.newDuration,
      ).toMap();
      data['userId'] = userId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await firestore.collection('activity_events').doc(event.id).set(data, SetOptions(merge: true));
      _setStatus(SyncStatus.success);
    } catch (e) {
      dev.log("SYNC ERROR: Failed to push event: $e");
      _setStatus(SyncStatus.error);
    }
  }

  Future<void> pushCountRecord(CountRecord record, {bool isDelete = false}) async {
    final userId = currentUserId;
    if (userId == null) return;

    _setStatus(SyncStatus.syncing);
    dev.log("SYNC PUSH: Count Record Updated | id=${record.id}");

    try {
      final docRef = firestore.collection('count_records').doc(record.id);
      if (isDelete) {
        await docRef.delete();
        _setStatus(SyncStatus.success);
        return;
      }

      final data = CountRecordModel.fromEntity(record).toMap();
      data['userId'] = userId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      _setStatus(SyncStatus.success);
    } catch (e) {
      dev.log("SYNC ERROR: Failed to push count record: $e");
      _setStatus(SyncStatus.error);
    }
  }

  // --- Receive Methods (Remote -> Local) ---

  Future<void> _onActivitiesUpdate(QuerySnapshot snapshot) async {
    bool hasChanges = false;
    for (var change in snapshot.docChanges) {
      // Ignore local writes that trigger a snapshot before reaching the server
      if (change.doc.metadata.hasPendingWrites) continue;

      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      _setStatus(SyncStatus.syncing);
      dev.log("SYNC PULL: Remote Update Received | collection=activities, id=${change.doc.id}");

      try {
        if (change.type == DocumentChangeType.removed) {
          dev.log("SYNC RESOLVE: Using remote (deleted) | id=${change.doc.id}");
          await localRepository.deleteActivity(change.doc.id, isRemoteUpdate: true);
          hasChanges = true;
          continue;
        }

        final remoteActivity = ActivityModel.fromMap(data);
        final localObj = await localRepository.getActivityById(remoteActivity.id);
        
        dev.log("SYNC RESOLVE: Using remote | id=${remoteActivity.id}");
        if (localObj == null) {
          await localRepository.saveActivity(remoteActivity, isRemoteUpdate: true);
        } else {
          await localRepository.updateActivity(remoteActivity, isRemoteUpdate: true);
        }
        hasChanges = true;
      } catch (e) {
        dev.log("SYNC ERROR: Failed to apply remote activity update: $e");
        _setStatus(SyncStatus.error);
      }
    }
    
    if (hasChanges) {
      sl<ActivityController>().loadActivities();
      _setStatus(SyncStatus.success);
    }
  }

  Future<void> _onEventsUpdate(QuerySnapshot snapshot) async {
    for (var change in snapshot.docChanges) {
      if (change.doc.metadata.hasPendingWrites) continue;

      if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        dev.log("SYNC PULL: Remote Update Received | collection=activity_events, id=${change.doc.id}");
        _setStatus(SyncStatus.syncing);

        try {
          final event = ActivityEventModel.fromMap(data);
          dev.log("SYNC RESOLVE: Using remote | id=${event.id}");
          await localRepository.saveEvent(event, isRemoteUpdate: true);
          _setStatus(SyncStatus.success);
        } catch (e) {
          dev.log("SYNC ERROR: Failed to apply remote event update: $e");
          _setStatus(SyncStatus.error);
        }
      }
    }
  }

  Future<void> _onCountsUpdate(QuerySnapshot snapshot) async {
    bool hasChanges = false;
    for (var change in snapshot.docChanges) {
      if (change.doc.metadata.hasPendingWrites) continue;

      _setStatus(SyncStatus.syncing);
      dev.log("SYNC PULL: Remote Update Received | collection=count_records, id=${change.doc.id}");

      try {
        if (change.type == DocumentChangeType.removed) {
          dev.log("SYNC RESOLVE: Using remote (deleted) | id=${change.doc.id}");
          await localRepository.deleteCountRecord(change.doc.id, isRemoteUpdate: true);
          hasChanges = true;
          continue;
        }

        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final record = CountRecordModel.fromMap(data);
        
        dev.log("SYNC RESOLVE: Using remote | id=${record.id}");
        await localRepository.saveCountRecord(record, isRemoteUpdate: true);
        hasChanges = true;
      } catch (e) {
        dev.log("SYNC ERROR: Failed to apply remote count record update: $e");
        _setStatus(SyncStatus.error);
      }
    }
    if (hasChanges) {
      sl<ActivityController>().loadActivities();
      _setStatus(SyncStatus.success);
    }
  }
}
