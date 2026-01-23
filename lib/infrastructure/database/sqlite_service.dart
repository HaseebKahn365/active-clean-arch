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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        children_ids TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT,
        total_seconds INTEGER NOT NULL
      );

      CREATE TABLE activity_events (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        duration_delta INTEGER NOT NULL,
        previous_status TEXT NOT NULL,
        next_status TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
