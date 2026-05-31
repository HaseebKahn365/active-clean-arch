import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../infrastructure/ai/analytics_markdown_fallback.dart';
import '../../../infrastructure/ai/analytics_widget_models.dart';
import 'analytics_widgets/analytics_widget_error_card.dart';
import 'analytics_widgets/bar_chart_widget.dart';
import 'analytics_widgets/comparison_summary_widget.dart';
import 'analytics_widgets/donut_chart_widget.dart';
import 'analytics_widgets/leaderboard_widget.dart';
import 'analytics_widgets/line_chart_widget.dart';
import 'analytics_widgets/metric_card_widget.dart';

/// Top-level router that reads a raw widget payload map, validates it,
/// and delegates to the correct sub-widget.
///
/// When a widget cannot be rendered, this never shows a bare error — it
/// degrades to a markdown summary built from the payload (or an embedded
/// `__fallbackMarkdown`). The error card is only used when there is genuinely
/// no usable data.
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
    dev.log("WIDGET RENDER START: $type");

    Widget buildFallback(String reason) {
      dev.log('WIDGET FALLBACK: $reason');
      final markdown =
          payload['__fallbackMarkdown']?.toString() ??
          AnalyticsMarkdownFallbackRenderer.render(widgetPayload: payload);
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: (markdown != null && markdown.trim().isNotEmpty)
              ? _MarkdownFallbackCard(markdown: markdown)
              : AnalyticsWidgetErrorCard(reason: reason),
        ),
      );
    }

    try {
      final parsed = AnalyticsWidgetPayload.fromJson(payload);

      if (parsed == null) {
        return buildFallback('reason=parsed null for type=$type');
      }

      final validationError = _validatePayload(parsed);
      if (validationError != null) {
        return buildFallback(validationError);
      }

      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildWidget(parsed),
        ),
      );
    } catch (e) {
      dev.log('WIDGET RENDER EXCEPTION: $e');
      return buildFallback('render exception: $e');
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

/// Renders a markdown summary used when a widget cannot be displayed but the
/// underlying analytics data is still available.
class _MarkdownFallbackCard extends StatelessWidget {
  final String markdown;

  const _MarkdownFallbackCard({required this.markdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: MarkdownBody(
        data: markdown,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyMedium,
          tableBody: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
