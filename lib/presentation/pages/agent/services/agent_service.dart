import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_ai/firebase_ai.dart';

import 'package:active/presentation/pages/agent/models/pending_action.dart';
import 'package:active/presentation/pages/agent/services/agent_tools.dart';

/// Log channel for everything the agent does. Filter the debug console by
/// this name to follow a full request/tool-call/response cycle.
const String kAgentLogName = 'Agent';

/// Token usage reported by the API for one user message. Because a single
/// message can take several model turns (one per tool round), these are
/// summed across every turn in that exchange.
class TokenUsage {
  const TokenUsage({
    this.promptTokens = 0,
    this.responseTokens = 0,
    this.thoughtTokens = 0,
    this.totalTokens = 0,
  });

  final int promptTokens;
  final int responseTokens;
  final int thoughtTokens;
  final int totalTokens;

  bool get isEmpty => totalTokens == 0;

  TokenUsage operator +(TokenUsage other) => TokenUsage(
        promptTokens: promptTokens + other.promptTokens,
        responseTokens: responseTokens + other.responseTokens,
        thoughtTokens: thoughtTokens + other.thoughtTokens,
        totalTokens: totalTokens + other.totalTokens,
      );

  factory TokenUsage.fromMetadata(UsageMetadata meta) => TokenUsage(
        promptTokens: meta.promptTokenCount ?? 0,
        responseTokens: meta.candidatesTokenCount ?? 0,
        thoughtTokens: meta.thoughtsTokenCount ?? 0,
        totalTokens: meta.totalTokenCount ?? 0,
      );

  @override
  String toString() => 'prompt $promptTokens + response $responseTokens'
      '${thoughtTokens > 0 ? ' + thinking $thoughtTokens' : ''} '
      '= $totalTokens total';
}

/// Result of a single agent turn, including which tools were invoked so the
/// UI can surface "fetched from database" style provenance.
class AgentResponse {
  AgentResponse({
    required this.text,
    required this.toolsUsed,
    this.usage = const TokenUsage(),
    this.pendingAction,
  });

  final String text;
  final List<String> toolsUsed;
  final TokenUsage usage;

  /// Set when the agent proposed a destructive action needing confirmation.
  final PendingAction? pendingAction;
}

/// Drives a Gemini chat session (via Firebase AI Logic) with function
/// calling wired up to the local SQLite activity database.
class AgentService {
  AgentService({AgentTools? tools}) : _tools = tools ?? AgentTools() {
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: modelName,
        tools: _tools.tools,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(temperature: 0.2),
      );
      _chat = _model.startChat();
      dev.log('Initialized model "$modelName"', name: kAgentLogName);
    } catch (e, st) {
      dev.log(
        'FAILED to initialize model "$modelName": $e',
        name: kAgentLogName,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Gemini model backing the agent.
  static const String modelName = 'gemini-3.6-flash';

  final AgentTools _tools;
  late final GenerativeModel _model;
  late ChatSession _chat;

  /// Running total across every message in the current conversation.
  TokenUsage get sessionUsage => _sessionUsage;
  TokenUsage _sessionUsage = const TokenUsage();

  static const _systemPrompt = '''
You are the in-app assistant for "Active", a personal activity/habit tracker.
The user logs quantities (counts or minutes) against activities they define,
each with a timestamp. You can both READ their data and MODIFY it by calling
the available tools — never guess or fabricate numbers, always call a tool to
fetch real data first.

Acting on the user's behalf:
- To add a new activity, call create_activity. Infer whether it is a "count"
  activity (pushups, glasses of water) or a "time" activity in minutes
  (reading, meditation) rather than asking, unless it is genuinely ambiguous.
- To record something the user did ("I did 20 pushups", "log 30 min reading"),
  call log_record. If the activity does not exist yet, create it first with
  create_activity and then log against it — do this in one go without asking.
- To delete an activity, call request_delete_activity. This does NOT delete
  anything; it asks the user to confirm. Tell them what will be removed and
  that they need to confirm. Never claim something was deleted.
- For analytical questions the other tools cannot answer (streaks, best
  weekday, daily averages, trends), call run_analytical_query with a SELECT.

Take the obvious action rather than asking permission for it. "Create a bicep
curl activity" means call create_activity now, not ask which type they want.

Today's date and the user's local timezone offset are provided in each user
turn's context. Resolve relative time expressions yourself before calling a
tool, e.g.:
- "yesterday" -> the single day before today
- "today" -> just today
- "this week" -> Monday through today (or the full week if referring to a
  completed week)
- "last week" -> the previous Monday-Sunday week
- "this month" / "last month" -> full calendar months
- "this year" -> January 1st through today

Always pass start_date as inclusive and end_date as EXCLUSIVE (the day after
the last day you want included), both formatted YYYY-MM-DD.

If the user names an activity that doesn't clearly match anything, call
list_activities to see what exists and pick the closest match, or ask the
user to clarify if nothing is close.

When you reply, write a short, friendly, direct answer in Markdown. Prefer:
- A bolded headline number/result first.
- A compact Markdown table when returning multiple records or comparing
  several activities.
- No filler like "Sure, I can help with that" — just answer.
If a tool returns zero records, say so plainly rather than treating it as an
error.

Always write dates day-first for the user: "19/08/2026", "19 Aug 2026", or
"19 August". Never month-first (not "08/19/2026", not "Aug 19"). This applies
only to prose and tables you show the user — tool arguments stay YYYY-MM-DD.
''';

  /// Sends [message] and streams the reply.
  ///
  /// [onDelta] fires for each text chunk as it arrives so the UI can render
  /// progressively; [onToolStart] fires when a database tool begins running,
  /// so the UI can show what the agent is doing during the pause before any
  /// text exists.
  Future<AgentResponse> send(
    String message, {
    void Function(String delta)? onDelta,
    void Function(String toolLabel)? onToolStart,
  }) async {
    final stopwatch = Stopwatch()..start();
    final now = DateTime.now();
    final contextPrefix =
        '[Context: today is ${_isoDate(now)} (${_weekday(now)}), '
        'current local time ${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}]\n';

    dev.log('→ USER: $message', name: kAgentLogName);

    // Stale proposals must not leak into a new turn.
    _tools.pendingAction = null;
    final toolsUsed = <String>[];

    try {
      var content = Content.text('$contextPrefix$message');
      var round = 0;
      var firstTokenLogged = false;
      var usage = const TokenUsage();
      final buffer = StringBuffer();

      // Each pass streams one model turn. If that turn asks for tools, we run
      // them and loop; otherwise the streamed text is the final answer.
      while (true) {
        final pendingCalls = <FunctionCall>[];
        // Chunks report usage cumulatively within a turn, so keep the largest
        // rather than adding every chunk's figure.
        var turnUsage = const TokenUsage();

        await for (final chunk in _chat.sendMessageStream(content)) {
          pendingCalls.addAll(chunk.functionCalls);

          final meta = chunk.usageMetadata;
          if (meta != null) {
            final chunkUsage = TokenUsage.fromMetadata(meta);
            if (chunkUsage.totalTokens >= turnUsage.totalTokens) {
              turnUsage = chunkUsage;
            }
          }

          final delta = chunk.text;
          if (delta == null || delta.isEmpty) continue;

          if (!firstTokenLogged) {
            firstTokenLogged = true;
            dev.log(
              'First token after ${stopwatch.elapsedMilliseconds}ms',
              name: kAgentLogName,
            );
          }
          buffer.write(delta);
          onDelta?.call(delta);
        }

        usage = usage + turnUsage;
        if (!turnUsage.isEmpty) {
          dev.log('  tokens this turn: $turnUsage', name: kAgentLogName);
        }

        if (pendingCalls.isEmpty) break;

        round++;
        dev.log(
          'Tool round $round: ${pendingCalls.length} call(s) requested',
          name: kAgentLogName,
        );

        final parts = <Part>[];
        for (final call in pendingCalls) {
          final friendly = _friendlyToolName(call.name);
          toolsUsed.add(friendly);
          onToolStart?.call(friendly);

          dev.log(
            '  ⚙ CALL ${call.name}(${_encode(call.args)})',
            name: kAgentLogName,
          );

          final toolWatch = Stopwatch()..start();
          final result = await _tools.dispatch(call);
          toolWatch.stop();

          if (result['error'] != null) {
            dev.log(
              '  ✗ ${call.name} failed in ${toolWatch.elapsedMilliseconds}ms: '
              '${result['error']}',
              name: kAgentLogName,
            );
          } else {
            dev.log(
              '  ✓ ${call.name} ok in ${toolWatch.elapsedMilliseconds}ms → '
              '${_encode(result)}',
              name: kAgentLogName,
            );
          }

          parts.add(FunctionResponse(call.name, result, id: call.id));
        }

        // The Google AI backend rejects role 'function' (which
        // Content.functionResponses produces), so send the results as 'user'.
        content = Content('user', parts);
      }

      stopwatch.stop();
      final text = buffer.toString().trim();

      if (text.isEmpty) {
        dev.log(
          '← EMPTY response after ${stopwatch.elapsedMilliseconds}ms '
          '(tools used: ${toolsUsed.isEmpty ? "none" : toolsUsed.join(", ")})',
          name: kAgentLogName,
        );
        return AgentResponse(
          text: "I wasn't able to generate a response for that — try rephrasing?",
          toolsUsed: toolsUsed,
          usage: usage,
        );
      }

      dev.log(
        '← DONE in ${stopwatch.elapsedMilliseconds}ms | tools: '
        '${toolsUsed.isEmpty ? "none" : toolsUsed.join(", ")} | '
        '${text.length} chars | tokens: $usage'
        '${round > 0 ? ' across ${round + 1} model turns' : ''}',
        name: kAgentLogName,
      );

      _sessionUsage = _sessionUsage + usage;
      dev.log(
        'Session total: ${_sessionUsage.totalTokens} tokens',
        name: kAgentLogName,
      );

      return AgentResponse(
        text: text,
        toolsUsed: toolsUsed,
        usage: usage,
        pendingAction: _tools.pendingAction,
      );
    } catch (e, st) {
      stopwatch.stop();
      dev.log(
        '✗ send() FAILED after ${stopwatch.elapsedMilliseconds}ms: $e',
        name: kAgentLogName,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  void reset() {
    _chat = _model.startChat();
    dev.log(
      'Conversation reset (discarding ${_sessionUsage.totalTokens} '
      'tokens of session usage)',
      name: kAgentLogName,
    );
    _sessionUsage = const TokenUsage();
  }

  /// Compact JSON for logging; falls back to toString for odd payloads and
  /// truncates so a big record dump cannot flood the console.
  String _encode(Object? value) {
    String text;
    try {
      text = jsonEncode(value);
    } catch (_) {
      text = value.toString();
    }
    const limit = 800;
    return text.length <= limit
        ? text
        : '${text.substring(0, limit)}… (${text.length} chars)';
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _weekday(DateTime d) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][d.weekday - 1];

  String _friendlyToolName(String raw) {
    switch (raw) {
      case 'list_activities':
        return 'Listed activities';
      case 'get_activity_records':
        return 'Fetched records';
      case 'get_activity_summary':
        return 'Fetched summary';
      case 'compare_activities':
        return 'Compared activities';
      case 'create_activity':
        return 'Created activity';
      case 'log_record':
        return 'Logged entry';
      case 'request_delete_activity':
        return 'Requested deletion';
      case 'run_analytical_query':
        return 'Ran query';
      default:
        return raw;
    }
  }
}
