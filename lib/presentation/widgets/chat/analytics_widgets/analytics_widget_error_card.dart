import 'package:flutter/material.dart';

/// Fallback rendered when a widget payload is missing required fields
/// or contains unrecognised data. Never crashes — always shows something.
class AnalyticsWidgetErrorCard extends StatelessWidget {
  final String? reason;

  const AnalyticsWidgetErrorCard({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bar_chart_outlined, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason ?? 'Could not render analytics widget.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
