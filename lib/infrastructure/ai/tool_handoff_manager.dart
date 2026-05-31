import '../../domain/entities/activity.dart';
import 'ai_tool_contracts.dart';
import 'ai_tool_definitions.dart';

class ToolHandoffResult {
  final String tool;
  final Map<String, dynamic> resolvedArgs;
  final List<String> missingRequired;
  final bool usedContext;
  final bool usedSearch;

  const ToolHandoffResult({
    required this.tool,
    required this.resolvedArgs,
    required this.missingRequired,
    required this.usedContext,
    required this.usedSearch,
  });

  bool get isReady => missingRequired.isEmpty;
}

class ToolHandoffManager {
  const ToolHandoffManager();

  ToolHandoffResult resolve({
    required String tool,
    required Map<String, dynamic> args,
    required Map<String, dynamic> appContext,
    required Map<String, Activity> activities,
  }) {
    final resolved = _normalizeArgs(args);
    var usedContext = false;
    var usedSearch = false;
    final required =
        AiToolContracts.byName[tool]?.requiredFields ?? const <String>[];

    if (_requiresActivityId(tool) && _isBlank(resolved['activityId'])) {
      final selectedId = appContext['selectedActivityId']?.toString();
      if (!_isBlank(selectedId)) {
        resolved['activityId'] = selectedId;
        usedContext = true;
      }
    }

    if (_requiresActivityId(tool) && _isBlank(resolved['activityId'])) {
      final guessedName = _extractActivityNameHint(resolved, appContext);
      if (!_isBlank(guessedName)) {
        final match = _findBestActivityMatch(activities, guessedName!);
        if (match != null) {
          resolved['activityId'] = match.id;
          usedSearch = true;
        }
      }
    }

    final missing = required
        .where((field) => _isBlank(resolved[field]))
        .toList(growable: false);
    return ToolHandoffResult(
      tool: tool,
      resolvedArgs: resolved,
      missingRequired: missing,
      usedContext: usedContext,
      usedSearch: usedSearch,
    );
  }

  static bool _requiresActivityId(String tool) {
    return {
      AiToolNames.getActivityById,
      AiToolNames.getActivityChildren,
      AiToolNames.pauseActivity,
      AiToolNames.resumeActivity,
      AiToolNames.finishActivity,
      AiToolNames.renameActivity,
      AiToolNames.moveActivity,
      AiToolNames.deleteActivity,
      AiToolNames.addCount,
      AiToolNames.getActivityAnalytics,
      AiToolNames.getTrendData,
    }.contains(tool);
  }

  static Map<String, dynamic> _normalizeArgs(Map<String, dynamic> args) {
    final out = <String, dynamic>{...args};
    void rename(String from, String to) {
      if (out.containsKey(from) && !out.containsKey(to)) {
        out[to] = out[from];
      }
    }

    rename('nodeld', 'activityId');
    rename('nodeId', 'activityId');
    rename('id', 'activityId');
    rename('activityID', 'activityId');
    rename('parentld', 'parentId');
    rename('queryText', 'query');
    rename('activityName', 'name');
    return out;
  }

  static String? _extractActivityNameHint(
    Map<String, dynamic> args,
    Map<String, dynamic> appContext,
  ) {
    for (final key in ['activityName', 'name', 'query', 'activity']) {
      final value = args[key]?.toString();
      if (!_isBlank(value)) return value!.trim();
    }
    final selectedName = appContext['selectedActivityName']?.toString();
    if (!_isBlank(selectedName)) return selectedName!.trim();
    return null;
  }

  static Activity? _findBestActivityMatch(
    Map<String, Activity> activities,
    String query,
  ) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    final exact = activities.values
        .where((a) => a.name.toLowerCase() == normalized)
        .toList();
    if (exact.length == 1) return exact.first;
    if (exact.length > 1) return null;

    final contains = activities.values
        .where((a) => a.name.toLowerCase().contains(normalized))
        .toList();
    if (contains.length == 1) return contains.first;
    return null;
  }

  static bool _isBlank(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }
}
