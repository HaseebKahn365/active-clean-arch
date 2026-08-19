import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/stats/widgets/monthly_heat_map.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.activity,
  });

  final Activity activity;

  /// Formats a record timestamp day-first, e.g. "3 Mar 2026 • 2:30 PM".
  /// Day always precedes the month; never month-first.
  static String formatRecordTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $m ${dt.year} • $hour:$min $period';
  }

  /// Formats a short axis/tooltip label day-first, e.g. "3/9".
  static String formatShortDate(DateTime date) => '${date.day}/${date.month}';

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<int, int> _monthlyTotals = {};
  ActivityStats _stats = const ActivityStats();

  int _selectedRangeDays = 30;
  List<double> _historicalTotals = [];

  final List<ActivityRecord> _records = [];
  int _totalRecordCount = 0;
  bool _isLoadingMore = false;
  bool _isLoading = true;
  static const int _pageSize = 15;
  StreamSubscription<void>? _dbSubscription;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _dbSubscription = DatabaseHelper.instance.onDatabaseChanged.listen((_) {
      if (mounted) {
        _loadAllData();
      }
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (widget.activity.id == null) return;
    final actId = widget.activity.id!;

    try {
      final monthly = await DatabaseHelper.instance.getMonthlyDailyTotals(
        actId,
        _selectedMonth.year,
        _selectedMonth.month,
      );
      final stats = await DatabaseHelper.instance.getActivityStats(actId);
      final history = await DatabaseHelper.instance.getHistoricalDailyTotals(
        actId,
        days: _selectedRangeDays,
      );
      final count = await DatabaseHelper.instance.getRecordCountForActivity(actId);
      final initialRecords = await DatabaseHelper.instance.getPaginatedRecords(
        actId,
        limit: _pageSize,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _monthlyTotals = monthly;
          _stats = stats;
          _historicalTotals = history;
          _totalRecordCount = count;
          _records.clear();
          _records.addAll(initialRecords);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onMonthChanged(DateTime newMonth) async {
    setState(() {
      _selectedMonth = DateTime(newMonth.year, newMonth.month, 1);
    });
    if (widget.activity.id != null) {
      final monthly = await DatabaseHelper.instance.getMonthlyDailyTotals(
        widget.activity.id!,
        _selectedMonth.year,
        _selectedMonth.month,
      );
      if (mounted) {
        setState(() {
          _monthlyTotals = monthly;
        });
      }
    }
  }

  Future<void> _onRangeChanged(int days) async {
    setState(() {
      _selectedRangeDays = days;
    });
    if (widget.activity.id != null) {
      final history = await DatabaseHelper.instance.getHistoricalDailyTotals(
        widget.activity.id!,
        days: days,
      );
      if (mounted) {
        setState(() {
          _historicalTotals = history;
        });
      }
    }
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || _records.length >= _totalRecordCount || widget.activity.id == null) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final moreRecords = await DatabaseHelper.instance.getPaginatedRecords(
        widget.activity.id!,
        limit: _pageSize,
        offset: _records.length,
      );

      if (mounted) {
        setState(() {
          _records.addAll(moreRecords);
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _deleteRecord(ActivityRecord record) async {
    if (record.id == null) return;
    final isCount = widget.activity.type == ActivityType.count;
    final unit = isCount ? 'count' : 'min';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Delete Entry'),
          content: Text(
            'Are you sure you want to delete this record entry of ${record.quantity >= 0 ? "+${record.quantity}" : "${record.quantity}"} $unit logged on ${_formatDateTime(record.timestamp)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && record.id != null) {
      await DatabaseHelper.instance.deleteRecord(record.id!);
    }
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  String _formatDateTime(DateTime dt) =>
      ActivityDetailPage.formatRecordTimestamp(dt);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCount = widget.activity.type == ActivityType.count;
    final unit = isCount ? 'count' : 'min';
    final pluralUnit = isCount ? 'counts' : 'mins';

    final monthTotal = _monthlyTotals.values.fold<int>(0, (sum, v) => sum + v);
    final activeDaysCount = _monthlyTotals.values.where((v) => v > 0).length;
    final avgPerActiveDay = activeDaysCount > 0 ? (monthTotal / activeDaysCount) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header with back navigation
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Back to Stats',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.activity.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Chip(
                          avatar: Icon(
                            isCount ? Icons.tag : Icons.schedule,
                            size: 16,
                          ),
                          label: Text(isCount ? 'Count' : 'Time'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4 Overview Metric Cards
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricCard(
                            label: 'All-Time Total',
                            value: '${_stats.totalQuantity}',
                            subtitle: pluralUnit,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DetailMetricCard(
                            label: 'Month Total',
                            value: '$monthTotal',
                            subtitle: pluralUnit,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricCard(
                            label: 'Daily Active Avg',
                            value: avgPerActiveDay.toStringAsFixed(1),
                            subtitle: '$unit/active day',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DetailMetricCard(
                            label: 'Total Entries',
                            value: '$_totalRecordCount',
                            subtitle: 'entries logged',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Monthly Heat Map Section
                    Text(
                      'Monthly Heat Map',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MonthlyHeatMap(
                      currentMonth: _selectedMonth,
                      dailyTotals: _monthlyTotals,
                      activityType: widget.activity.type,
                      onMonthChanged: _onMonthChanged,
                    ),
                    const SizedBox(height: 24),

                    // Historical Scrollable Chart Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'History Trend',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 7, label: Text('7D')),
                            ButtonSegment(value: 30, label: Text('30D')),
                            ButtonSegment(value: 90, label: Text('90D')),
                          ],
                          selected: {_selectedRangeDays},
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onSelectionChanged: (selection) {
                            _onRangeChanged(selection.first);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _HistoricalTrendChart(
                          dailyTotals: _historicalTotals,
                          days: _selectedRangeDays,
                          unit: unit,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Paginated Recent Record Entries Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Record Entries ($_totalRecordCount)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_records.isEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No records logged yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _records.length,
                          separatorBuilder: (context, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final r = _records[index];
                            final isPositive = r.quantity >= 0;

                            return ListTile(
                              dense: true,
                              title: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    _formatDateTime(r.timestamp),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '(${_timeAgo(r.timestamp)})',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? colorScheme.surfaceContainerHigh
                                          : const Color(0xFFFF7043).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${isPositive ? '+' : ''}${r.quantity} $unit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isPositive
                                            ? colorScheme.primary
                                            : const Color(0xFFE64A19),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _deleteRecord(r),
                                    tooltip: 'Delete entry',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // Load More Pagination Button
                    if (_records.length < _totalRecordCount) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: _isLoadingMore
                            ? const CircularProgressIndicator()
                            : TextButton.icon(
                                onPressed: _loadMoreRecords,
                                icon: const Icon(Icons.expand_more),
                                label: Text(
                                  'Load More (${_records.length} of $_totalRecordCount)',
                                ),
                              ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  const _DetailMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricalTrendChart extends StatelessWidget {
  const _HistoricalTrendChart({
    required this.dailyTotals,
    required this.days,
    required this.unit,
  });

  final List<double> dailyTotals;
  final int days;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final values = dailyTotals.length == days ? dailyTotals : List.filled(days, 0.0);
    final rawMax = values.fold<double>(0.0, math.max);
    final rawMin = values.fold<double>(0.0, math.min);

    final maxY = rawMax <= 0 ? 10.0 : (rawMax * 1.25).ceilToDouble();
    final minY = rawMin >= 0 ? 0.0 : (rawMin * 1.25).floorToDouble();

    final spots = List.generate(days, (i) => FlSpot(i.toDouble(), values[i]));

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (days - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => colorScheme.surfaceContainerHigh,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final dayOffset = (days - 1) - spot.x.toInt();
                  final date = DateTime.now().subtract(Duration(days: dayOffset));
                  final dateStr = ActivityDetailPage.formatShortDate(date);
                  return LineTooltipItem(
                    '$dateStr\n${spot.y.toInt()} $unit',
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
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.outline.withValues(alpha: 0.12),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (_) => FlLine(
              color: colorScheme.outline.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                reservedSize: 24,
                interval: (days / 4).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < days) {
                    final dayOffset = (days - 1) - idx;
                    if (dayOffset == 0) {
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          'Today',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    final date = DateTime.now().subtract(Duration(days: dayOffset));
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        ActivityDetailPage.formatShortDate(date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              barWidth: 3.0,
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
    );
  }
}
