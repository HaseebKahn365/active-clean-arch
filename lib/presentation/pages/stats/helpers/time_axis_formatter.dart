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

  static double getInterval(double windowSize, TimeRange range) {
    if (windowSize <= 0) return 1.0;

    // Adjust interval based on how many units are visible
    if (windowSize <= 2) return 0.25; // Quarter units if zoomed in a lot
    if (windowSize <= 5) return 0.5;
    if (windowSize <= 14) return 1.0;
    if (windowSize <= 35) return 7.0;
    if (windowSize <= 100) return 14.0;

    return (windowSize / 5).ceilToDouble();
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
