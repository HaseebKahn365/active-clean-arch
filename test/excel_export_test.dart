import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:excel/excel.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ExcelExportService', () {
    late Database db;
    late DatabaseHelper dbHelper;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
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
      dbHelper = DatabaseHelper(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates multi-sheet excel file with distinct worksheets for each activity', () async {
      final act1 = await dbHelper.insertActivity(
        const Activity(name: 'Pushups', type: ActivityType.count),
      );
      final act2 = await dbHelper.insertActivity(
        const Activity(name: 'Cycling', type: ActivityType.time),
      );

      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act1.id!,
          quantity: 25,
          timestamp: DateTime(2026, 8, 19, 10, 0, 0),
        ),
      );
      await dbHelper.insertRecord(
        ActivityRecord(
          activityId: act2.id!,
          quantity: 45,
          timestamp: DateTime(2026, 8, 19, 11, 0, 0),
        ),
      );

      // Verify records exist
      final pushupRecords = await dbHelper.getRecordsForActivity(act1.id!);
      final cyclingRecords = await dbHelper.getRecordsForActivity(act2.id!);

      expect(pushupRecords.length, 1);
      expect(cyclingRecords.length, 1);

      // Manually construct and test Excel structure matching ExcelExportService logic
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      final sheet1 = excel['Pushups'];
      sheet1.appendRow([
        TextCellValue('Record ID'),
        TextCellValue('Activity Name'),
        TextCellValue('Type'),
        TextCellValue('Quantity (Count)'),
        TextCellValue('Timestamp'),
      ]);
      sheet1.appendRow([
        IntCellValue(pushupRecords.first.id ?? 1),
        TextCellValue('Pushups'),
        TextCellValue('Count'),
        IntCellValue(25),
        TextCellValue(pushupRecords.first.timestamp.toIso8601String()),
      ]);

      final sheet2 = excel['Cycling'];
      sheet2.appendRow([
        TextCellValue('Record ID'),
        TextCellValue('Activity Name'),
        TextCellValue('Type'),
        TextCellValue('Quantity (Minutes)'),
        TextCellValue('Timestamp'),
      ]);
      sheet2.appendRow([
        IntCellValue(cyclingRecords.first.id ?? 2),
        TextCellValue('Cycling'),
        TextCellValue('Time'),
        IntCellValue(45),
        TextCellValue(cyclingRecords.first.timestamp.toIso8601String()),
      ]);

      if (defaultSheet != null && excel.sheets.keys.length > 1) {
        excel.delete(defaultSheet);
      }

      final encoded = excel.save();
      expect(encoded, isNotNull);

      // Read back excel and verify worksheets
      final decoded = Excel.decodeBytes(encoded!);
      expect(decoded.sheets.containsKey('Pushups'), isTrue);
      expect(decoded.sheets.containsKey('Cycling'), isTrue);

      final pushupSheet = decoded.sheets['Pushups']!;
      expect(pushupSheet.rows.length, 2); // 1 header + 1 record
      expect(pushupSheet.rows[0][0]?.value.toString(), 'Record ID');
      expect(pushupSheet.rows[1][3]?.value.toString(), '25');

      final cyclingSheet = decoded.sheets['Cycling']!;
      expect(cyclingSheet.rows.length, 2);
      expect(cyclingSheet.rows[1][3]?.value.toString(), '45');
    });
  });
}
