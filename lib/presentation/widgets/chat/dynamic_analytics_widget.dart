import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../../../infrastructure/ai/analytics_widget_models.dart';
import 'analytics_widgets/analytics_widget_error_card.dart';
import 'analytics_widgets/bar_chart_widget.dart';
import 'analytics_widgets/comparison_summary_widget.dart';
import 'analytics_widgets/donut_chart_widget.dart';
import 'analytics_widgets/leaderboard_widget.dart';
import 'analytics_widgets/line_chart_widget.dart';
import 'analytics_widgets/metric_card_widget.dart';

/// Top-level router that reads a raw widget payload map, validates it,
/// and delegates to the correct sub-widget. Shows an error card on failure.
///
/// Usage inside the chat list:
/// ```dart
/// DynamicAnalyticsWidget(payload: message.payload!)
/// ```
class DynamicAnalyticsWidget extends StatelessWidget {
  final Map<String, dynamic> payload;

  const DynamicAnalyticsWidget({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final type = payload['widgetType']?.toString() ?? 'unknown';
    final title = payload['title']?.toString() ?? '';

    dev.log("AI WIDGET RENDER: type=$type title=$title");

    Widget buildError(String message) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnalyticsWidgetErrorCard(reason: message),
        ),
      );
    }

    try {
      final parsed = AnalyticsWidgetPayload.fromJson(payload);

      if (parsed == null) {
        dev.log("AI WIDGET ERROR: parsed null for type=$type title=$title");
        return buildError('Could not render "$type" widget — required data is missing.');
      }

      // Deep payload validation
      final validationError = _validatePayload(parsed);
      if (validationError != null) {
        dev.log("AI WIDGET VALIDATION FAILURE: $validationError");
        return buildError(validationError);
      }

      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildWidget(parsed),
        ),
      );
    } catch (e, stack) {
      dev.log("AI WIDGET EXCEPTION during parsing: $e\n$stack");
      return buildError('Failed to display widget due to malformed payload.');
    }
  }

  String? _validatePayload(AnalyticsWidgetPayload parsed) {
    if (parsed.title.trim().isEmpty) {
      return 'Widget title cannot be empty.';
    }

    switch (parsed) {
      case BarChartPayload p:
        if (p.data.labels.isEmpty) {
          return 'Bar chart requires at least one label.';
        }
        if (p.data.series.isEmpty) {
          return 'Bar chart requires at least one data series.';
        }
        for (final s in p.data.series) {
          if (s.values.length < p.data.labels.length) {
            return 'Data series "${s.name}" is missing values for some labels.';
          }
        }
      case LineChartPayload p:
        if (p.data.labels.isEmpty) {
          return 'Line chart requires at least one label.';
        }
        if (p.data.series.isEmpty) {
          return 'Line chart requires at least one data series.';
        }
        for (final s in p.data.series) {
          if (s.values.length < p.data.labels.length) {
            return 'Line series "${s.name}" is missing values for some labels.';
          }
        }
      case DonutChartPayload p:
        if (p.data.isEmpty) {
          return 'Donut chart requires at least one data slice.';
        }
      case LeaderboardPayload p:
        if (p.items.isEmpty) {
          return 'Leaderboard requires at least one item.';
        }
      case ComparisonSummaryPayload p:
        if (p.items.isEmpty) {
          return 'Comparison summary requires at least one comparison row.';
        }
      case MetricCardPayload p:
        if (p.value.isEmpty) {
          return 'Metric card requires a value.';
        }
    }
    return null; // All valid!
  }

  Widget _buildWidget(AnalyticsWidgetPayload parsed) {
    return switch (parsed) {
      MetricCardPayload p => MetricCardWidget(payload: p),
      BarChartPayload p => BarChartWidget(payload: p),
      DonutChartPayload p => DonutChartWidget(payload: p),
      LineChartPayload p => LineChartWidget(payload: p),
      LeaderboardPayload p => LeaderboardWidget(payload: p),
      ComparisonSummaryPayload p => ComparisonSummaryWidget(payload: p),
    };
  }
}
