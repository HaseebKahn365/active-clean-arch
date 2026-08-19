import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/stats/widgets/monthly_heat_map.dart';
import 'package:active/presentation/theme/app_theme.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.activity,
  });

  final Activity activity;

  /// Formats a record timestamp day-first, e.g. "3 Mar 2026 • 2:30 PM".
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCount = widget.activity.type == ActivityType.count;
    final unit = isCount ? 'count' : 'min';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.getSurfaceCard(isDark),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.getBorderCard(isDark)),
          ),
          title: Text(
            'Delete Entry',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          content: Text(
            'Are you sure you want to delete this record entry of ${record.quantity >= 0 ? "+${record.quantity}" : "${record.quantity}"} $unit logged on ${_formatDateTime(record.timestamp)}?',
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.getTextSecondary(isDark)),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCount = widget.activity.type == ActivityType.count;
    final unit = isCount ? 'count' : 'min';

    final monthTotal = _monthlyTotals.values.fold<int>(0, (sum, v) => sum + v);
    final activeDaysCount = _monthlyTotals.values.where((v) => v > 0).length;
    final avgPerActiveDay = activeDaysCount > 0 ? (monthTotal / activeDaysCount) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.getSurfaceDark(isDark),
                ),
              )
            : RefreshIndicator(
                color: AppColors.getSurfaceDark(isDark),
                onRefresh: _loadAllData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                  children: [
                    // Header with back navigation & type pill
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceSubtle(isDark),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, size: 18),
                            padding: EdgeInsets.zero,
                            color: AppColors.getTextPrimary(isDark),
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Back to Stats',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.activity.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.getTextPrimary(isDark),
                              letterSpacing: -0.4,
                            ),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCount ? Icons.tag_rounded : Icons.schedule_rounded,
                                size: 14,
                                color: isCount
                                    ? AppColors.getCountIcon(isDark)
                                    : AppColors.getTimeIcon(isDark),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isCount ? 'Count' : 'Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Hero Card: All-Time Total (Solid dark container)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceDark,
                        borderRadius: BorderRadius.circular(28),
                        border: isDark
                            ? Border.all(color: AppColors.darkBorderCard)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All-Time Total',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lightTextMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_stats.totalQuantity}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1.0,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$unit all-time',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Stat Pills Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatPill(
                          label: 'Month',
                          value: '$monthTotal $unit',
                        ),
                        _StatPill(
                          label: 'Daily avg',
                          value: avgPerActiveDay.toStringAsFixed(1),
                        ),
                        _StatPill(
                          label: 'Entries',
                          value: '$_totalRecordCount',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Monthly Heat Map Section
                    Text(
                      'Monthly Heat Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(isDark),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MonthlyHeatMap(
                      currentMonth: _selectedMonth,
                      dailyTotals: _monthlyTotals,
                      activityType: widget.activity.type,
                      onMonthChanged: _onMonthChanged,
                    ),
                    const SizedBox(height: 24),

                    // Historical Scrollable Chart Section with Sliding Range Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'History Trend',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.getTextPrimary(isDark),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Container(
                          width: 144,
                          height: 36,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceSubtle(isDark),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final itemW = constraints.maxWidth / 3;
                              final align = _selectedRangeDays == 7
                                  ? const Alignment(-1.0, 0.0)
                                  : _selectedRangeDays == 30
                                      ? const Alignment(0.0, 0.0)
                                      : const Alignment(1.0, 0.0);

                              return Stack(
                                children: [
                                  AnimatedAlign(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    alignment: align,
                                    child: Container(
                                      width: itemW,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: AppColors.getSurfaceDark(isDark),
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isDark ? Colors.black45 : Colors.black12,
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RangePill(
                                          label: '7D',
                                          isSelected: _selectedRangeDays == 7,
                                          onTap: () => _onRangeChanged(7),
                                        ),
                                      ),
                                      Expanded(
                                        child: _RangePill(
                                          label: '30D',
                                          isSelected: _selectedRangeDays == 30,
                                          onTap: () => _onRangeChanged(30),
                                        ),
                                      ),
                                      Expanded(
                                        child: _RangePill(
                                          label: '90D',
                                          isSelected: _selectedRangeDays == 90,
                                          onTap: () => _onRangeChanged(90),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceCard(isDark),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.getBorderCard(isDark),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: _HistoricalTrendChart(
                        dailyTotals: _historicalTotals,
                        days: _selectedRangeDays,
                        unit: unit,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Paginated Recent Record Entries Section
                    Text(
                      'Record Entries ($_totalRecordCount)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(isDark),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_records.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceCard(isDark),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.getBorderCard(isDark),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'No records logged yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceCard(isDark),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.getBorderCard(isDark),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _records.length,
                          separatorBuilder: (context, i) => Divider(
                            height: 1,
                            color: AppColors.getBorderDivider(isDark),
                          ),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                  ),
                                  Text(
                                    '(${_timeAgo(r.timestamp)})',
                                    style: TextStyle(
                                      color: AppColors.getTextMuted(isDark),
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
                                          ? AppColors.getSurfaceSubtle(isDark)
                                          : (isDark ? const Color(0xFF3B1A1E) : const Color(0xFFFFEEEE)),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${isPositive ? '+' : ''}${r.quantity} $unit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: isPositive
                                            ? AppColors.getTextPrimary(isDark)
                                            : AppColors.error,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.getTextSubtle(isDark),
                                    ),
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
                            ? CircularProgressIndicator(
                                color: AppColors.getSurfaceDark(isDark),
                              )
                            : TextButton.icon(
                                onPressed: _loadMoreRecords,
                                icon: Icon(
                                  Icons.expand_more,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                label: Text(
                                  'Load More (${_records.length} of $_totalRecordCount)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCard(isDark),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.getBorderCard(isDark),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextMuted(isDark),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? AppColors.getTextOnDark(isDark)
                : AppColors.getTextSecondary(isDark),
          ),
          child: Text(label),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final values = dailyTotals.length == days ? dailyTotals : List.filled(days, 0.0);
    final rawMax = values.fold<double>(0.0, math.max);
    final rawMin = values.fold<double>(0.0, math.min);

    final maxY = rawMax <= 0 ? 10.0 : (rawMax * 1.25).ceilToDouble();
    final minY = rawMin >= 0 ? 0.0 : (rawMin * 1.25).floorToDouble();

    final spots = List.generate(days, (i) => FlSpot(i.toDouble(), values[i]));

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (days - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceDark,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final dayOffset = (days - 1) - spot.x.toInt();
                  final date = DateTime.now().subtract(Duration(days: dayOffset));
                  final dateStr = ActivityDetailPage.formatShortDate(date);
                  return LineTooltipItem(
                    '$dateStr\n${spot.y.toInt()} $unit',
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
            getDrawingVerticalLine: (_) => FlLine(
              color: AppColors.getBorderSubtle(isDark),
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
                          style: TextStyle(
                            color: AppColors.getTextPrimary(isDark),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }
                    final date = DateTime.now().subtract(Duration(days: dayOffset));
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        ActivityDetailPage.formatShortDate(date),
                        style: TextStyle(
                          color: AppColors.getTextMuted(isDark),
                          fontSize: 11,
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
    );
  }
}
