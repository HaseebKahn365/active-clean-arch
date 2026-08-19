import 'dart:async';
import 'package:flutter/material.dart';
import 'package:active/data/datasources/database_helper.dart';
import 'package:active/data/services/excel_export_service.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/stats/activity_detail_page.dart';
import 'package:active/presentation/pages/stats/widgets/activity_chart_card.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: _activities.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.55,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.show_chart_rounded,
                                    size: 64,
                                    color: colorScheme.outline.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No activity statistics yet',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create activities on the Home tab and log entries to see weekly trends',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Text(
                                "This Week's Activity",
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._activities.map((activity) {
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
                            );
                          }),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isExporting || _activities.isEmpty ? null : _exportToExcel,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.table_view_rounded),
                            label: Text(_isExporting ? 'Exporting...' : 'Export to Excel'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
      ),
    );
  }
}
