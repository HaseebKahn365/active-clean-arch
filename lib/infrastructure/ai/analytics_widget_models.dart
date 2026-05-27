/// Typed models for AI analytics widget payloads.
///
/// Each model maps 1-to-1 with a `widgetType` value the AI (or local tool)
/// can embed inside `AiToolEnvelope.data['widgetPayload']`.
library;

import 'dart:developer' as dev;

// ---------------------------------------------------------------------------
// Widget type constants
// ---------------------------------------------------------------------------

abstract final class AnalyticsWidgetType {
  static const String metricCard = 'metric_card';
  static const String barChart = 'bar_chart';
  static const String donutChart = 'donut_chart';
  static const String pieChart = 'pie_chart';
  static const String lineChart = 'line_chart';
  static const String leaderboard = 'leaderboard';
  static const String comparisonSummary = 'comparison_summary';
}

// ---------------------------------------------------------------------------
// Base
// ---------------------------------------------------------------------------

sealed class AnalyticsWidgetPayload {
  final String widgetType;
  final String title;
  final String? description;
  final String? insights;
  final String? footer;

  const AnalyticsWidgetPayload({
    required this.widgetType,
    required this.title,
    this.description,
    this.insights,
    this.footer,
  });

  /// Deserialise from raw JSON coming out of `AiChatMessage.payload`.
  /// Returns `null` when required fields are missing or unrecognised.
  static AnalyticsWidgetPayload? fromJson(Map<String, dynamic> json) {
    final type = json['widgetType']?.toString();
    if (type == null) return null;

    return switch (type) {
      AnalyticsWidgetType.metricCard => MetricCardPayload.fromJson(json),
      AnalyticsWidgetType.barChart => BarChartPayload.fromJson(json),
      AnalyticsWidgetType.donutChart ||
      AnalyticsWidgetType.pieChart =>
        DonutChartPayload.fromJson(json),
      AnalyticsWidgetType.lineChart => LineChartPayload.fromJson(json),
      AnalyticsWidgetType.leaderboard => LeaderboardPayload.fromJson(json),
      AnalyticsWidgetType.comparisonSummary =>
        ComparisonSummaryPayload.fromJson(json),
      _ => null,
    };
  }
}

// ---------------------------------------------------------------------------
// 1. MetricCard
// ---------------------------------------------------------------------------

class MetricCardPayload extends AnalyticsWidgetPayload {
  final String value;
  final String? subtitle;
  final String? trend;

  const MetricCardPayload({
    required super.title,
    super.description,
    super.insights,
    super.footer,
    required this.value,
    this.subtitle,
    this.trend,
  }) : super(widgetType: AnalyticsWidgetType.metricCard);

  static MetricCardPayload? fromJson(Map<String, dynamic> json) {
    final value = json['value']?.toString();
    if (value == null) return null;
    return MetricCardPayload(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      insights: json['insights']?.toString(),
      footer: json['footer']?.toString(),
      value: value,
      subtitle: json['subtitle']?.toString(),
      trend: json['trend']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. BarChart
// ---------------------------------------------------------------------------

class BarChartSeries {
  final String name;
  final List<double> values;

  const BarChartSeries({required this.name, required this.values});

  static BarChartSeries? fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString();
    final rawValues = json['values'];
    if (name == null || rawValues is! List) return null;
    final values = rawValues.map((v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }).toList();
    return BarChartSeries(name: name, values: values);
  }
}

class BarChartData {
  final List<String> labels;
  final List<BarChartSeries> series;

  const BarChartData({required this.labels, required this.series});

  static BarChartData? fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final rawSeries = json['series'];
    if (rawLabels is! List || rawSeries is! List) return null;
    final labels = rawLabels.map((l) => l.toString()).toList();
    final series = rawSeries
        .whereType<Map>()
        .map((s) => BarChartSeries.fromJson(Map<String, dynamic>.from(s)))
        .whereType<BarChartSeries>()
        .toList();
    if (series.isEmpty) return null;
    return BarChartData(labels: labels, series: series);
  }
}

class BarChartPayload extends AnalyticsWidgetPayload {
  final BarChartData data;
  final String? xAxisLabel;
  final String? yAxisLabel;

  const BarChartPayload({
    required super.title,
    super.description,
    super.insights,
    super.footer,
    required this.data,
    this.xAxisLabel,
    this.yAxisLabel,
  }) : super(widgetType: AnalyticsWidgetType.barChart);

  static BarChartPayload? fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) return null;
    final data = BarChartData.fromJson(Map<String, dynamic>.from(rawData));
    if (data == null) return null;
    return BarChartPayload(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      insights: json['insights']?.toString(),
      footer: json['footer']?.toString(),
      data: data,
      xAxisLabel: json['xAxisLabel']?.toString(),
      yAxisLabel: json['yAxisLabel']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. DonutChart / PieChart
// ---------------------------------------------------------------------------

class DonutChartItem {
  final String label;
  final double value;

  const DonutChartItem({required this.label, required this.value});

  static DonutChartItem? fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString();
    if (label == null) return null;

    // Try to find the numeric value under various potential keys
    var rawValue = json['value'] ??
        json['seconds'] ??
        json['count'] ??
        json['duration'] ??
        json['durationDelta'] ??
        json['repetitions'] ??
        json['amount'];

    // If rawValue is still null, look for any entry that is a number
    // or a string that parses as a number (excluding the label itself)
    if (rawValue == null) {
      for (final entry in json.entries) {
        if (entry.key != 'label') {
          final val = entry.value;
          if (val is num) {
            rawValue = val;
            break;
          } else if (val is String && double.tryParse(val) != null) {
            rawValue = val;
            break;
          }
        }
      }
    }

    if (rawValue == null) return null;

    double? value;
    if (rawValue is num) {
      value = rawValue.toDouble();
    } else if (rawValue is String) {
      value = double.tryParse(rawValue);
    }

    if (value == null) return null;
    return DonutChartItem(label: label, value: value);
  }
}

class DonutChartPayload extends AnalyticsWidgetPayload {
  final List<DonutChartItem> data;
  final bool isDonut;

  const DonutChartPayload({
    required super.title,
    super.description,
    super.insights,
    super.footer,
    required this.data,
    required this.isDonut,
  }) : super(widgetType: AnalyticsWidgetType.donutChart);

  static DonutChartPayload? fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    dev.log('DONUT PARSE: rawData runtimeType=${rawData.runtimeType} value=$rawData');
    if (rawData == null) {
      dev.log('DONUT PARSE FAIL: data key is null');
      return null;
    }

    final List<DonutChartItem> items = [];

    if (rawData is List) {
      for (final element in rawData) {
        if (element is Map) {
          final item = DonutChartItem.fromJson(Map<String, dynamic>.from(element));
          if (item != null) {
            items.add(item);
          } else {
            // Check if it's a map with single entry like {"Pushups": 100}
            if (element.length == 1) {
              final entry = element.entries.first;
              final label = entry.key?.toString();
              final val = _parseValue(entry.value);
              if (label != null && val != null) {
                items.add(DonutChartItem(label: label, value: val));
              }
            } else {
              // Try to find any label and value key pair in the map
              String? foundLabel;
              double? foundValue;
              for (final entry in element.entries) {
                final k = entry.key?.toString();
                final v = entry.value;
                if (k == 'label' || k == 'name' || k == 'title' || k == 'activityName') {
                  foundLabel = v?.toString();
                } else {
                  final parsedVal = _parseValue(v);
                  if (parsedVal != null) {
                    foundValue = parsedVal;
                  }
                }
              }
              // If we still couldn't parse it, find any string (as label) and any double (as value)
              if (foundLabel == null || foundValue == null) {
                for (final entry in element.entries) {
                  final v = entry.value;
                  if (v is String && foundLabel == null && double.tryParse(v) == null) {
                    foundLabel = v;
                  } else {
                    final parsedVal = _parseValue(v);
                    if (parsedVal != null && foundValue == null) {
                      foundValue = parsedVal;
                    }
                  }
                }
              }
              if (foundLabel != null && foundValue != null) {
                items.add(DonutChartItem(label: foundLabel, value: foundValue));
              }
            }
          }
        } else if (element is List && element.length >= 2) {
          // ["Pushups", 100]
          final label = element[0]?.toString();
          final val = _parseValue(element[1]);
          if (label != null && val != null) {
            items.add(DonutChartItem(label: label, value: val));
          }
        }
      }
    } else if (rawData is Map) {
      final rawLabels = rawData['labels'];
      final rawSeries = rawData['series'];

      if (rawLabels is List && rawSeries is List && rawLabels.isNotEmpty) {
        // Bar-chart style: {labels: ["Pushups", "Bicep Curls"], series: [300, 0]}
        // series can also be a list of series objects: [{name: "...", values: [...]}]
        List<double> values = [];
        if (rawSeries.isNotEmpty) {
          final first = rawSeries.first;
          if (first is Map && first['values'] is List) {
            // [{name: "Last Month", values: [300.0, 0.0]}]
            values = (first['values'] as List)
                .map((v) => _parseValue(v) ?? 0.0)
                .toList();
          } else {
            // flat list: [300, 0]
            values = rawSeries.map((v) => _parseValue(v) ?? 0.0).toList();
          }
        }
        for (var i = 0; i < rawLabels.length; i++) {
          final label = rawLabels[i]?.toString();
          final val = i < values.length ? values[i] : 0.0;
          if (label != null) {
            items.add(DonutChartItem(label: label, value: val));
          }
        }
      } else {
        // Simple key→value map: {"Pushups": 100, "Bicep Curls": 150}
        for (final entry in rawData.entries) {
          final label = entry.key?.toString();
          final val = _parseValue(entry.value);
          if (label != null && val != null) {
            items.add(DonutChartItem(label: label, value: val));
          }
        }
      }
    }

    dev.log('DONUT PARSE: extracted ${items.length} items from rawData');
    if (items.isEmpty) {
      dev.log('DONUT PARSE FAIL: no items could be extracted — rawData=$rawData');
      return null;
    }

    final type = json['widgetType']?.toString();
    return DonutChartPayload(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      insights: json['insights']?.toString(),
      footer: json['footer']?.toString(),
      data: items,
      isDonut: type == AnalyticsWidgetType.donutChart,
    );
  }

  static double? _parseValue(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }
}

// ---------------------------------------------------------------------------
// 4. LineChart
// ---------------------------------------------------------------------------

class LineChartSeries {
  final String name;
  final List<double> values;

  const LineChartSeries({required this.name, required this.values});

  static LineChartSeries? fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString();
    final rawValues = json['values'];
    if (name == null || rawValues is! List) return null;
    final values = rawValues.map((v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }).toList();
    return LineChartSeries(name: name, values: values);
  }
}

class LineChartData {
  final List<String> labels;
  final List<LineChartSeries> series;

  const LineChartData({required this.labels, required this.series});

  static LineChartData? fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final rawSeries = json['series'];
    if (rawLabels is! List || rawSeries is! List) return null;
    final labels = rawLabels.map((l) => l.toString()).toList();
    final series = rawSeries
        .whereType<Map>()
        .map((s) => LineChartSeries.fromJson(Map<String, dynamic>.from(s)))
        .whereType<LineChartSeries>()
        .toList();
    if (series.isEmpty) return null;
    return LineChartData(labels: labels, series: series);
  }
}

class LineChartPayload extends AnalyticsWidgetPayload {
  final LineChartData data;
  final String? xAxisLabel;
  final String? yAxisLabel;

  const LineChartPayload({
    required super.title,
    super.description,
    super.insights,
    super.footer,
    required this.data,
    this.xAxisLabel,
    this.yAxisLabel,
  }) : super(widgetType: AnalyticsWidgetType.lineChart);

  static LineChartPayload? fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) return null;
    final data = LineChartData.fromJson(Map<String, dynamic>.from(rawData));
    if (data == null) return null;
    return LineChartPayload(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      insights: json['insights']?.toString(),
      footer: json['footer']?.toString(),
      data: data,
      xAxisLabel: json['xAxisLabel']?.toString(),
      yAxisLabel: json['yAxisLabel']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Leaderboard
// ---------------------------------------------------------------------------

class LeaderboardItem {
  final String label;
  final String value;
  final String? subtitle;

  const LeaderboardItem({required this.label, required this.value, this.subtitle});

  static LeaderboardItem? fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString();
    final value = json['value']?.toString();
    if (label == null || value == null) return null;
    return LeaderboardItem(
      label: label,
      value: value,
      subtitle: json['subtitle']?.toString(),
    );
  }
}

class LeaderboardPayload extends AnalyticsWidgetPayload {
  final List<LeaderboardItem> items;

  const LeaderboardPayload({
    required super.title,
    super.description,
    super.insights,
    super.footer,
    required this.items,
  }) : super(widgetType: AnalyticsWidgetType.leaderboard);

  static LeaderboardPayload? fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) return null;
    final items = rawItems
        .whereType<Map>()
        .map((i) => LeaderboardItem.fromJson(Map<String, dynamic>.from(i)))
        .whereType<LeaderboardItem>()
        .toList();
    if (items.isEmpty) return null;
    return LeaderboardPayload(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      insights: json['insights']?.toString(),
      footer: json['footer']?.toString(),
      items: items,
    );
  }
}

// ---------------------------------------------------------------------------
// 6. ComparisonSummary
// ---------------------------------------------------------------------------

class ComparisonSummaryItem {
  final String label;
  final String current;
  final String previous;
  final String? difference;
  final String? trend; // 'up' | 'down' | 'neutral'

  const ComparisonSummaryItem({
    required this.label,
    required this.current,
    required this.previous,
    this.difference,
    this.trend,
  });

  static ComparisonSummaryItem? fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString();
    if (label == null) return null;
    return ComparisonSummaryItem(
      label: label,
      current: json['current']?.toString() ?? '—',
      previous: json['previous']?.toString() ?? '—',
      difference: json['difference']?.toString(),
      trend: json['trend']?.toString(),
    );
  }
}

class ComparisonSummaryPayload extends AnalyticsWidgetPayload {
  final List<ComparisonSummaryItem> items;
  final String? currentPeriodLabel;
  final String? previousPeriodLabel;

  const ComparisonSummaryPayload({
    required super.title,
    super.description,
    super.insights,
    super.footer,
    required this.items,
    this.currentPeriodLabel,
    this.previousPeriodLabel,
  }) : super(widgetType: AnalyticsWidgetType.comparisonSummary);

  static ComparisonSummaryPayload? fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) return null;
    final items = rawItems
        .whereType<Map>()
        .map((i) => ComparisonSummaryItem.fromJson(Map<String, dynamic>.from(i)))
        .whereType<ComparisonSummaryItem>()
        .toList();
    if (items.isEmpty) return null;
    return ComparisonSummaryPayload(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      insights: json['insights']?.toString(),
      footer: json['footer']?.toString(),
      items: items,
      currentPeriodLabel: json['currentPeriodLabel']?.toString(),
      previousPeriodLabel: json['previousPeriodLabel']?.toString(),
    );
  }
}
