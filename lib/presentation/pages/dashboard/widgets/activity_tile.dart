import 'package:active/presentation/widgets/activity_details_sheet.dart';
import '../../activity_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/activity.dart';
import '../../../providers/activity_manager_provider.dart';
import '../../stats/activity_stats_page.dart';

class ActivityTile extends StatefulWidget {
  final Activity activity;
  final VoidCallback? onTap;

  const ActivityTile({super.key, required this.activity, this.onTap});

  @override
  State<ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<ActivityTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      upperBound: 1.0,
      lowerBound: 0.96,
      value: 1.0,
    );
    _scaleAnimation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.reverse();
  void _onTapUp(TapUpDetails details) => _controller.forward();
  void _onTapCancel() => _controller.forward();

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Activity>(
      data: widget.activity,
      // The feedback widget shown while dragging
      feedback: Material(
        color: Colors.transparent,
        elevation: 10,
        child: SizedBox(width: MediaQuery.of(context).size.width * 0.9, child: _buildBody(context)),
      ),
      // The widget at the original position while dragging
      childWhenDragging: Opacity(opacity: 0.3, child: _buildBody(context, dragging: true)),
      child: DragTarget<Activity>(
        onWillAcceptWithDetails: (details) {
          final draggedActivity = details.data;
          // Cannot drop onto itself or its current parent (no-op) or its own children (cycle)
          return draggedActivity.id != widget.activity.id;
        },
        onAcceptWithDetails: (details) {
          final draggedActivity = details.data;
          context.read<ActivityController>().moveActivity(draggedActivity.id, widget.activity.id);
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          return _buildBody(context, isHighlighted: isHighlighted);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, {bool isHighlighted = false, bool dragging = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isHighlighted ? colorScheme.primaryContainer : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: isHighlighted
              ? Border.all(color: colorScheme.primary, width: 2)
              : (Theme.of(context).cardTheme.shape is RoundedRectangleBorder
                    ? Border.fromBorderSide((Theme.of(context).cardTheme.shape as RoundedRectangleBorder).side)
                    : null),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Positioned(
              //   left: 0,
              //   top: 0,
              //   bottom: 0,
              //   width: 6,
              //   child: Container(
              //     color: widget.activity.type == ActivityType.timeBased ? colorScheme.primary : const Color(0xFF10B981),
              //   ),
              // ),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTapDown: dragging ? null : _onTapDown,
                onTapUp: dragging ? null : _onTapUp,
                onTapCancel: dragging ? null : _onTapCancel,
                onTap: dragging || widget.onTap != null
                    ? widget.onTap
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ActivityDetailPage(activityId: widget.activity.id)),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.only(left: 18, right: 12, top: 12, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Status, Name, Type Icon, Badge, More
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getStatusColor(context).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getStatusIcon(), color: _getStatusColor(context), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.activity.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _getStatusLabel(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.activity.childrenIds.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${widget.activity.childrenIds.length}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                              ),
                            ),
                          ],
                          IconButton(
                            icon: Icon(Icons.bar_chart_rounded, color: colorScheme.primary, size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ActivityStatsPage(activityId: widget.activity.id)),
                              );
                            },
                          ),
                          _buildMoreMenu(context),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Middle Section: Metrics
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.activity.type == ActivityType.timeBased) ...[
                            _DurationText(activityId: widget.activity.id, isProminent: true),
                            _CumulativeDurationText(activityId: widget.activity.id),
                            if (widget.activity.goalSeconds > 0) _GoalBadge(goalSeconds: widget.activity.goalSeconds),
                          ] else ...[
                            _CountText(activityId: widget.activity.id, isProminent: true),
                            _DurationText(activityId: widget.activity.id),
                            _CumulativeDurationText(activityId: widget.activity.id),
                          ],
                        ],
                      ),
                      // Bottom Section: Actions (Only if not dragging)
                      if (!dragging) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        _buildActions(context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              ActivityDetailsSheet(activity: widget.activity, controller: context.read<ActivityController>()),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final List<Widget> actions = [];

    // Timer Logic
    if (widget.activity.status == ActivityStatus.running) {
      actions.add(
        _ActionButton(
          label: "Pause",
          icon: Icons.pause_rounded,
          color: Colors.orange,
          onTap: () => context.read<ActivityController>().pauseActivity(widget.activity.id),
        ),
      );
    } else {
      actions.add(
        _ActionButton(
          label: "Start",
          icon: Icons.play_arrow_rounded,
          color: colorScheme.primary,
          onTap: () => context.read<ActivityController>().startActivity(widget.activity.id),
        ),
      );
    }

    actions.add(const SizedBox(width: 8));

    // Count Logic
    if (widget.activity.type == ActivityType.countBased) {
      actions.add(
        _ActionButton(
          label: "Add Count",
          icon: Icons.add_circle_outline_rounded,
          color: const Color(0xFF10B981),
          onTap: () => _showAddCountSheet(context),
          isOutlined: true,
        ),
      );
      actions.add(const SizedBox(width: 8));
    }

    actions.add(const SizedBox(width: 8));

    actions.add(
      _ActionButton(
        label: "Finish",
        icon: Icons.done_all_rounded,
        color: colorScheme.secondary,
        onTap: () => context.read<ActivityController>().completeActivity(widget.activity.id),
      ),
    );

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: actions);
  }

  void _showAddCountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddCountSheet(
        activity: widget.activity,
        onAdd: (value) {
          context.read<ActivityController>().addCount(widget.activity.id, value);
        },
      ),
    );
  }

  String _getStatusLabel() {
    if (widget.activity.status == ActivityStatus.completed) return "COMPLETED";
    if (widget.activity.status == ActivityStatus.paused) return "PAUSED";
    if (widget.activity.status == ActivityStatus.idle) {
      return widget.activity.type == ActivityType.timeBased ? "TIMER" : "COUNTER";
    }
    return widget.activity.type == ActivityType.timeBased ? "TIMING" : "COUNTING";
  }

  Color _getStatusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.activity.status) {
      case ActivityStatus.running:
        return colorScheme.primary;
      case ActivityStatus.paused:
        return Colors.orange;
      case ActivityStatus.completed:
        return colorScheme.secondary;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.activity.status) {
      case ActivityStatus.running:
        return Icons.play_circle_filled_rounded;
      case ActivityStatus.paused:
        return Icons.pause_circle_filled_rounded;
      case ActivityStatus.completed:
        return Icons.check_circle_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }
}

class _CumulativeDurationText extends StatelessWidget {
  final String activityId;
  const _CumulativeDurationText({required this.activityId});

  @override
  Widget build(BuildContext context) {
    final totalSeconds = context.select<ActivityController, int>(
      (controller) => controller.getCumulativeSeconds(activityId),
    );

    // If there are no children, cumulative duration is same as duration, so we don't show it separately.
    final activity = context.select<ActivityController, Activity?>((c) => c.activitiesMap[activityId]);
    if (activity == null || activity.childrenIds.isEmpty) return const SizedBox.shrink();

    return Text(
      '• Total: ${_formatDuration(totalSeconds)}',
      style: TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }
}

class _DurationText extends StatelessWidget {
  final String activityId;
  final bool isProminent;
  const _DurationText({required this.activityId, this.isProminent = false});

  @override
  Widget build(BuildContext context) {
    final durationInSeconds = context.select<ActivityController, int>(
      (controller) => controller.getEffectiveSeconds(activityId),
    );
    return Text(
      _formatDuration(durationInSeconds),
      style: TextStyle(
        fontSize: isProminent ? 16 : 12,
        fontFamily: 'monospace',
        fontWeight: isProminent ? FontWeight.bold : FontWeight.w600,
        color: isProminent ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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

class _CountText extends StatelessWidget {
  final String activityId;
  final bool isProminent;
  const _CountText({required this.activityId, this.isProminent = false});

  @override
  Widget build(BuildContext context) {
    final total = context.select<ActivityController, double>((c) => c.getCountTotalFor(activityId));

    return Text(
      'Count: ${total % 1 == 0 ? total.toInt() : total}',
      style: TextStyle(
        fontSize: isProminent ? 16 : 12,
        fontWeight: isProminent ? FontWeight.bold : FontWeight.w600,
        color: isProminent ? const Color(0xFF10B981) : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  final int goalSeconds;
  const _GoalBadge({required this.goalSeconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 12, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            _formatDuration(goalSeconds),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isOutlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isOutlined ? 1.0 : 0.2),
            width: isOutlined ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCountSheet extends StatefulWidget {
  final Activity activity;
  final Function(double) onAdd;

  const _AddCountSheet({required this.activity, required this.onAdd});

  @override
  State<_AddCountSheet> createState() => _AddCountSheetState();
}

class _AddCountSheetState extends State<_AddCountSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<int> _quickAddValues = [1, 5, 10, 25, 50];
  final List<int> _quickSubValues = [-1, -5];

  void _submit(int value) {
    if (value.abs() > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Count value cannot exceed 5000")));
      return;
    }
    widget.onAdd(value.toDouble());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.numbers_rounded, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Add Count", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        widget.activity.name,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: true),
              autofocus: true,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "0",
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_rounded, size: 32),
                  color: colorScheme.primary,
                  onPressed: () {
                    final val = int.tryParse(_controller.text);
                    if (val != null) _submit(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text("Quick Add", style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._quickAddValues.map(
                  (v) => ActionChip(
                    label: Text("+$v"),
                    onPressed: () => _submit(v),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    labelStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text("Corrections", style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._quickSubValues.map(
                  (v) => ActionChip(
                    label: Text("$v"),
                    onPressed: () => _submit(v),
                    backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.5),
                    labelStyle: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
