import 'dart:async';
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
import 'analytics_markdown_fallback.dart';
import 'ai_chat_models.dart';
import 'ai_tool_contracts.dart';
import 'ai_tool_definitions.dart';
import 'ai_tool_dispatcher.dart';
import 'ai_tool_result.dart';
import 'tool_handoff_manager.dart';

class AiChatService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final Map<String, Activity> Function()? _localActivitiesProvider;
  final Future<void> Function(String activityId, double value)? _localAddCount;
  final Future<void> Function(String activityId)? _localStartActivity;
  final Future<void> Function(String activityId)? _localPauseActivity;
  final Future<void> Function(String activityId)? _localCompleteActivity;
  final Future<void> Function(String name, {String? parentId})?
  _localCreateActivity;
  final Future<void> Function(String activityId, {String? name})?
  _localUpdateActivity;
  final Future<void> Function(String activityId, String? newParentId)?
  _localMoveActivity;
  final Future<void> Function(String activityId)? _localDeleteActivity;
  final Future<List<CountRecord>> Function(String activityId)?
  _localGetCountRecords;
  final Future<List<ActivityEvent>> Function(String activityId)?
  _localGetActivityEvents;
  final int Function(String activityId)? _localGetEffectiveSeconds;
  final double Function(String activityId)? _localGetCountTotal;

  // New: cross-activity analytics callbacks
  final Future<List<CountRecord>> Function()? _localGetAllCountRecords;
  final Future<List<ActivityEvent>> Function()? _localGetAllEvents;

  final _uuid = const Uuid();

  late final AiToolDispatcher _dispatcher;
  final ToolHandoffManager _handoffManager = const ToolHandoffManager();
  late final GenerativeModel _model;
  late ChatSession _chat;
  final String _modelId = 'gemini-3-flash-preview';

  final List<AiChatMessage> _messages = [];
  bool _isBusy = false;
  Map<String, dynamic> _appContext = const {};
  String _sessionId = const Uuid().v4();
  int _activeRunToken = 0;
  bool _haltRequested = false;

  static const _toolStates = {
    'pending',
    'acquiring_parameters',
    'running',
    'retrying',
    'success',
    'failed',
  };

  AiChatService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    Map<String, Activity> Function()? localActivitiesProvider,
    Future<void> Function(String activityId, double value)? localAddCount,
    Future<void> Function(String activityId)? localStartActivity,
    Future<void> Function(String activityId)? localPauseActivity,
    Future<void> Function(String activityId)? localCompleteActivity,
    Future<void> Function(String name, {String? parentId})? localCreateActivity,
    Future<void> Function(String activityId, {String? name})?
    localUpdateActivity,
    Future<void> Function(String activityId, String? newParentId)?
    localMoveActivity,
    Future<void> Function(String activityId)? localDeleteActivity,
    Future<List<CountRecord>> Function(String activityId)? localGetCountRecords,
    Future<List<ActivityEvent>> Function(String activityId)?
    localGetActivityEvents,
    int Function(String activityId)? localGetEffectiveSeconds,
    double Function(String activityId)? localGetCountTotal,
    Future<List<CountRecord>> Function()? localGetAllCountRecords,
    Future<List<ActivityEvent>> Function()? localGetAllEvents,
  }) : _auth = auth ?? FirebaseAuth.instance,
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
    _sessionId = _uuid.v4();
    notifyListeners();
  }

  void reset() {
    _messages.clear();
    _rebuildChats();
    _sessionId = _uuid.v4();
    notifyListeners();
  }

  Future<void> haltProcessing() async {
    if (!_isBusy) return;
    final haltedSessionId = _sessionId;
    _haltRequested = true;
    _activeRunToken++;
    _isBusy = false;
    _chat = _model.startChat(maxTurns: 20);
    _sessionId = _uuid.v4();
    dev.log('AI HALT: local run terminated for session=$haltedSessionId');
    _messages.add(
      AiChatMessage(
        id: _uuid.v4(),
        role: AiChatRole.assistant,
        text: 'Stopped the ongoing process. You can start a new request now.',
      ),
    );
    notifyListeners();

    unawaited(_dispatcher.abortSession(haltedSessionId));
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
            'You have access to tools for reading app data, modifying activities, and generating analytics.',
            '',
            'CRITICAL RULES:',
            '1. Use tools whenever the user asks about real app data or requests an action.',
            '2. Never invent app data.',
            '3. Never claim an action succeeded unless a tool returned success.',
            '4. If parameters are missing, use UI context and search tools before asking the user.',
            '5. If a tool fails, recover once if possible, otherwise explain the failure.',
            '6. For analytics, call local analytics tools and use compact summarized outputs.',
            '7. For visual answers, return structured widget payloads only.',
            '8. Do not output malformed JSON or empty content blocks.',
            '9. Keep final responses short and based on tool results.',
            '',
            'RESPONSE BLOCK CONTRACT:',
            'Return one or more JSON blocks when useful.',
            'Text block: {"type":"text","text":"..."}',
            'Tool status block: {"type":"tool_status","tool":"toolName","status":"success","message":"..."}',
            'Analytics widget block: {"type":"analytics_widget","widget":{"widgetType":"bar_chart","title":"...","data":{}}}',
            'Never return empty {} blocks.',
            '',
            'FALLBACK RULES:',
            'If you cannot produce valid widget JSON with complete data, do NOT guess or emit empty/partial widget JSON.',
            'Instead, return a clear markdown answer (a short heading, a markdown table or bullet list, and a one-line summary) built from the tool results.',
            'Prefer a valid widget when the data is complete; otherwise prefer plain markdown over a broken widget.',
            'Never return empty content.',
          ].join('\n'),
        ),
      ]),
    );

    _chat = _model.startChat(maxTurns: 20);
  }

  Future<void> sendUserMessage(String text) async {
    if (_isBusy) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_auth.currentUser == null) {
      _messages.add(
        AiChatMessage(
          id: _uuid.v4(),
          role: AiChatRole.assistant,
          text: 'Please sign in first to use AI tools.',
        ),
      );
      notifyListeners();
      return;
    }

    final intent = _classifyIntent(trimmed);
    dev.log('AI INTENT: $intent');
    final prompt =
        'App Context:\n${jsonEncode(_appContext)}\n\nUser Message:\n$trimmed';

    _messages.add(
      AiChatMessage(id: _uuid.v4(), role: AiChatRole.user, text: trimmed),
    );
    _haltRequested = false;
    final runToken = ++_activeRunToken;
    final runSessionId = _sessionId;
    _isBusy = true;
    notifyListeners();

    try {
      var hadToolCall = false;
      var hadSuccessfulToolCall = false;
      final successfulToolResults = <AiToolEnvelope>[];

      final handledSimpleLookup = await _tryHandleActivityInfoQuestion(
        trimmed,
        runToken: runToken,
        runSessionId: runSessionId,
      );
      if (handledSimpleLookup) {
        dev.log('AI RESPONSE GENERATED: direct activity lookup flow');
        return;
      }
      var response = await _chat.sendMessage(Content.text(prompt));
      if (_isRunCancelled(runToken)) return;

      for (var turn = 0; turn < 12; turn++) {
        if (_isRunCancelled(runToken)) return;
        final calls = _extractFunctionCalls(response);
        if (calls.isEmpty) break;

        for (final call in calls) {
          if (_isRunCancelled(runToken)) return;
          hadToolCall = true;
          final toolName = _canonicalToolName(call.name);
          final args = Map<String, dynamic>.from(call.args);
          dev.log('TOOL HANDOFF: selected=$toolName');
          dev.log('TOOL PARAMS BEFORE VALIDATION: $args');

          final statusMessageId = _emitToolStatus(
            toolName: toolName,
            status: 'pending',
            message: 'Preparing tool call...',
            args: args,
          );
          _updateToolStatusById(
            statusMessageId,
            status: 'acquiring_parameters',
            message: 'Resolving parameters from context...',
          );

          _updateToolStatusById(
            statusMessageId,
            status: 'running',
            message: 'Executing tool...',
          );
          final result = await _guardedToolCall(
            toolName,
            args,
            sessionId: runSessionId,
            isCancelled: () => _isRunCancelled(runToken),
            onStatus: (status, message) {
              if (_isRunCancelled(runToken)) return;
              _updateToolStatusById(
                statusMessageId,
                status: status,
                message: message,
              );
            },
          );
          if (_isRunCancelled(runToken)) return;
          final finalStatus = result.success ? 'success' : 'failed';
          _updateToolStatusById(
            statusMessageId,
            status: finalStatus,
            message: result.message.isEmpty
                ? (result.success
                      ? 'Completed successfully.'
                      : 'Tool call failed.')
                : result.message,
            envelope: result,
          );

          if (result.success) {
            hadSuccessfulToolCall = true;
            successfulToolResults.add(result);
            dev.log("AI TOOL SUCCESS: $toolName | result=${result.toJson()}");
            _emitWidgetIfPresent(result);
          } else {
            dev.log(
              "AI TOOL FAILED: $toolName | error=${result.errorCode ?? result.error?.code}",
            );
          }

          response = await _chat.sendMessage(
            Content.functionResponses([
              FunctionResponse(toolName, result.toJson(), id: call.id),
            ]),
          );
          if (_isRunCancelled(runToken)) return;
        }
      }

      final textOut = response.text?.trim();
      if (textOut != null && textOut.isNotEmpty) {
        if (_isRunCancelled(runToken)) return;
        if (_looksLikeGenericFailure(textOut) &&
            successfulToolResults.isNotEmpty) {
          final recovered = _responseFromSuccessfulTools(
            trimmed,
            successfulToolResults,
          );
          if (recovered != null) {
            dev.log(
              'CHAT RESPONSE FALLBACK: recovered from successful tool data',
            );
            _messages.add(
              AiChatMessage(
                id: _uuid.v4(),
                role: AiChatRole.assistant,
                text: recovered,
              ),
            );
            return;
          }
        }
        if (intent == 'activity_action' &&
            hadToolCall &&
            !hadSuccessfulToolCall) {
          dev.log(
            'AI RESPONSE BLOCKED: action requested without successful tool call',
          );
        }
        final emitted = _consumeAssistantResponse(
          textOut,
          successfulToolResults: successfulToolResults,
        );
        if (!emitted && successfulToolResults.isNotEmpty) {
          final recovered = _responseFromSuccessfulTools(
            trimmed,
            successfulToolResults,
          );
          if (recovered != null) {
            dev.log(
              'CHAT RESPONSE FALLBACK: forced markdown from tool success',
            );
            _messages.add(
              AiChatMessage(
                id: _uuid.v4(),
                role: AiChatRole.assistant,
                text: recovered,
              ),
            );
            return;
          }
        }
      } else if (_extractFunctionCalls(response).isNotEmpty) {
        if (successfulToolResults.isNotEmpty) {
          final recovered = _responseFromSuccessfulTools(
            trimmed,
            successfulToolResults,
          );
          if (recovered != null) {
            dev.log('CHAT RESPONSE FALLBACK: max turns recovered from tools');
            _messages.add(
              AiChatMessage(
                id: _uuid.v4(),
                role: AiChatRole.assistant,
                text: recovered,
              ),
            );
            return;
          }
        }
      } else {
        if (successfulToolResults.isNotEmpty) {
          final recovered = _responseFromSuccessfulTools(
            trimmed,
            successfulToolResults,
          );
          if (recovered != null) {
            dev.log(
              'CHAT RESPONSE FALLBACK: empty content recovered from tools',
            );
            _messages.add(
              AiChatMessage(
                id: _uuid.v4(),
                role: AiChatRole.assistant,
                text: recovered,
              ),
            );
            return;
          }
        }
        dev.log(
          "AI RESPONSE BLOCKED: action requested without tool call or no text output",
        );
      }
    } on FirebaseAISdkException catch (e) {
      if (_isRunCancelled(runToken)) return;
      dev.log('AI SDK ERROR: ${e.message}');
      _messages.add(
        AiChatMessage(
          id: _uuid.v4(),
          role: AiChatRole.assistant,
          text:
              'The assistant service had a temporary problem. Please try again.',
        ),
      );
    } catch (e) {
      if (_isRunCancelled(runToken)) return;
      dev.log('AI GENERAL ERROR: $e');
      _messages.add(
        AiChatMessage(
          id: _uuid.v4(),
          role: AiChatRole.assistant,
          text: 'I could not complete that request due to an internal error.',
        ),
      );
    } finally {
      if (!_isRunCancelled(runToken)) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  bool _looksLikeGenericFailure(String text) {
    final lower = text.toLowerCase();
    return lower.contains('did not get a usable result') ||
        lower.contains('could not render this response correctly') ||
        lower.contains('could not find usable data for that request') ||
        lower.contains('could not find any data to show for that request') ||
        lower.contains('unable to render');
  }

  String? _responseFromSuccessfulTools(
    String userText,
    List<AiToolEnvelope> successfulToolResults,
  ) {
    for (var i = successfulToolResults.length - 1; i >= 0; i--) {
      final toolResult = successfulToolResults[i];
      final markdown = toolResult.markdownFallback.trim();
      if (markdown.isNotEmpty) {
        dev.log(
          'AI RESPONSE GENERATED: from tool data tool=${toolResult.tool}',
        );
        return markdown;
      }

      final fallback = AnalyticsMarkdownFallbackRenderer.render(
        toolData: toolResult.data,
      );
      if (fallback != null && fallback.trim().isNotEmpty) {
        dev.log(
          'AI RESPONSE GENERATED: from fallback renderer tool=${toolResult.tool}',
        );
        return fallback;
      }

      if (toolResult.message.trim().isNotEmpty) {
        dev.log(
          'AI RESPONSE GENERATED: from tool message tool=${toolResult.tool}',
        );
        return toolResult.message.trim();
      }
    }
    return null;
  }

  Future<bool> _tryHandleActivityInfoQuestion(
    String userText, {
    required int runToken,
    required String runSessionId,
  }) async {
    final queryType = _detectActivityInfoQueryType(userText);
    if (queryType == null) return false;

    final activityName = _extractActivityNameFromQuestion(userText);
    final selectedName = _appContext['selectedActivityName']?.toString();
    final query = (activityName?.trim().isNotEmpty ?? false)
        ? activityName!.trim()
        : (selectedName?.trim().isNotEmpty ?? false
              ? selectedName!.trim()
              : null);
    if (query == null || query.isEmpty) return false;

    dev.log('TOOL ROUTING: direct activity info flow query="$query"');

    final searchStatusId = _emitToolStatus(
      toolName: AiToolNames.searchActivities,
      status: 'running',
      message: 'Searching activities...',
      args: {'query': query},
    );
    final searchResult = await _guardedToolCall(
      AiToolNames.searchActivities,
      {'query': query},
      sessionId: runSessionId,
      isCancelled: () => _isRunCancelled(runToken),
    );
    _updateToolStatusById(
      searchStatusId,
      status: searchResult.success ? 'success' : 'failed',
      message: searchResult.message.isEmpty
          ? (searchResult.success ? 'Search completed.' : 'Search failed.')
          : searchResult.message,
      envelope: searchResult,
    );
    if (_isRunCancelled(runToken)) return true;
    if (!searchResult.success) return false;

    final rawMatches = searchResult.data['matches'];
    final matches = rawMatches is List
        ? rawMatches
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
        : <Map<String, dynamic>>[];

    if (matches.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: _uuid.v4(),
          role: AiChatRole.assistant,
          text: 'No activity found matching "$query".',
        ),
      );
      return true;
    }

    if (matches.length > 1) {
      final options = matches
          .take(5)
          .map((m) => '- ${m['name'] ?? m['id']}')
          .join('\n');
      _messages.add(
        AiChatMessage(
          id: _uuid.v4(),
          role: AiChatRole.assistant,
          text:
              'I found multiple activities matching "$query". Which one do you mean?\n$options',
        ),
      );
      return true;
    }

    final id = matches.first['id']?.toString();
    if (id == null || id.isEmpty) return false;

    final getByIdStatusId = _emitToolStatus(
      toolName: AiToolNames.getActivityById,
      status: 'running',
      message: 'Loading activity details...',
      args: {'activityId': id},
    );
    final detailResult = await _guardedToolCall(
      AiToolNames.getActivityById,
      {'activityId': id},
      sessionId: runSessionId,
      isCancelled: () => _isRunCancelled(runToken),
    );
    _updateToolStatusById(
      getByIdStatusId,
      status: detailResult.success ? 'success' : 'failed',
      message: detailResult.message.isEmpty
          ? (detailResult.success
                ? 'Details loaded.'
                : 'Failed to load activity details.')
          : detailResult.message,
      envelope: detailResult,
    );
    if (_isRunCancelled(runToken)) return true;
    if (!detailResult.success) return false;

    final activity = detailResult.data['activity'];
    if (activity is! Map) return false;
    final activityData = Map<String, dynamic>.from(activity);
    final response = _buildActivityInfoResponse(
      queryType: queryType,
      activityData: activityData,
    );
    if (response == null) return false;

    dev.log(
      'AI RESPONSE GENERATED: from tool data queryType=$queryType activityId=$id',
    );
    _messages.add(
      AiChatMessage(id: _uuid.v4(), role: AiChatRole.assistant, text: response),
    );
    return true;
  }

  String? _detectActivityInfoQueryType(String text) {
    final lower = text.toLowerCase();
    if (RegExp(
      r'\b(details|detail|info|information|summary|about)\b',
    ).hasMatch(lower)) {
      return 'details';
    }
    if (RegExp(r'\b(created|when was|origin date)\b').hasMatch(lower)) {
      return 'created_at';
    }
    if (RegExp(r'\b(total time|time spent|duration)\b').hasMatch(lower)) {
      return 'duration';
    }
    if (RegExp(r'\bstatus\b').hasMatch(lower)) {
      return 'status';
    }
    return null;
  }

  String? _extractActivityNameFromQuestion(String text) {
    final cleaned = text.trim().replaceAll('\n', ' ');
    final directPatterns = <RegExp>[
      RegExp(r'show me details of (.+)', caseSensitive: false),
      RegExp(r'show details of (.+)', caseSensitive: false),
      RegExp(r'details of (.+)', caseSensitive: false),
      RegExp(r'info(?:rmation)? (?:about|for) (.+)', caseSensitive: false),
      RegExp(r'when was (.+?) activity created', caseSensitive: false),
      RegExp(r'when was (.+?) created', caseSensitive: false),
      RegExp(r'origin date for (.+)', caseSensitive: false),
      RegExp(r'total time spent on (.+)', caseSensitive: false),
      RegExp(r'status of (.+)', caseSensitive: false),
    ];
    for (final pattern in directPatterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    if (cleaned.contains('.')) {
      final first = cleaned.split('.').first.trim();
      if (first.isNotEmpty && first.length > 2) return first;
    }

    if (RegExp(r'\bthis activity\b', caseSensitive: false).hasMatch(cleaned)) {
      return _appContext['selectedActivityName']?.toString();
    }
    return null;
  }

  String? _buildActivityInfoResponse({
    required String queryType,
    required Map<String, dynamic> activityData,
  }) {
    final name = activityData['name']?.toString() ?? 'This activity';
    if (queryType == 'details') {
      return _activityMarkdownSummary(activityData);
    }
    if (queryType == 'created_at') {
      final createdAt = activityData['createdAt']?.toString();
      if (createdAt == null || createdAt.isEmpty) return null;
      return '$name was created on $createdAt.';
    }
    if (queryType == 'duration') {
      final durationHuman = activityData['durationHuman']?.toString();
      if (durationHuman != null && durationHuman.isNotEmpty) {
        return '$name total time spent: $durationHuman.';
      }
      final secondsRaw =
          activityData['durationSeconds'] ?? activityData['totalSeconds'];
      final seconds = secondsRaw is num
          ? secondsRaw.toInt()
          : int.tryParse(secondsRaw?.toString() ?? '');
      if (seconds == null) return null;
      return '$name total time spent: ${_formatSeconds(seconds)}.';
    }
    if (queryType == 'status') {
      final status = activityData['status']?.toString();
      if (status == null || status.isEmpty) return null;
      return '$name is currently $status.';
    }
    return null;
  }

  Map<String, dynamic> _activityToolData(Activity activity) {
    final totalDurationSeconds =
        _localGetEffectiveSeconds?.call(activity.id) ?? activity.totalSeconds;
    final totalCount = _localGetCountTotal?.call(activity.id);
    final status = activity.status.name;
    return {
      ...activity.toJson(),
      'id': activity.id,
      'name': activity.name,
      'status': status,
      'type': activity.type.name,
      'durationSeconds': totalDurationSeconds,
      'durationHuman': _formatSeconds(totalDurationSeconds),
      'totalCount': totalCount,
      'countInfo': totalCount,
      'createdAt': activity.createdAt.toIso8601String(),
      'updatedAt': activity.updatedAt.toIso8601String(),
      'completedAt': status == 'completed'
          ? activity.updatedAt.toIso8601String()
          : null,
    };
  }

  String _activityMarkdownSummary(Map<String, dynamic> activityData) {
    final name = activityData['name']?.toString() ?? 'Activity';
    final status = activityData['status']?.toString() ?? 'unknown';
    final type = activityData['type']?.toString() ?? 'unknown';
    final duration =
        activityData['durationHuman']?.toString() ??
        _formatSeconds((activityData['durationSeconds'] as num?)?.toInt() ?? 0);
    final createdAt = activityData['createdAt']?.toString() ?? 'unknown';
    final updatedAt = activityData['updatedAt']?.toString() ?? 'unknown';
    final totalCount = activityData['totalCount'];
    final countLine = totalCount != null ? '\n- Total Count: $totalCount' : '';
    return [
      '## Activity Summary: $name',
      '',
      '- Status: $status',
      '- Type: $type',
      '- Total Time: $duration$countLine',
      '- Created At: $createdAt',
      '- Updated At: $updatedAt',
    ].join('\n');
  }

  bool _consumeAssistantResponse(
    String text, {
    List<AiToolEnvelope> successfulToolResults = const [],
  }) {
    final parsedBlocks = _parseResponseBlocks(text);
    var emittedTypedBlock = false;

    for (final block in parsedBlocks) {
      final type = block['type']?.toString();
      if (type == 'text') {
        final plain = block['text']?.toString().trim() ?? '';
        if (plain.isNotEmpty) {
          if (_looksLikeGenericFailure(plain) &&
              successfulToolResults.isNotEmpty) {
            continue;
          }
          _messages.add(
            AiChatMessage(
              id: _uuid.v4(),
              role: AiChatRole.assistant,
              text: plain,
            ),
          );
          emittedTypedBlock = true;
        }
      } else if (type == 'tool_status') {
        final tool = block['tool']?.toString() ?? 'tool';
        final status = _sanitizeToolState(
          block['status']?.toString() ?? 'failed',
        );
        final message = block['message']?.toString() ?? '';
        _emitToolStatus(
          toolName: tool,
          status: status,
          message: message,
          args: const {},
        );
        emittedTypedBlock = true;
      } else if (type == 'analytics_widget') {
        final widget = block['widget'];
        if (widget is Map<String, dynamic>) {
          _emitAnalyticsResult(
            widgetPayload: widget,
            invalidReason: 'invalid analytics_widget payload',
          );
          emittedTypedBlock = true;
        }
      }
    }

    if (!emittedTypedBlock) {
      final emittedWidget = _tryParseAndEmitWidgetFromText(text);
      if (emittedWidget) {
        emittedTypedBlock = true;
      }
      final cleanText = _stripJsonBlock(text);
      if (cleanText.isNotEmpty) {
        if (_looksLikeGenericFailure(cleanText) &&
            successfulToolResults.isNotEmpty) {
          final recovered = _responseFromSuccessfulTools(
            cleanText,
            successfulToolResults,
          );
          if (recovered != null) {
            dev.log('CHAT RESPONSE FALLBACK: generic cleanText replaced');
            _messages.add(
              AiChatMessage(
                id: _uuid.v4(),
                role: AiChatRole.assistant,
                text: recovered,
              ),
            );
            emittedTypedBlock = true;
          }
        } else {
          _messages.add(
            AiChatMessage(
              id: _uuid.v4(),
              role: AiChatRole.assistant,
              text: cleanText,
            ),
          );
          emittedTypedBlock = true;
        }
      } else if (!emittedWidget && text.contains('{') && text.contains('}')) {
        // The model returned JSON-ish content we could not map to a widget.
        // Try to recover a markdown summary from any parseable object before
        // falling back to an honest message.
        final recovered = _recoverMarkdownFromText(text);
        if (recovered != null) {
          dev.log('CHAT RESPONSE FALLBACK: empty content recovered');
          _messages.add(
            AiChatMessage(
              id: _uuid.v4(),
              role: AiChatRole.assistant,
              text: recovered,
            ),
          );
          emittedTypedBlock = true;
        } else {
          if (successfulToolResults.isNotEmpty) {
            final toolRecovered = _responseFromSuccessfulTools(
              text,
              successfulToolResults,
            );
            if (toolRecovered != null) {
              dev.log('TOOL FALLBACK: rendering markdown from tool result');
              _messages.add(
                AiChatMessage(
                  id: _uuid.v4(),
                  role: AiChatRole.assistant,
                  text: toolRecovered,
                ),
              );
              emittedTypedBlock = true;
            }
          }
          if (!emittedTypedBlock) {
            dev.log('CHAT RESPONSE FALLBACK: no usable content in response');
            _messages.add(
              AiChatMessage(
                id: _uuid.v4(),
                role: AiChatRole.assistant,
                text: 'I could not find usable data for that request.',
              ),
            );
          }
        }
      }
    }
    return emittedTypedBlock;
  }

  /// Attempts to build a markdown summary from any JSON object embedded in the
  /// model's text response, even when it is not a recognised widget block.
  String? _recoverMarkdownFromText(String text) {
    final candidates = <Map<String, dynamic>>[];
    candidates.addAll(_parseResponseBlocks(text));

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      try {
        final parsed = jsonDecode(text.substring(start, end + 1));
        if (parsed is Map<String, dynamic>) candidates.add(parsed);
      } catch (_) {
        // ignore unparseable fragment
      }
    }

    for (final candidate in candidates) {
      final widget = candidate['widget'];
      final widgetPayload = widget is Map<String, dynamic>
          ? widget
          : (candidate.containsKey('widgetType') ? candidate : null);
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: widgetPayload,
        toolData: candidate['data'] is Map<String, dynamic>
            ? candidate['data'] as Map<String, dynamic>
            : candidate,
      );
      if (md != null && md.trim().isNotEmpty) return md;
    }
    return null;
  }

  List<Map<String, dynamic>> _parseResponseBlocks(String text) {
    final blocks = <Map<String, dynamic>>[];
    final codeBlockRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    for (final match in codeBlockRegex.allMatches(text)) {
      final candidate = match.group(1);
      if (candidate == null) continue;
      try {
        final parsed = jsonDecode(candidate);
        if (parsed is Map<String, dynamic>) {
          blocks.add(parsed);
        }
      } catch (_) {
        dev.log('WIDGET VALIDATION FAILED: malformed json block');
      }
    }
    return blocks;
  }

  /// Returns true when an analytics block (widget or markdown fallback) was
  /// emitted from the response text.
  bool _tryParseAndEmitWidgetFromText(String text) {
    final jsonRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final match = jsonRegex.firstMatch(text);
    String? jsonText = match?.group(1);
    if (jsonText == null) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        jsonText = text.substring(start, end + 1);
      }
    }

    if (jsonText == null) return false;

    try {
      final parsed = jsonDecode(jsonText);
      if (parsed is Map<String, dynamic> &&
          parsed['type'] == 'analytics_widget') {
        final widget = parsed['widget'];
        if (widget is Map<String, dynamic>) {
          _emitAnalyticsResult(
            widgetPayload: widget,
            invalidReason: 'invalid widgetType in text response',
          );
          return true;
        }
      }
    } catch (e) {
      dev.log('WIDGET RENDER EXCEPTION: $e');
    }
    return false;
  }

  String _stripJsonBlock(String text) {
    final jsonRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final clean = text.replaceAll(jsonRegex, '').trim();
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

  Future<AiToolEnvelope> _guardedToolCall(
    String toolName,
    Map<String, dynamic> args, {
    required String sessionId,
    bool Function()? isCancelled,
    void Function(String status, String message)? onStatus,
  }) async {
    if (isCancelled?.call() == true) {
      return AiToolEnvelope.failure(
        tool: toolName,
        errorCode: AiToolErrorCodes.invalidState,
        message: 'Request was halted.',
      );
    }
    final localActivities =
        _localActivitiesProvider?.call() ?? const <String, Activity>{};
    final handoff = _handoffManager.resolve(
      tool: toolName,
      args: args,
      appContext: _appContext,
      activities: localActivities,
    );
    dev.log('TOOL PARAMS RESOLVED: ${handoff.resolvedArgs}');

    if (!handoff.isReady) {
      final missing = handoff.missingRequired.join(', ');
      return AiToolEnvelope.failure(
        tool: toolName,
        errorCode: AiToolErrorCodes.missingParameter,
        message: _clarificationForMissing(
          toolName,
          handoff.missingRequired,
          fallback: missing,
        ),
      );
    }

    final normalizedArgs = handoff.resolvedArgs;

    // Run analytics tools locally first and only send compact summaries.
    final isAnalytics =
        toolName == AiToolNames.compareCounts ||
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
      if (local != null) return _normalizeEnvelope(toolName, local);
      if (isCancelled?.call() == true) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.invalidState,
          message: 'Request was halted.',
        );
      }
    }

    var res = await _dispatcher.call(
      toolName,
      normalizedArgs,
      sessionId: sessionId,
    );
    res = _normalizeEnvelope(toolName, res);

    final errorCode = res.errorCode ?? res.error?.code;
    if (!res.success &&
        (errorCode == AiToolErrorCodes.missingParameter ||
            errorCode == AiToolErrorCodes.notFound)) {
      onStatus?.call('retrying', 'Recovering after ${errorCode ?? 'error'}...');
      dev.log('TOOL RETRY: $toolName after parameter acquisition');
      final retryArgs = Map<String, dynamic>.from(normalizedArgs);
      if (errorCode == AiToolErrorCodes.notFound &&
          !_hasActivityId(retryArgs)) {
        final retryHandoff = _handoffManager.resolve(
          tool: toolName,
          args: retryArgs,
          appContext: _appContext,
          activities: localActivities,
        );
        retryArgs.addAll(retryHandoff.resolvedArgs);
      }
      final localRetry = await _tryLocalFallback(toolName, retryArgs);
      if (localRetry != null) {
        return _normalizeEnvelope(toolName, localRetry);
      }
      final retryRes = await _dispatcher.call(
        toolName,
        retryArgs,
        sessionId: sessionId,
      );
      return _normalizeEnvelope(toolName, retryRes);
    }

    return res;
  }

  bool _hasActivityId(Map<String, dynamic> args) {
    final value = args['activityId'];
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    return true;
  }

  AiToolEnvelope _normalizeEnvelope(String toolName, AiToolEnvelope raw) {
    final tool = raw.tool.isEmpty || raw.tool == 'unknown_tool'
        ? toolName
        : raw.tool;
    final code = raw.errorCode ?? raw.error?.code;
    final fallback = raw.markdownFallback.trim().isNotEmpty
        ? raw.markdownFallback.trim()
        : (AnalyticsMarkdownFallbackRenderer.render(toolData: raw.data) ?? '');
    return AiToolEnvelope(
      success: raw.success,
      tool: tool,
      data: raw.data,
      message: raw.message,
      markdownFallback: fallback,
      errorCode: raw.success ? null : (code ?? AiToolErrorCodes.internalError),
      action: raw.action ?? toolName,
      activityId: raw.activityId,
      activityName: raw.activityName,
      error: raw.error,
    );
  }

  void _emitWidgetIfPresent(AiToolEnvelope envelope) {
    if (!envelope.success) return;
    final widgetPayload = envelope.data['widgetPayload'];
    final payload = widgetPayload is Map
        ? Map<String, dynamic>.from(widgetPayload)
        : null;

    // Only emit a dedicated analytics block when there is an actual widget
    // payload. Plain data-query tool results are summarised by the model.
    if (payload == null) return;

    _emitAnalyticsResult(
      widgetPayload: payload,
      toolData: envelope.data,
      invalidReason: 'invalid tool widget payload',
    );
  }

  /// Emits the best available representation of an analytics result:
  /// 1. a valid widget (with markdown fallback embedded for render-time safety),
  /// 2. else markdown derived from the widget payload or raw tool data,
  /// 3. else a short honest failure message.
  void _emitAnalyticsResult({
    Map<String, dynamic>? widgetPayload,
    Map<String, dynamic>? toolData,
    required String invalidReason,
  }) {
    final fallbackMarkdown = AnalyticsMarkdownFallbackRenderer.render(
      widgetPayload: widgetPayload,
      toolData: toolData,
    );

    if (widgetPayload != null && _isValidWidgetPayload(widgetPayload)) {
      final type = widgetPayload['widgetType']?.toString() ?? 'unknown';
      dev.log('WIDGET RENDER START: $type');
      final payload = Map<String, dynamic>.from(widgetPayload);
      if (fallbackMarkdown != null) {
        payload['__fallbackMarkdown'] = fallbackMarkdown;
      }
      _messages.add(
        AiChatMessage(
          id: _uuid.v4(),
          role: AiChatRole.analytics,
          text: '',
          payload: payload,
        ),
      );
      notifyListeners();
      return;
    }

    dev.log('WIDGET VALIDATION FAILED: reason=$invalidReason');

    if (fallbackMarkdown != null) {
      _messages.add(
        AiChatMessage(
          id: _uuid.v4(),
          role: AiChatRole.assistant,
          text: fallbackMarkdown,
        ),
      );
      notifyListeners();
      return;
    }

    dev.log('CHAT RESPONSE FALLBACK: no usable analytics data');
    _messages.add(
      AiChatMessage(
        id: _uuid.v4(),
        role: AiChatRole.assistant,
        text: 'I could not find any data to show for that request.',
      ),
    );
    notifyListeners();
  }

  String _classifyIntent(String text) {
    final lower = text.toLowerCase();
    if (RegExp(
      r'\b(compare|trend|analytics|summary|chart|rank|leaderboard)\b',
    ).hasMatch(lower)) {
      return 'analytics_query';
    }
    if (RegExp(
      r'\b(pause|resume|finish|complete|delete|rename|move|create|add)\b',
    ).hasMatch(lower)) {
      return 'activity_action';
    }
    return 'data_query';
  }

  String _emitToolStatus({
    required String toolName,
    required String status,
    required String message,
    required Map<String, dynamic> args,
  }) {
    final normalized = _sanitizeToolState(status);
    final id = _uuid.v4();
    _messages.add(
      AiChatMessage(
        id: id,
        role: AiChatRole.tool,
        text: message,
        payload: {
          'name': toolName,
          'status': normalized,
          'args': args,
          'message': message,
        },
      ),
    );
    notifyListeners();
    return id;
  }

  void _updateToolStatusById(
    String id, {
    required String status,
    required String message,
    AiToolEnvelope? envelope,
  }) {
    final normalized = _sanitizeToolState(status);
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.id != id || m.role != AiChatRole.tool) continue;
      final payload = Map<String, dynamic>.from(
        m.payload ?? const <String, dynamic>{},
      );
      payload['status'] = normalized;
      payload['message'] = message;
      if (envelope != null) {
        payload['result'] = envelope.toJson();
      }
      _messages[i] = AiChatMessage(
        id: m.id,
        role: m.role,
        text: message,
        payload: payload,
      );
      notifyListeners();
      return;
    }
  }

  String _sanitizeToolState(String status) {
    if (_toolStates.contains(status)) return status;
    return 'failed';
  }

  String _canonicalToolName(String toolName) {
    const aliases = <String, String>{
      'getActivityByld': AiToolNames.getActivityById,
      'getActivityByID': AiToolNames.getActivityById,
      'searchActivity': AiToolNames.searchActivities,
      'finishThisActivity': AiToolNames.finishActivity,
    };
    final canonical = aliases[toolName] ?? toolName;
    if (canonical != toolName) {
      dev.log('TOOL ROUTING: normalized $toolName -> $canonical');
    }
    return canonical;
  }

  bool _isValidWidgetPayload(Map<String, dynamic> payload) {
    final type = payload['widgetType']?.toString();
    if (type == null || type.trim().isEmpty) return false;
    if ((payload['title']?.toString().trim().isEmpty ?? true)) return false;
    final data = payload['data'];
    if (type == 'metric_card') {
      return (payload['value']?.toString().trim().isNotEmpty ?? false);
    }
    if (type == 'leaderboard' || type == 'comparison_summary') {
      return payload['items'] is List && (payload['items'] as List).isNotEmpty;
    }
    if (type == 'donut_chart') {
      return data is List && data.isNotEmpty;
    }
    if (type == 'bar_chart' || type == 'line_chart') {
      if (data is! Map<String, dynamic>) return false;
      final labels = data['labels'];
      final series = data['series'];
      return labels is List &&
          labels.isNotEmpty &&
          series is List &&
          series.isNotEmpty;
    }
    return true;
  }

  String _clarificationForMissing(
    String tool,
    List<String> missing, {
    required String fallback,
  }) {
    if (missing.contains('activityId')) {
      return switch (tool) {
        AiToolNames.pauseActivity => 'Which activity should I pause?',
        AiToolNames.resumeActivity => 'Which activity should I resume?',
        AiToolNames.finishActivity => 'Which activity should I finish?',
        AiToolNames.deleteActivity => 'Which activity should I delete?',
        _ => 'Which activity should I use?',
      };
    }
    return 'Missing required parameter(s): $fallback';
  }

  bool _isRunCancelled(int token) {
    return _haltRequested || token != _activeRunToken;
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

  Future<AiToolEnvelope?> _tryLocalFallback(
    String toolName,
    Map<String, dynamic> args,
  ) async {
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
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'No activity is currently selected.',
        );
      }
      final a = map[id];
      if (a == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.notFound,
          message: 'Selected activity not found.',
        );
      }
      final activityData = _activityToolData(a);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        tool: toolName,
        activityId: a.id,
        activityName: a.name,
        data: {'activity': activityData},
        message: 'Selected activity loaded.',
        markdownFallback: _activityMarkdownSummary(activityData),
      );
    }

    if (toolName == AiToolNames.getActiveActivities) {
      final active = map.values
          .where((a) => a.status == ActivityStatus.running)
          .toList();
      return AiToolEnvelope(
        success: true,
        action: toolName,
        data: {
          'activities': active
              .map(
                (a) => {
                  ...a.toJson(),
                  'totalDuration': _localGetEffectiveSeconds?.call(a.id),
                  'totalCount': _localGetCountTotal?.call(a.id),
                },
              )
              .toList(),
        },
      );
    }

    if (toolName == AiToolNames.getActivityById) {
      final id = args['activityId']?.toString();
      final a = map[id];
      if (a == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.notFound,
          message: 'Activity not found.',
        );
      }
      final activityData = _activityToolData(a);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        tool: toolName,
        activityId: a.id,
        activityName: a.name,
        data: {'activity': activityData},
        message: 'Activity details loaded successfully.',
        markdownFallback: _activityMarkdownSummary(activityData),
      );
    }

    if (toolName == AiToolNames.searchActivities) {
      final q = args['query']?.toString().toLowerCase() ?? '';
      final matches = map.values
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.description.toLowerCase().contains(q),
          )
          .take(10)
          .toList();
      final matchesData = matches
          .map((a) => _activityToolData(a))
          .toList(growable: false);
      final markdown = matchesData.isEmpty
          ? 'No activity matched your search.'
          : [
              '## Search Results',
              '',
              ...matchesData.map((m) => '- ${m['name']} (${m['status']})'),
            ].join('\n');
      return AiToolEnvelope(
        success: true,
        action: toolName,
        tool: toolName,
        data: {'matches': matchesData},
        message: matchesData.isEmpty
            ? 'No matching activities found.'
            : 'Found ${matchesData.length} matching activities.',
        markdownFallback: markdown,
      );
    }

    if (toolName == AiToolNames.getTodaySummary) {
      final summary = _appContext['todaySummary'] ?? {};
      return AiToolEnvelope(
        success: true,
        action: toolName,
        data: {'summary': summary},
      );
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
      if (id == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing activityId.',
        );
      }
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
      if (id == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing activityId.',
        );
      }
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
      if (id == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing activityId.',
        );
      }
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
      if (id == null || newName == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing arguments.',
        );
      }
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
      if (id == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing activityId.',
        );
      }
      await _localMoveActivity(id, newParentId);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: id,
        message: 'Activity moved successfully.',
      );
    }

    if (toolName == AiToolNames.deleteActivity) {
      if (_localDeleteActivity == null) return null;
      final id = args['activityId']?.toString();
      if (id == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing activityId.',
        );
      }
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
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw?.toString() ?? '0');
      if (id == null || amount == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing arguments.',
        );
      }
      await _localAddCount(id, amount);
      return AiToolEnvelope(
        success: true,
        action: toolName,
        activityId: id,
        message: 'Added $amount to activity.',
      );
    }

    if (toolName == AiToolNames.getActivityAnalytics) {
      final id = args['activityId']?.toString();
      if (id == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.missingParameter,
          message: 'Missing activityId.',
        );
      }
      final a = map[id];
      if (a == null) {
        return AiToolEnvelope.failure(
          tool: toolName,
          errorCode: AiToolErrorCodes.notFound,
          message: 'Activity not found.',
        );
      }

      final startDateStr = args['startDate']?.toString();
      final endDateStr = args['endDate']?.toString();
      final start = startDateStr != null
          ? DateTime.tryParse(startDateStr)
          : null;
      final end = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      if (a.type == ActivityType.countBased) {
        if (_localGetCountRecords == null) return null;
        var records = await _localGetCountRecords(id);
        if (start != null) {
          records = records.where((r) => r.timestamp.isAfter(start)).toList();
        }
        if (end != null) {
          records = records.where((r) => r.timestamp.isBefore(end)).toList();
        }

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
        if (start != null) {
          events = events.where((e) => e.timestamp.isAfter(start)).toList();
        }
        if (end != null) {
          events = events.where((e) => e.timestamp.isBefore(end)).toList();
        }

        final totalSeconds = events.fold<int>(
          0,
          (sum, e) => sum + e.durationDelta,
        );
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

  Future<AiToolEnvelope> _handleCompareCounts(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
    dev.log("LOCAL ANALYTICS TOOL: compareCounts");
    final periodA = args['periodA']?.toString() ?? 'this_week';
    final periodB = args['periodB']?.toString() ?? 'last_week';

    final (startA, endA) = _parsePeriodRange(periodA);
    final (startB, endB) = _parsePeriodRange(periodB);

    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];
    final countActivities = map.values
        .where((a) => a.type == ActivityType.countBased)
        .toList();

    final activitiesList = <Map<String, dynamic>>[];

    for (final a in countActivities) {
      final curVal = allCountRecords
          .where(
            (r) =>
                r.activityId == a.id &&
                r.timestamp.isAfter(startA) &&
                r.timestamp.isBefore(endA),
          )
          .fold<double>(0, (s, r) => s + r.value);
      final prevVal = allCountRecords
          .where(
            (r) =>
                r.activityId == a.id &&
                r.timestamp.isAfter(startB) &&
                r.timestamp.isBefore(endB),
          )
          .fold<double>(0, (s, r) => s + r.value);

      if (curVal == 0 && prevVal == 0) continue;

      activitiesList.add({
        'name': a.name,
        'current': curVal.round(),
        'previous': prevVal.round(),
        'difference': (curVal - prevVal).round(),
      });
    }

    dev.log(
      "ANALYTICS REDUCTION: compareCounts reduced ${allCountRecords.length} records to ${activitiesList.length} compared activities",
    );

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.compareCounts,
      data: {'activities': activitiesList},
    );
  }

  // ---------------------------------------------------------------------------
  // 2️⃣ getTimeAllocation(period)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetTimeAllocation(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
    dev.log("LOCAL ANALYTICS TOOL: getTimeAllocation");
    final period = args['period']?.toString() ?? 'this_week';
    final (start, end) = _parsePeriodRange(period);

    final allEvents = await _localGetAllEvents?.call() ?? [];

    final categoryTotals = <String, int>{};
    for (final e in allEvents) {
      if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
        categoryTotals[e.activityId] =
            (categoryTotals[e.activityId] ?? 0) + e.durationDelta;
      }
    }

    final categoriesList = <Map<String, dynamic>>[];
    for (final entry in categoryTotals.entries) {
      final a = map[entry.key];
      if (a != null && entry.value > 0) {
        categoriesList.add({'label': a.name, 'seconds': entry.value});
      }
    }

    categoriesList.sort(
      (a, b) => (b['seconds'] as int).compareTo(a['seconds'] as int),
    );
    dev.log(
      "ANALYTICS REDUCTION: getTimeAllocation reduced ${allEvents.length} events to ${categoriesList.length} category sums",
    );

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getTimeAllocation,
      data: {'categories': categoriesList},
    );
  }

  // ---------------------------------------------------------------------------
  // 3️⃣ getTrend(metric, period, granularity)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetTrend(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
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
      dev.log(
        "ANALYTICS REDUCTION: getTrend count reduced ${allCountRecords.length} records",
      );
    } else {
      for (final e in allEvents) {
        if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
          final key = '${e.timestamp.month}/${e.timestamp.day}';
          dataPoints[key] = (dataPoints[key] ?? 0) + e.durationDelta;
        }
      }
      dev.log(
        "ANALYTICS REDUCTION: getTrend duration reduced ${allEvents.length} events",
      );
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
      data: {'labels': labels, 'values': values},
    );
  }

  // ---------------------------------------------------------------------------
  // 4️⃣ getLeaderboard(period)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetLeaderboard(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
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
        timeTotals[e.activityId] =
            (timeTotals[e.activityId] ?? 0) + e.durationDelta;
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
        return double.parse(
          b['value'] as String,
        ).compareTo(double.parse(a['value'] as String));
      }
    });

    dev.log(
      "ANALYTICS REDUCTION: getLeaderboard reduced ${allEvents.length} events and ${allCountRecords.length} records into ${items.length} rankings",
    );

    return AiToolEnvelope(
      success: true,
      action: AiToolNames.getLeaderboard,
      data: {'items': items},
    );
  }

  // ---------------------------------------------------------------------------
  // 5️⃣ getProductivitySummary(period)
  // ---------------------------------------------------------------------------

  Future<AiToolEnvelope> _handleGetProductivitySummary(
    Map<String, dynamic> args,
    Map<String, Activity> map,
  ) async {
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
        .where(
          (a) =>
              a.status == ActivityStatus.completed &&
              a.updatedAt.isAfter(start) &&
              a.updatedAt.isBefore(end),
        )
        .length;

    // Top activity determination
    final timeTotals = <String, int>{};
    for (final e in allEvents) {
      if (e.timestamp.isAfter(start) && e.timestamp.isBefore(end)) {
        timeTotals[e.activityId] =
            (timeTotals[e.activityId] ?? 0) + e.durationDelta;
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

    dev.log(
      "ANALYTICS REDUCTION: getProductivitySummary consolidated ${allEvents.length} events and ${allCountRecords.length} records into productivity summary",
    );

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
    final filterIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toSet()
        : null;

    final (curStart, curEnd) = _parsePeriodRange(currentPeriod);
    final (prevStart, prevEnd) = _parsePeriodRange(previousPeriod);

    final allCountRecords = await _localGetAllCountRecords?.call() ?? [];
    final allEvents = await _localGetAllEvents?.call() ?? [];

    final activities = map.values.where((a) {
      if (filterIds != null && !filterIds.contains(a.id)) return false;
      return true;
    }).toList();

    if (activities.isEmpty) {
      return AiToolEnvelope.failure(
        tool: AiToolNames.compareActivityAnalytics,
        errorCode: AiToolErrorCodes.notFound,
        message: 'No matching activities found.',
      );
    }

    final comparisonItems = <Map<String, dynamic>>[];

    for (final a in activities) {
      final useCount =
          metric == 'count' ||
          (metric == null && a.type == ActivityType.countBased);
      final useDuration =
          metric == 'duration' ||
          (metric == null && a.type != ActivityType.countBased);

      if (useCount && a.type == ActivityType.countBased) {
        final curRecords = allCountRecords
            .where(
              (r) =>
                  r.activityId == a.id &&
                  r.timestamp.isAfter(curStart) &&
                  r.timestamp.isBefore(curEnd),
            )
            .toList();
        final prevRecords = allCountRecords
            .where(
              (r) =>
                  r.activityId == a.id &&
                  r.timestamp.isAfter(prevStart) &&
                  r.timestamp.isBefore(prevEnd),
            )
            .toList();

        final curVal = curRecords.fold<double>(0, (s, r) => s + r.value);
        final prevVal = prevRecords.fold<double>(0, (s, r) => s + r.value);

        if (curVal == 0 && prevVal == 0) continue;

        final diff = curVal - prevVal;
        final trend = diff > 0
            ? 'up'
            : diff < 0
            ? 'down'
            : 'neutral';

        comparisonItems.add({
          'label': a.name,
          'current': curVal.toStringAsFixed(0),
          'previous': prevVal.toStringAsFixed(0),
          'difference': diff >= 0
              ? '+${diff.toStringAsFixed(0)}'
              : diff.toStringAsFixed(0),
          'trend': trend,
        });
      } else if (useDuration) {
        final curSecs = allEvents
            .where(
              (e) =>
                  e.activityId == a.id &&
                  e.timestamp.isAfter(curStart) &&
                  e.timestamp.isBefore(curEnd),
            )
            .fold<int>(0, (s, e) => s + e.durationDelta);
        final prevSecs = allEvents
            .where(
              (e) =>
                  e.activityId == a.id &&
                  e.timestamp.isAfter(prevStart) &&
                  e.timestamp.isBefore(prevEnd),
            )
            .fold<int>(0, (s, e) => s + e.durationDelta);

        if (curSecs == 0 && prevSecs == 0) continue;

        final diff = curSecs - prevSecs;
        final trend = diff > 0
            ? 'up'
            : diff < 0
            ? 'down'
            : 'neutral';

        comparisonItems.add({
          'label': a.name,
          'current': _formatSeconds(curSecs),
          'previous': _formatSeconds(prevSecs),
          'difference': diff >= 0
              ? '+${_formatSeconds(diff.abs())}'
              : '-${_formatSeconds(diff.abs())}',
          'trend': trend,
        });
      }
    }

    dev.log(
      "AI ANALYTICS TOOL RESULT: compareActivityAnalytics records=${comparisonItems.length}",
    );

    if (comparisonItems.isEmpty) {
      return AiToolEnvelope.failure(
        tool: AiToolNames.compareActivityAnalytics,
        errorCode: AiToolErrorCodes.emptyResult,
        message: 'No activity data found for the selected periods.',
        data: {'comparisonItems': const []},
      );
    }

    final widgetPayload = {
      'widgetType': 'comparison_summary',
      'title':
          '${_periodLabel(currentPeriod)} vs ${_periodLabel(previousPeriod)}',
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

    final countActivities = map.values
        .where((a) => a.type == ActivityType.countBased)
        .toList();

    final results = <Map<String, dynamic>>[];
    for (final a in countActivities) {
      final total = allCountRecords
          .where(
            (r) =>
                r.activityId == a.id &&
                r.timestamp.isAfter(start) &&
                r.timestamp.isBefore(end),
          )
          .fold<double>(0, (s, r) => s + r.value);

      if (total > 0) {
        results.add({'label': a.name, 'value': total, 'activityId': a.id});
      }
    }

    results.sort(
      (a, b) => (b['value'] as double).compareTo(a['value'] as double),
    );

    dev.log(
      "AI ANALYTICS TOOL RESULT: getCountBasedActivityStats records=${results.length}",
    );

    if (results.isEmpty) {
      return AiToolEnvelope.failure(
        tool: AiToolNames.getCountBasedActivityStats,
        errorCode: AiToolErrorCodes.emptyResult,
        message:
            'No count-based activity data found for ${_periodLabel(period)}.',
        data: {'stats': const []},
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
      data: {'stats': results, 'widgetPayload': widgetPayload},
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
          .where(
            (e) =>
                e.activityId == a.id &&
                e.timestamp.isAfter(start) &&
                e.timestamp.isBefore(end),
          )
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

    dev.log(
      "AI ANALYTICS TOOL RESULT: getTimeBasedActivityStats records=${results.length}",
    );

    if (results.isEmpty) {
      return AiToolEnvelope.failure(
        tool: AiToolNames.getTimeBasedActivityStats,
        errorCode: AiToolErrorCodes.emptyResult,
        message:
            'No time-based activity data found for ${_periodLabel(period)}.',
        data: {'stats': const []},
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
      data: {'stats': results, 'widgetPayload': widgetPayload},
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

    dev.log(
      "AI ANALYTICS TOOL RESULT: getCategoryAllocation records=${items.length}",
    );

    if (items.isEmpty) {
      return AiToolEnvelope.failure(
        tool: AiToolNames.getCategoryAllocation,
        errorCode: AiToolErrorCodes.emptyResult,
        message: 'No activity data found for ${_periodLabel(period)}.',
        data: {'allocation': const []},
      );
    }

    final topItems = items.take(8).toList();
    if (items.length > 8) {
      final otherTotal = items
          .skip(8)
          .fold<int>(0, (s, i) => s + (i['value'] as int));
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
      data: {'allocation': items, 'widgetPayload': widgetPayload},
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
    if (id == null) {
      return AiToolEnvelope.failure(
        tool: AiToolNames.getTrendData,
        errorCode: AiToolErrorCodes.missingParameter,
        message: 'Missing activityId.',
      );
    }
    final a = map[id];
    if (a == null) {
      return AiToolEnvelope.failure(
        tool: AiToolNames.getTrendData,
        errorCode: AiToolErrorCodes.notFound,
        message: 'Activity not found.',
      );
    }

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
      return AiToolEnvelope.failure(
        tool: AiToolNames.getTrendData,
        errorCode: AiToolErrorCodes.emptyResult,
        message:
            'No trend data found for ${a.name} in ${_periodLabel(period)}.',
        data: {'trendPoints': const []},
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
}
