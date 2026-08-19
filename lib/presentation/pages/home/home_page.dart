import 'dart:async';
import 'package:flutter/material.dart';

import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/pages/home/widgets/activity_list_item.dart';
import 'package:active/presentation/pages/home/widgets/create_activity_field.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Activity> _activities = [];
  final Map<int, ActivityStats> _stats = {};
  bool _isLoading = true;
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Delete Activity'),
          content: Text(
            'Are you sure you want to delete "${activity.name}"? All associated records and statistics will be permanently removed.',
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

    if (confirmed == true && activity.id != null) {
      await DatabaseHelper.instance.deleteActivity(activity.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Activities', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_activities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No activities yet',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      )
                    else
                      ..._activities.map(
                        (activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ActivityListItem(
                            activity: activity,
                            stats: activity.id != null
                                ? (_stats[activity.id!] ?? const ActivityStats())
                                : const ActivityStats(),
                            onAddRecord: (quantity) => _addRecord(activity, quantity),
                            onDelete: () => _deleteActivity(activity),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text('New', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    CreateActivityField(onCreate: _addActivity),
                  ],
                ),
              ),
      ),
    );
  }
}
