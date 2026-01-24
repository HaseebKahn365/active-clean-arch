import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/activity.dart';
import '../../../providers/activity_provider.dart';
import 'activity_tile.dart';

class ActivityList extends StatelessWidget {
  const ActivityList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.roots.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final roots = controller.roots;

        if (roots.isEmpty) {
          return child!;
        }

        return DragTarget<Activity>(
          onWillAcceptWithDetails: (details) {
            // Can move to root if it's not already at root
            return details.data.parentId != null;
          },
          onAcceptWithDetails: (details) {
            controller.moveActivity(details.data.id, null);
          },
          builder: (context, candidateData, _) {
            final isHighlighted = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: isHighlighted ? const EdgeInsets.all(8) : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: isHighlighted ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roots.length,
                itemBuilder: (context, index) {
                  final activity = roots[index];
                  return ActivityTile(activity: activity);
                },
              ),
            );
          },
        );
      },
      child: _buildEmptyState(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: cardTheme.shape is RoundedRectangleBorder
            ? Border.fromBorderSide((cardTheme.shape as RoundedRectangleBorder).side)
            : null,
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, size: 48, color: colorScheme.onSurfaceVariant.withAlpha(50)),
          const SizedBox(height: 16),
          Text(
            'Your day is a blank canvas.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text('Start an activity to begin tracking.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
