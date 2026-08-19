import 'package:flutter_test/flutter_test.dart';

import 'package:active/presentation/pages/stats/activity_detail_page.dart';

/// The user's convention is day-first (dd/mm/yyyy). These pin the ordering so
/// it cannot regress to US-style month-first.
void main() {
  group('formatShortDate', () {
    test('puts the day before the month', () {
      expect(
        ActivityDetailPage.formatShortDate(DateTime(2026, 9, 3)),
        '3/9',
      );
    });

    test('is unambiguous when day and month could be swapped', () {
      // 4 May, not 5 April.
      expect(
        ActivityDetailPage.formatShortDate(DateTime(2026, 5, 4)),
        '4/5',
      );
    });

    test('handles a day number that cannot be a month', () {
      expect(
        ActivityDetailPage.formatShortDate(DateTime(2026, 2, 28)),
        '28/2',
      );
    });
  });

  group('formatRecordTimestamp', () {
    test('renders day before month name', () {
      expect(
        ActivityDetailPage.formatRecordTimestamp(DateTime(2026, 3, 3, 14, 30)),
        '3 Mar 2026 • 2:30 PM',
      );
    });

    test('never renders month-first', () {
      final formatted =
          ActivityDetailPage.formatRecordTimestamp(DateTime(2026, 8, 19, 9, 5));
      expect(formatted, startsWith('19 Aug'));
      expect(formatted, isNot(contains('Aug 19')));
    });

    test('formats midnight as 12 AM', () {
      expect(
        ActivityDetailPage.formatRecordTimestamp(DateTime(2026, 1, 1, 0, 0)),
        '1 Jan 2026 • 12:00 AM',
      );
    });

    test('formats noon as 12 PM', () {
      expect(
        ActivityDetailPage.formatRecordTimestamp(DateTime(2026, 1, 1, 12, 0)),
        '1 Jan 2026 • 12:00 PM',
      );
    });

    test('pads minutes', () {
      expect(
        ActivityDetailPage.formatRecordTimestamp(DateTime(2026, 6, 7, 8, 5)),
        '7 Jun 2026 • 8:05 AM',
      );
    });
  });
}
