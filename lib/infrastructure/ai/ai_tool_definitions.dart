import 'package:firebase_ai/firebase_ai.dart';

/// Canonical tool names. Keep these stable: the model will learn them.
abstract final class AiToolNames {
  static const String getSelectedActivity = 'getSelectedActivity';
  static const String getActiveActivities = 'getActiveActivities';
  static const String getActivityById = 'getActivityById';
  static const String searchActivities = 'searchActivities';
  static const String getTodaySummary = 'getTodaySummary';
  static const String getActivityChildren = 'getActivityChildren';

  static const String createActivity = 'createActivity';
  static const String pauseActivity = 'pauseActivity';
  static const String resumeActivity = 'resumeActivity';
  static const String finishActivity = 'finishActivity';
  static const String renameActivity = 'renameActivity';
  static const String moveActivity = 'moveActivity';
  static const String deleteActivity = 'deleteActivity';
  static const String addCount = 'addCount';
  
  // Existing analytics tools
  static const String getActivityAnalytics = 'getActivityAnalytics';
  static const String compareActivityAnalytics = 'compareActivityAnalytics';
  static const String getCountBasedActivityStats = 'getCountBasedActivityStats';
  static const String getTimeBasedActivityStats = 'getTimeBasedActivityStats';
  static const String getCategoryAllocation = 'getCategoryAllocation';
  static const String getTrendData = 'getTrendData';

  // New local-first analytics tools
  static const String compareCounts = 'compareCounts';
  static const String getTimeAllocation = 'getTimeAllocation';
  static const String getTrend = 'getTrend';
  static const String getLeaderboard = 'getLeaderboard';
  static const String getProductivitySummary = 'getProductivitySummary';

  static const Set<String> allowlist = {
    getSelectedActivity,
    getActiveActivities,
    getActivityById,
    searchActivities,
    getTodaySummary,
    getActivityChildren,
    createActivity,
    pauseActivity,
    resumeActivity,
    finishActivity,
    renameActivity,
    moveActivity,
    deleteActivity,
    addCount,
    getActivityAnalytics,
    compareActivityAnalytics,
    getCountBasedActivityStats,
    getTimeBasedActivityStats,
    getCategoryAllocation,
    getTrendData,
    // New tools
    compareCounts,
    getTimeAllocation,
    getTrend,
    getLeaderboard,
    getProductivitySummary,
  };
}

/// System-wide declarative tools mapped directly to App UI actions or local SQLite queries.
/// Used by the FirebaseAI / GenerativeModel client to discover valid callbacks.
final List<FunctionDeclaration> kAiToolDeclarations = [
  // ---------------------------------------------------------------------------
  // Action tools
  // ---------------------------------------------------------------------------
  FunctionDeclaration(
    AiToolNames.getSelectedActivity,
    'Get the details of the activity currently selected in the UI context (name, status, type, parent, ID).',
    parameters: const {},
  ),
  FunctionDeclaration(
    AiToolNames.getActiveActivities,
    'List all activities currently in "running" status (active timers).',
    parameters: const {},
  ),
  FunctionDeclaration(
    AiToolNames.getActivityById,
    'Retrieve details of a specific activity by its ID.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.searchActivities,
    'Search the user\'s activities by name or description. Returns matching results.',
    parameters: {
      'query': JSONSchema.string(description: 'Text query to search for.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.getTodaySummary,
    'Get a breakdown of today\'s total focus time and active/completed activities.',
    parameters: const {},
  ),
  FunctionDeclaration(
    AiToolNames.getActivityChildren,
    'Get sub-activities (children) of a given parent activity.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the parent activity.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.createActivity,
    'Create a new activity in the tracking system. Can optionally specify a parent ID.',
    parameters: {
      'name': JSONSchema.string(description: 'Display name of the new activity.'),
      'parentId': JSONSchema.string(
        description: 'Optional ID of the parent activity to nest under.',
        nullable: true,
      ),
    },
    optionalParameters: const ['parentId'],
  ),
  FunctionDeclaration(
    AiToolNames.pauseActivity,
    'Pause tracking for an active time-based activity (stops timer).',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity to pause.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.resumeActivity,
    'Start or resume tracking for a time-based activity (starts timer).',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity to resume.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.finishActivity,
    'Mark an activity as completed. If it was active, stops tracking.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity to finish.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.renameActivity,
    'Change the name of an existing activity.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity to rename.'),
      'newName': JSONSchema.string(description: 'The new display name for the activity.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.moveActivity,
    'Move an activity to nest under a different parent, or to root level.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity to move.'),
      'newParentId': JSONSchema.string(
        description: 'The unique ID of the new parent activity, or null to move to root.',
        nullable: true,
      ),
    },
  ),
  FunctionDeclaration(
    AiToolNames.deleteActivity,
    'Permanently delete an activity and all its associated events and count logs.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity to delete.'),
    },
  ),
  FunctionDeclaration(
    AiToolNames.addCount,
    'Log discrete value input for a count-based activity (e.g. log 30 pushups).',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the count-based activity.'),
      'amount': JSONSchema.number(description: 'The value to log (e.g. 10.0, 30.0).'),
    },
  ),

  // ---------------------------------------------------------------------------
  // Analytics tools
  // ---------------------------------------------------------------------------
  FunctionDeclaration(
    AiToolNames.getActivityAnalytics,
    'Fetch analytics details (total duration or count value) for a single activity over a specific date range.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity.'),
      'startDate': JSONSchema.string(
        description: 'Start of date range (ISO 8601 string, e.g. "2026-05-01T00:00:00Z").',
        nullable: true,
      ),
      'endDate': JSONSchema.string(
        description: 'End of date range (ISO 8601 string, e.g. "2026-05-07T23:59:59Z").',
        nullable: true,
      ),
    },
    optionalParameters: const ['startDate', 'endDate'],
  ),

  // New local-first analytics tools
  FunctionDeclaration(
    AiToolNames.compareCounts,
    'Compare count-based activity totals across two periods. Returns a summarized comparison list.',
    parameters: {
      'periodA': JSONSchema.string(
        description: 'The primary period to compare. One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
      'periodB': JSONSchema.string(
        description: 'The baseline period to compare against. One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
    },
  ),
  FunctionDeclaration(
    AiToolNames.getTimeAllocation,
    'Get time duration allocation across categories for a period. Returns total seconds per activity.',
    parameters: {
      'period': JSONSchema.string(
        description: 'The analysis period. One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
    },
  ),
  FunctionDeclaration(
    AiToolNames.getTrend,
    'Get trend data (metric value per label/date) for a given metric (count or duration) over a period.',
    parameters: {
      'metric': JSONSchema.string(
        description: 'The metric type: "count" for count-based or "duration" for time-based.',
      ),
      'period': JSONSchema.string(
        description: 'One of: this_week, last_week, this_month, last_month.',
      ),
      'granularity': JSONSchema.string(
        description: 'Optional granularity: "day" or "week". Default is "day".',
        nullable: true,
      ),
    },
    optionalParameters: const ['granularity'],
  ),
  FunctionDeclaration(
    AiToolNames.getLeaderboard,
    'Get ranked time-based or count-based activities for a period.',
    parameters: {
      'period': JSONSchema.string(
        description: 'One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
    },
  ),
  FunctionDeclaration(
    AiToolNames.getProductivitySummary,
    'Get a compact productivity summary for a period including total focus time, total count values, number of completed activities, and the top active activity.',
    parameters: {
      'period': JSONSchema.string(
        description: 'One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
    },
  ),

  // Legacy analytics tools for fallback/compatibility
  FunctionDeclaration(
    AiToolNames.compareActivityAnalytics,
    'Compare activity performance (count or duration) across two periods.',
    parameters: {
      'currentPeriod': JSONSchema.string(
        description: 'The primary period. One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
      'previousPeriod': JSONSchema.string(
        description: 'The baseline period to compare. One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
      'metric': JSONSchema.string(
        description: 'Optional filter: "count" for count-based or "duration" for time-based.',
        nullable: true,
      ),
      'activityIds': JSONSchema.array(
        description: 'Optional list of activity IDs to restrict comparison to.',
        items: JSONSchema.string(),
        nullable: true,
      ),
    },
    optionalParameters: const ['metric', 'activityIds'],
  ),
  FunctionDeclaration(
    AiToolNames.getCountBasedActivityStats,
    'Return totals and logs for all count-based activities in a period.',
    parameters: {
      'period': JSONSchema.string(
        description: 'One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
    },
  ),
  FunctionDeclaration(
    AiToolNames.getTimeBasedActivityStats,
    'Return duration totals for all time-based activities in a period.',
    parameters: {
      'period': JSONSchema.string(
        description: 'One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
    },
  ),
  FunctionDeclaration(
    AiToolNames.getCategoryAllocation,
    'Return time distribution across all activities in a period as percentages.',
    parameters: {
      'period': JSONSchema.string(
        description: 'One of: today, yesterday, this_week, last_week, this_month, last_month.',
      ),
    },
  ),
  FunctionDeclaration(
    AiToolNames.getTrendData,
    'Return chartable daily trend data for an activity metric over a period.',
    parameters: {
      'activityId': JSONSchema.string(description: 'The unique ID of the activity.'),
      'metric': JSONSchema.string(
        description: '"count" for count-based activities, "duration" for time-based activities.',
      ),
      'period': JSONSchema.string(
        description: 'One of: this_week, last_week, this_month, last_month.',
      ),
      'granularity': JSONSchema.string(
        description: '"day" (default) or "week".',
        nullable: true,
      ),
    },
    optionalParameters: const ['granularity'],
  ),
];
