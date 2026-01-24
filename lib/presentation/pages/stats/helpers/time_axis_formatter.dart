import 'package:intl/intl.dart';
import '../../../providers/stats_provider.dart';

class TimeAxisFormatter {
  static String formatXAxis(DateTime date, TimeRange range) {
    switch (range) {
      case TimeRange.day:
        return DateFormat('HH:mm').format(date);
      case TimeRange.week:
        return DateFormat('E').format(date); // Mon, Tue, etc.
      case TimeRange.month:
        final now = DateTime.now();
        final start = now.subtract(const Duration(days: 29));
        final diff = date.difference(start).inDays;
        final weekNum = (diff / 7).floor() + 1;
        return 'Wk $weekNum';
      case TimeRange.year:
        return DateFormat('MMM').format(date); // Jan, Feb, etc.
      case TimeRange.forever:
        final now = DateTime.now();
        final diff = now.difference(date).inDays;
        if (diff > 730) return DateFormat('yyyy').format(date);
        if (diff > 365) return 'Q${((date.month - 1) ~/ 3) + 1} ${date.year}';
        return DateFormat('MMM yyyy').format(date);
    }
  }

  static double getInterval(int dataLength, TimeRange range) {
    if (dataLength <= 0) return 1.0;

    switch (range) {
      case TimeRange.day:
        return 4.0; // Every 4 hours (24/4 = 6 labels)
      case TimeRange.week:
        return 1.0; // Every day (7 labels)
      case TimeRange.month:
        // Month has ~30 slots (days)
        return 7.0; // Weekly ticks (4-5 labels)
      case TimeRange.year:
        // Year has 12 slots (months)
        return 2.0; // Every 2 months (6 labels)
      case TimeRange.forever:
        if (dataLength > 12) return (dataLength / 6).ceilToDouble();
        return 1.0;
    }
  }

  static String getTooltipDateFormat(DateTime date, TimeRange range) {
    switch (range) {
      case TimeRange.day:
        return DateFormat('HH:mm, MMM d').format(date);
      case TimeRange.week:
        return DateFormat('EEEE, MMM d').format(date);
      case TimeRange.month:
        return DateFormat('MMM d, yyyy').format(date);
      case TimeRange.year:
        return DateFormat('MMMM yyyy').format(date);
      case TimeRange.forever:
        return DateFormat('MMM yyyy').format(date);
    }
  }
}
