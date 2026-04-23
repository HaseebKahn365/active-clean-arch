import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'riverpod_bridge.dart';
import '../../domain/entities/activity.dart';

class PauseNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  bool get isPaused => state.isNotEmpty;

  Future<void> pauseAll() async {
    final activityController = ref.read(activityControllerProvider);
    final activeActivities = activityController.activitiesMap.values
        .where((a) => a.status == ActivityStatus.running)
        .toList();

    if (activeActivities.isEmpty) return;

    state = activeActivities.map((a) => a.id).toList();
    
    for (final id in state) {
      await activityController.pauseActivity(id);
    }
  }

  Future<void> resumeAll() async {
    if (state.isEmpty) return;

    final activityController = ref.read(activityControllerProvider);
    for (final id in state) {
      await activityController.startActivity(id);
    }

    state = [];
  }
}

final pauseStateProvider = NotifierProvider<PauseNotifier, List<String>>(PauseNotifier.new);
