import 'package:active/presentation/widgets/activity_details_sheet.dart';
import '../../activity_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/activity.dart';
import '../../../providers/activity_provider.dart';

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

  void _onTapDown(TapDownDetails details) {
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.forward();
  }

  void _onTapCancel() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Theme.of(context).cardTheme.shape is RoundedRectangleBorder
              ? Border.fromBorderSide((Theme.of(context).cardTheme.shape as RoundedRectangleBorder).side)
              : null,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap:
              widget.onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ActivityDetailPage(activityId: widget.activity.id)),
                );
              },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(context).withAlpha(30),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_getStatusIcon(), color: _getStatusColor(context), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activity.name,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          _DurationText(activityId: widget.activity.id),
                        ],
                      ),
                    ),
                    _buildActions(context),
                    const SizedBox(width: 8),
                    _buildMoreMenu(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
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
    if (widget.activity.status == ActivityStatus.completed) {
      return Icon(Icons.check_circle, color: colorScheme.secondary);
    }

    return Row(
      children: [
        if (widget.activity.status == ActivityStatus.running)
          _ActionButton(
            icon: Icons.pause_rounded,
            color: Colors.orange,
            onTap: () => context.read<ActivityController>().pauseActivity(widget.activity.id),
          )
        else
          _ActionButton(
            icon: Icons.play_arrow_rounded,
            color: colorScheme.primary,
            onTap: () => context.read<ActivityController>().startActivity(widget.activity.id),
          ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.done_all_rounded,
          color: colorScheme.secondary,
          onTap: () => context.read<ActivityController>().completeActivity(widget.activity.id),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          color: colorScheme.error,
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity? All progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<ActivityController>().deleteActivity(widget.activity.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
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

class _DurationText extends StatelessWidget {
  final String activityId;

  const _DurationText({required this.activityId});

  @override
  Widget build(BuildContext context) {
    final durationInSeconds = context.select<ActivityController, int>(
      (controller) => controller.getEffectiveSeconds(activityId),
    );

    return Text(
      _formatDuration(durationInSeconds),
      style: TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
