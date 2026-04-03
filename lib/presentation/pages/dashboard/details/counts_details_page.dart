import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/activity_manager_provider.dart';

class CountsDetailsPage extends StatelessWidget {
  const CountsDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsController>();
    final controller = context.watch<ActivityController>();
    final records = stats.getTodayCountRecords();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Counts')),
      body: records.isEmpty
          ? const Center(child: Text('No counts recorded yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final r = records[index];
                final activity = controller.activitiesMap[r.activityId];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(activity?.name ?? 'Unknown Activity', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('HH:mm:ss').format(r.timestamp)),
                    trailing: Text(
                      '+${r.value.toInt()}',
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
