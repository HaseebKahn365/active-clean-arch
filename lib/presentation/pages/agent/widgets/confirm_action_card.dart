import 'package:flutter/material.dart';

import 'package:active/presentation/pages/agent/models/pending_action.dart';

/// Confirmation card for a destructive action the agent proposed.
/// Nothing is deleted until [onConfirm] fires.
class ConfirmActionCard extends StatelessWidget {
  const ConfirmActionCard({
    super.key,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
    this.resolved,
  });

  final PendingAction action;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Once the user has chosen, the buttons are replaced by the outcome.
  final ConfirmOutcome? resolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (resolved != null) {
      final confirmed = resolved == ConfirmOutcome.confirmed;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              confirmed ? Icons.check_circle : Icons.cancel_outlined,
              size: 16,
              color: confirmed ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                confirmed
                    ? 'Deleted "${action.targetName}"'
                    : 'Kept "${action.targetName}"',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final count = action.recordCount ?? 0;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm deletion',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count > 0
                ? 'This permanently removes "${action.targetName}" and all '
                    '$count of its ${count == 1 ? 'record' : 'records'}. '
                    'This cannot be undone.'
                : 'This permanently removes "${action.targetName}". '
                    'This cannot be undone.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum ConfirmOutcome { confirmed, cancelled }
