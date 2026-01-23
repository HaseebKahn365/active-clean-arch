import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/sync_repository.dart';

class SyncController extends ChangeNotifier {
  final ActivityRepository activityRepository;
  final SyncRepository syncRepository;
  final Connectivity connectivity;

  SyncController({required this.activityRepository, required this.syncRepository, required this.connectivity});

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  StreamSubscription? _connectivitySubscription;

  void init(String? userId) {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // connectivity_plus 6.x returns a List<ConnectivityResult>
      if (results.any((r) => r != ConnectivityResult.none)) {
        if (userId != null) {
          syncEvents(userId);
        }
      }
    });

    // Initial sync attempt
    if (userId != null) {
      syncEvents(userId);
    }
  }

  Future<void> syncEvents(String userId) async {
    if (_isSyncing) return;

    final results = await connectivity.checkConnectivity();
    if (results.any((r) => r == ConnectivityResult.none)) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final unsyncedEvents = await activityRepository.getUnsyncedEvents();

      for (final event in unsyncedEvents) {
        try {
          await syncRepository.uploadEvent(userId, event);
          await activityRepository.markEventAsSynced(event.id);
        } catch (e) {
          debugPrint('Failed to sync event ${event.id}: $e');
          // Continue with next event
        }
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
