import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/activity_provider.dart';
import '../../activity_detail_page.dart';

class PinnedActivityList extends StatelessWidget {
  const PinnedActivityList({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pinned = context.watch<ActivityController>().pinnedActivities;

    if (pinned.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.push_pin, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Pinned Activities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pinned.length,
            itemBuilder: (context, index) {
              final activity = pinned[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 16),
                child: Material(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ActivityDetailPage(activityId: activity.id)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            activity.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          _PinnedDurationText(activityId: activity.id),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _PinnedDurationText extends StatelessWidget {
  final String activityId;

  const _PinnedDurationText({required this.activityId});

  @override
  Widget build(BuildContext context) {
    final durationInSeconds = context.select<ActivityController, int>(
      (controller) => controller.getEffectiveSeconds(activityId),
    );

    return Text(
      _formatDuration(durationInSeconds),
      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
