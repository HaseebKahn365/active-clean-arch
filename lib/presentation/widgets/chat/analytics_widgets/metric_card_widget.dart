import 'package:flutter/material.dart';
import '../../../../infrastructure/ai/analytics_widget_models.dart';
import '../../../../presentation/theme/app_colors.dart';
import 'analytics_widget_container.dart';

class MetricCardWidget extends StatelessWidget {
  final MetricCardPayload payload;

  const MetricCardWidget({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = payload.trend;
    final trendUp = trend != null && (trend.startsWith('+') || trend.contains('up') || trend.contains('Up'));
    final trendDown = trend != null && (trend.startsWith('-') || trend.contains('down') || trend.contains('Down'));

    final chartArea = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          payload.value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (payload.subtitle != null || trend != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (payload.subtitle != null)
                Text(
                  payload.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (payload.subtitle != null && trend != null) const SizedBox(width: 8),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trendUp
                        ? AppColors.success.withValues(alpha: 0.15)
                        : trendDown
                            ? AppColors.error.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp
                            ? Icons.trending_up
                            : trendDown
                                ? Icons.trending_down
                                : Icons.trending_flat,
                        size: 12,
                        color: trendUp
                            ? AppColors.success
                            : trendDown
                                ? AppColors.error
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trend,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: trendUp
                              ? AppColors.success
                              : trendDown
                                  ? AppColors.error
                                  : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );

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
      icon: Icons.analytics_outlined,
      chartArea: chartArea,
      summaryFooter: summaryFooter,
      insightsSection: payload.insights,
      isEmpty: payload.value.isEmpty,
      emptyMessage: 'No metric data available.',
    );
  }
}
