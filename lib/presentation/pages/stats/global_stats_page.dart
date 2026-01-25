import 'package:active/presentation/widgets/mac_swipe_back_navigator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/stats_provider.dart';
import '../../../domain/entities/activity.dart';
import 'package:intl/intl.dart';
import 'helpers/time_axis_formatter.dart';
import '../../widgets/interactive_line_chart.dart';
import '../../widgets/interactive_bar_chart.dart';

class GlobalStatsPage extends StatefulWidget {
  const GlobalStatsPage({super.key});

  @override
  State<GlobalStatsPage> createState() => _GlobalStatsPageState();
}

class _GlobalStatsPageState extends State<GlobalStatsPage> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsController>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Analytical Dashboard', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        // actions: [_buildDesktopRangeSelector(stats), const SizedBox(width: 16)],
      ),
      body: !stats.hasData
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: _buildRangeSelector(stats),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: isDesktop ? _buildDesktopLayout(context, stats) : _buildMobileLayout(context, stats),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, StatsController stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryGrid(context, stats, crossAxisCount: 2),
        const SizedBox(height: 24),
        _buildMainTrendChart(context, stats),
        const SizedBox(height: 24),
        _buildCategoryBreakdown(context, stats),
        const SizedBox(height: 24),
        _buildTopActivities(context, stats),
        const SizedBox(height: 24),
        _buildCountBasedMetrics(context, stats),
      ],
    );
  }

  Widget _buildRangeSelector(StatsController stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TimeRange.values.map((range) {
          final isSelected = stats.selectedRange == range;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(range.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              onSelected: (_) => stats.setRange(range),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, StatsController stats) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildSummaryGrid(context, stats, crossAxisCount: 4),
                  const SizedBox(height: 24),
                  _buildMainTrendChart(context, stats),
                  const SizedBox(height: 24),
                  _buildCountBasedMetrics(context, stats),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildCategoryBreakdown(context, stats),
                  const SizedBox(height: 24),
                  _buildTopActivities(context, stats),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(BuildContext context, StatsController stats, {required int crossAxisCount}) {
    final focusSeconds = stats.getTotalFocusTime();
    final focusDuration = Duration(seconds: focusSeconds);
    final colorScheme = Theme.of(context).colorScheme;
    final hours = focusDuration.inHours;

    final minutes = focusDuration.inMinutes % 60;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.0,
      children: [
        _buildStatCard(
          context,
          'Total Focus',
          '${hours}h ${minutes}m',
          Icons.timer_rounded,
          Theme.of(context).colorScheme.primary,
        ),
        _buildStatCard(context, 'Daily Average', _calculateDailyAvg(stats), Icons.auto_graph_rounded, Colors.orange),
        _buildStatCard(context, 'Goal Progress', '85%', Icons.flag_rounded, colorScheme.secondary),
        _buildStatCard(context, 'Active Streak', '12 Days', Icons.local_fire_department_rounded, Colors.redAccent),
      ],
    );
  }

  String _calculateDailyAvg(StatsController stats) {
    final data = stats.getFocusTimeByDay();
    if (data.isEmpty) return '0h';
    final total = data.values.fold(0, (sum, v) => sum + v);
    final avg = total / data.length;
    final hours = (avg / 3600).toStringAsFixed(1);
    return '${hours}h';
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTrendChart(BuildContext context, StatsController stats) {
    final colorScheme = Theme.of(context).colorScheme;
    final dataMap = stats.getFocusTimeByDay();
    final sortedDates = dataMap.keys.toList()..sort();

    if (dataMap.values.every((v) => v == 0)) {
      return _buildEmptyState('No activity tracked in this period');
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataMap[sortedDates[i]]!.toDouble() / 3600));
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Focus Time Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(
                '${stats.selectedRange.name.toUpperCase()} VIEW',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 350,
            child: InteractiveLineChart(
              spots: spots,
              initialWindowSize: stats.selectedRange == TimeRange.month
                  ? 30
                  : (stats.selectedRange == TimeRange.year ? 365 : 7),
              dataBuilder: (minX, maxX, minY, maxY) => LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.none(),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots
                          .map((spot) {
                            final index = spot.x.round();
                            if (index < 0 || index >= sortedDates.length) return null;
                            final date = sortedDates[index];
                            final hours = spot.y.toStringAsFixed(1);
                            return LineTooltipItem(
                              '${TimeAxisFormatter.getTooltipDateFormat(date, stats.selectedRange)}\n$hours hours',
                              const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          })
                          .toList()
                          .whereType<LineTooltipItem>()
                          .toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  verticalInterval: TimeAxisFormatter.getInterval(maxX - minX, stats.selectedRange),
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: colorScheme.outlineVariant.withValues(alpha: 0.1), strokeWidth: 1),
                  getDrawingVerticalLine: (value) =>
                      FlLine(color: colorScheme.outlineVariant.withValues(alpha: 0.1), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(1)}h',
                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: TimeAxisFormatter.getInterval(maxX - minX, stats.selectedRange),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index >= sortedDates.length || index < 0) {
                          return const SizedBox();
                        }

                        if ((value - index).abs() > 0.01) return const SizedBox();

                        final date = sortedDates[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            TimeAxisFormatter.formatXAxis(date, stats.selectedRange),
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [colorScheme.primary.withValues(alpha: 0.2), colorScheme.primary.withValues(alpha: 0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, StatsController stats) {
    final colorScheme = Theme.of(context).colorScheme;
    final distribution = stats.getCategoryDistribution();

    if (distribution.isEmpty || distribution.values.every((v) => v == 0)) {
      return _buildEmptyState('No category data');
    }

    final total = distribution.values.fold(0, (sum, v) => sum + v);

    final colors = [colorScheme.primary, Colors.orange, colorScheme.secondary, Colors.purpleAccent, Colors.cyan];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Category Allocation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 4,
                centerSpaceRadius: 70,
                sections: distribution.entries.toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final isTouched = index == touchedIndex;
                  final value = entry.value.value;
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: value.toDouble(),
                    title: isTouched ? '${(value / total * 100).toInt()}%' : '',
                    radius: isTouched ? 30 : 20,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: distribution.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: colors[index % colors.length], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value.key} (${(entry.value.value / 3600).toStringAsFixed(1)}h)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActivities(BuildContext context, StatsController stats) {
    final top = stats.getTopActivities();
    if (top.isEmpty) return const SizedBox.shrink();

    final maxVal = top.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ...top.map((entry) => _buildTopActivityTile(context, entry.key, entry.value, maxVal)),
      ],
    );
  }

  Widget _buildTopActivityTile(BuildContext context, Activity activity, int seconds, int maxSeconds) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final percentage = (seconds / maxSeconds);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bolt_rounded, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      '${hours}h ${minutes}m total',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.trending_up, color: colorScheme.secondary, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
              color: colorScheme.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBasedMetrics(BuildContext context, StatsController stats) {
    final metrics = stats.getAllCountBasedMetrics();
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Volume', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                MacSwipeBackNavigator.isBlocked = true;
              } else if (notification is ScrollEndNotification) {
                MacSwipeBackNavigator.isBlocked = false;
              }
              return false;
            },
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(), // Ensure it can overscroll slightly
              children: () {
                final list = metrics.values.toList();
                list.sort((a, b) {
                  final aLatest = a.dailyCounts.keys.isEmpty
                      ? DateTime(2000)
                      : a.dailyCounts.keys.reduce((curr, next) => curr.isAfter(next) ? curr : next);
                  final bLatest = b.dailyCounts.keys.isEmpty
                      ? DateTime(2000)
                      : b.dailyCounts.keys.reduce((curr, next) => curr.isAfter(next) ? curr : next);
                  return bLatest.compareTo(aLatest);
                });
                return list.map((m) => _buildDensityCard(context, m)).toList();
              }(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDensityCard(BuildContext context, CountBasedMetrics metrics) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortedDates = metrics.dailyCounts.keys.toList()..sort();

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  metrics.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${metrics.totalCount.toInt()}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniMetric('TIME', '${(metrics.totalTimeSpent / 3600).toStringAsFixed(1)}h'),
              const SizedBox(width: 12),
              // _buildMiniMetric('EFF.', '${metrics.efficiencyPerHour.toStringAsFixed(1)}/h'),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 100, // Slightly taller for pan/zoom space
            child: InteractiveBarChart(
              dataCount: sortedDates.length,
              barValues: sortedDates.map((d) => metrics.dailyCounts[d] ?? 0.0).toList(),
              initialWindowSize: 14,
              minWindowSize: 4,
              topPadding: 10,
              dataBuilder: (minX, maxX, minY, maxY) {
                final barValues = sortedDates.map((d) => metrics.dailyCounts[d] ?? 0.0).toList();
                return BarChartData(
                  minY: minY,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: List.generate(sortedDates.length, (i) {
                    if (i < minX - 1 || i > maxX + 1) return null;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: barValues[i],
                          color: colorScheme.primary,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    );
                  }).whereType<BarChartGroupData>().toList(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final date = sortedDates[group.x];
                        return BarTooltipItem(
                          '${DateFormat('MMM d').format(date)}\n${rod.toY.toInt()} units',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= sortedDates.length) return const SizedBox.shrink();

                          // Only show labels for first and last visible bars to keep it minimalist
                          final bool isStart = (value - minX).abs() < 0.5;
                          final bool isEnd = (value - maxX).abs() < 0.5;

                          if (!isStart && !isEnd) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('d MMM').format(sortedDates[index]),
                              style: TextStyle(
                                fontSize: 8,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.grey),
        ),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
