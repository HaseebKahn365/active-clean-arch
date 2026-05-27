import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// Hide model types that clash with fl_chart names
import '../../../../infrastructure/ai/analytics_widget_models.dart'
    hide LineChartData;
import '../../../../presentation/theme/app_colors.dart';
import 'analytics_widget_container.dart';

class LineChartWidget extends StatelessWidget {
  final LineChartPayload payload;

  const LineChartWidget({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = payload.data;
    final labels = data.labels;
    final series = data.series;

    final isEmpty = labels.isEmpty || series.isEmpty;

    final allValues = series.expand((s) => s.values).toList();
    final maxVal = allValues.isEmpty ? 10.0 : allValues.reduce((a, b) => a > b ? a : b);

    final needsScroll = labels.length > 10;
    final scrollWidth = (labels.length * 30.0 + 60).clamp(0.0, 800.0);

    Widget buildChart(double width) {
      return SizedBox(
        width: width,
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
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
                  interval: labels.length > 7 ? (labels.length / 5).ceilToDouble() : 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        labels[idx],
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
            lineBarsData: List.generate(series.length, (si) {
              final s = series[si];
              final color = AppColors.chartPalette[si % AppColors.chartPalette.length];
              return LineChartBarData(
                spots: List.generate(
                  s.values.length,
                  (xi) => FlSpot(xi.toDouble(), s.values[xi]),
                ),
                isCurved: true,
                curveSmoothness: 0.3,
                color: color,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: labels.length <= 14,
                  getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                    radius: 3,
                    color: color,
                    strokeWidth: 1.5,
                    strokeColor: theme.colorScheme.surface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.08),
                ),
              );
            }),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((spot) {
                  final si = spot.barIndex;
                  final xi = spot.x.toInt();
                  final label = xi < labels.length ? labels[xi] : '';
                  return LineTooltipItem(
                    '$label\n${_formatAxisValue(spot.y)}',
                    TextStyle(
                      color: AppColors.chartPalette[si % AppColors.chartPalette.length],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          duration: const Duration(milliseconds: 200),
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

    final legend = series.length > 1
        ? Wrap(
            spacing: 12,
            runSpacing: 4,
            children: List.generate(series.length, (i) {
              final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
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
      icon: Icons.show_chart_rounded,
      chartArea: chartArea,
      legend: legend,
      summaryFooter: summaryFooter,
      insightsSection: payload.insights,
      isEmpty: isEmpty,
      emptyMessage: 'No daily activity records found for this period.',
    );
  }

  String _formatAxisValue(double v) {
    if (v >= 3600) return '${(v / 3600).toStringAsFixed(1)}h';
    if (v >= 60) return '${(v / 60).toStringAsFixed(0)}m';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
