import 'ai_tool_definitions.dart';

abstract final class AiToolErrorCodes {
  static const String missingParameter = 'MISSING_PARAMETER';
  static const String notFound = 'NOT_FOUND';
  static const String ambiguousMatch = 'AMBIGUOUS_MATCH';
  static const String invalidState = 'INVALID_STATE';
  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String validationError = 'VALIDATION_ERROR';
  static const String emptyResult = 'EMPTY_RESULT';
  static const String internalError = 'INTERNAL_ERROR';
}

class AiToolContract {
  final String name;
  final String description;
  final List<String> requiredFields;
  final List<String> optionalFields;
  final Map<String, dynamic> inputExample;
  final Map<String, dynamic> outputSuccessExample;
  final Map<String, dynamic> outputErrorExample;

  const AiToolContract({
    required this.name,
    required this.description,
    required this.requiredFields,
    this.optionalFields = const [],
    this.inputExample = const {},
    this.outputSuccessExample = const {},
    this.outputErrorExample = const {},
  });
}

abstract final class AiToolContracts {
  static final Map<String, AiToolContract> byName = {
    AiToolNames.pauseActivity: const AiToolContract(
      name: AiToolNames.pauseActivity,
      description: 'Pause a running activity.',
      requiredFields: ['activityId'],
      inputExample: {'activityId': 'abc123'},
    ),
    AiToolNames.resumeActivity: const AiToolContract(
      name: AiToolNames.resumeActivity,
      description: 'Resume an activity.',
      requiredFields: ['activityId'],
      inputExample: {'activityId': 'abc123'},
    ),
    AiToolNames.finishActivity: const AiToolContract(
      name: AiToolNames.finishActivity,
      description: 'Finish an activity.',
      requiredFields: ['activityId'],
      inputExample: {'activityId': 'abc123'},
    ),
    AiToolNames.renameActivity: const AiToolContract(
      name: AiToolNames.renameActivity,
      description: 'Rename an activity.',
      requiredFields: ['activityId', 'newName'],
      inputExample: {'activityId': 'abc123', 'newName': 'Study'},
    ),
    AiToolNames.moveActivity: const AiToolContract(
      name: AiToolNames.moveActivity,
      description: 'Move an activity under a new parent.',
      requiredFields: ['activityId'],
      optionalFields: ['newParentId'],
      inputExample: {'activityId': 'abc123', 'newParentId': 'parent999'},
    ),
    AiToolNames.deleteActivity: const AiToolContract(
      name: AiToolNames.deleteActivity,
      description: 'Delete an activity.',
      requiredFields: ['activityId'],
      inputExample: {'activityId': 'abc123'},
    ),
    AiToolNames.addCount: const AiToolContract(
      name: AiToolNames.addCount,
      description: 'Add count amount to a count-based activity.',
      requiredFields: ['activityId', 'amount'],
      inputExample: {'activityId': 'abc123', 'amount': 10},
    ),
    AiToolNames.createActivity: const AiToolContract(
      name: AiToolNames.createActivity,
      description: 'Create a new activity.',
      requiredFields: ['name'],
      optionalFields: ['parentId'],
      inputExample: {'name': 'Practical MLOps', 'parentId': null},
    ),
    AiToolNames.searchActivities: const AiToolContract(
      name: AiToolNames.searchActivities,
      description: 'Search activities by keyword.',
      requiredFields: ['query'],
      inputExample: {'query': 'study'},
    ),
    AiToolNames.getActivityById: const AiToolContract(
      name: AiToolNames.getActivityById,
      description: 'Fetch one activity by id.',
      requiredFields: ['activityId'],
      inputExample: {'activityId': 'abc123'},
    ),
    AiToolNames.getActivityAnalytics: const AiToolContract(
      name: AiToolNames.getActivityAnalytics,
      description: 'Get analytics for one activity.',
      requiredFields: ['activityId'],
      optionalFields: ['startDate', 'endDate'],
      inputExample: {
        'activityId': 'abc123',
        'startDate': null,
        'endDate': null,
      },
    ),
    AiToolNames.compareActivityAnalytics: const AiToolContract(
      name: AiToolNames.compareActivityAnalytics,
      description: 'Compare analytics between periods.',
      requiredFields: ['currentPeriod', 'previousPeriod'],
      optionalFields: ['metric', 'activityIds'],
      inputExample: {'currentPeriod': 'today', 'previousPeriod': 'yesterday'},
    ),
    AiToolNames.getCountBasedActivityStats: const AiToolContract(
      name: AiToolNames.getCountBasedActivityStats,
      description: 'Get summarized count stats.',
      requiredFields: ['period'],
      inputExample: {'period': 'this_month'},
    ),
    AiToolNames.getTimeBasedActivityStats: const AiToolContract(
      name: AiToolNames.getTimeBasedActivityStats,
      description: 'Get summarized duration stats.',
      requiredFields: ['period'],
      inputExample: {'period': 'this_month'},
    ),
    AiToolNames.getCategoryAllocation: const AiToolContract(
      name: AiToolNames.getCategoryAllocation,
      description: 'Get time allocation by activity/category.',
      requiredFields: ['period'],
      inputExample: {'period': 'this_month'},
    ),
    AiToolNames.getTrendData: const AiToolContract(
      name: AiToolNames.getTrendData,
      description: 'Get trend data for one activity.',
      requiredFields: ['activityId', 'metric', 'period'],
      optionalFields: ['granularity'],
      inputExample: {
        'activityId': 'abc123',
        'metric': 'duration',
        'period': 'this_week',
      },
    ),
    AiToolNames.compareCounts: const AiToolContract(
      name: AiToolNames.compareCounts,
      description: 'Compare count totals between two periods.',
      requiredFields: ['periodA', 'periodB'],
      inputExample: {'periodA': 'today', 'periodB': 'yesterday'},
    ),
    AiToolNames.getTimeAllocation: const AiToolContract(
      name: AiToolNames.getTimeAllocation,
      description: 'Get local summarized time allocation.',
      requiredFields: ['period'],
      inputExample: {'period': 'this_week'},
    ),
    AiToolNames.getTrend: const AiToolContract(
      name: AiToolNames.getTrend,
      description: 'Get local summarized trend.',
      requiredFields: ['metric', 'period'],
      optionalFields: ['granularity'],
      inputExample: {
        'metric': 'duration',
        'period': 'this_week',
        'granularity': 'day',
      },
    ),
    AiToolNames.getLeaderboard: const AiToolContract(
      name: AiToolNames.getLeaderboard,
      description: 'Get ranked activity leaderboard.',
      requiredFields: ['period'],
      inputExample: {'period': 'this_week'},
    ),
    AiToolNames.getProductivitySummary: const AiToolContract(
      name: AiToolNames.getProductivitySummary,
      description: 'Get compact productivity summary.',
      requiredFields: ['period'],
      inputExample: {'period': 'this_week'},
    ),
  };
}
