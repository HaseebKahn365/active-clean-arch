import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

class ActivityListItem extends StatefulWidget {
  const ActivityListItem({
    super.key,
    required this.activity,
    required this.stats,
    required this.onAddRecord,
    this.onDelete,
  });

  final Activity activity;
  final ActivityStats stats;
  final void Function(int quantity) onAddRecord;
  final VoidCallback? onDelete;

  @override
  State<ActivityListItem> createState() => _ActivityListItemState();
}

class _ActivityListItemState extends State<ActivityListItem> {
  final _recordController = TextEditingController();

  @override
  void dispose() {
    _recordController.dispose();
    super.dispose();
  }

  void _submitRecord() {
    final text = _recordController.text.trim();
    if (text.isEmpty) return;
    final quantity = int.tryParse(text);
    if (quantity == null || quantity == 0) return;

    widget.onAddRecord(quantity);
    _recordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCount = widget.activity.type == ActivityType.count;
    final singleUnit = isCount ? 'count' : 'min';
    final hint = isCount ? 'Add count (+/-)' : 'Add minutes (+/-)';

    final best = widget.stats.bestDayTotal;
    // Today ties or beats the record: today *is* the best day, so show it as
    // a live achievement rather than a target to chase.
    final isRecordToday = best > 0 && widget.stats.todayTotal >= best;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHigh,
          child: Icon(
            isCount ? Icons.tag : Icons.schedule,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        title: Text(
          widget.activity.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BestChip(
              best: best,
              unit: singleUnit,
              isRecordToday: isRecordToday,
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: widget.onDelete,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete activity',
              ),
            ],
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Total record entries indicator
          Row(
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.stats.entryCount} ${widget.stats.entryCount == 1 ? 'record entry' : 'record entries'} · '
                  '${widget.stats.totalQuantity} $singleUnit total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented Cards for Today, Weekly, Monthly, and Yearly
          Row(
            children: [
              Expanded(
                child: _SegmentedStatCard(
                  label: 'Today',
                  value: '${widget.stats.todayTotal}',
                  unit: singleUnit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentedStatCard(
                  label: 'Weekly',
                  value: '${widget.stats.weekTotal}',
                  unit: singleUnit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentedStatCard(
                  label: 'Monthly',
                  value: '${widget.stats.monthTotal}',
                  unit: singleUnit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentedStatCard(
                  label: 'Yearly',
                  value: '${widget.stats.yearTotal}',
                  unit: singleUnit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Input field to add records (supports negative and positive values)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _recordController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                  ],
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitRecord(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _submitRecord,
                icon: const Icon(Icons.add, size: 20),
                tooltip: isCount ? 'Log count' : 'Log minutes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the personal best for a single day, as a target to beat.
/// Turns into a celebratory state once today matches or exceeds it.
class _BestChip extends StatelessWidget {
  const _BestChip({
    required this.best,
    required this.unit,
    required this.isRecordToday,
  });

  final int best;
  final String unit;
  final bool isRecordToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (best <= 0) {
      return Chip(
        label: const Text('No best yet'),
        visualDensity: VisualDensity.compact,
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final background = isRecordToday
        ? colorScheme.tertiaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = isRecordToday
        ? colorScheme.onTertiaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: isRecordToday
            ? Border.all(color: colorScheme.tertiary.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRecordToday
                ? Icons.emoji_events_rounded
                : Icons.military_tech_outlined,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            isRecordToday ? '$best $unit today!' : 'Best: $best $unit',
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedStatCard extends StatelessWidget {
  const _SegmentedStatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              fontSize: 15,
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
