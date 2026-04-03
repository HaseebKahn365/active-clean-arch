import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/activity_manager_provider.dart';
import '../../../providers/pause_provider.dart';

class PauseDetailsPage extends StatelessWidget {
  const PauseDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final activityController = context.watch<ActivityController>();
    final pauseProvider = context.watch<PauseProvider>();
    final pausedIds = pauseProvider.pausedActivityIds;

    return Scaffold(
      appBar: AppBar(title: const Text('Globally Paused Activities')),
      body: pausedIds.isEmpty
          ? const Center(child: Text('No activities globally paused.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pausedIds.length,
              itemBuilder: (context, index) {
                final id = pausedIds[index];
                final activity = activityController.activitiesMap[id];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.pause_circle_outline, color: Colors.orange),
                    title: Text(activity?.name ?? 'Unknown Activity', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Activity ID: $id'),
                    trailing: Switch(
                      value: false, // It's paused
                      onChanged: (val) {
                        if (val) {
                          // This is simplified, maybe it shouldn't be here but the req asks for details
                          activityController.startActivity(id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
