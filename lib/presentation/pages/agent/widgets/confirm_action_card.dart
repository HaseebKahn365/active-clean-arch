import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:active/presentation/pages/agent/models/pending_action.dart';
import 'package:active/presentation/theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (resolved != null) {
      final confirmed = resolved == ConfirmOutcome.confirmed;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceSubtle(isDark),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              confirmed ? Icons.check_circle_rounded : Icons.cancel_outlined,
              size: 16,
              color: confirmed ? AppColors.error : AppColors.getTextSecondary(isDark),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                confirmed
                    ? 'Deleted "${action.targetName}"'
                    : 'Kept "${action.targetName}"',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
            ),
          ],
        ),
      )
        .animate()
        .fadeIn(duration: 200.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic);
    }

    final count = action.recordCount ?? 0;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm deletion',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.error,
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
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.getTextSecondary(isDark),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    )
      .animate()
      .fadeIn(duration: 250.ms)
      .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

enum ConfirmOutcome { confirmed, cancelled }
