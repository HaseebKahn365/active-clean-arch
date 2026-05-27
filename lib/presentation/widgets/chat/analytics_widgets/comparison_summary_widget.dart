import 'package:flutter/material.dart';
import '../../../../infrastructure/ai/analytics_widget_models.dart';
import '../../../../presentation/theme/app_colors.dart';
import 'analytics_widget_container.dart';

class ComparisonSummaryWidget extends StatelessWidget {
  final ComparisonSummaryPayload payload;

  const ComparisonSummaryWidget({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = payload.items;
    final curLabel = payload.currentPeriodLabel ?? 'Current';
    final prevLabel = payload.previousPeriodLabel ?? 'Previous';

    final isEmpty = items.isEmpty;

    Widget? chartArea;
    if (!isEmpty) {
      chartArea = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                const Expanded(flex: 5, child: SizedBox()),
                Expanded(
                  flex: 3,
                  child: Text(
                    curLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    prevLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) => _ComparisonRow(item: item)),
        ],
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
      icon: Icons.compare_arrows_rounded,
      chartArea: chartArea,
      summaryFooter: summaryFooter,
      insightsSection: payload.insights,
      isEmpty: isEmpty,
      emptyMessage: 'No comparison data detected for this period.',
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final ComparisonSummaryItem item;

  const _ComparisonRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = item.trend;
    final isUp = trend == 'up';
    final isDown = trend == 'down';

    final trendColor = isUp
        ? AppColors.success
        : isDown
            ? AppColors.error
            : theme.colorScheme.onSurfaceVariant;

    final trendIcon = isUp
        ? Icons.arrow_upward_rounded
        : isDown
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Label
          Expanded(
            flex: 5,
            child: Text(
              item.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Current value
          Expanded(
            flex: 3,
            child: Text(
              item.current,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Previous value
          Expanded(
            flex: 3,
            child: Text(
              item.previous,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Difference badge
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(trendIcon, size: 10, color: trendColor),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    item.difference ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trendColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
