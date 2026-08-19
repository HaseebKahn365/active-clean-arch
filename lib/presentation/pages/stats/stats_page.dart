import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/data/services/excel_export_service.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/stats/activity_detail_page.dart';
import 'package:active/presentation/pages/stats/widgets/activity_chart_card.dart';
import 'package:active/presentation/theme/app_theme.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final List<Activity> _activities = [];
  final Map<int, List<double>> _weeklyTotals = {};
  bool _isLoading = true;
  bool _isExporting = false;
  StreamSubscription<void>? _dbSubscription;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _dbSubscription = DatabaseHelper.instance.onDatabaseChanged.listen((_) {
      if (mounted) {
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final activities = await DatabaseHelper.instance.getActivities();
      final weeklyTotals = await DatabaseHelper.instance.getWeeklyDailyTotals();
      if (mounted) {
        setState(() {
          _activities.clear();
          _activities.addAll(activities);
          _weeklyTotals.clear();
          _weeklyTotals.addAll(weeklyTotals);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final path = await ExcelExportService.exportActivitiesToExcel(shareAfterExport: true);
      if (mounted) {
        setState(() => _isExporting = false);
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel file generated successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No activities found to export.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.getSurfaceDark(isDark),
                ),
              )
            : RefreshIndicator(
                color: AppColors.getSurfaceDark(isDark),
                onRefresh: _loadStats,
                child: _activities.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                        children: [
                          Text(
                            'This week',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.getTextPrimary(isDark),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your activity across the last 7 days',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceCard(isDark),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.getBorderCard(isDark),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.show_chart_rounded,
                                  size: 56,
                                  color: AppColors.getTextSubtle(isDark),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No activity statistics yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create activities on the Home tab and log entries to see weekly trends',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.getTextSecondary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                        children: [
                          Text(
                            'This week',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.getTextPrimary(isDark),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your activity across the last 7 days',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 20),
                          for (int i = 0; i < _activities.length; i++) ...[
                            () {
                              final activity = _activities[i];
                              final daily = activity.id != null
                                  ? (_weeklyTotals[activity.id!] ?? List.filled(7, 0.0))
                                  : List.filled(7, 0.0);
                              return ActivityChartCard(
                                activity: activity,
                                dailyValues: daily,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ActivityDetailPage(activity: activity),
                                    ),
                                  );
                                },
                              )
                                .animate(key: ValueKey('chart_${activity.id ?? i}'))
                                .fadeIn(duration: 250.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.08, end: 0, duration: 250.ms, curve: Curves.easeOutCubic);
                            }(),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting || _activities.isEmpty ? null : _exportToExcel,
                              icon: _isExporting
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.getTextOnDark(isDark),
                                      ),
                                    )
                                  : const Icon(Icons.table_view_rounded, size: 20),
                              label: Text(
                                _isExporting ? 'Exporting...' : 'Export to Excel',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getSurfaceDark(isDark),
                                foregroundColor: AppColors.getTextOnDark(isDark),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
              ),
      ),
    );
  }
}
