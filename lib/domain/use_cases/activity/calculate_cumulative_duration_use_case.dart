import '../../entities/activity.dart';

class CalculateCumulativeDurationUseCase {
  /// Calculates the cumulative duration of an activity and all its descendants.
  ///
  /// [activitiesMap] is the authoritative source of truth.
  /// [activityId] is the root of the calculation.
  /// [getEffectiveSeconds] is a callback to get the real-time duration (persisted + ticking) of a single activity.
  int execute(String activityId, Map<String, Activity> activitiesMap, int Function(String id) getEffectiveSeconds) {
    int total = getEffectiveSeconds(activityId);

    final activity = activitiesMap[activityId];
    if (activity == null) return 0;

    for (final childId in activity.childrenIds) {
      total += execute(childId, activitiesMap, getEffectiveSeconds);
    }

    return total;
  }
}
