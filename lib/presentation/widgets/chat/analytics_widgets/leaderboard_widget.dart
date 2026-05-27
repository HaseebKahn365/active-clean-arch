import 'package:flutter/material.dart';
import '../../../../infrastructure/ai/analytics_widget_models.dart';
import '../../../../presentation/theme/app_colors.dart';
import 'analytics_widget_container.dart';

class LeaderboardWidget extends StatelessWidget {
  final LeaderboardPayload payload;

  const LeaderboardWidget({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = payload.items;
    final isEmpty = items.isEmpty;

    Widget? chartArea;
    if (!isEmpty) {
      chartArea = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(items.length, (i) => _LeaderboardRow(
          rank: i + 1,
          item: items[i],
          isFirst: i == 0,
        )),
      );
    }

    final summaryFooter = payload.footer != null
        ? Text(
            payload.footer!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          )
        : null;

    return AnalyticsWidgetContainer(
      title: payload.title,
      subtitle: payload.description,
      icon: Icons.emoji_events_outlined,
      chartArea: chartArea,
      summaryFooter: summaryFooter,
      insightsSection: payload.insights,
      isEmpty: isEmpty,
      emptyMessage: 'No rankings detected for this period.',
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final LeaderboardItem item;
  final bool isFirst;

  const _LeaderboardRow({
    required this.rank,
    required this.item,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankColor = switch (rank) {
      1 => AppColors.warning,
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isFirst
            ? AppColors.warning.withValues(alpha: 0.08)
            : theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: isFirst
            ? Border.all(color: AppColors.warning.withValues(alpha: 0.25))
            : null,
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 24,
            child: rank <= 3
                ? Icon(
                    rank == 1
                        ? Icons.emoji_events
                        : rank == 2
                            ? Icons.workspace_premium
                            : Icons.military_tech,
                    size: 18,
                    color: rankColor,
                  )
                : Text(
                    '$rank',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 10),
          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle != null)
                  Text(
                    item.subtitle!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Value badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFirst
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.value,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isFirst ? AppColors.warning : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
