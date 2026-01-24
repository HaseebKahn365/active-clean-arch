import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/activity.dart';
import '../../domain/use_cases/activity/get_activities_use_case.dart';
import '../../domain/use_cases/activity/delete_activity_use_case.dart';
import '../../domain/use_cases/activity/start_activity_use_case.dart';
import '../../domain/use_cases/activity/pause_activity_use_case.dart';
import '../../domain/use_cases/activity/complete_activity_use_case.dart';
import '../../domain/use_cases/activity/checkpoint_activity_use_case.dart';
import '../../domain/use_cases/activity/create_activity_use_case.dart';
import '../../domain/use_cases/activity/get_breadcrumbs_use_case.dart';
import '../../domain/use_cases/activity/update_activity_use_case.dart';

class ActivityController extends ChangeNotifier {
  final GetActivitiesUseCase getActivitiesUseCase;
  final DeleteActivityUseCase deleteActivityUseCase;
  final StartActivityUseCase startActivityUseCase;
  final PauseActivityUseCase pauseActivityUseCase;
  final CompleteActivityUseCase completeActivityUseCase;
  final CheckpointActivityUseCase checkpointActivityUseCase;
  final CreateActivityUseCase createActivityUseCase;
  final GetBreadcrumbsUseCase getBreadcrumbsUseCase;
  final UpdateActivityUseCase updateActivityUseCase;

  ActivityController({
    required this.getActivitiesUseCase,
    required this.deleteActivityUseCase,
    required this.startActivityUseCase,
    required this.pauseActivityUseCase,
    required this.completeActivityUseCase,
    required this.checkpointActivityUseCase,
    required this.createActivityUseCase,
    required this.getBreadcrumbsUseCase,
    required this.updateActivityUseCase,
  });

  Map<String, Activity> _activitiesMap = {};
  bool _isLoading = false;
  StreamSubscription? _tickSubscription;
  int _tickCount = 0;

  bool get isLoading => _isLoading;

  /// Returns sorted root activities
  List<Activity> get roots =>
      _activitiesMap.values.where((a) => a.parentId == null).toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Exposed for fast lookup in Selectors
  Map<String, Activity> get activitiesMap => _activitiesMap;

  Future<void> loadActivities() async {
    _isLoading = true;
    notifyListeners();

    try {
      final list = await getActivitiesUseCase.execute();
      _activitiesMap = {for (var a in list) a.id: a};
      _startTick();
    } catch (e) {
      debugPrint('Error loading activities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startTick() {
    _tickSubscription?.cancel();
    _tickCount = 0;
    _tickSubscription = Stream.periodic(const Duration(seconds: 1)).listen((_) async {
      _tickCount++;

      final runningActivities = _activitiesMap.values.where((a) => a.status == ActivityStatus.running).toList();

      if (runningActivities.isEmpty) return;

      // 1. Notify listeners for UI duration updates
      notifyListeners();

      // 2. Periodic Checkpoint (every 60 seconds) as per Step 13
      if (_tickCount >= 60) {
        _tickCount = 0;
        for (final activity in runningActivities) {
          await checkpointActivityUseCase.execute(activity.id);
        }
        // Refresh hidden state after checkpoint (to get new started_at and total_seconds)
        final list = await getActivitiesUseCase.execute();
        _activitiesMap = {for (var a in list) a.id: a};
      }
    });
  }

  /// Calculates real-time duration for an activity.
  /// Logic from Step 14: displayed_seconds = last_persisted_total + (Current Time - started_at)
  int getEffectiveSeconds(String activityId) {
    final activity = _activitiesMap[activityId];
    if (activity == null) return 0;

    if (activity.status == ActivityStatus.running && activity.startedAt != null) {
      final delta = DateTime.now().difference(activity.startedAt!).inSeconds;
      return activity.totalSeconds + delta;
    }

    return activity.totalSeconds;
  }

  // Activity Actions
  Future<void> startActivity(String id) async {
    await startActivityUseCase.execute(id);
    await loadActivities();
  }

  Future<void> pauseActivity(String id) async {
    await pauseActivityUseCase.execute(id);
    await loadActivities();
  }

  Future<void> completeActivity(String id) async {
    await completeActivityUseCase.execute(id);
    await loadActivities();
  }

  Future<void> createActivity(String name, {String? parentId, String? description}) async {
    await createActivityUseCase.execute(name, parentId: parentId, description: description ?? '');
    await loadActivities();
  }

  Future<void> deleteActivity(String id) async {
    await deleteActivityUseCase.execute(id);
    await loadActivities();
  }

  Future<void> updateActivity(String id, {String? name, String? description}) async {
    await updateActivityUseCase.execute(id, name: name, description: description);
    await loadActivities();
  }

  @override
  void dispose() {
    _tickSubscription?.cancel();
    super.dispose();
  }

  /// Returns children of a specific activity.
  List<Activity> getChildrenOf(String parentId) {
    return _activitiesMap.values.where((a) => a.parentId == parentId).toList();
  }

  Future<List<Activity>> getBreadcrumbs(String activityId) {
    return getBreadcrumbsUseCase.execute(activityId);
  }
}
