import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  final StreamController<void> _changeController = StreamController<void>.broadcast();
  Stream<void> get onDatabaseChanged => _changeController.stream;

  void _notifyChange() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  DatabaseHelper._init();

  DatabaseHelper({Database? db}) {
    if (db != null) {
      _database = db;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('active.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Database? _readOnlyDatabase;

  /// A separate read-only handle used for agent-generated SQL.
  ///
  /// SQLite itself rejects writes on this connection, so a statement that
  /// slips past validation still cannot modify data.
  Future<Database> get readOnlyDatabase async {
    if (_readOnlyDatabase != null) return _readOnlyDatabase!;

    // Ensure the schema exists before opening read-only; a read-only open
    // cannot create the file.
    await database;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'active.db');
    _readOnlyDatabase = await openDatabase(path, readOnly: true);
    return _readOnlyDatabase!;
  }

  /// Overrides the read-only handle. Tests use this to point at an in-memory
  /// database, since a second connection to `:memory:` would be a new blank
  /// database rather than the same one.
  // ignore: use_setters_to_change_properties
  void debugSetReadOnlyDatabase(Database db) {
    _readOnlyDatabase = db;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS records');
      await db.execute('DROP TABLE IF EXISTS activities');
      await _createDB(db, newVersion);
    }
  }

  // --- Activities ---

  Future<Activity> insertActivity(Activity activity) async {
    final db = await database;
    final id = await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChange();
    return activity.copyWith(id: id);
  }

  Future<List<Activity>> getActivities() async {
    final db = await database;
    final maps = await db.query(
      'activities',
      orderBy: 'created_at DESC',
    );

    if (maps.isEmpty) {
      return [];
    }

    return maps.map((map) => Activity.fromMap(map)).toList();
  }

  Future<int> deleteActivity(int id) async {
    final db = await database;
    final result = await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
    return result;
  }

  // --- Records ---

  Future<ActivityRecord> insertRecord(ActivityRecord record) async {
    final db = await database;
    final id = await db.insert(
      'records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChange();
    return record.copyWith(id: id);
  }

  Future<List<ActivityRecord>> getRecordsForActivity(int activityId) async {
    final db = await database;
    final maps = await db.query(
      'records',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => ActivityRecord.fromMap(map)).toList();
  }

  Future<int> getTotalQuantityForActivity(int activityId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(quantity), 0) as total FROM records WHERE activity_id = ?',
      [activityId],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toInt();
    }
    return 0;
  }

  Future<Map<int, int>> getTotalQuantities() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT activity_id, COALESCE(SUM(quantity), 0) as total FROM records GROUP BY activity_id',
    );
    final map = <int, int>{};
    for (final row in result) {
      final actId = row['activity_id'] as int?;
      final total = row['total'] as num?;
      if (actId != null && total != null) {
        map[actId] = total.toInt();
      }
    }
    return map;
  }

  Future<ActivityStats> getActivityStats(int activityId) async {
    final records = await getRecordsForActivity(activityId);
    return ActivityStats.fromRecords(records);
  }

  Future<Map<int, ActivityStats>> getAllActivityStats() async {
    final db = await database;
    final maps = await db.query('records', orderBy: 'timestamp DESC');
    final recordsByActivity = <int, List<ActivityRecord>>{};
    for (final map in maps) {
      final record = ActivityRecord.fromMap(map);
      recordsByActivity.putIfAbsent(record.activityId, () => []).add(record);
    }
    final statsMap = <int, ActivityStats>{};
    for (final entry in recordsByActivity.entries) {
      statsMap[entry.key] = ActivityStats.fromRecords(entry.value);
    }
    return statsMap;
  }

  Future<Map<int, List<double>>> getWeeklyDailyTotals([DateTime? now]) async {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final startOfWindow = today.subtract(const Duration(days: 6));
    final endOfWindow = today.add(const Duration(days: 1));

    final db = await database;
    final maps = await db.query(
      'records',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfWindow.toIso8601String(), endOfWindow.toIso8601String()],
      orderBy: 'timestamp ASC',
    );

    final weeklyMap = <int, List<double>>{};
    for (final map in maps) {
      final record = ActivityRecord.fromMap(map);
      weeklyMap.putIfAbsent(record.activityId, () => List.filled(7, 0.0));
      final recordDay = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      final dayIndex = recordDay.difference(startOfWindow).inDays.clamp(0, 6);
      weeklyMap[record.activityId]![dayIndex] += record.quantity.toDouble();
    }
    return weeklyMap;
  }

  Future<Map<int, int>> getMonthlyDailyTotals(int activityId, int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final db = await database;
    final maps = await db.query(
      'records',
      where: 'activity_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [activityId, startOfMonth.toIso8601String(), endOfMonth.toIso8601String()],
      orderBy: 'timestamp ASC',
    );

    final dailyMap = <int, int>{};
    for (final map in maps) {
      final record = ActivityRecord.fromMap(map);
      final day = record.timestamp.day;
      dailyMap[day] = (dailyMap[day] ?? 0) + record.quantity;
    }
    return dailyMap;
  }

  Future<List<double>> getHistoricalDailyTotals(int activityId, {int days = 30, DateTime? now}) async {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final startOfWindow = today.subtract(Duration(days: days - 1));
    final endOfWindow = today.add(const Duration(days: 1));

    final db = await database;
    final maps = await db.query(
      'records',
      where: 'activity_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [activityId, startOfWindow.toIso8601String(), endOfWindow.toIso8601String()],
      orderBy: 'timestamp ASC',
    );

    final dailyList = List.filled(days, 0.0);
    for (final map in maps) {
      final record = ActivityRecord.fromMap(map);
      final recordDay = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      final dayIndex = recordDay.difference(startOfWindow).inDays;
      if (dayIndex >= 0 && dayIndex < days) {
        dailyList[dayIndex] += record.quantity.toDouble();
      }
    }
    return dailyList;
  }

  Future<List<ActivityRecord>> getPaginatedRecords(int activityId, {int limit = 15, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'records',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => ActivityRecord.fromMap(m)).toList();
  }

  Future<int> getRecordCountForActivity(int activityId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM records WHERE activity_id = ?',
      [activityId],
    );
    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as num).toInt();
    }
    return 0;
  }

  Future<List<ActivityRecord>> getRecordsInRange(
    int activityId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'records',
      where: 'activity_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [activityId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ActivityRecord.fromMap(m)).toList();
  }

  Future<int> getTotalQuantityInRange(
    int activityId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(quantity), 0) as total FROM records '
      'WHERE activity_id = ? AND timestamp >= ? AND timestamp < ?',
      [activityId, start.toIso8601String(), end.toIso8601String()],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toInt();
    }
    return 0;
  }

  Future<Activity?> findActivityByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'activities',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isNotEmpty) return Activity.fromMap(maps.first);

    final fuzzy = await db.query(
      'activities',
      where: 'LOWER(name) LIKE LOWER(?)',
      whereArgs: ['%$name%'],
      limit: 1,
    );
    if (fuzzy.isNotEmpty) return Activity.fromMap(fuzzy.first);
    return null;
  }

  /// Runs a read-only SELECT for the agent's analytical queries.
  ///
  /// Validation rejects anything that is not a single SELECT, and execution
  /// happens on a read-only connection so writes fail at the SQLite layer
  /// even if validation is somehow bypassed.
  Future<List<Map<String, Object?>>> runReadOnlyQuery(
    String sql, {
    int maxRows = 200,
  }) async {
    final violation = validateSelectOnly(sql);
    if (violation != null) {
      throw ArgumentError(violation);
    }

    final db = await readOnlyDatabase;
    final rows = await db.rawQuery(sql);
    return rows.length > maxRows ? rows.sublist(0, maxRows) : rows;
  }

  /// Returns null when [sql] is a single safe SELECT, otherwise a message
  /// explaining why it was rejected.
  static String? validateSelectOnly(String sql) {
    final trimmed = sql.trim();
    if (trimmed.isEmpty) return 'Query is empty.';

    // Strip string literals so keywords inside them cannot trip the checks,
    // and comments so they cannot hide a second statement.
    final stripped = trimmed
        .replaceAll(RegExp("'[^']*'"), "''")
        .replaceAll(RegExp(r'--[^\n]*'), ' ')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');

    // Reject stacked statements: a semicolon anywhere but a single trailing one.
    final withoutTrailing = stripped.endsWith(';')
        ? stripped.substring(0, stripped.length - 1)
        : stripped;
    if (withoutTrailing.contains(';')) {
      return 'Only a single statement is allowed.';
    }

    final lower = withoutTrailing.toLowerCase();
    if (!lower.startsWith('select') && !lower.startsWith('with')) {
      return 'Only SELECT queries are allowed.';
    }

    const forbidden = [
      'insert', 'update', 'delete', 'drop', 'alter', 'create', 'replace',
      'truncate', 'attach', 'detach', 'pragma', 'vacuum', 'reindex', 'grant',
    ];
    for (final word in forbidden) {
      if (RegExp('\\b$word\\b').hasMatch(lower)) {
        return 'The "$word" keyword is not allowed in analytical queries.';
      }
    }
    return null;
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    final result = await db.delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
    return result;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
    if (!_changeController.isClosed) {
      await _changeController.close();
    }
  }
}
