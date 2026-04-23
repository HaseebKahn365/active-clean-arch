import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/riverpod_bridge.dart';
import '../../../providers/pause_notifier.dart';

class PauseDetailsPage extends ConsumerWidget {
  const PauseDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityController = ref.watch(activityControllerProvider);
    final pausedIds = ref.watch(pauseStateProvider);

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
