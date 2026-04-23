import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/entities/activity.dart';
import '../../../../providers/dashboard_ui_notifier.dart';
import '../../../../providers/riverpod_bridge.dart';
import 'tree_layout.dart';
import 'dart:math' as math;

class ActivityTree extends ConsumerStatefulWidget {
  const ActivityTree({super.key});

  @override
  ConsumerState<ActivityTree> createState() => _ActivityTreeState();
}

class _ActivityTreeState extends ConsumerState<ActivityTree> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uiState = ref.read(dashboardUiProvider);
      if (uiState.expandedNodeIds.isEmpty) {
        final activities = ref.read(activityControllerProvider).activitiesMap.values.toList();
        final roots = activities.where((a) => a.parentId == null).map((a) => a.id).toSet();
        ref.read(dashboardUiProvider.notifier).setExpandedNodes(roots);
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final Matrix4 matrix = _transformationController.value.clone();
    final double currentScale = matrix.getMaxScaleOnAxis();
    final double newScale = (currentScale * factor).clamp(0.4, 2.5);
    final double scaleChange = newScale / currentScale;
    
    final Size size = MediaQuery.of(context).size;
    final Offset center = Offset(size.width / 2, size.height / 2);
    
    matrix.leftTranslate(center.dx, center.dy);
    matrix.scale(scaleChange);
    matrix.leftTranslate(-center.dx, -center.dy);
    
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final activityController = ref.watch(activityControllerProvider);
    final uiState = ref.watch(dashboardUiProvider);
    final activities = activityController.activitiesMap.values.toList();

    if (activities.isEmpty) {
      return const Center(child: Text('No activities to display.'));
    }

    final layout = TreeLayoutEngine.calculateLayout(activities, uiState.expandedNodeIds);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            GestureDetector(
              onTapDown: (_) => ref.read(dashboardUiProvider.notifier).selectNode(null),
              onPanUpdate: uiState.draggingNodeId != null ? _handleDragUpdate : null,
              onPanEnd: uiState.draggingNodeId != null ? _handleDragEnd : null,
              child: InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(5000),
                minScale: 0.4,
                maxScale: 2.5,
                panEnabled: uiState.draggingNodeId == null,
                child: SizedBox(
                  width: 10000,
                  height: 10000,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(10000, 10000),
                        painter: TreePainter(
                          layout: layout,
                          expandedNodes: uiState.expandedNodeIds,
                          theme: Theme.of(context),
                          animationValue: _animationController.value,
                        ),
                      ),
                      ...layout.values.map((node) {
                        final isVisible = _isNodeVisible(node, uiState.expandedNodeIds, layout);
                        if (!isVisible) return const SizedBox.shrink();

                        final isDragging = uiState.draggingNodeId == node.activity.id;

                        return Positioned(
                          left: isDragging 
                              ? uiState.dragPosition!.dx - TreeLayoutEngine.nodeWidth / 2
                              : node.x - TreeLayoutEngine.nodeWidth / 2,
                          top: isDragging 
                              ? uiState.dragPosition!.dy - TreeLayoutEngine.nodeHeight / 2
                              : node.y,
                          width: TreeLayoutEngine.nodeWidth,
                          child: TreeNode(
                            node: node,
                            isSelected: uiState.selectedNodeId == node.activity.id,
                            isExpanded: uiState.expandedNodeIds.contains(node.activity.id),
                            isDragging: isDragging,
                            isHoverTarget: uiState.hoverTargetId == node.activity.id,
                            onSelect: () => ref.read(dashboardUiProvider.notifier).selectNode(node.activity.id),
                            onToggle: () => ref.read(dashboardUiProvider.notifier).toggleNodeExpansion(node.activity.id),
                            onStartDrag: (pos) => ref.read(dashboardUiProvider.notifier).startDragging(node.activity.id, pos),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 24,
              left: 24,
              child: DetailsPanel(selectedNodeId: uiState.selectedNodeId),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: TreeControls(
                onZoomIn: () => _zoom(1.2),
                onZoomOut: () => _zoom(0.8),
                onReset: _resetZoom,
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final uiState = ref.read(dashboardUiProvider);
    final layout = TreeLayoutEngine.calculateLayout(
      ref.read(activityControllerProvider).activitiesMap.values.toList(),
      uiState.expandedNodeIds,
    );

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPos = renderBox.globalToLocal(details.globalPosition);
    final Matrix4 inverseMatrix = _transformationController.value.clone()..invert();
    final Offset canvasPos = MatrixUtils.transformPoint(inverseMatrix, localPos);

    String? hoverId;
    for (final node in layout.values) {
      if (node.activity.id == uiState.draggingNodeId) continue;
      final double dx = (node.x - canvasPos.dx).abs();
      final double dy = (node.y + TreeLayoutEngine.nodeHeight / 2 - canvasPos.dy).abs();
      if (dx < TreeLayoutEngine.nodeWidth / 2 && dy < TreeLayoutEngine.nodeHeight / 2) {
        if (!_isDescendant(node.activity.id, uiState.draggingNodeId!, layout)) {
          hoverId = node.activity.id;
          break;
        }
      }
    }
    ref.read(dashboardUiProvider.notifier).updateDrag(canvasPos, hoverId: hoverId);
  }

  bool _isDescendant(String targetId, String potentialParentId, Map<String, TreeLayoutNode> layout) {
    final target = layout[targetId];
    if (target == null || target.activity.parentId == null) return false;
    if (target.activity.parentId == potentialParentId) return true;
    return _isDescendant(target.activity.parentId!, potentialParentId, layout);
  }

  void _handleDragEnd(DragEndDetails details) {
    final uiState = ref.read(dashboardUiProvider);
    if (uiState.draggingNodeId != null && uiState.hoverTargetId != null) {
      ref.read(activityControllerProvider.notifier).moveActivity(
            uiState.draggingNodeId!,
            uiState.hoverTargetId,
          );
    }
    ref.read(dashboardUiProvider.notifier).stopDragging();
  }

  bool _isNodeVisible(TreeLayoutNode node, Set<String> expandedNodes, Map<String, TreeLayoutNode> layout) {
    if (node.activity.parentId == null) return true;
    final parent = layout[node.activity.parentId];
    if (parent == null) return false;
    if (!expandedNodes.contains(parent.activity.id)) return false;
    return _isNodeVisible(parent, expandedNodes, layout);
  }
}

class TreePainter extends CustomPainter {
  final Map<String, TreeLayoutNode> layout;
  final Set<String> expandedNodes;
  final ThemeData theme;
  final double animationValue;

  TreePainter({
    required this.layout,
    required this.expandedNodes,
    required this.theme,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final node in layout.values) {
      if (!expandedNodes.contains(node.activity.id)) continue;
      for (final child in node.children) {
        final startX = node.x;
        final startY = node.y + TreeLayoutEngine.nodeHeight;
        final endX = child.x;
        final endY = child.y;
        final midY = (startY + endY) / 2;
        final path = Path()
          ..moveTo(startX, startY)
          ..cubicTo(startX, midY, endX, midY, endX, endY);

        final isActive = node.activity.status == ActivityStatus.running && child.activity.status == ActivityStatus.running;
        paint.color = isActive ? theme.colorScheme.primary.withValues(alpha: 0.8) : theme.colorScheme.onSurface.withValues(alpha: 0.4);
        paint.strokeWidth = isActive ? 4 : 2.5;
        canvas.drawPath(path, paint);

        if (isActive) {
          final dashPath = _createAnimatedDashPath(path, animationValue);
          final activePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..color = theme.colorScheme.primary;
          canvas.drawPath(dashPath, activePaint);
        }
      }
    }
  }

  Path _createAnimatedDashPath(Path source, double dashPhase) {
    final path = Path();
    final metrics = source.computeMetrics();
    for (final metric in metrics) {
      const dashLength = 10.0;
      const gapLength = 10.0;
      final step = dashLength + gapLength;
      double start = (dashPhase * step) % step;
      if (start > 0) start -= step;
      for (double d = start; d < metric.length; d += step) {
        final double s = math.max(0, d);
        final double e = math.min(metric.length, d + dashLength);
        if (s < e) path.addPath(metric.extractPath(s, e), Offset.zero);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant TreePainter oldDelegate) {
    return oldDelegate.layout != layout || oldDelegate.expandedNodes != expandedNodes || oldDelegate.animationValue != animationValue;
  }
}

class TreeNode extends StatelessWidget {
  final TreeLayoutNode node;
  final bool isSelected;
  final bool isExpanded;
  final bool isDragging;
  final bool isHoverTarget;
  final VoidCallback onSelect;
  final VoidCallback onToggle;
  final Function(Offset) onStartDrag;

  const TreeNode({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isExpanded,
    this.isDragging = false,
    this.isHoverTarget = false,
    required this.onSelect,
    required this.onToggle,
    required this.onStartDrag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activity = node.activity;
    final isRunning = activity.status == ActivityStatus.running;
    final isCompleted = activity.status == ActivityStatus.completed;

    Color borderColor = theme.dividerColor;
    Color bgColor = theme.cardColor.withValues(alpha: 0.8);
    double opacity = 1.0;
    List<BoxShadow> boxShadow = [];

    if (isRunning) {
      borderColor = colorScheme.primary.withValues(alpha: 0.5);
      bgColor = theme.cardColor;
      boxShadow = [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)];
    } else if (isCompleted) {
      borderColor = colorScheme.secondary.withValues(alpha: 0.3);
      bgColor = colorScheme.secondary.withValues(alpha: 0.05);
      opacity = 0.7;
    }

    return GestureDetector(
      onTap: onSelect,
      onDoubleTap: () => onStartDrag(Offset(node.x, node.y)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHoverTarget ? colorScheme.primary.withValues(alpha: 0.1) : bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHoverTarget ? colorScheme.primary : (isSelected ? colorScheme.primary : borderColor),
            width: (isSelected || isHoverTarget) ? 2 : 1,
          ),
          boxShadow: (isSelected || isDragging) ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: isDragging ? 30 : 10,
              spreadRadius: isDragging ? 10 : 5,
              offset: isDragging ? const Offset(0, 10) : Offset.zero,
            )
          ] : boxShadow,
        ),
        transform: isDragging ? (Matrix4.identity()..scale(1.1)) : Matrix4.identity(),
        child: Opacity(
          opacity: isDragging ? 0.6 : opacity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -20,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(colorScheme, activity.status),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Icon(_getStatusIcon(activity.status), size: 12, color: Colors.white),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(activity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isRunning ? colorScheme.primary : theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 10, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(_formatDuration(activity.totalSeconds), style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
                      if (isRunning) ...[const Spacer(), Icon(Icons.bolt, size: 12, color: colorScheme.primary)],
                    ],
                  ),
                ],
              ),
              if (node.children.isNotEmpty)
                Positioned(
                  bottom: -22,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle, border: Border.all(color: theme.dividerColor)),
                        child: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ColorScheme colorScheme, ActivityStatus status) {
    switch (status) {
      case ActivityStatus.running: return colorScheme.primary;
      case ActivityStatus.paused: return Colors.orange;
      case ActivityStatus.completed: return colorScheme.secondary;
      default: return colorScheme.outline;
    }
  }

  IconData _getStatusIcon(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.running: return Icons.bolt;
      case ActivityStatus.paused: return Icons.pause;
      case ActivityStatus.completed: return Icons.check;
      default: return Icons.radio_button_unchecked;
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class DetailsPanel extends ConsumerWidget {
  final String? selectedNodeId;
  const DetailsPanel({super.key, this.selectedNodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedNodeId == null) {
      return Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
        child: const Text('Select a node to view details', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      );
    }
    final activity = ref.watch(activityControllerProvider).activitiesMap[selectedNodeId];
    if (activity == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('EXPLORER DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: theme.hintColor)),
            ],
          ),
          const Divider(height: 24),
          Text(activity.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _getStatusColor(colorScheme, activity.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _getStatusColor(colorScheme, activity.status).withValues(alpha: 0.3))),
            child: Text(activity.status.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getStatusColor(colorScheme, activity.status))),
          ),
          const SizedBox(height: 20),
          Row(children: [_buildStat(context, Icons.access_time, 'Duration', _formatDuration(activity.totalSeconds))]),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 10, color: theme.hintColor), const SizedBox(width: 4), Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.hintColor))]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getStatusColor(ColorScheme colorScheme, ActivityStatus status) {
    switch (status) {
      case ActivityStatus.running: return colorScheme.primary;
      case ActivityStatus.paused: return Colors.orange;
      case ActivityStatus.completed: return colorScheme.secondary;
      default: return colorScheme.outline;
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class TreeControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  const TreeControls({super.key, required this.onZoomIn, required this.onZoomOut, required this.onReset});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildButton(Icons.add, onZoomIn, theme),
        const SizedBox(height: 8),
        _buildButton(Icons.remove, onZoomOut, theme),
        const SizedBox(height: 8),
        _buildButton(Icons.fullscreen, onReset, theme, isPrimary: true),
      ],
    );
  }
  Widget _buildButton(IconData icon, VoidCallback onPressed, ThemeData theme, {bool isPrimary = false}) {
    return Container(
      decoration: BoxDecoration(color: isPrimary ? theme.colorScheme.primary : theme.cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: IconButton(icon: Icon(icon, color: isPrimary ? Colors.white : theme.iconTheme.color), onPressed: onPressed),
    );
  }
}
