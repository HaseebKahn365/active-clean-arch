import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/stats_provider.dart';

class TimeDetailsPage extends StatelessWidget {
  const TimeDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsController>();
    final breakdown = stats.getTodayActivityTimeBreakdown();
    final sortedBreakdown = breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colorScheme = Theme.of(context).colorScheme;

    String formatDuration(int seconds) {
      final d = Duration(seconds: seconds);
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      if (h > 0) return '${h}h ${m}m ${s}s';
      if (m > 0) return '${m}m ${s}s';
      return '${s}s';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Duration')),
      body: breakdown.isEmpty
          ? const Center(child: Text('No activity tracked yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedBreakdown.length,
              itemBuilder: (context, index) {
                final entry = sortedBreakdown[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(
                      formatDuration(entry.value),
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
