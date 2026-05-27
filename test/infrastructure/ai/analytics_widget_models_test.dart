import 'package:flutter_test/flutter_test.dart';
import 'package:active/infrastructure/ai/analytics_widget_models.dart';

void main() {
  group('DonutChartItem parsing', () {
    test('should parse when standard "value" is a double', () {
      final json = {'label': 'Coding', 'value': 45.5};
      final item = DonutChartItem.fromJson(json);
      expect(item, isNotNull);
      expect(item!.label, 'Coding');
      expect(item.value, 45.5);
    });

    test('should parse when "value" is a String number', () {
      final json = {'label': 'Coding', 'value': '120.5'};
      final item = DonutChartItem.fromJson(json);
      expect(item, isNotNull);
      expect(item!.label, 'Coding');
      expect(item.value, 120.5);
    });

    test('should parse alternative keys like "seconds"', () {
      final json = {'label': 'Meeting', 'seconds': 3600};
      final item = DonutChartItem.fromJson(json);
      expect(item, isNotNull);
      expect(item!.label, 'Meeting');
      expect(item.value, 3600.0);
    });

    test('should parse alternative keys like "count"', () {
      final json = {'label': 'Pushups', 'count': 75};
      final item = DonutChartItem.fromJson(json);
      expect(item, isNotNull);
      expect(item!.label, 'Pushups');
      expect(item.value, 75.0);
    });

    test('should fallback to other numeric fields in the map', () {
      final json = {'label': 'Exercise', 'repetitions': 150};
      final item = DonutChartItem.fromJson(json);
      expect(item, isNotNull);
      expect(item!.label, 'Exercise');
      expect(item.value, 150.0);
    });

    test('should fallback to string numeric fields in the map', () {
      final json = {'label': 'Exercise', 'custom_key': '250.75'};
      final item = DonutChartItem.fromJson(json);
      expect(item, isNotNull);
      expect(item!.label, 'Exercise');
      expect(item.value, 250.75);
    });
  });

  group('DonutChartPayload parsing', () {
    test('should parse full payload with standard list of maps', () {
      final json = {
        'widgetType': 'donut_chart',
        'title': 'Time Allocation',
        'description': 'Last Month',
        'data': [
          {'label': 'Coding', 'seconds': 7200},
          {'label': 'Reading', 'count': '5'},
        ]
      };

      final payload = DonutChartPayload.fromJson(json);
      expect(payload, isNotNull);
      expect(payload!.title, 'Time Allocation');
      expect(payload.data.length, 2);
      expect(payload.data[0].label, 'Coding');
      expect(payload.data[0].value, 7200.0);
      expect(payload.data[1].label, 'Reading');
      expect(payload.data[1].value, 5.0);
      expect(payload.isDonut, isTrue);
    });

    test('should parse payload when data is a Map of key-value pairs', () {
      final json = {
        'widgetType': 'donut_chart',
        'title': 'Pushups vs. Bicep Curls',
        'data': {
          'Pushups': 100,
          'Bicep Curls': '150.0'
        }
      };

      final payload = DonutChartPayload.fromJson(json);
      expect(payload, isNotNull);
      expect(payload!.title, 'Pushups vs. Bicep Curls');
      expect(payload.data.length, 2);
      expect(payload.data[0].label, 'Pushups');
      expect(payload.data[0].value, 100.0);
      expect(payload.data[1].label, 'Bicep Curls');
      expect(payload.data[1].value, 150.0);
    });

    test('should parse payload when data is a List of single-entry maps', () {
      final json = {
        'widgetType': 'donut_chart',
        'title': 'Pushups vs. Bicep Curls',
        'data': [
          {'Pushups': 100},
          {'Bicep Curls': '150.0'}
        ]
      };

      final payload = DonutChartPayload.fromJson(json);
      expect(payload, isNotNull);
      expect(payload!.title, 'Pushups vs. Bicep Curls');
      expect(payload.data.length, 2);
      expect(payload.data[0].label, 'Pushups');
      expect(payload.data[0].value, 100.0);
      expect(payload.data[1].label, 'Bicep Curls');
      expect(payload.data[1].value, 150.0);
    });

    test('should parse payload when data is a List of Lists', () {
      final json = {
        'widgetType': 'donut_chart',
        'title': 'Pushups vs. Bicep Curls',
        'data': [
          ['Pushups', 100],
          ['Bicep Curls', '150.0']
        ]
      };

      final payload = DonutChartPayload.fromJson(json);
      expect(payload, isNotNull);
      expect(payload!.title, 'Pushups vs. Bicep Curls');
      expect(payload.data.length, 2);
      expect(payload.data[0].label, 'Pushups');
      expect(payload.data[0].value, 100.0);
      expect(payload.data[1].label, 'Bicep Curls');
      expect(payload.data[1].value, 150.0);
    });

    test('should parse payload when data uses custom keys like activityName and totalCount', () {
      final json = {
        'widgetType': 'donut_chart',
        'title': 'Pushups vs. Bicep Curls',
        'data': [
          {'activityName': 'Pushups', 'totalCount': 100},
          {'activityName': 'Bicep Curls', 'totalCount': '150.0'}
        ]
      };

      final payload = DonutChartPayload.fromJson(json);
      expect(payload, isNotNull);
      expect(payload!.title, 'Pushups vs. Bicep Curls');
      expect(payload.data.length, 2);
      expect(payload.data[0].label, 'Pushups');
      expect(payload.data[0].value, 100.0);
      expect(payload.data[1].label, 'Bicep Curls');
      expect(payload.data[1].value, 150.0);
    });

    test('should parse payload when data is {labels:[...], series:[...]} with flat values', () {
      // Exact shape seen in live logs:
      // {labels: [Pushups, Bicep Curls], series: [300, 0]}
      final json = {
        'widgetType': 'donut_chart',
        'title': 'Exercise Comparison',
        'data': {
          'labels': ['Pushups', 'Bicep Curls'],
          'series': [300, 0],
        }
      };

      final payload = DonutChartPayload.fromJson(json);
      expect(payload, isNotNull);
      expect(payload!.title, 'Exercise Comparison');
      expect(payload.data.length, 2);
      expect(payload.data[0].label, 'Pushups');
      expect(payload.data[0].value, 300.0);
      expect(payload.data[1].label, 'Bicep Curls');
      expect(payload.data[1].value, 0.0);
    });

    test('should parse payload when data is {labels:[...], series:[{name, values:[...]}]}', () {
      // Nested series-object shape (bar-chart format re-used for donut):
      // {labels: ["Pushups","Bicep Curls"], series: [{name:"Last Month", values:[300.0, 0.0]}]}
      final json = {
        'widgetType': 'donut_chart',
        'title': 'Exercise Comparison',
        'data': {
          'labels': ['Pushups', 'Bicep Curls'],
          'series': [
            {'name': 'Last Month', 'values': [300.0, 0.0]}
          ],
        }
      };

      final payload = DonutChartPayload.fromJson(json);
      expect(payload, isNotNull);
      expect(payload!.title, 'Exercise Comparison');
      expect(payload.data.length, 2);
      expect(payload.data[0].label, 'Pushups');
      expect(payload.data[0].value, 300.0);
      expect(payload.data[1].label, 'Bicep Curls');
      expect(payload.data[1].value, 0.0);
    });
  });

  group('BarChartSeries and LineChartSeries parsing', () {
    test('should parse values with mixed num and string formats', () {
      final json = {
        'name': 'Progress',
        'values': [10.5, '20.0', 30, '40.5']
      };

      final barSeries = BarChartSeries.fromJson(json);
      expect(barSeries, isNotNull);
      expect(barSeries!.name, 'Progress');
      expect(barSeries.values, [10.5, 20.0, 30.0, 40.5]);

      final lineSeries = LineChartSeries.fromJson(json);
      expect(lineSeries, isNotNull);
      expect(lineSeries!.name, 'Progress');
      expect(lineSeries.values, [10.5, 20.0, 30.0, 40.5]);
    });
  });
}
