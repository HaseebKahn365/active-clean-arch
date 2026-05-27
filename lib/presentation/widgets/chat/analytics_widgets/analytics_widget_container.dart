import 'package:flutter/material.dart';
import '../../../../presentation/theme/app_colors.dart';

class AnalyticsWidgetContainer extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? chartArea;
  final Widget? legend;
  final Widget? summaryFooter;
  final String? insightsSection;
  final bool isEmpty;
  final String? emptyMessage;

  const AnalyticsWidgetContainer({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.chartArea,
    this.legend,
    this.summaryFooter,
    this.insightsSection,
    this.isEmpty = false,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEmptyMessage = emptyMessage != null && emptyMessage!.isNotEmpty;
    final displayEmpty = isEmpty || (chartArea == null && !hasEmptyMessage);

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row (Title, Subtitle & Icon)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon ?? Icons.bar_chart_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Body: Empty State or Chart Area
          if (displayEmpty)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bubble_chart_outlined,
                    size: 28,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage ?? 'No activity detected for this period.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Main Chart/Widget body
            if (chartArea != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: chartArea!,
              ),

            // Legend
            if (legend != null) ...[
              const SizedBox(height: 12),
              legend!,
            ],

            // Summary Footer
            if (summaryFooter != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 8),
              summaryFooter!,
            ],
          ],

          // Insights Section
          if (insightsSection != null && insightsSection!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insightsSection!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
