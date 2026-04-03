import 'package:flutter/foundation.dart';
import 'activity_manager_provider.dart';
import '../../domain/entities/activity.dart';

class PauseProvider extends ChangeNotifier {
  final ActivityController activityController;
  List<String> _pausedActivityIds = [];

  PauseProvider({required this.activityController});

  List<String> get pausedActivityIds => _pausedActivityIds;

  bool get isPaused => _pausedActivityIds.isNotEmpty;

  Future<void> pauseAll() async {
    final activeActivities = activityController.activitiesMap.values
        .where((a) => a.status == ActivityStatus.running)
        .toList();

    if (activeActivities.isEmpty) return;

    _pausedActivityIds = activeActivities.map((a) => a.id).toList();
    
    for (final id in _pausedActivityIds) {
      await activityController.pauseActivity(id);
    }
    
    notifyListeners();
  }

  Future<void> resumeAll() async {
    if (_pausedActivityIds.isEmpty) return;

    for (final id in _pausedActivityIds) {
      await activityController.startActivity(id);
    }

    _pausedActivityIds = [];
    notifyListeners();
  }
}
