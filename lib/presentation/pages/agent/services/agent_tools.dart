import 'dart:developer' as dev;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/agent/models/pending_action.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

const String _logName = 'AgentTools';

/// Declares the callable tools Gemini can use to read and modify the user's
/// tracked activities, and executes them against SQLite.
class AgentTools {
  AgentTools({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Set when a tool proposes a destructive action. The UI reads this after
  /// the turn and renders a confirmation card; nothing is deleted until the
  /// user accepts.
  PendingAction? pendingAction;

  static const _listActivities = 'list_activities';
  static const _getActivityRecords = 'get_activity_records';
  static const _getActivitySummary = 'get_activity_summary';
  static const _compareActivities = 'compare_activities';
  static const _createActivity = 'create_activity';
  static const _logRecord = 'log_record';
  static const _requestDeleteActivity = 'request_delete_activity';
  static const _runAnalyticalQuery = 'run_analytical_query';

  /// Schema handed to the model for [_runAnalyticalQuery].
  static const schemaDescription = '''
TABLE activities (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,        -- 'count' or 'time' (time is in minutes)
  created_at TEXT NOT NULL   -- ISO-8601
)
TABLE records (
  id INTEGER PRIMARY KEY,
  activity_id INTEGER NOT NULL REFERENCES activities(id),
  quantity INTEGER NOT NULL,
  timestamp TEXT NOT NULL    -- ISO-8601
)''';

  List<Tool> get tools => [
        Tool.functionDeclarations([
          FunctionDeclaration(
            _listActivities,
            'Lists every activity the user currently tracks, with its type '
            '(count or time/minutes) and total logged quantity. Use this '
            'first if you are unsure which activities exist or need to '
            'resolve an ambiguous activity name mentioned by the user.',
            parameters: {},
          ),
          FunctionDeclaration(
            _getActivityRecords,
            'Fetches the individual logged entries (date + quantity) for a '
            'single named activity within a date range. Use this when the '
            'user wants to see specific entries/records, not just a total.',
            parameters: {
              'activity_name': Schema.string(
                description: 'The name of the activity, e.g. "Pushups" or '
                    '"Reading". Must match (or closely match) an activity '
                    'from list_activities.',
              ),
              'start_date': Schema.string(
                description: 'Inclusive start of the date range, formatted '
                    'as YYYY-MM-DD, in the user\'s local time.',
              ),
              'end_date': Schema.string(
                description: 'Exclusive end of the date range, formatted as '
                    'YYYY-MM-DD (the day AFTER the last day to include), in '
                    'the user\'s local time.',
              ),
            },
          ),
          FunctionDeclaration(
            _getActivitySummary,
            'Gets the total quantity logged for a single named activity '
            'within a date range, plus the number of entries. Use this for '
            'questions like "how many X yesterday/this week/in March".',
            parameters: {
              'activity_name': Schema.string(
                description: 'The name of the activity to summarize.',
              ),
              'start_date': Schema.string(
                description: 'Inclusive start of the date range, YYYY-MM-DD.',
              ),
              'end_date': Schema.string(
                description: 'Exclusive end of the date range, YYYY-MM-DD '
                    '(the day AFTER the last day to include).',
              ),
              'label': Schema.string(
                description: 'A short human-readable label for this time '
                    'range, e.g. "yesterday", "this week", "March 2026". '
                    'Used for display purposes only.',
              ),
            },
          ),
          FunctionDeclaration(
            _compareActivities,
            'Gets totals for MULTIPLE named activities over the same date '
            'range, so they can be compared side by side. Use this when the '
            'user asks to compare two or more activities, or asks for "all" '
            'activities in a given period.',
            parameters: {
              'activity_names': Schema.array(
                items: Schema.string(),
                description: 'Names of the activities to compare. Pass all '
                    'known activity names if the user asks about "all" or '
                    '"every" activity.',
              ),
              'start_date': Schema.string(
                description: 'Inclusive start of the date range, YYYY-MM-DD.',
              ),
              'end_date': Schema.string(
                description: 'Exclusive end of the date range, YYYY-MM-DD.',
              ),
              'label': Schema.string(
                description: 'Short human-readable label for the time range.',
              ),
            },
          ),
          FunctionDeclaration(
            _createActivity,
            'Creates a new activity for the user to track. Call this when the '
            'user asks to add, create, or start tracking something new. If an '
            'activity with that name already exists, this reports it instead '
            'of creating a duplicate.',
            parameters: {
              'name': Schema.string(
                description: 'Name of the new activity, e.g. "Bicep Curls". '
                    'Use the user\'s wording, cleaned up with normal '
                    'capitalization.',
              ),
              'type': Schema.enumString(
                enumValues: const ['count', 'time'],
                description: 'Use "count" for things counted in repetitions '
                    'or units (pushups, glasses of water) and "time" for '
                    'things measured in minutes (reading, meditation). Infer '
                    'this from the activity; only ask if genuinely ambiguous.',
              ),
            },
          ),
          FunctionDeclaration(
            _logRecord,
            'Logs a quantity against an existing activity. Call this when the '
            'user reports doing something, e.g. "I did 20 pushups" or "log 30 '
            'minutes of reading". Quantity may be negative to correct an '
            'earlier over-entry.',
            parameters: {
              'activity_name': Schema.string(
                description: 'Name of the activity to log against. Must match '
                    'an existing activity.',
              ),
              'quantity': Schema.integer(
                description: 'Amount to log: repetitions for count activities, '
                    'minutes for time activities. Negative values subtract.',
              ),
              'date': Schema.string(
                description: 'Optional date for the entry as YYYY-MM-DD. Omit '
                    'to log against right now. Use this when the user says '
                    'something like "yesterday" or names a past date.',
              ),
            },
            optionalParameters: const ['date'],
          ),
          FunctionDeclaration(
            _requestDeleteActivity,
            'Asks the user to confirm deleting an activity. This does NOT '
            'delete anything by itself — it shows a confirmation card and the '
            'user decides. Deleting an activity also removes all of its '
            'records permanently. After calling this, tell the user what will '
            'be removed and that they need to confirm.',
            parameters: {
              'activity_name': Schema.string(
                description: 'Name of the activity the user wants deleted.',
              ),
            },
          ),
          FunctionDeclaration(
            _runAnalyticalQuery,
            'Runs a read-only SQL SELECT against the activity database for '
            'analytical questions the other tools cannot answer — streaks, '
            'best/worst weekday, averages per day, trends over time, '
            'correlations. ONLY SELECT statements are permitted; any attempt '
            'to modify data is rejected. Prefer the purpose-built tools above '
            'when they fit, since they are faster.\n\nSchema:\n'
            '$schemaDescription\n\n'
            'Note: timestamps are ISO-8601 text, so use SQLite date functions '
            "like date(timestamp) and strftime('%w', timestamp) for weekday.",
            parameters: {
              'sql': Schema.string(
                description: 'A single SQLite SELECT statement. No semicolon '
                    'needed. Must not contain multiple statements.',
              ),
              'purpose': Schema.string(
                description: 'One short phrase describing what this query '
                    'answers, shown to the user for transparency.',
              ),
            },
          ),
        ]),
      ];

  /// Executes a Gemini function call and returns its JSON-serializable result.
  ///
  /// Database failures are converted into an `error` payload rather than
  /// thrown, so the model can explain the problem instead of the whole turn
  /// collapsing.
  Future<Map<String, Object?>> dispatch(FunctionCall call) async {
    try {
      switch (call.name) {
        case _listActivities:
          return await _listActivitiesImpl();
        case _getActivityRecords:
          return await _getActivityRecordsImpl(call.args);
        case _getActivitySummary:
          return await _getActivitySummaryImpl(call.args);
        case _compareActivities:
          return await _compareActivitiesImpl(call.args);
        case _createActivity:
          return await _createActivityImpl(call.args);
        case _logRecord:
          return await _logRecordImpl(call.args);
        case _requestDeleteActivity:
          return await _requestDeleteActivityImpl(call.args);
        case _runAnalyticalQuery:
          return await _runAnalyticalQueryImpl(call.args);
        default:
          dev.log('Unknown tool requested: "${call.name}"', name: _logName);
          return {'error': 'Unknown tool "${call.name}"'};
      }
    } catch (e, st) {
      dev.log(
        'Database error while running "${call.name}": $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return {'error': 'Database query failed: $e'};
    }
  }

  Future<Map<String, Object?>> _listActivitiesImpl() async {
    final activities = await _db.getActivities();
    final totals = await _db.getTotalQuantities();
    return {
      'activities': [
        for (final a in activities)
          {
            'name': a.name,
            'type': a.type.name,
            'total_logged': a.id != null ? (totals[a.id!] ?? 0) : 0,
          },
      ],
    };
  }

  Future<Activity?> _resolveActivity(String name) async {
    final match = await _db.findActivityByName(name);
    if (match == null) {
      dev.log('No activity matched "$name"', name: _logName);
    } else if (match.name.toLowerCase() != name.toLowerCase()) {
      dev.log('Fuzzy-matched "$name" → "${match.name}"', name: _logName);
    }
    return match;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<Map<String, Object?>> _getActivityRecordsImpl(
    Map<String, Object?> args,
  ) async {
    final name = args['activity_name'] as String?;
    if (name == null) return {'error': 'activity_name is required'};

    final activity = await _resolveActivity(name);
    if (activity == null || activity.id == null) {
      return {'error': 'No activity found matching "$name"'};
    }

    final start = _parseDate(args['start_date'] as String?);
    final end = _parseDate(args['end_date'] as String?);
    if (start == null || end == null) {
      return {'error': 'start_date and end_date must be valid YYYY-MM-DD dates'};
    }

    final records = await _db.getRecordsInRange(activity.id!, start, end);
    final unit = activity.type == ActivityType.count ? 'count' : 'min';

    return {
      'activity_name': activity.name,
      'unit': unit,
      'entry_count': records.length,
      'total': records.fold<int>(0, (sum, r) => sum + r.quantity),
      'records': [
        for (final r in records)
          {
            'date': r.timestamp.toIso8601String(),
            'quantity': r.quantity,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _getActivitySummaryImpl(
    Map<String, Object?> args,
  ) async {
    final name = args['activity_name'] as String?;
    if (name == null) return {'error': 'activity_name is required'};

    final activity = await _resolveActivity(name);
    if (activity == null || activity.id == null) {
      return {'error': 'No activity found matching "$name"'};
    }

    final start = _parseDate(args['start_date'] as String?);
    final end = _parseDate(args['end_date'] as String?);
    if (start == null || end == null) {
      return {'error': 'start_date and end_date must be valid YYYY-MM-DD dates'};
    }

    final total = await _db.getTotalQuantityInRange(activity.id!, start, end);
    final records = await _db.getRecordsInRange(activity.id!, start, end);
    final unit = activity.type == ActivityType.count ? 'count' : 'min';

    return {
      'activity_name': activity.name,
      'unit': unit,
      'label': args['label'] ?? '',
      'total': total,
      'entry_count': records.length,
    };
  }

  Future<Map<String, Object?>> _compareActivitiesImpl(
    Map<String, Object?> args,
  ) async {
    final names = (args['activity_names'] as List?)?.cast<Object?>() ?? [];
    final start = _parseDate(args['start_date'] as String?);
    final end = _parseDate(args['end_date'] as String?);
    if (start == null || end == null) {
      return {'error': 'start_date and end_date must be valid YYYY-MM-DD dates'};
    }

    final results = <Map<String, Object?>>[];
    for (final rawName in names) {
      final name = rawName?.toString();
      if (name == null) continue;
      final activity = await _resolveActivity(name);
      if (activity == null || activity.id == null) {
        results.add({'activity_name': name, 'error': 'not found'});
        continue;
      }
      final total = await _db.getTotalQuantityInRange(activity.id!, start, end);
      final unit = activity.type == ActivityType.count ? 'count' : 'min';
      results.add({
        'activity_name': activity.name,
        'unit': unit,
        'total': total,
      });
    }

    return {
      'label': args['label'] ?? '',
      'comparison': results,
    };
  }

  // --- Write tools ---

  Future<Map<String, Object?>> _createActivityImpl(
    Map<String, Object?> args,
  ) async {
    final name = (args['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      return {'error': 'name is required'};
    }

    final existing = await _db.findActivityByName(name);
    if (existing != null && existing.name.toLowerCase() == name.toLowerCase()) {
      dev.log('Activity "$name" already exists, not creating', name: _logName);
      return {
        'created': false,
        'reason': 'An activity named "${existing.name}" already exists.',
        'activity_name': existing.name,
      };
    }

    final rawType = (args['type'] as String?)?.toLowerCase();
    final type = rawType == 'time' ? ActivityType.time : ActivityType.count;

    final created = await _db.insertActivity(
      Activity(name: name, type: type, createdAt: DateTime.now()),
    );
    dev.log('Created activity "${created.name}" (${type.name})', name: _logName);

    return {
      'created': true,
      'activity_name': created.name,
      'type': type.name,
      'unit': type == ActivityType.count ? 'count' : 'min',
    };
  }

  Future<Map<String, Object?>> _logRecordImpl(Map<String, Object?> args) async {
    final name = args['activity_name'] as String?;
    if (name == null) return {'error': 'activity_name is required'};

    final activity = await _resolveActivity(name);
    if (activity == null || activity.id == null) {
      return {
        'error': 'No activity found matching "$name". Create it first with '
            'create_activity, or ask the user which activity they meant.',
      };
    }

    final rawQuantity = args['quantity'];
    final quantity = rawQuantity is num
        ? rawQuantity.toInt()
        : int.tryParse(rawQuantity?.toString() ?? '');
    if (quantity == null) {
      return {'error': 'quantity must be a whole number'};
    }
    if (quantity == 0) {
      return {'error': 'quantity must not be zero'};
    }

    // A bare YYYY-MM-DD parses to midnight; keep the current time-of-day for
    // "today" so entries stay ordered sensibly within the day.
    final dateArg = args['date'] as String?;
    DateTime timestamp;
    if (dateArg == null) {
      timestamp = DateTime.now();
    } else {
      final parsed = _parseDate(dateArg);
      if (parsed == null) {
        return {'error': 'date must be a valid YYYY-MM-DD date'};
      }
      final now = DateTime.now();
      final isToday = parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day;
      timestamp = isToday
          ? now
          : DateTime(parsed.year, parsed.month, parsed.day, 12);
    }

    await _db.insertRecord(ActivityRecord(
      activityId: activity.id!,
      quantity: quantity,
      timestamp: timestamp,
    ));

    final unit = activity.type == ActivityType.count ? 'count' : 'min';
    final newTotal = await _db.getTotalQuantityForActivity(activity.id!);
    dev.log(
      'Logged $quantity $unit to "${activity.name}" '
      'at ${timestamp.toIso8601String()}',
      name: _logName,
    );

    return {
      'logged': true,
      'activity_name': activity.name,
      'quantity': quantity,
      'unit': unit,
      'date': timestamp.toIso8601String(),
      'new_total': newTotal,
    };
  }

  Future<Map<String, Object?>> _requestDeleteActivityImpl(
    Map<String, Object?> args,
  ) async {
    final name = args['activity_name'] as String?;
    if (name == null) return {'error': 'activity_name is required'};

    final activity = await _resolveActivity(name);
    if (activity == null || activity.id == null) {
      return {'error': 'No activity found matching "$name"'};
    }

    final recordCount = await _db.getRecordCountForActivity(activity.id!);

    pendingAction = PendingAction(
      kind: PendingActionKind.deleteActivity,
      description: 'Delete "${activity.name}" and its $recordCount '
          '${recordCount == 1 ? 'record' : 'records'}',
      targetId: activity.id!,
      targetName: activity.name,
      recordCount: recordCount,
    );

    dev.log(
      'Proposed deletion of "${activity.name}" '
      '($recordCount records) — awaiting confirmation',
      name: _logName,
    );

    return {
      'confirmation_required': true,
      'activity_name': activity.name,
      'records_that_would_be_deleted': recordCount,
      'note': 'Nothing has been deleted. The user must confirm first.',
    };
  }

  Future<Map<String, Object?>> _runAnalyticalQueryImpl(
    Map<String, Object?> args,
  ) async {
    final sql = args['sql'] as String?;
    if (sql == null || sql.trim().isEmpty) {
      return {'error': 'sql is required'};
    }

    final purpose = args['purpose'] as String? ?? '';
    dev.log('Analytical query ($purpose): $sql', name: _logName);

    try {
      final rows = await _db.runReadOnlyQuery(sql);
      dev.log('  → ${rows.length} row(s)', name: _logName);
      return {
        'purpose': purpose,
        'row_count': rows.length,
        'rows': rows,
      };
    } on ArgumentError catch (e) {
      dev.log('  ✗ rejected: ${e.message}', name: _logName);
      return {
        'error': 'Query rejected: ${e.message}',
        'hint': 'Only read-only SELECT statements are permitted.',
      };
    }
  }
}
