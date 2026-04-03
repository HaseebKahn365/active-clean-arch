import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/stats_provider.dart';

class DoneDetailsPage extends StatelessWidget {
  const DoneDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsController>();
    final completedActivities = stats.getTodayCompletedActivities();

    return Scaffold(
      appBar: AppBar(title: const Text('Completed Today')),
      body: completedActivities.isEmpty
          ? const Center(child: Text('No activities completed today yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: completedActivities.length,
              itemBuilder: (context, index) {
                final activity = completedActivities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                    title: Text(activity.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: activity.description.isNotEmpty ? Text(activity.description) : null,
                  ),
                );
              },
            ),
    );
  }
}
