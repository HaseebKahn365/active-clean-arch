import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/home/widgets/activity_list_item.dart';
import 'package:active/presentation/pages/home/widgets/create_activity_field.dart';
import 'package:active/presentation/providers/theme_provider.dart';
import 'package:active/presentation/theme/app_theme.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final List<Activity> _activities = [];
  final Map<int, ActivityStats> _stats = {};
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'count', 'time'
  StreamSubscription<void>? _dbSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _dbSubscription = DatabaseHelper.instance.onDatabaseChanged.listen((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final activities = await DatabaseHelper.instance.getActivities();
      final stats = await DatabaseHelper.instance.getAllActivityStats();
      if (mounted) {
        setState(() {
          _activities.clear();
          _activities.addAll(activities);
          _stats.clear();
          _stats.addAll(stats);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addActivity(String name, ActivityType type) async {
    final activity = Activity(
      name: name,
      type: type,
      createdAt: DateTime.now(),
    );

    try {
      await DatabaseHelper.instance.insertActivity(activity);
    } catch (_) {
      if (mounted) {
        setState(() {
          _activities.insert(0, activity);
        });
      }
    }
  }

  Future<void> _addRecord(Activity activity, int quantity) async {
    if (activity.id == null) return;

    final record = ActivityRecord(
      activityId: activity.id!,
      quantity: quantity,
      timestamp: DateTime.now(),
    );

    try {
      await DatabaseHelper.instance.insertRecord(record);
    } catch (_) {
      // Handle error gracefully
    }
  }

  Future<void> _deleteActivity(Activity activity) async {
    if (activity.id == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            'Delete Activity',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${activity.name}"? All associated records and statistics will be permanently removed.',
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

    if (confirmed == true && activity.id != null) {
      await DatabaseHelper.instance.deleteActivity(activity.id!);
    }
  }

  List<Activity> get _filteredActivities {
    if (_selectedFilter == 'count') {
      return _activities.where((a) => a.type == ActivityType.count).toList();
    } else if (_selectedFilter == 'time') {
      return _activities.where((a) => a.type == ActivityType.time).toList();
    }
    return _activities;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredActivities;

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
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  children: [
                    // Header Row with Title & Theme Switcher Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Activities',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.getTextPrimary(isDark),
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Animated Dark/Light Theme Toggle Button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceSubtle(isDark),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.getBorderSubtle(isDark),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) => RotationTransition(
                                turns: anim,
                                child: ScaleTransition(scale: anim, child: child),
                              ),
                              child: Icon(
                                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                key: ValueKey(isDark),
                                size: 20,
                                color: isDark ? AppColors.goldAccent : AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                            onPressed: () {
                              ref.read(themeProvider.notifier).toggleTheme();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filter Chips Row (All, Count, Time)
                    Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _selectedFilter == 'all',
                          onTap: () => setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Count',
                          isSelected: _selectedFilter == 'count',
                          onTap: () => setState(() => _selectedFilter = 'count'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Time',
                          isSelected: _selectedFilter == 'time',
                          onTap: () => setState(() => _selectedFilter = 'time'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Activity Items List with Staggered Entrance Animations
                    if (filtered.isEmpty)
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
                            'No activities yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ),
                        ),
                      )
                    else
                      for (int i = 0; i < filtered.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ActivityListItem(
                            activity: filtered[i],
                            stats: filtered[i].id != null
                                ? (_stats[filtered[i].id!] ?? const ActivityStats())
                                : const ActivityStats(),
                            onAddRecord: (quantity) => _addRecord(filtered[i], quantity),
                            onDelete: () => _deleteActivity(filtered[i]),
                          )
                            .animate(key: ValueKey('activity_${filtered[i].id ?? i}'))
                            .fadeIn(duration: 250.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.08, end: 0, duration: 250.ms, curve: Curves.easeOutCubic),
                        ),

                    const SizedBox(height: 18),

                    // New Activity Creation Card
                    CreateActivityField(onCreate: _addActivity),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

    final bg = isSelected
        ? AppColors.getSurfaceDark(isDark)
        : AppColors.getBackground(isDark);
    final fg = isSelected
        ? AppColors.getTextOnDark(isDark)
        : AppColors.getTextPrimary(isDark);
    final border = isSelected
        ? AppColors.getSurfaceDark(isDark)
        : AppColors.getBorderSubtle(isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1.5),
        ),
        child: AnimatedScale(
          scale: isSelected ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
