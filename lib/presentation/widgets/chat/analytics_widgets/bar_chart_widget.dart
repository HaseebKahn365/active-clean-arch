import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// Hide model types that clash with fl_chart names
import '../../../../infrastructure/ai/analytics_widget_models.dart'
    hide BarChartData;
import '../../../../presentation/theme/app_colors.dart';
import 'analytics_widget_container.dart';

class BarChartWidget extends StatelessWidget {
  final BarChartPayload payload;

  const BarChartWidget({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = payload.data;
    final labels = data.labels;
    final series = data.series;
    final seriesCount = series.length;
    final labelCount = labels.length;

    final isEmpty = labelCount == 0 || seriesCount == 0;

    const barWidth = 12.0;
    const groupGap = 6.0;
    const chartHeight = 180.0;

    final needsScroll = labelCount > 6;
    final groupWidth = seriesCount * (barWidth + 2) + groupGap;
    final scrollWidth = (groupWidth * labelCount + 40).clamp(0.0, 800.0);

    final allValues = series.expand((s) => s.values).toList();
    final maxVal = allValues.isEmpty ? 10.0 : allValues.reduce((a, b) => a > b ? a : b);

    Widget buildChart(double width) {
      return SizedBox(
        width: width,
        height: chartHeight,
        child: BarChart(
          BarChartData(
            maxY: maxVal * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: theme.dividerColor.withValues(alpha: 0.25),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max) return const SizedBox.shrink();
                    return Text(
                      _formatAxisValue(value),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                    final label = labels[idx];
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label.length > 8 ? '${label.substring(0, 7)}…' : label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(labelCount, (groupIdx) {
              return BarChartGroupData(
                x: groupIdx,
                groupVertically: false,
                barRods: List.generate(seriesCount, (seriesIdx) {
                  final value = seriesIdx < series[seriesIdx].values.length
                      ? series[seriesIdx].values[groupIdx]
                      : 0.0;
                  final color = AppColors.chartPalette[seriesIdx % AppColors.chartPalette.length];
                  return BarChartRodData(
                    toY: value,
                    color: color,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  );
                }),
                barsSpace: 3,
              );
            }),
          ),
          duration: Duration.zero,
        ),
      );
    }

    final chartArea = needsScroll
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: buildChart(scrollWidth),
          )
        : LayoutBuilder(
            builder: (context, constraints) => buildChart(constraints.maxWidth),
          );

    final legend = seriesCount > 1
        ? Wrap(
            spacing: 12,
            runSpacing: 4,
            children: List.generate(series.length, (i) {
              final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    series[i].name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }),
          )
        : null;

    final summaryFooter = (payload.xAxisLabel != null || payload.yAxisLabel != null || payload.footer != null)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (payload.footer != null)
                Text(
                  payload.footer!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (payload.xAxisLabel != null || payload.yAxisLabel != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (payload.yAxisLabel != null)
                      Text(
                        'Y: ${payload.yAxisLabel!}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    if (payload.xAxisLabel != null)
                      Text(
                        'X: ${payload.xAxisLabel!}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          )
        : null;

    return AnalyticsWidgetContainer(
      title: payload.title,
      subtitle: payload.description,
      icon: Icons.bar_chart_rounded,
      chartArea: chartArea,
      legend: legend,
      summaryFooter: summaryFooter,
      insightsSection: payload.insights,
      isEmpty: isEmpty,
      emptyMessage: 'No activity detected for this period.',
    );
  }

  String _formatAxisValue(double v) {
    if (v >= 3600) return '${(v / 3600).toStringAsFixed(0)}h';
    if (v >= 60) return '${(v / 60).toStringAsFixed(0)}m';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
