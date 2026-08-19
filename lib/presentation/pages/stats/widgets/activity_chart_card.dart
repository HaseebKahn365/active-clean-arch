import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

class ActivityChartCard extends StatelessWidget {
  const ActivityChartCard({
    super.key,
    required this.activity,
    required this.dailyValues,
    this.dayLabels,
    this.onTap,
  });

  final Activity activity;
  final List<double> dailyValues;
  final List<String>? dayLabels;
  final VoidCallback? onTap;

  List<String> get _resolvedDayLabels {
    if (dayLabels != null && dayLabels!.length == 7) {
      return dayLabels!;
    }
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      if (i == 6) return 'Today';
      final date = now.subtract(Duration(days: 6 - i));
      return weekdays[date.weekday - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCount = activity.type == ActivityType.count;
    final unit = isCount ? 'count' : 'min';
    final pluralUnit = isCount ? 'counts' : 'mins';

    final totalWeek = dailyValues.fold<double>(0, (sum, val) => sum + val);

    final values = dailyValues.length == 7 ? dailyValues : List.filled(7, 0.0);
    final rawMax = values.reduce(math.max);
    final rawMin = values.reduce(math.min);

    // Calculate Y range with headroom for smooth curves
    final maxY = rawMax <= 0 ? 10.0 : (rawMax * 1.25).ceilToDouble();
    final minY = rawMin >= 0 ? 0.0 : (rawMin * 1.25).floorToDouble();

    final spots = List.generate(7, (i) => FlSpot(i.toDouble(), values[i]));
    final resolvedLabels = _resolvedDayLabels;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    child: Icon(
                      isCount ? Icons.tag : Icons.schedule,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            activity.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${totalWeek.toInt()} ${totalWeek.toInt() == 1 ? unit : pluralUnit}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Smooth Line Chart
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 6,
                    minY: minY,
                    maxY: maxY,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => colorScheme.surfaceContainerHigh,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt().clamp(0, 6);
                            final dayName = resolvedLabels[idx];
                            return LineTooltipItem(
                              '$dayName\n${spot.y.toInt()} $unit',
                              theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ) ?? const TextStyle(),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: colorScheme.outline.withValues(alpha: 0.12),
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (value) => FlLine(
                        color: colorScheme.outline.withValues(alpha: 0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max || value == meta.min) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                value.toInt().toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < 7) {
                              final isToday = idx == 6;
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  resolvedLabels[idx],
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isToday
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        preventCurveOverShooting: true,
                        barWidth: 3.5,
                        color: colorScheme.primary,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.38),
                              colorScheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
