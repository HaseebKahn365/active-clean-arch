import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._init();
  static Database? _database;

  SqliteService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('active.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Robustly check and add all potentially missing columns to 'activities'
      final columns = await db.rawQuery('PRAGMA table_info(activities)');
      final columnNames = columns.map((e) => e['name'] as String).toList();

      const requiredColumns = {
        'goal_seconds': 'INTEGER NOT NULL DEFAULT 0',
        'type': 'TEXT NOT NULL DEFAULT "ActivityType.timeBased"',
        'is_pinned': 'INTEGER NOT NULL DEFAULT 0',
        'description': 'TEXT NOT NULL DEFAULT ""',
      };

      for (var entry in requiredColumns.entries) {
        if (!columnNames.contains(entry.key)) {
          await db.execute('ALTER TABLE activities ADD COLUMN ${entry.key} ${entry.value}');
        }
      }

      // Ensure all subsidiary tables exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_events (
          id TEXT PRIMARY KEY,
          activity_id TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          duration_delta INTEGER NOT NULL,
          previous_status TEXT NOT NULL,
          next_status TEXT NOT NULL,
          old_parent_id TEXT,
          new_parent_id TEXT,
          old_duration INTEGER,
          new_duration INTEGER,
          FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS count_records (
          id TEXT PRIMARY KEY,
          activity_id TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          value REAL NOT NULL,
          FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
        );
      ''');
    }

    if (oldVersion < 3) {
      // Clean up sync related columns if they exist
      try {
        await db.execute('ALTER TABLE activity_events DROP COLUMN is_synced');
      } catch (e) {
        // DROP COLUMN might not be supported on older SQLite versions on Android
        // We can just ignore it as the model doesn't use it anymore
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT "",
        parent_id TEXT,
        children_ids TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT,
        total_seconds INTEGER NOT NULL,
        goal_seconds INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL DEFAULT 'ActivityType.timeBased',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE count_records (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        value REAL NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE activity_events (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        duration_delta INTEGER NOT NULL,
        previous_status TEXT NOT NULL,
        next_status TEXT NOT NULL,
        old_parent_id TEXT,
        new_parent_id TEXT,
        old_duration INTEGER,
        new_duration INTEGER,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
