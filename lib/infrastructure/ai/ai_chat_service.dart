import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/count_record.dart';
import 'ai_chat_models.dart';
import 'ai_tool_definitions.dart';
import 'ai_tool_dispatcher.dart';
import 'ai_tool_result.dart';

class AiChatService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final Map<String, Activity> Function()? _localActivitiesProvider;
  final Future<void> Function(String activityId, double value)? _localAddCount;
  final Future<void> Function(String activityId)? _localStartActivity;
  final Future<void> Function(String activityId)? _localPauseActivity;
  final Future<void> Function(String activityId)? _localCompleteActivity;
  final Future<void> Function(String name, {String? parentId})? _localCreateActivity;
  final Future<void> Function(String activityId, {String? name})? _localUpdateActivity;
  final Future<void> Function(String activityId, String? newParentId)? _localMoveActivity;
  final Future<void> Function(String activityId)? _localDeleteActivity;
  final Future<List<CountRecord>> Function(String activityId)? _localGetCountRecords;
  final Future<List<ActivityEvent>> Function(String activityId)? _localGetActivityEvents;
  final int Function(String activityId)? _localGetEffectiveSeconds;
  final double Function(String activityId)? _localGetCountTotal;

  // New: cross-activity analytics callbacks
  final Future<List<CountRecord>> Function()? _localGetAllCountRecords;
  final Future<List<ActivityEvent>> Function()? _localGetAllEvents;

  final _uuid = const Uuid();

  late final AiToolDispatcher _dispatcher;
  late final GenerativeModel _model;
  late ChatSession _chat;
  final String _modelId = 'gemini-3-flash-preview';

  final List<AiChatMessage> _messages = [];
  bool _isBusy = false;
  Map<String, dynamic> _appContext = const {};

  AiChatService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    Map<String, Activity> Function()? localActivitiesProvider,
    Future<void> Function(String activityId, double value)? localAddCount,
    Future<void> Function(String activityId)? localStartActivity,
    Future<void> Function(String activityId)? localPauseActivity,
    Future<void> Function(String activityId)? localCompleteActivity,
    Future<void> Function(String name, {String? parentId})? localCreateActivity,
    Future<void> Function(String activityId, {String? name})? localUpdateActivity,
    Future<void> Function(String activityId, String? newParentId)? localMoveActivity,
    Future<void> Function(String activityId)? localDeleteActivity,
    Future<List<CountRecord>> Function(String activityId)? localGetCountRecords,
    Future<List<ActivityEvent>> Function(String activityId)? localGetActivityEvents,
    int Function(String activityId)? localGetEffectiveSeconds,
    double Function(String activityId)? localGetCountTotal,
    Future<List<CountRecord>> Function()? localGetAllCountRecords,
    Future<List<ActivityEvent>> Function()? localGetAllEvents,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _localActivitiesProvider = localActivitiesProvider,
        _localAddCount = localAddCount,
        _localStartActivity = localStartActivity,
        _localPauseActivity = localPauseActivity,
        _localCompleteActivity = localCompleteActivity,
        _localCreateActivity = localCreateActivity,
        _localUpdateActivity = localUpdateActivity,
        _localMoveActivity = localMoveActivity,
        _localDeleteActivity = localDeleteActivity,
        _localGetCountRecords = localGetCountRecords,
        _localGetActivityEvents = localGetActivityEvents,
        _localGetEffectiveSeconds = localGetEffectiveSeconds,
        _localGetCountTotal = localGetCountTotal,
        _localGetAllCountRecords = localGetAllCountRecords,
        _localGetAllEvents = localGetAllEvents {
    _dispatcher = AiToolDispatcher(_functions);
    _rebuildChats();
  }

  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool get isBusy => _isBusy;

  void clearHistory() {
    _messages.clear();
    _chat = _model.startChat(maxTurns: 20);
    notifyListeners();
  }

  void reset() {
    _messages.clear();
    _rebuildChats();
    notifyListeners();
  }

  void updateContext(Map<String, dynamic> context) {
    _appContext = context;
  }

  void _rebuildChats() {
    _model = FirebaseAI.googleAI(auth: _auth).generativeModel(
      model: _modelId,
      tools: [Tool.functionDeclarations(kAiToolDeclarations)],
      systemInstruction: Content('system', [
        TextPart(
          [
            'You are an in-app productivity assistant for an activity tracking app.',
            'You help the user inspect, create, pause, resume, finish, modify, organize, and analyze activities.',
            'You have access to tools for performing real app actions and fetching real analytics data.',
            '',
            'CRITICAL RULES:',
            '1. Never claim that an action was completed unless the correct tool was called and returned success.',
            '2. If the user asks to pause, resume, finish, create, delete, rename, move, or modify an activity, you MUST call the matching tool.',
            '3. Do not simulate tool results.',
            '4. Do not say "done", "paused", "resumed", "created", or "updated" unless the tool confirms success.',
            '5. If a tool fails, clearly explain that the action failed and show the reason.',
            '6. If the user request is ambiguous, ask a short clarification question.',
            '7. If the user asks about current app data, use the read/query tools instead of guessing.',
            '8. Do not invent activity names, statuses, durations, counts, or IDs.',
            '9. Keep responses short and action-focused.',
            '10. Prefer performing the action over explaining how to perform it.',
            '11. When multiple activities match the user request, ask the user to choose unless the app context identifies the selected activity.',
            '12. If there is a selected activity in the UI context, use it as the default target when the user says "this activity", "current activity", or "selected activity".',
            '13. Always report the final result based on the tool response.',
            '14. When asked about progress, totals, or "how many" for an activity, check the activity type. For count-based activities (like pushups), report the "totalCount". For time-based activities, report the duration.',
            '15. Use the "getActivityAnalytics" tool for historical questions like "this week" or "this month" to get precise totals over that period.',
            '',
            'ANALYTICS RULES:',
            '16. If the user asks for analytics, comparisons, summaries, charts, trends, allocation, rankings, or any data-driven question, you MUST call the appropriate local analytics tool.',
            '17. Never invent statistics or numbers. All analytical data must come from a tool call.',
            '18. Never request raw datasets or events. Only query tools that return summarized structured results.',
            '19. Use these local analytics tools:',
            '    - compareCounts(periodA, periodB): for count comparisons across two periods.',
            '    - getTimeAllocation(period): for time distribution across activities.',
            '    - getTrend(metric, period, granularity): for line/trend data over time.',
            '    - getLeaderboard(period): for ranking activities.',
            '    - getProductivitySummary(period): for compact metrics (total focus, total counts, completed, top activity).',
            '    - getActivityAnalytics(activityId): for specific single activity details.',
            '20. After calling a local analytics tool, you MUST select the best visual representation and output it inside a STRICT structured JSON payload in your text response.',
            '    Format your text response with a professional explanation followed by the structured widget JSON payload like this:',
            '    ```json',
            '    {',
            '      "type": "analytics_widget",',
            '      "widget": {',
            '        "widgetType": "bar_chart",', // or metric_card, donut_chart, line_chart, leaderboard, comparison_summary
            '        "title": "Title of the widget",',
            '        "description": "Short explanation",',
            '        "insights": "AI-derived summary insights or key bullet points",', // optional
            '        "footer": "Total or summary sentence in footer",', // optional
            '        "data": { ... }', // strictly matching the data schema for the widgetType
            '      }',
            '    }',
            '    ```',
            '    Use "donut_chart" for allocation/pie, "line_chart" for trend over time, "bar_chart" or "leaderboard" for comparison/rankings, and "metric_card" for quick summary.',
            '21. If data is unavailable or the period has no records, say so honestly — do not fabricate.',
            '22. Prefer visual widgets over long text for all analytical answers.',
          ].join('\n'),
        ),
      ]),
    );

    _chat = _model.startChat(maxTurns: 20);
  }

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_auth.currentUser == null) {
      _messages.add(
        AiChatMessage(id: _uuid.v4(), role: AiChatRole.assistant, text: 'Please sign in first to use AI tools.'),
      );
      notifyListeners();
      return;
    }

    final prompt = 'App Context:\n${_appContext.toString()}\n\nUser Message:\n$trimmed';

    _messages.add(AiChatMessage(id: _uuid.v4(), role: AiChatRole.user, text: trimmed));
    _isBusy = true;
    notifyListeners();

    try {
      var response = await _chat.sendMessage(Content.text(prompt));

      for (var turn = 0; turn < 12; turn++) {
        final calls = _extractFunctionCalls(response);
        if (calls.isEmpty) break;

        for (final call in calls) {
          final toolName = call.name;
          final args = Map<String, dynamic>.from(call.args);

          dev.log("AI TOOL REQUEST: $toolName | args=$args");

          _messages.add(
            AiChatMessage(
              id: _uuid.v4(),
              role: AiChatRole.tool,
              text: 'Calling $toolName',
              payload: {'name': toolName, 'args': args, 'status': 'running'},
            ),
          );
          notifyListeners();

          final result = await _guardedToolCall(toolName, args);

          if (result.success) {
            dev.log("AI TOOL SUCCESS: $toolName | result=${result.toJson()}");
          } else {
            dev.log("AI TOOL FAILED: $toolName | error=${result.error?.message}");
          }

          _replaceLastToolStatus(status: result.success ? 'success' : 'error', envelope: result);
          _emitWidgetIfPresent(result);

          response = await _chat.sendMessage(
            Content.functionResponses([FunctionResponse(toolName, result.toJson(), id: call.id)]),
          );
        }
      }

      final textOut = response.text?.trim();
      if (textOut != null && textOut.isNotEmpty) {
        _tryParseAndEmitWidgetFromText(textOut);
        final cleanText = _stripJsonBlock(textOut);
        if (cleanText.isNotEmpty) {
          _messages.add(AiChatMessage(id: _uuid.v4(), role: AiChatRole.assistant, text: cleanText));
        }
      } else if (_extractFunctionCalls(response).isNotEmpty) {
        // Max turns reached
      } else {
        dev.log("AI RESPONSE BLOCKED: action requested without tool call or no text output");
      }
    } on FirebaseAISdkException catch (e) {
      _messages.add(AiChatMessage(id: _uuid.v4(), role: AiChatRole.assistant, text: 'AI SDK error: ${e.message}'));
    } catch (e) {
      _messages.add(AiChatMessage(id: _uuid.v4(), role: AiChatRole.assistant, text: 'Error: $e'));
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _tryParseAndEmitWidgetFromText(String text) {
    // 1. Try to find markdown code block ```json ... ``` or ``` ... ``` containing JSON
    final jsonRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final match = jsonRegex.firstMatch(text);
    String? jsonText = match?.group(1);

    // 2. If no code block, try to find first '{' and last '}'
    if (jsonText == null) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        jsonText = text.substring(start, end + 1);
      }
    }

    if (jsonText != null) {
      try {
        final parsed = jsonDecode(jsonText);
        if (parsed is Map<String, dynamic> && parsed['type'] == 'analytics_widget') {
          final widget = parsed['widget'];
          if (widget is Map<String, dynamic>) {
            final payload = Map<String, dynamic>.from(widget);
            final type = payload['widgetType']?.toString() ?? 'unknown';
            final title = payload['title']?.toString() ?? '';
            dev.log("AI WIDGET RENDER FROM TEXT: type=$type title=$title");
            
            _messages.add(
              AiChatMessage(
                id: _uuid.v4(),
                role: AiChatRole.analytics,
                text: '',
                payload: payload,
              ),
            );
            notifyListeners();
          }
        }
      } catch (e) {
        dev.log("WIDGET ERROR: malformed payload in text: $e");
      }
    }
  }

  String _stripJsonBlock(String text) {
    // Strip markdown code block
    final jsonRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    var clean = text.replaceAll(jsonRegex, '').trim();
    
    // If it was pure JSON, clean might be empty.
    if (clean.startsWith('{') && clean.endsWith('}')) {
      return '';
    }
    
    return clean;
  }

  List<FunctionCall> _extractFunctionCalls(GenerateContentResponse response) {
    if (response.candidates.isEmpty) return const [];
    final content = response.candidates.first.content;
    final parts = content.parts;
    return parts.whereType<FunctionCall>().toList(growable: false);
  }

  Future<AiToolEnvelope> _guardedToolCall(String toolName, Map<String, dynamic> args) async {
    final normalizedArgs = _normalizeArgs(args);
    
    // NEW RULE: Run analytics tools locally FIRST! Avoid Cloud Function latency.
    final isAnalytics = toolName == AiToolNames.compareCounts ||
        toolName == AiToolNames.getTimeAllocation ||
        toolName == AiToolNames.getTrend ||
        toolName == AiToolNames.getLeaderboard ||
        toolName == AiToolNames.getProductivitySummary ||
        toolName == AiToolNames.compareActivityAnalytics ||
        toolName == AiToolNames.getCountBasedActivityStats ||
        toolName == AiToolNames.getTimeBasedActivityStats ||
        toolName == AiToolNames.getCategoryAllocation ||
        toolName == AiToolNames.getTrendData ||
        toolName == AiToolNames.getActivityAnalytics;

    if (isAnalytics) {
      final local = await _tryLocalFallback(toolName, normalizedArgs);
      if (local != null) return local;
    }

    final res = await _dispatcher.call(toolName, normalizedArgs);
    if (!res.success && res.error?.code == 'not-found') {
      final local = await _tryLocalFallback(toolName, normalizedArgs);
      if (local != null) return local;
    }
    return res;
  }

  Map<String, dynamic> _normalizeArgs(Map<String, dynamic> args) {
    final out = <String, dynamic>{...args};
    void rename(String from, String to) {
      if (out.containsKey(from) && !out.containsKey(to)) {
        out[to] = out[from];
      }
    }

    rename('nodeld', 'activityId');
    rename('nodeId', 'activityId');
    rename('id', 'activityId');
    rename('parentld', 'parentId');
    return out;
  }

  void _emitWidgetIfPresent(AiToolEnvelope envelope) {
    if (!envelope.success) return;
    final widgetPayload = envelope.data?['widgetPayload'];
    if (widgetPayload is! Map) return;

    final payload = Map<String, dynamic>.from(widgetPayload);
    final type = payload['widgetType']?.toString() ?? 'unknown';
    final title = payload['title']?.toString() ?? '';

    dev.log("AI WIDGET RENDER FROM TOOL RESULT: type=$type title=$title");

    _messages.add(
      AiChatMessage(
        id: _uuid.v4(),
        role: AiChatRole.analytics,
        text: '',
        payload: payload,
      ),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Date Helpers
  // ---------------------------------------------------------------------------

  static (DateTime, DateTime) _parsePeriodRange(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return switch (period) {
      'today' => (today, tomorrow),
      'yesterday' => (today.subtract(const Duration(days: 1)), today),
      'this_week' => (
          today.subtract(Duration(days: today.weekday - 1)),
          tomorrow,
        ),
      'last_week' => (
          today.subtract(Duration(days: today.weekday - 1 + 7)),
          today.subtract(Duration(days: today.weekday - 1)),
        ),
      'this_month' => (DateTime(today.year, today.month, 1), tomorrow),
      'last_month' => (
          DateTime(today.year, today.month - 1, 1),
          DateTime(today.year, today.month, 1),
        ),
      _ => (today, tomorrow), // default to today
    };
  }

  static String _periodLabel(String period) => switch (period) {
    'today' => 'Today',
    'yesterday' => 'Yesterday',
    'this_week' => 'This Week',
    'last_week' => 'Last Week',
    'this_month' => 'This Month',
    'last_month' => 'Last Month',
    _ => period,
  };

  static String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }

  // ---------------------------------------------------------------------------
  // Local fallbacks
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope?> _tryLocalFallback(String toolName, Map<String, dynamic> args) async {
    final provider = _localActivitiesProvider;
    if (provider == null) return null;
    final map = provider();

    // -------------------------------------------------------------------------
    // New analytics tools
    // -------------------------------------------------------------------------

    if (toolName == AiToolNames.compareCounts) {
      return await _handleCompareCounts(args, map);
    }
    if (toolName == AiToolNames.getTimeAllocation) {
      return await _handleGetTimeAllocation(args, map);
    }
    if (toolName == AiToolNames.getTrend) {
      return await _handleGetTrend(args, map);
    }
    if (toolName == AiToolNames.getLeaderboard) {
      return await _handleGetLeaderboard(args, map);
    }
    if (toolName == AiToolNames.getProductivitySummary) {
      return await _handleGetProductivitySummary(args, map);
    }

    // -------------------------------------------------------------------------
    // Existing tools
    // -------------------------------------------------------------------------

    if (toolName == AiToolNames.getSelectedActivity) {
      final id = _appContext['selectedActivityId']?.toString();
      if (id == null) {
        return const AiToolEnvelope(success: false, message: 'No activity is currently selected.');
      }
      final a = map[id];
      if (a == null) {
        return const AiToolEnvelope(success: false, message: 'Selected activity not found.');
      }
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: a.id,
        activityName: a.name,
        data: {
          'activity': {
            ...a.toJson(),
            'totalDuration': _localGetEffectiveSeconds?.call(a.id),
            'totalCount': _localGetCountTotal?.call(a.id),
          }
        },
      );
    }

    if (toolName == AiToolNames.getActiveActivities) {
      final active = map.values.where((a) => a.status == ActivityStatus.running).toList();
      return AiToolEnvelope(
        success: true,
        action: toolName,
        data: {
          'activities': active.map((a) => {
            ...a.toJson(),
            'totalDuration': _localGetEffectiveSeconds?.call(a.id),
            'totalCount': _localGetCountTotal?.call(a.id),
          }).toList()
        },
      );
    }

    if (toolName == AiToolNames.getActivityById) {
      final id = args['activityId']?.toString();
      final a = map[id];
      if (a == null) return const AiToolEnvelope(success: false, message: 'Activity not found.');
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: a.id,
        activityName: a.name,
        data: {
          'activity': {
            ...a.toJson(),
            'totalDuration': _localGetEffectiveSeconds?.call(a.id),
            'totalCount': _localGetCountTotal?.call(a.id),
          }
        },
      );
    }

    if (toolName == AiToolNames.searchActivities) {
      final q = args['query']?.toString().toLowerCase() ?? '';
      final matches = map.values
          .where((a) => a.name.toLowerCase().contains(q) || a.description.toLowerCase().contains(q))
          .take(10)
          .toList();
      return AiToolEnvelope(
        success: true,
        action: toolName,
        data: {
          'matches': matches.map((a) => {
            ...a.toJson(),
            'totalDuration': _localGetEffectiveSeconds?.call(a.id),
            'totalCount': _localGetCountTotal?.call(a.id),
          }).toList()
        },
      );
    }

    if (toolName == AiToolNames.getTodaySummary) {
      final summary = _appContext['todaySummary'] ?? {};
      return AiToolEnvelope(success: true, action: toolName, data: {'summary': summary});
    }

    if (toolName == AiToolNames.getActivityChildren) {
      final id = args['activityId']?.toString();
      final children = map.values.where((a) => a.parentId == id).toList();
      return AiToolEnvelope(
        success: true,
        action: toolName,
        data: {'children': children.map((a) => a.toJson()).toList()},
      );
    }

    if (toolName == AiToolNames.createActivity) {
      if (_localCreateActivity == null) return null;
      final name = args['name']?.toString() ?? 'New Activity';
      final parentId = args['parentId']?.toString();
      await _localCreateActivity(name, parentId: parentId);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityName: name,
        message: 'Activity "$name" created successfully.',
      );
    }

    if (toolName == AiToolNames.pauseActivity) {
      if (_localPauseActivity == null) return null;
      final id = args['activityId']?.toString();
      if (id == null) return const AiToolEnvelope(success: false, message: 'Missing activityId.');
      final a = map[id];
      await _localPauseActivity(id);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: id,
        activityName: a?.name,
        message: 'Activity "${a?.name ?? id}" paused successfully.',
      );
    }

    if (toolName == AiToolNames.resumeActivity) {
      if (_localStartActivity == null) return null;
      final id = args['activityId']?.toString();
      if (id == null) return const AiToolEnvelope(success: false, message: 'Missing activityId.');
      final a = map[id];
      await _localStartActivity(id);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: id,
        activityName: a?.name,
        message: 'Activity "${a?.name ?? id}" resumed successfully.',
      );
    }

    if (toolName == AiToolNames.finishActivity) {
      if (_localCompleteActivity == null) return null;
      final id = args['activityId']?.toString();
      if (id == null) return const AiToolEnvelope(success: false, message: 'Missing activityId.');
      final a = map[id];
      await _localCompleteActivity(id);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: id,
        activityName: a?.name,
        message: 'Activity "${a?.name ?? id}" finished successfully.',
      );
    }

    if (toolName == AiToolNames.renameActivity) {
      if (_localUpdateActivity == null) return null;
      final id = args['activityId']?.toString();
      final newName = args['newName']?.toString();
      if (id == null || newName == null) return const AiToolEnvelope(success: false, message: 'Missing arguments.');
      await _localUpdateActivity(id, name: newName);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: id,
        activityName: newName,
        message: 'Activity renamed to "$newName".',
      );
    }

    if (toolName == AiToolNames.moveActivity) {
      if (_localMoveActivity == null) return null;
      final id = args['activityId']?.toString();
      final newParentId = args['newParentId']?.toString();
      if (id == null) return const AiToolEnvelope(success: false, message: 'Missing activityId.');
      await _localMoveActivity(id, newParentId);
      return AiToolEnvelope(success: true, action: toolName, activityId: id, message: 'Activity moved successfully.');
    }

    if (toolName == AiToolNames.deleteActivity) {
      if (_localDeleteActivity == null) return null;
      final id = args['activityId']?.toString();
      if (id == null) return const AiToolEnvelope(success: false, message: 'Missing activityId.');
      final a = map[id];
      await _localDeleteActivity(id);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: id,
        activityName: a?.name,
        message: 'Activity "${a?.name ?? id}" deleted successfully.',
      );
    }

    if (toolName == AiToolNames.addCount) {
      if (_localAddCount == null) return null;
      final id = args['activityId']?.toString();
      final amountRaw = args['amount'];
      final amount = amountRaw is num ? amountRaw.toDouble() : double.tryParse(amountRaw?.toString() ?? '0');
      if (id == null || amount == null) return const AiToolEnvelope(success: false, message: 'Missing arguments.');
      await _localAddCount(id, amount);
      return AiToolEnvelope(success: true, action: toolName, activityId: id, message: 'Added $amount to activity.');
    }

    if (toolName == AiToolNames.getActivityAnalytics) {
      final id = args['activityId']?.toString();
      if (id == null) return const AiToolEnvelope(success: false, message: 'Missing activityId.');
      final a = map[id];
      if (a == null) return const AiToolEnvelope(success: false, message: 'Activity not found.');

      final startDateStr = args['startDate']?.toString();
      final endDateStr = args['endDate']?.toString();
      final start = startDateStr != null ? DateTime.tryParse(startDateStr) : null;
      final end = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      if (a.type == ActivityType.countBased) {
        if (_localGetCountRecords == null) return null;
        var records = await _localGetCountRecords(id);
        if (start != null) records = records.where((r) => r.timestamp.isAfter(start)).toList();
        if (end != null) records = records.where((r) => r.timestamp.isBefore(end)).toList();

        final total = records.fold<double>(0, (sum, r) => sum + r.value);
        return AiToolEnvelope(
          success: true,
          action: toolName,
          activityId: id,
          activityName: a.name,
          data: {
            'totalCount': total,
            'recordCount': records.length,
            'unit': 'counts',
          },
        );
      } else {
        if (_localGetActivityEvents == null) return null;
        var events = await _localGetActivityEvents(id);
        if (start != null) events = events.where((e) => e.timestamp.isAfter(start)).toList();
        if (end != null) events = events.where((e) => e.timestamp.isBefore(end)).toList();

        final totalSeconds = events.fold<int>(0, (sum, e) => sum + e.durationDelta);
        return AiToolEnvelope(
          success: true,
          action: toolName,
          activityId: id,
          activityName: a.name,
          data: {
            'totalDurationSeconds': totalSeconds,
            'eventCount': events.length,
            'unit': 'seconds',
          },
        );
      }
    }

    // -------------------------------------------------------------------------
    // Legacy analytics tools for fallback/compatibility
    // -------------------------------------------------------------------------

    if (toolName == AiToolNames.compareActivityAnalytics) {
      return await _handleCompareActivityAnalytics(args, map);
    }

    if (toolName == AiToolNames.getCountBasedActivityStats) {
      return await _handleGetCountBasedActivityStats(args, map);
    }

    if (toolName == AiToolNames.getTimeBasedActivityStats) {
      return await _handleGetTimeBasedActivityStats(args, map);
    }

    if (toolName == AiToolNames.getCategoryAllocation) {
      return await _handleGetCategoryAllocation(args, map);
    }

    if (toolName == AiToolNames.getTrendData) {
      return await _handleGetTrendData(args, map);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 1️⃣ compareCounts(periodA, periodB)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleCompareCounts(Map<String, dynamic> args, Map<String, Activity> map) async {
    dev.log("LOCAL ANALYTICS TOOL: compareCounts");
    final periodA = args['periodA']?.toString() ?? 'this_week';
    final periodB = args['periodB']?.toString() ?? 'last_week';

    final (startA, endA) = _parsePeriodRange(periodA);
    final (startB, endB) = _parsePeriodRange(periodB);

    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];
    final countActivities = map.values.where((a) => a.type == ActivityType.countBased).toList();

    final activitiesList = <Map<String, dynamic>>[];

    for (final a in countActivities) {
      final curVal = allCountRecords
          .where((r) => r.activityId == a.id && r.timestamp.isAfter(startA) && r.timestamp.isBefore(endA))
          .fold<double>(0, (s, r) => s + r.value);
      final prevVal = allCountRecords
          .where((r) => r.activityId == a.id && r.timestamp.isAfter(startB) && r.timestamp.isBefore(endB))
          .fold<double>(0, (s, r) => s + r.value);

      if (curVal == 0 && prevVal == 0) continue;

      activitiesList.add({
        'name': a.name,
        'current': curVal.round(),
        'previous': prevVal.round(),
        'difference': (curVal - prevVal).round(),
      });
    }

    dev.log("ANALYTICS REDUCTION: compareCounts reduced ${allCountRecords.length} records to ${activitiesList.length} compared activities");

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.compareCounts,
      data: {
        'activities': activitiesList,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2️⃣ getTimeAllocation(period)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetTimeAllocation(Map<String, dynamic> args, Map<String, Activity> map) async {
    dev.log("LOCAL ANALYTICS TOOL: getTimeAllocation");
    final period = args['period']?.toString() ?? 'this_week';
    final (start, end) = _parsePeriodRange(period);

    final allEvents = await _localGetAllEvents?.call() ?? [];

    final categoryTotals = <String, int>{};
    for (final e in allEvents) {
      if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
        categoryTotals[e.activityId] = (categoryTotals[e.activityId] ?? 0) + e.durationDelta;
      }
    }

    final categoriesList = <Map<String, dynamic>>[];
    for (final entry in categoryTotals.entries) {
      final a = map[entry.key];
      if (a != null && entry.value > 0) {
        categoriesList.add({
          'label': a.name,
          'seconds': entry.value,
        });
      }
    }

    categoriesList.sort((a, b) => (b['seconds'] as int).compareTo(a['seconds'] as int));
    dev.log("ANALYTICS REDUCTION: getTimeAllocation reduced ${allEvents.length} events to ${categoriesList.length} category sums");

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getTimeAllocation,
      data: {
        'categories': categoriesList,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 3️⃣ getTrend(metric, period, granularity)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetTrend(Map<String, dynamic> args, Map<String, Activity> map) async {
    dev.log("LOCAL ANALYTICS TOOL: getTrend");
    final metric = args['metric']?.toString() ?? 'duration';
    final period = args['period']?.toString() ?? 'this_week';

    final (start, end) = _parsePeriodRange(period);

    final labels = <String>[];
    final values = <double>[];

    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];
    final allEvents = await _localGetAllEvents?.call() ?? [];

    final dataPoints = <String, double>{};

    if (metric == 'count') {
      for (final r in allCountRecords) {
        if (r.timestamp.isAfter(start) && r.timestamp.isBefore(end)) {
          final key = '${r.timestamp.month}/${r.timestamp.day}';
          dataPoints[key] = (dataPoints[key] ?? 0) + r.value;
        }
      }
      dev.log("ANALYTICS REDUCTION: getTrend count reduced ${allCountRecords.length} records");
    } else {
      for (final e in allEvents) {
        if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
          final key = '${e.timestamp.month}/${e.timestamp.day}';
          dataPoints[key] = (dataPoints[key] ?? 0) + e.durationDelta;
        }
      }
      dev.log("ANALYTICS REDUCTION: getTrend duration reduced ${allEvents.length} events");
    }

    var cursor = start;
    while (cursor.isBefore(end)) {
      final key = '${cursor.month}/${cursor.day}';
      labels.add(key);
      values.add(dataPoints[key] ?? 0.0);
      cursor = cursor.add(const Duration(days: 1));
    }

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getTrend,
      data: {
        'labels': labels,
        'values': values,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4️⃣ getLeaderboard(period)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetLeaderboard(Map<String, dynamic> args, Map<String, Activity> map) async {
    dev.log("LOCAL ANALYTICS TOOL: getLeaderboard");
    final period = args['period']?.toString() ?? 'this_week';
    final (start, end) = _parsePeriodRange(period);

    final allEvents = await _localGetAllEvents?.call() ?? [];
    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];

    final items = <Map<String, dynamic>>[];

    // Add time-based activities
    final timeTotals = <String, int>{};
    for (final e in allEvents) {
      if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
        timeTotals[e.activityId] = (timeTotals[e.activityId] ?? 0) + e.durationDelta;
      }
    }
    for (final entry in timeTotals.entries) {
      final a = map[entry.key];
      if (a != null && entry.value > 0) {
        items.add({
          'label': a.name,
          'value': _formatSeconds(entry.value),
          'rawSeconds': entry.value,
          'type': 'duration',
        });
      }
    }

    // Add count-based activities
    final countTotals = <String, double>{};
    for (final r in allCountRecords) {
      if (r.timestamp.isAfter(start) && r.timestamp.isBefore(end)) {
        countTotals[r.activityId] = (countTotals[r.activityId] ?? 0) + r.value;
      }
    }
    for (final entry in countTotals.entries) {
      final a = map[entry.key];
      if (a != null && entry.value > 0) {
        items.add({
          'label': a.name,
          'value': entry.value.round().toString(),
          'rawSeconds': 0, // secondary sorting
          'type': 'count',
        });
      }
    }

    // Sort ranked items: duration first, then counts
    items.sort((a, b) {
      if (a['type'] == 'duration' && b['type'] == 'duration') {
        return (b['rawSeconds'] as int).compareTo(a['rawSeconds'] as int);
      } else if (a['type'] == 'duration') {
        return -1;
      } else if (b['type'] == 'duration') {
        return 1;
      } else {
        return double.parse(b['value'] as String).compareTo(double.parse(a['value'] as String));
      }
    });

    dev.log("ANALYTICS REDUCTION: getLeaderboard reduced ${allEvents.length} events and ${allCountRecords.length} records into ${items.length} rankings");

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getLeaderboard,
      data: {
        'items': items,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5️⃣ getProductivitySummary(period)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetProductivitySummary(Map<String, dynamic> args, Map<String, Activity> map) async {
    dev.log("LOCAL ANALYTICS TOOL: getProductivitySummary");
    final period = args['period']?.toString() ?? 'this_week';
    final (start, end) = _parsePeriodRange(period);

    final allEvents = await _localGetAllEvents?.call() ?? [];
    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];

    int totalFocus = 0;
    for (final e in allEvents) {
      if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
        totalFocus += e.durationDelta;
      }
    }

    double totalCounts = 0;
    for (final r in allCountRecords) {
      if (r.timestamp.isAfter(start) && r.timestamp.isBefore(end)) {
        totalCounts += r.value;
      }
    }

    // Completed activities count
    final completedCount = map.values
        .where((a) => a.status == ActivityStatus.completed && a.updatedAt.isAfter(start) && a.updatedAt.isBefore(end))
        .length;

    // Top activity determination
    final timeTotals = <String, int>{};
    for (final e in allEvents) {
      if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
        timeTotals[e.activityId] = (timeTotals[e.activityId] ?? 0) + e.durationDelta;
      }
    }
    String topActivity = 'None';
    int maxFocus = 0;
    for (final entry in timeTotals.entries) {
      if (entry.value > maxFocus) {
        final a = map[entry.key];
        if (a != null) {
          maxFocus = entry.value;
          topActivity = a.name;
        }
      }
    }

    dev.log("ANALYTICS REDUCTION: getProductivitySummary consolidated ${allEvents.length} events and ${allCountRecords.length} records into productivity summary");

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getProductivitySummary,
      data: {
        'totalFocus': _formatSeconds(totalFocus),
        'totalCounts': totalCounts.round(),
        'completedActivities': completedCount,
        'topActivity': topActivity,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // compareActivityAnalytics
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope?> _handleCompareActivityAnalytics(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
    dev.log("AI ANALYTICS TOOL REQUEST: compareActivityAnalytics");

    final currentPeriod = args['currentPeriod']?.toString() ?? 'today';
    final previousPeriod = args['previousPeriod']?.toString() ?? 'yesterday';
    final metric = args['metric']?.toString();
    final rawIds = args['activityIds'];
    final filterIds = rawIds is List ? rawIds.map((e) => e.toString()).toSet() : null;

    final (curStart, curEnd) = _parsePeriodRange(currentPeriod);
    final (prevStart, prevEnd) = _parsePeriodRange(previousPeriod);

    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];
    final allEvents = await _localGetAllEvents?.call() ?? [];

    final activities = map.values.where((a) {
      if (filterIds != null && !filterIds.contains(a.id)) return false;
      return true;
    }).toList();

    if (activities.isEmpty) {
      return const AiToolEnvelope(success: false, message: 'No matching activities found.');
    }

    final comparisonItems = <Map<String, dynamic>>[];

    for (final a in activities) {
      final useCount = metric == 'count' ||
          (metric == null && a.type == ActivityType.countBased);
      final useDuration = metric == 'duration' ||
          (metric == null && a.type != ActivityType.countBased);

      if (useCount && a.type == ActivityType.countBased) {
        final curRecords = allCountRecords
            .where((r) =>
                r.activityId == a.id &&
                r.timestamp.isAfter(curStart) &&
                r.timestamp.isBefore(curEnd))
            .toList();
        final prevRecords = allCountRecords
            .where((r) =>
                r.activityId == a.id &&
                r.timestamp.isAfter(prevStart) &&
                r.timestamp.isBefore(prevEnd))
            .toList();

        final curVal = curRecords.fold<double>(0, (s, r) => s + r.value);
        final prevVal = prevRecords.fold<double>(0, (s, r) => s + r.value);

        if (curVal == 0 && prevVal == 0) continue;

        final diff = curVal - prevVal;
        final trend = diff > 0 ? 'up' : diff < 0 ? 'down' : 'neutral';

        comparisonItems.add({
          'label': a.name,
          'current': curVal.toStringAsFixed(0),
          'previous': prevVal.toStringAsFixed(0),
          'difference': diff >= 0 ? '+${diff.toStringAsFixed(0)}' : diff.toStringAsFixed(0),
          'trend': trend,
        });
      } else if (useDuration) {
        final curSecs = allEvents
            .where((e) =>
                e.activityId == a.id &&
                e.timestamp.isAfter(curStart) &&
                e.timestamp.isBefore(curEnd))
            .fold<int>(0, (s, e) => s + e.durationDelta);
        final prevSecs = allEvents
            .where((e) =>
                e.activityId == a.id &&
                e.timestamp.isAfter(prevStart) &&
                e.timestamp.isBefore(prevEnd))
            .fold<int>(0, (s, e) => s + e.durationDelta);

        if (curSecs == 0 && prevSecs == 0) continue;

        final diff = curSecs - prevSecs;
        final trend = diff > 0 ? 'up' : diff < 0 ? 'down' : 'neutral';

        comparisonItems.add({
          'label': a.name,
          'current': _formatSeconds(curSecs),
          'previous': _formatSeconds(prevSecs),
          'difference': diff >= 0 ? '+${_formatSeconds(diff.abs())}' : '-${_formatSeconds(diff.abs())}',
          'trend': trend,
        });
      }
    }

    dev.log("AI ANALYTICS TOOL RESULT: compareActivityAnalytics records=${comparisonItems.length}");

    if (comparisonItems.isEmpty) {
      return AiToolEnvelope(
        success: true,
        action: AiToolNames.compareActivityAnalytics,
        message: 'No activity data found for the selected periods.',
        data: {'comparisonItems': []},
      );
    }

    final widgetPayload = {
      'widgetType': 'comparison_summary',
      'title': '${_periodLabel(currentPeriod)} vs ${_periodLabel(previousPeriod)}',
      'description': 'Activity comparison across two periods',
      'currentPeriodLabel': _periodLabel(currentPeriod),
      'previousPeriodLabel': _periodLabel(previousPeriod),
      'items': comparisonItems,
    };

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.compareActivityAnalytics,
      data: {
        'comparisonItems': comparisonItems,
        'widgetPayload': widgetPayload,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // getCountBasedActivityStats
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope?> _handleGetCountBasedActivityStats(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
    dev.log("AI ANALYTICS TOOL REQUEST: getCountBasedActivityStats");

    final period = args['period']?.toString() ?? 'today';
    final (start, end) = _parsePeriodRange(period);

    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];

    final countActivities = map.values.where((a) => a.type == ActivityType.countBased).toList();

    final results = <Map<String, dynamic>>[];
    for (final a in countActivities) {
      final total = allCountRecords
          .where((r) =>
              r.activityId == a.id &&
              r.timestamp.isAfter(start) &&
              r.timestamp.isBefore(end))
          .fold<double>(0, (s, r) => s + r.value);

      if (total > 0) {
        results.add({'label': a.name, 'value': total, 'activityId': a.id});
      }
    }

    results.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    dev.log("AI ANALYTICS TOOL RESULT: getCountBasedActivityStats records=${results.length}");

    if (results.isEmpty) {
      return AiToolEnvelope(
        success: true,
        action: AiToolNames.getCountBasedActivityStats,
        message: 'No count-based activity data found for ${_periodLabel(period)}.',
        data: {'stats': []},
      );
    }

    final labels = results.map((r) => r['label'].toString()).toList();
    final values = results.map((r) => (r['value'] as double)).toList();

    final widgetPayload = results.length > 1
        ? {
            'widgetType': 'bar_chart',
            'title': 'Count Activities — ${_periodLabel(period)}',
            'xAxisLabel': 'Activity',
            'yAxisLabel': 'Count',
            'data': {
              'labels': labels,
              'series': [
                {'name': _periodLabel(period), 'values': values},
              ],
            },
          }
        : {
            'widgetType': 'metric_card',
            'title': results.first['label'].toString(),
            'value': values.first.toStringAsFixed(0),
            'subtitle': _periodLabel(period),
          };

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getCountBasedActivityStats,
      data: {
        'stats': results,
        'widgetPayload': widgetPayload,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // getTimeBasedActivityStats
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope?> _handleGetTimeBasedActivityStats(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
    dev.log("AI ANALYTICS TOOL REQUEST: getTimeBasedActivityStats");

    final period = args['period']?.toString() ?? 'today';
    final (start, end) = _parsePeriodRange(period);

    final allEvents = await _localGetAllEvents?.call() ?? [];

    final results = <Map<String, dynamic>>[];
    for (final a in map.values) {
      final totalSeconds = allEvents
          .where((e) =>
              e.activityId == a.id &&
              e.timestamp.isAfter(start) &&
              e.timestamp.isBefore(end))
          .fold<int>(0, (s, e) => s + e.durationDelta);

      if (totalSeconds > 0) {
        results.add({
          'label': a.name,
          'value': totalSeconds,
          'activityId': a.id,
        });
      }
    }

    results.sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));

    dev.log("AI ANALYTICS TOOL RESULT: getTimeBasedActivityStats records=${results.length}");

    if (results.isEmpty) {
      return AiToolEnvelope(
        success: true,
        action: AiToolNames.getTimeBasedActivityStats,
        message: 'No time-based activity data found for ${_periodLabel(period)}.',
        data: {'stats': []},
      );
    }

    final topN = results.take(10).toList();
    final labels = topN.map((r) => r['label'].toString()).toList();
    final values = topN.map((r) => (r['value'] as int).toDouble()).toList();

    final leaderboardItems = topN.map((r) {
      return {
        'label': r['label'].toString(),
        'value': _formatSeconds(r['value'] as int),
      };
    }).toList();

    final widgetPayload = topN.length > 3
        ? {
            'widgetType': 'leaderboard',
            'title': 'Top Activities — ${_periodLabel(period)}',
            'description': 'Ranked by time spent',
            'items': leaderboardItems,
          }
        : {
            'widgetType': 'bar_chart',
            'title': 'Time per Activity — ${_periodLabel(period)}',
            'xAxisLabel': 'Activity',
            'yAxisLabel': 'Seconds',
            'data': {
              'labels': labels,
              'series': [
                {'name': _periodLabel(period), 'values': values},
              ],
            },
          };

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getTimeBasedActivityStats,
      data: {
        'stats': results,
        'widgetPayload': widgetPayload,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // getCategoryAllocation
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope?> _handleGetCategoryAllocation(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
    dev.log("AI ANALYTICS TOOL REQUEST: getCategoryAllocation");

    final period = args['period']?.toString() ?? 'today';
    final (start, end) = _parsePeriodRange(period);

    final allEvents = await _localGetAllEvents?.call() ?? [];

    final totals = <String, int>{};
    for (final e in allEvents) {
      if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
        totals[e.activityId] = (totals[e.activityId] ?? 0) + e.durationDelta;
      }
    }

    final items = <Map<String, dynamic>>[];
    for (final entry in totals.entries) {
      final a = map[entry.key];
      if (a != null && entry.value > 0) {
        items.add({'label': a.name, 'value': entry.value});
      }
    }
    items.sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));

    dev.log("AI ANALYTICS TOOL RESULT: getCategoryAllocation records=${items.length}");

    if (items.isEmpty) {
      return AiToolEnvelope(
        success: true,
        action: AiToolNames.getCategoryAllocation,
        message: 'No activity data found for ${_periodLabel(period)}.',
        data: {'allocation': []},
      );
    }

    final topItems = items.take(8).toList();
    if (items.length > 8) {
      final otherTotal = items.skip(8).fold<int>(0, (s, i) => s + (i['value'] as int));
      topItems.add({'label': 'Other', 'value': otherTotal});
    }

    final widgetPayload = {
      'widgetType': 'donut_chart',
      'title': 'Time Allocation — ${_periodLabel(period)}',
      'description': 'Time distribution across activities',
      'data': topItems,
    };

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getCategoryAllocation,
      data: {
        'allocation': items,
        'widgetPayload': widgetPayload,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // getTrendData
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope?> _handleGetTrendData(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
    dev.log("AI ANALYTICS TOOL REQUEST: getTrendData");

    final id = args['activityId']?.toString();
    if (id == null) return const AiToolEnvelope(success: false, message: 'Missing activityId.');
    final a = map[id];
    if (a == null) return const AiToolEnvelope(success: false, message: 'Activity not found.');

    final metric = args['metric']?.toString() ?? 'duration';
    final period = args['period']?.toString() ?? 'this_week';
    final (start, end) = _parsePeriodRange(period);

    final dataPoints = <String, double>{};

    if (metric == 'count' || a.type == ActivityType.countBased) {
      final records = await _localGetCountRecords?.call(id) ?? [];
      for (final r in records) {
        if (r.timestamp.isAfter(start) && r.timestamp.isBefore(end)) {
          final dayKey = '${r.timestamp.month}/${r.timestamp.day}';
          dataPoints[dayKey] = (dataPoints[dayKey] ?? 0) + r.value;
        }
      }
    } else {
      final events = await _localGetActivityEvents?.call(id) ?? [];
      for (final e in events) {
        if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
          final dayKey = '${e.timestamp.month}/${e.timestamp.day}';
          dataPoints[dayKey] = (dataPoints[dayKey] ?? 0) + e.durationDelta;
        }
      }
    }

    final allDays = <String, double>{};
    var cursor = start;
    while (cursor.isBefore(end)) {
      final key = '${cursor.month}/${cursor.day}';
      allDays[key] = dataPoints[key] ?? 0;
      cursor = cursor.add(const Duration(days: 1));
    }

    final labels = allDays.keys.toList();
    final values = allDays.values.toList();

    dev.log("AI ANALYTICS TOOL RESULT: getTrendData points=${labels.length}");

    if (labels.isEmpty) {
      return AiToolEnvelope(
        success: true,
        action: AiToolNames.getTrendData,
        message: 'No trend data found for ${a.name} in ${_periodLabel(period)}.',
        data: {'trendPoints': []},
      );
    }

    final yLabel = metric == 'count' ? 'Count' : 'Seconds';

    final widgetPayload = {
      'widgetType': 'line_chart',
      'title': '${a.name} — ${_periodLabel(period)}',
      'description': 'Daily $metric trend',
      'xAxisLabel': 'Date',
      'yAxisLabel': yLabel,
      'data': {
        'labels': labels,
        'series': [
          {'name': a.name, 'values': values},
        ],
      },
    };

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getTrendData,
      activityId: id,
      activityName: a.name,
      data: {
        'trendPoints': List.generate(
          labels.length,
          (i) => {'date': labels[i], 'value': values[i]},
        ),
        'widgetPayload': widgetPayload,
      },
    );
  }

  void _replaceLastToolStatus({required String status, required AiToolEnvelope envelope}) {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role != AiChatRole.tool) continue;
      final payload = m.payload;
      if (payload == null) continue;
      if (payload['status'] != 'running') continue;
      final next = Map<String, dynamic>.from(payload);
      next['status'] = status;
      next['result'] = envelope.toJson();
      _messages[i] = AiChatMessage(id: m.id, role: m.role, text: m.text, payload: next);
      return;
    }
  }
}
