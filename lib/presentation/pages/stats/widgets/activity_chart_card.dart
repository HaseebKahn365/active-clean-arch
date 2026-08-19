import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.getBorderCard(isDark),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isCount
                            ? AppColors.getCountIconBg(isDark)
                            : AppColors.getTimeIconBg(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCount ? Icons.tag_rounded : Icons.schedule_rounded,
                        size: 18,
                        color: isCount
                            ? AppColors.getCountIcon(isDark)
                            : AppColors.getTimeIcon(isDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              activity.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.getTextSubtle(isDark),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.getBorderSubtle(isDark),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${totalWeek.toInt()} ${totalWeek.toInt() == 1 ? unit : pluralUnit}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Smooth Line Chart with Morph Animation
                SizedBox(
                  height: 120,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 6,
                      minY: minY,
                      maxY: maxY,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceDark,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt().clamp(0, 6);
                              final dayName = resolvedLabels[idx];
                              return LineTooltipItem(
                                '$dayName\n${spot.y.toInt()} $unit',
                                TextStyle(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextOnDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: false,
                        drawVerticalLine: true,
                        getDrawingVerticalLine: (value) => FlLine(
                          color: AppColors.getBorderSubtle(isDark),
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
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: AppColors.getTextSubtle(isDark),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < 7) {
                                final isToday = idx == 6;
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    resolvedLabels[idx],
                                    style: TextStyle(
                                      color: isToday
                                          ? AppColors.getTextPrimary(isDark)
                                          : AppColors.getTextMuted(isDark),
                                      fontSize: 11,
                                      fontWeight: isToday
                                          ? FontWeight.w800
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
                          curveSmoothness: 0.3,
                          preventCurveOverShooting: true,
                          barWidth: 3.0,
                          color: isDark ? const Color(0xFFE4E4E7) : AppColors.lightSurfaceDark,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      const Color(0xFFFFFFFF).withValues(alpha: 0.18),
                                      const Color(0xFFFFFFFF).withValues(alpha: 0.0),
                                    ]
                                  : [
                                      AppColors.lightSurfaceDark.withValues(alpha: 0.16),
                                      AppColors.lightSurfaceDark.withValues(alpha: 0.0),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
