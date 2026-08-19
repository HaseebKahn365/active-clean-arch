import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

class ExcelExportService {
  static Future<String?> exportActivitiesToExcel({bool shareAfterExport = true}) async {
    final activities = await DatabaseHelper.instance.getActivities();
    if (activities.isEmpty) {
      return null;
    }

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    for (final activity in activities) {
      if (activity.id == null) continue;
      // Excel sheet names max 31 chars and no invalid chars: \ / ? * : [ ]
      var sheetName = activity.name.replaceAll(RegExp(r'[\\/?*:[\]]'), '_').trim();
      if (sheetName.isEmpty) {
        sheetName = 'Activity_${activity.id}';
      } else if (sheetName.length > 31) {
        sheetName = sheetName.substring(0, 31);
      }

      final sheet = excel[sheetName];
      final isCount = activity.type == ActivityType.count;
      final unit = isCount ? 'Count' : 'Minutes';

      // Header row
      sheet.appendRow([
        TextCellValue('Record ID'),
        TextCellValue('Activity Name'),
        TextCellValue('Type'),
        TextCellValue('Quantity ($unit)'),
        TextCellValue('Timestamp'),
      ]);

      // Fetch all records for this activity
      final records = await DatabaseHelper.instance.getRecordsForActivity(activity.id!);
      for (final record in records) {
        sheet.appendRow([
          IntCellValue(record.id ?? 0),
          TextCellValue(activity.name),
          TextCellValue(isCount ? 'Count' : 'Time'),
          IntCellValue(record.quantity),
          TextCellValue(record.timestamp.toIso8601String()),
        ]);
      }
    }

    // Delete the default empty sheet if custom sheets exist
    if (defaultSheet != null && excel.sheets.keys.length > 1) {
      excel.delete(defaultSheet);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final timestampStr = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'active_records_$timestampStr.xlsx';
    final filePath = p.join(directory.path, fileName);

    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    if (shareAfterExport) {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Active Activity Records Export',
        text: 'Exported activities and records excel spreadsheet.',
      );
    }

    return filePath;
  }
}
