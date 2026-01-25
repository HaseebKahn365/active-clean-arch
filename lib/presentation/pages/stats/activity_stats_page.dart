import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/stats_provider.dart';
import '../../providers/activity_manager_provider.dart';
import 'helpers/time_axis_formatter.dart';
import '../../widgets/interactive_bar_chart.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_event.dart';

class ActivityStatsPage extends StatefulWidget {
  final String activityId;

  const ActivityStatsPage({super.key, required this.activityId});

  @override
  State<ActivityStatsPage> createState() => _ActivityStatsPageState();
}

class _ActivityStatsPageState extends State<ActivityStatsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<TimeRange> _tabs = [TimeRange.day, TimeRange.week, TimeRange.month, TimeRange.year];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: 1); // Default to Week
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<StatsController>().setRange(_tabs[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsController>();
    final activityController = context.watch<ActivityController>();
    final activity = activityController.activitiesMap[widget.activityId];
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (activity == null) {
      return const Scaffold(body: Center(child: Text('Activity data not found')));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Column(
          children: [
            FutureBuilder<List<Activity>>(
              future: activityController.getBreadcrumbs(widget.activityId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final path = snapshot.data!.map((a) => a.name.toUpperCase()).join(' > ');
                return Text(
                  path,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                );
              },
            ),
            Text(activity.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isDesktop,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: _tabs.map((t) => Tab(text: t.name.toUpperCase())).toList(),
        ),
      ),
      body: !stats.hasData
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _tabs
                  .map((range) => _buildRangeContent(context, stats, activity, activityController, isDesktop))
                  .toList(),
            ),
    );
  }

  Widget _buildRangeContent(
    BuildContext context,
    StatsController stats,
    Activity activity,
    ActivityController activityController,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? _buildDesktopLayout(context, stats, activity, activityController, isDesktop)
              : _buildMobileLayout(context, stats, activity, activityController, isDesktop),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    StatsController stats,
    Activity activity,
    ActivityController controller,
    bool isDesktop,
  ) {
    return Column(
      children: [
        _buildHeroStatus(context, activity, controller),
        const SizedBox(height: 32),
        _buildQuickStats(context, stats, activity, isDesktop),
        const SizedBox(height: 32),
        _buildPerformanceChart(context, stats, activity, isDesktop),
        const SizedBox(height: 32),
        _buildSessionTimeline(context, stats, activity),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    StatsController stats,
    Activity activity,
    ActivityController controller,
    bool isDesktop,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildHeroStatus(context, activity, controller),
                  const SizedBox(height: 32),
                  _buildQuickStats(context, stats, activity, true),
                ],
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildPerformanceChart(context, stats, activity, true),
                  const SizedBox(height: 32),
                  _buildSessionTimeline(context, stats, activity),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroStatus(BuildContext context, Activity activity, ActivityController controller) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCountBased = activity.type == ActivityType.countBased;

    final val = isCountBased
        ? controller.getCountTotalFor(widget.activityId)
        : controller.getEffectiveSeconds(widget.activityId).toDouble();

    // Adjust goal label based on range
    String goalLabel = 'DAILY GOAL';
    if (_tabs[_tabController.index] == TimeRange.week) goalLabel = 'WEEKLY GOAL';
    if (_tabs[_tabController.index] == TimeRange.month) goalLabel = 'MONTHLY GOAL';
    if (_tabs[_tabController.index] == TimeRange.year) goalLabel = 'ANNUAL GOAL';

    final goalMult = _getGoalMultiplier(_tabs[_tabController.index]);
    final goal =
        (activity.goalSeconds > 0 ? activity.goalSeconds.toDouble() : (isCountBased ? 10.0 : 3600.0)) * goalMult;

    final progress = (val / goal).clamp(0.0, 1.0);
    final displayVal = isCountBased ? val.toInt().toString() : _formatToClock(val.toInt());

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: activity.status == ActivityStatus.running && !isCountBased
                ? colorScheme.secondary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activity.status == ActivityStatus.running && !isCountBased
                  ? colorScheme.secondary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activity.status == ActivityStatus.running && !isCountBased) _PulseDot(color: colorScheme.secondary),
              if (activity.status == ActivityStatus.running && !isCountBased) const SizedBox(width: 8),
              Text(
                (isCountBased ? 'COUNT BASED' : activity.status.name).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: activity.status == ActivityStatus.running && !isCountBased
                      ? colorScheme.secondary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 95,
                  startDegreeOffset: 270,
                  sections: [
                    PieChartSectionData(color: colorScheme.primary, value: progress, radius: 12, showTitle: false),
                    PieChartSectionData(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                      value: 1 - progress,
                      radius: 12,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayVal,
                      style: TextStyle(
                        fontSize: isCountBased ? 72 : 54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$goalLabel ',
                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          isCountBased ? goal.toInt().toString() : _formatToClock(goal.toInt()),
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getGoalMultiplier(TimeRange range) {
    switch (range) {
      case TimeRange.day:
        return 1.0;
      case TimeRange.week:
        return 7.0;
      case TimeRange.month:
        return 30.0;
      case TimeRange.year:
        return 365.0;
      default:
        return 1.0;
    }
  }

  String _formatToClock(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Widget _buildQuickStats(BuildContext context, StatsController stats, Activity activity, bool isDesktop) {
    final isCountBased = activity.type == ActivityType.countBased;

    if (isCountBased) {
      final metrics = stats.getAllCountBasedMetrics()[activity.name];
      if (metrics == null) return const SizedBox.shrink();

      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Total Count',
                  metrics.totalCount.toInt().toString(),
                  Icons.analytics_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Time Spent',
                  _formatDurationSimple(metrics.totalTimeSpent),
                  Icons.timer_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            'Efficiency (Units per Hour)',
            '${metrics.efficiencyPerHour.toStringAsFixed(1)} / hr',
            Icons.speed_rounded,
            Colors.green,
          ),
        ],
      );
    }

    final trend = stats.getActivityTrend(widget.activityId);
    final totalSeconds = trend.values.fold(0, (sum, v) => sum + v);
    final avgSeconds = trend.isEmpty ? 0 : totalSeconds / trend.length;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            context,
            'Total Time',
            _formatDurationSimple(totalSeconds),
            Icons.history_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            context,
            'Avg / Period',
            _formatDurationSimple(avgSeconds.toInt()),
            Icons.speed_rounded,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  String _formatDurationSimple(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
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
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(BuildContext context, StatsController stats, Activity activity, bool isDesktop) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCountBased = activity.type == ActivityType.countBased;

    final Map<DateTime, double> trend = isCountBased
        ? (stats.getAllCountBasedMetrics()[activity.name]?.dailyCounts ?? {})
        : stats.getActivityTrend(widget.activityId).map((k, v) => MapEntry(k, v / 3600.0));

    final sortedEntry = trend.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (trend.values.every((v) => v == 0)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCountBased ? 'Performance Volume' : 'Focus Trend',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: InteractiveBarChart(
              dataCount: sortedEntry.length,
              barValues: sortedEntry.map((e) => e.value).toList(),
              initialWindowSize: stats.selectedRange == TimeRange.month
                  ? 15
                  : (stats.selectedRange == TimeRange.year ? 30 : 7),
              dataBuilder: (minX, maxX, minY, maxY) => BarChartData(
                minY: minY,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final index = group.x.round();
                      if (index < 0 || index >= sortedEntry.length) return null;
                      final date = sortedEntry[index].key;
                      final val = rod.toY.toStringAsFixed(isCountBased ? 0 : 1);
                      final unit = isCountBased ? 'units' : 'h';
                      return BarTooltipItem(
                        '${TimeAxisFormatter.getTooltipDateFormat(date, stats.selectedRange)}\n$val $unit',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: colorScheme.outlineVariant.withValues(alpha: 0.1), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: TimeAxisFormatter.getInterval(maxX - minX, stats.selectedRange),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index >= sortedEntry.length || index < 0) {
                          return const SizedBox();
                        }

                        if ((value - index).abs() > 0.01) return const SizedBox();

                        final date = sortedEntry[index].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            TimeAxisFormatter.formatXAxis(date, stats.selectedRange),
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final valStr = isCountBased ? value.toInt().toString() : '${value.toStringAsFixed(1)}h';
                        return Text(
                          valStr,
                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: List.generate(sortedEntry.length, (i) {
                  if (i < minX - 1 || i > maxX + 1) return null;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: sortedEntry[i].value,
                        color: i == sortedEntry.length - 1
                            ? colorScheme.primary
                            : colorScheme.primary.withValues(alpha: 0.3),
                        width: isDesktop
                            ? (24 / (maxX - minX + 1) * 7).clamp(8, 24)
                            : (16 / (maxX - minX + 1) * 7).clamp(4, 16),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).whereType<BarChartGroupData>().toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTimeline(BuildContext context, StatsController stats, Activity activity) {
    final events = stats.getActivityEvents(widget.activityId);
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Center(child: Text('No session history available')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        ...events.take(5).map((e) => _buildTimelineItem(context, e)),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, ActivityEvent event) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = DateFormat('hh:mm a').format(event.timestamp);
    final dateStr = DateFormat('MMM d').format(event.timestamp);
    final isFocus = event.durationDelta > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Container(width: 2, height: 32, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFocus ? 'FOCUS SESSION' : 'STATE CHANGE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isFocus ? colorScheme.primary : Colors.orange,
                  ),
                ),
                Text(
                  isFocus
                      ? '+${(event.durationDelta / 60).toStringAsFixed(1)}m added'
                      : 'Status: ${event.nextStatus.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(
            isFocus ? Icons.add_circle_outline_rounded : Icons.sync_problem_rounded,
            color: isFocus ? colorScheme.primary : Colors.orange,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
