import 'package:active/infrastructure/ai/analytics_markdown_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsMarkdownFallbackRenderer', () {
    test('renders comparison_summary widget as a markdown table', () {
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: {
          'widgetType': 'comparison_summary',
          'title': 'Counts Comparison',
          'currentPeriodLabel': 'Today',
          'previousPeriodLabel': 'Yesterday',
          'items': [
            {
              'label': 'Pushups',
              'current': '80',
              'previous': '60',
              'difference': '+20',
            },
          ],
        },
      );

      expect(md, isNotNull);
      expect(md, contains('## Counts Comparison'));
      expect(md, contains('| Pushups | 80 | 60 | +20 |'));
    });

    test('renders bar_chart widget as a markdown table', () {
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: {
          'widgetType': 'bar_chart',
          'title': 'Count Activities',
          'data': {
            'labels': ['Pushups', 'Bicep Curls'],
            'series': [
              {
                'name': 'This Week',
                'values': [300, 0],
              },
            ],
          },
        },
      );

      expect(md, isNotNull);
      expect(md, contains('## Count Activities'));
      expect(md, contains('| Pushups | 300 |'));
      expect(md, contains('| Bicep Curls | 0 |'));
    });

    test('renders donut_chart widget as a category table', () {
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: {
          'widgetType': 'donut_chart',
          'title': 'Time Allocation',
          'data': [
            {'label': 'Study', 'value': 9000},
            {'label': 'Workout', 'value': 2700},
          ],
        },
      );

      expect(md, isNotNull);
      expect(md, contains('## Time Allocation'));
      expect(md, contains('| Study | 9000 |'));
    });

    test('renders leaderboard widget as a numbered list', () {
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: {
          'widgetType': 'leaderboard',
          'title': 'Top Activities',
          'items': [
            {'label': 'Practical MLOps', 'value': '1h 20m'},
            {'label': 'Book Study', 'value': '50m'},
          ],
        },
      );

      expect(md, isNotNull);
      expect(md, contains('1. Practical MLOps — 1h 20m'));
      expect(md, contains('2. Book Study — 50m'));
    });

    test('falls back to raw tool data when widget payload is unusable', () {
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: {'widgetType': 'bar_chart', 'title': 'Broken'},
        toolData: {
          'categories': [
            {'label': 'Study', 'seconds': 3600},
          ],
        },
      );

      expect(md, isNotNull);
      expect(md, contains('| Study | 3600 |'));
    });

    test('returns null when there is no usable data', () {
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: const {},
        toolData: const {},
      );
      expect(md, isNull);
    });

    test('renders best-effort table for unknown widget type', () {
      final md = AnalyticsMarkdownFallbackRenderer.render(
        widgetPayload: {
          'widgetType': 'mystery_chart',
          'title': 'Mystery',
          'data': [
            {'label': 'A', 'value': 5},
            {'label': 'B', 'value': 10},
          ],
        },
      );

      expect(md, isNotNull);
      expect(md, contains('| A | 5 |'));
      expect(md, contains('| B | 10 |'));
    });
  });
}
