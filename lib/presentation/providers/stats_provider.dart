import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/count_record.dart';
import '../../domain/repositories/activity_repository.dart';
import 'activity_manager_provider.dart';

enum TimeRange { day, week, month, year, forever }

class StatsController extends ChangeNotifier {
  final ActivityRepository repository;
  final ActivityController activityController;

  StatsController({required this.repository, required this.activityController}) {
    activityController.addListener(_onActivityUpdate);
    loadData();
  }

  DateTime? _lastReloadTime;

  void _onActivityUpdate() {
    // Always notify so the "live" calculation in metrics (like getFocusTimeByDay) can update the graph visuals
    notifyListeners();

    if (_isLoading) return;

    final now = DateTime.now();
    // Throttle silent reloads from DB to every 10 seconds
    if (_lastReloadTime == null || now.difference(_lastReloadTime!) > const Duration(seconds: 10)) {
      loadData(silent: true);
    }
  }

  TimeRange _selectedRange = TimeRange.week;
  TimeRange get selectedRange => _selectedRange;

  bool _hasData = false;
  bool get hasData => _hasData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Activity> _activities = [];
  List<ActivityEvent> _events = [];
  List<CountRecord> _countRecords = [];

  void setRange(TimeRange range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    _clearCache(); // Range changed, metrics will differ
    notifyListeners();
  }

  Future<void> loadData({bool silent = false}) async {
    final shouldShowLoading = !silent && !_hasData;

    if (shouldShowLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        repository.getAllActivities(),
        repository.getAllEvents(),
        repository.getAllCountRecords(),
      ]);

      _activities = results[0] as List<Activity>;
      _events = results[1] as List<ActivityEvent>;
      _countRecords = results[2] as List<CountRecord>;
      _hasData = true;
      _lastReloadTime = DateTime.now();
      _clearCache();
    } catch (e) {
      debugPrint('Error loading stats data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- CACHING LOGIC ---
  final Map<String, dynamic> _cache = {};

  void _clearCache() {
    _cache.clear();
  }

  // --- COMPREHENSIVE METRICS ---

  /// Returns total focus time (seconds) for selected range including live data
  int getTotalFocusTime() {
    final now = DateTime.now();
    final start = _getStartTime(now);

    int total = _events.where((e) => e.timestamp.isAfter(start)).fold(0, (sum, e) => sum + e.durationDelta);

    for (final activity in activityController.activitiesMap.values) {
      if (activity.status == ActivityStatus.running && activity.startedAt != null) {
        final activityStart = activity.startedAt!;
        if (activityStart.isAfter(start)) {
          total += now.difference(activityStart).inSeconds;
        } else if (now.isAfter(start)) {
          total += now.difference(start).inSeconds;
        }
      }
    }
    return total;
  }

  /// Returns daily focus time map, grouped by range-specific granularity
  Map<DateTime, int> getFocusTimeByDay() {
    final cacheKey = 'focus_time_by_day_extended_${_selectedRange.name}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final now = DateTime.now();
    final start = _getDataStartTime(now);
    final map = <DateTime, int>{};

    // Initialize with all time slots in range to avoid gaps
    final List<DateTime> slots = _generateTimeSlots(start, now);
    for (var slot in slots) {
      map[slot] = 0;
    }

    // Aggregate from events
    for (final event in _events) {
      if (event.timestamp.isAfter(start)) {
        final slot = _mapToSlot(event.timestamp);
        if (map.containsKey(slot)) {
          map[slot] = (map[slot] ?? 0) + event.durationDelta;
        }
      }
    }

    // Group live delta by slots
    for (final activity in activityController.activitiesMap.values) {
      if (activity.status == ActivityStatus.running && activity.startedAt != null) {
        final liveDelta = now.difference(activity.startedAt!).inSeconds;
        final slot = _mapToSlot(now);
        if (map.containsKey(slot)) {
          map[slot] = (map[slot] ?? 0) + liveDelta;
        }
      }
    }

    _cache[cacheKey] = map;
    return map;
  }

  /// Returns total count and time spent for a specific activity
  MapEntry<double, int> getActivityDualMetrics(String activityId) {
    final now = DateTime.now();
    final start = _getStartTime(now);

    final counts = _countRecords
        .where((r) => r.activityId == activityId && r.timestamp.isAfter(start))
        .fold(0.0, (sum, r) => sum + r.value);

    final time = _events
        .where((e) => e.activityId == activityId && e.timestamp.isAfter(start))
        .fold(0, (sum, e) => sum + e.durationDelta);

    return MapEntry(counts, time);
  }

  /// Specialized metrics for Count-Based activities
  Map<String, CountBasedMetrics> getAllCountBasedMetrics() {
    final cacheKey = 'count_metrics_${_selectedRange.name}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final now = DateTime.now();
    final start = _getStartTime(now);
    final result = <String, CountBasedMetrics>{};

    final countActivities = _activities.where((a) => a.type == ActivityType.countBased);

    for (final activity in countActivities) {
      final records = _countRecords.where((r) => r.activityId == activity.id && r.timestamp.isAfter(start));
      final events = _events.where((e) => e.activityId == activity.id && e.timestamp.isAfter(start));

      final dailyCounts = <DateTime, double>{};
      final dailyTimeSpent = <DateTime, int>{};

      for (var r in records) {
        final date = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        dailyCounts[date] = (dailyCounts[date] ?? 0) + r.value;
      }

      for (var e in events) {
        final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
        dailyTimeSpent[date] = (dailyTimeSpent[date] ?? 0) + e.durationDelta;
      }

      final totalCount = dailyCounts.values.fold(0.0, (sum, v) => sum + v);
      final totalTime = dailyTimeSpent.values.fold(0, (sum, v) => sum + v);

      result[activity.name] = CountBasedMetrics(
        name: activity.name,
        totalCount: totalCount,
        totalTimeSpent: totalTime,
        dailyCounts: dailyCounts,
        dailyTimeSpent: dailyTimeSpent,
        goalCount: activity.goalSeconds.toDouble() > 0 ? activity.goalSeconds.toDouble() : null,
      );
    }
    _cache[cacheKey] = result;
    return result;
  }

  Map<String, int> getCategoryDistribution() {
    final cacheKey = 'category_dist_${_selectedRange.name}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final now = DateTime.now();
    final start = _getStartTime(now);
    final distribution = <String, int>{};

    final rootMap = <String, String>{};
    for (final activity in _activities) {
      rootMap[activity.id] = _getRootName(activity);
    }

    for (final event in _events) {
      if (event.timestamp.isAfter(start)) {
        final rootName = rootMap[event.activityId] ?? 'Unknown';
        distribution[rootName] = (distribution[rootName] ?? 0) + event.durationDelta;
      }
    }

    _cache[cacheKey] = distribution;
    return distribution;
  }

  List<MapEntry<Activity, int>> getTopActivities({int count = 5}) {
    final cacheKey = 'top_activities_${_selectedRange.name}_$count';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final now = DateTime.now();
    final start = _getStartTime(now);
    final activityTime = <String, int>{};

    for (final event in _events) {
      if (event.timestamp.isAfter(start)) {
        activityTime[event.activityId] = (activityTime[event.activityId] ?? 0) + event.durationDelta;
      }
    }

    final sortedList = activityTime.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final result = <MapEntry<Activity, int>>[];
    for (final entry in sortedList.take(count)) {
      final activity = _activities.cast<Activity?>().firstWhere((a) => a?.id == entry.key, orElse: () => null);
      if (activity != null) {
        result.add(MapEntry(activity, entry.value));
      }
    }
    _cache[cacheKey] = result;
    return result;
  }

  /// Returns unique activity IDs modified today
  int getTodayModificationCount() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final modifiedIds = <String>{};

    for (final e in _events) {
      if (e.timestamp.isAfter(todayStart)) {
        modifiedIds.add(e.activityId);
      }
    }

    for (final r in _countRecords) {
      if (r.timestamp.isAfter(todayStart)) {
        modifiedIds.add(r.activityId);
      }
    }

    // Include currently running status
    for (final a in activityController.activitiesMap.values) {
      if (a.status == ActivityStatus.running) {
        modifiedIds.add(a.id);
      }
    }

    return modifiedIds.length;
  }

  /// Returns (Activity Name, Progress Percentage 0.0-1.0)
  MapEntry<String, double>? getPriorityGoalProgress() {
    // 1. Priority: Running time-based activity with a goal
    final runningTimeWithGoal = activityController.activitiesMap.values
        .where((a) => a.status == ActivityStatus.running && a.type == ActivityType.timeBased && a.goalSeconds > 0)
        .toList();

    if (runningTimeWithGoal.isNotEmpty) {
      runningTimeWithGoal.sort((a, b) => (b.startedAt ?? DateTime(0)).compareTo(a.startedAt ?? DateTime(0)));
      final a = runningTimeWithGoal.first;
      final current = activityController.getEffectiveSeconds(a.id);
      return MapEntry(a.name, (current / a.goalSeconds).clamp(0.0, 1.0));
    }

    // 2. Priority: Most recently updated count-based activity with a goal
    final countWithGoal = _activities.where((a) => a.type == ActivityType.countBased && a.goalSeconds > 0).toList();

    if (countWithGoal.isNotEmpty) {
      countWithGoal.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final a = countWithGoal.first;
      final totalCount = activityController.getCountTotalFor(a.id);
      return MapEntry(a.name, (totalCount / a.goalSeconds).clamp(0.0, 1.0));
    }

    // 3. Fallback: Any last modified activity with a goal (e.g. paused time-based)
    final allWithGoal = _activities.where((a) => a.goalSeconds > 0).toList();
    if (allWithGoal.isEmpty) return null;

    allWithGoal.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final a = allWithGoal.first;

    if (a.type == ActivityType.timeBased) {
      final current = activityController.getEffectiveSeconds(a.id);
      return MapEntry(a.name, (current / a.goalSeconds).clamp(0.0, 1.0));
    } else {
      final totalCount = activityController.getCountTotalFor(a.id);
      return MapEntry(a.name, (totalCount / a.goalSeconds).clamp(0.0, 1.0));
    }
  }

  // --- INTERNAL HELPERS ---

  String _getRootName(Activity activity) {
    Activity current = activity;
    int depth = 0;
    while (current.parentId != null && depth < 20) {
      final parentId = current.parentId;
      final parent = _activities.cast<Activity>().firstWhere((a) => a.id == parentId, orElse: () => current);
      if (parent == current) break;
      current = parent;
      depth++;
    }
    return current.name;
  }

  DateTime _getStartTime(DateTime now) {
    switch (_selectedRange) {
      case TimeRange.day:
        return DateTime(now.year, now.month, now.day);
      case TimeRange.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case TimeRange.month:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      case TimeRange.year:
        return DateTime(now.year, now.month, 1).subtract(const Duration(days: 364));
      case TimeRange.forever:
        if (_events.isEmpty && _countRecords.isEmpty) return now.subtract(const Duration(days: 365));
        DateTime earliest = now;
        for (var e in _events) {
          if (e.timestamp.isBefore(earliest)) earliest = e.timestamp;
        }
        for (var r in _countRecords) {
          if (r.timestamp.isBefore(earliest)) earliest = r.timestamp;
        }
        return DateTime(earliest.year, earliest.month, earliest.day);
    }
  }

  DateTime _getDataStartTime(DateTime now) {
    switch (_selectedRange) {
      case TimeRange.day:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 3));
      case TimeRange.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      case TimeRange.month:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 120));
      case TimeRange.year:
        return DateTime(now.year, now.month, 1).subtract(const Duration(days: 365 * 2));
      case TimeRange.forever:
        return _getStartTime(now);
    }
  }

  List<DateTime> _generateTimeSlots(DateTime start, DateTime end) {
    final slots = <DateTime>[];
    DateTime current = start;

    switch (_selectedRange) {
      case TimeRange.day:
        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          slots.add(current);
          current = current.add(const Duration(hours: 1));
          if (slots.length > 24) break;
        }
        break;
      case TimeRange.month:
        // Group by week for Month view
        current = DateTime(start.year, start.month, start.day);
        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          slots.add(current);
          current = current.add(const Duration(days: 7));
          if (slots.length >= 5) break;
        }
        break;
      case TimeRange.forever:
        final diff = end.difference(start).inDays;
        if (diff > 730) {
          // More than 2 years -> Group by year
          while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
            slots.add(DateTime(current.year, 1, 1));
            current = DateTime(current.year + 1, 1, 1);
          }
        } else if (diff > 365) {
          // 1-2 years -> Group by quarter
          while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
            slots.add(DateTime(current.year, ((current.month - 1) ~/ 3) * 3 + 1, 1));
            current = DateTime(current.year, ((current.month - 1) ~/ 3) * 3 + 4, 1);
          }
        } else {
          // Less than 1 year -> Group by month
          while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
            slots.add(DateTime(current.year, current.month, 1));
            current = DateTime(current.year, current.month + 1, 1);
          }
        }
        break;
      case TimeRange.year:
        // Always group by month for Year view
        current = DateTime(start.year, start.month, 1);
        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          slots.add(current);
          current = DateTime(current.year, current.month + 1, 1);
        }
        break;
      default:
        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          slots.add(DateTime(current.year, current.month, current.day));
          current = current.add(const Duration(days: 1));
        }
    }
    return slots;
  }

  DateTime _mapToSlot(DateTime timestamp) {
    switch (_selectedRange) {
      case TimeRange.day:
        return DateTime(timestamp.year, timestamp.month, timestamp.day, timestamp.hour);
      case TimeRange.month:
        final start = _getStartTime(DateTime.now());
        final diff = timestamp.difference(start).inDays;
        if (diff < 0) return start;
        final weekNum = (diff / 7).floor();
        return start.add(Duration(days: weekNum * 7));
      case TimeRange.year:
        return DateTime(timestamp.year, timestamp.month, 1);
      case TimeRange.forever:
        final now = DateTime.now();
        final start = _getStartTime(now);
        final diff = now.difference(start).inDays;
        if (diff > 730) return DateTime(timestamp.year, 1, 1);
        if (diff > 365) return DateTime(timestamp.year, ((timestamp.month - 1) ~/ 3) * 3 + 1, 1);
        return DateTime(timestamp.year, timestamp.month, 1);
      default:
        return DateTime(timestamp.year, timestamp.month, timestamp.day);
    }
  }

  // --- SINGLE ACTIVITY PAGE ---

  List<ActivityEvent> getActivityEvents(String activityId) {
    return _events.where((e) => e.activityId == activityId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Map<DateTime, int> getActivityTrend(String activityId) {
    final cacheKey = 'activity_trend_extended_${activityId}_${_selectedRange.name}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final now = DateTime.now();
    final start = _getDataStartTime(now);
    final map = <DateTime, int>{};

    final slots = _generateTimeSlots(start, now);
    for (var slot in slots) {
      map[slot] = 0;
    }

    for (final event in _events) {
      if (event.activityId == activityId && event.timestamp.isAfter(start)) {
        final slot = _mapToSlot(event.timestamp);
        if (map.containsKey(slot)) {
          map[slot] = (map[slot] ?? 0) + event.durationDelta;
        }
      }
    }

    final currentActivity = activityController.activitiesMap[activityId];
    if (currentActivity?.status == ActivityStatus.running && currentActivity?.startedAt != null) {
      final slot = _mapToSlot(now);
      if (map.containsKey(slot)) {
        map[slot] = (map[slot] ?? 0) + now.difference(currentActivity!.startedAt!).inSeconds;
      }
      return map;
    }

    _cache[cacheKey] = map;
    return map;
  }

  @override
  void dispose() {
    activityController.removeListener(_onActivityUpdate);
    super.dispose();
  }
}

class CountBasedMetrics {
  final String name;
  final double totalCount;
  final int totalTimeSpent;
  final Map<DateTime, double> dailyCounts;
  final Map<DateTime, int> dailyTimeSpent;
  final double? goalCount;

  CountBasedMetrics({
    required this.name,
    required this.totalCount,
    required this.totalTimeSpent,
    required this.dailyCounts,
    required this.dailyTimeSpent,
    this.goalCount,
  });

  double get averageTimePerCount => totalCount > 0 ? totalTimeSpent / totalCount : 0;
  double get efficiencyPerHour => totalTimeSpent > 0 ? totalCount / (totalTimeSpent / 3600) : 0;
  int get progressPercentage => goalCount != null && goalCount! > 0 ? (totalCount / goalCount! * 100).toInt() : 0;
}
