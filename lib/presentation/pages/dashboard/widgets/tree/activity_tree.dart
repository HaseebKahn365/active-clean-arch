import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/entities/activity.dart';
import '../../../../providers/dashboard_ui_notifier.dart';
import '../../../../providers/riverpod_bridge.dart';
import '../create_activity_sheet.dart';
import 'tree_layout.dart';
import 'dart:math' as math;

class ActivityTree extends ConsumerStatefulWidget {
  const ActivityTree({super.key});

  @override
  ConsumerState<ActivityTree> createState() => _ActivityTreeState();
}

class _ActivityTreeState extends ConsumerState<ActivityTree>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
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
        final activities =
            ref.read(activityControllerProvider).activitiesMap.values.toList();
        final roots = activities
            .where((a) => a.parentId == null)
            .map((a) => a.id)
            .toSet();
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
    final double newScale = (currentScale * factor).clamp(0.2, 3.0);
    final double scaleChange = newScale / currentScale;
    final Size size = MediaQuery.of(context).size;
    final Offset center = Offset(size.width / 2, size.height / 2);
    matrix.leftTranslate(center.dx, center.dy);
    matrix.scale(scaleChange);
    matrix.leftTranslate(-center.dx, -center.dy);
    _transformationController.value = matrix;
  }

  void _resetZoom() => _transformationController.value = Matrix4.identity();

  bool _isNodeVisible(TreeLayoutNode node, Set<String> expandedNodes,
      Map<String, TreeLayoutNode> layout) {
    if (node.activity.parentId == null) return true;
    final parent = layout[node.activity.parentId];
    if (parent == null) return false;
    if (!expandedNodes.contains(parent.activity.id)) return false;
    return _isNodeVisible(parent, expandedNodes, layout);
  }

  bool _isDescendant(String targetId, String potentialParentId,
      Map<String, TreeLayoutNode> layout) {
    final target = layout[targetId];
    if (target == null || target.activity.parentId == null) return false;
    if (target.activity.parentId == potentialParentId) return true;
    return _isDescendant(target.activity.parentId!, potentialParentId, layout);
  }

  void _handleDetach(String nodeId) {
    ref.read(activityControllerProvider).moveActivity(nodeId, null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Activity moved to root'),
          duration: Duration(seconds: 1)),
    );
  }

  void _handleReparentAction(
      String targetId, Map<String, TreeLayoutNode> layout) {
    final uiState = ref.read(dashboardUiProvider);
    final sourceId = uiState.reparentingNodeId!;

    if (sourceId == targetId) {
      ref.read(dashboardUiProvider.notifier).stopReparenting();
      return;
    }

    if (_isDescendant(targetId, sourceId, layout)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot move a node into its own subtree'),
            duration: Duration(seconds: 2)),
      );
      ref.read(dashboardUiProvider.notifier).stopReparenting();
      return;
    }

    ref.read(activityControllerProvider).moveActivity(sourceId, targetId);
    ref.read(dashboardUiProvider.notifier).stopReparenting();
  }

  @override
  Widget build(BuildContext context) {
    final activityController = ref.watch(activityControllerProvider);
    final uiState = ref.watch(dashboardUiProvider);
    final activities = activityController.activitiesMap.values.toList();

    if (activities.isEmpty) {
      return const Center(child: Text('No activities to display.'));
    }

    final layout =
        TreeLayoutEngine.calculateLayout(activities, uiState.expandedNodeIds);
    final visibleNodes = layout.values
        .where((n) => _isNodeVisible(n, uiState.expandedNodeIds, layout))
        .toList();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return Stack(
          children: [
            GestureDetector(
              // Only cancel reparenting if there is no reparentingNodeId active.
              // We use onTap (not onTapDown) so node taps are handled first.
              onTap: () {
                if (uiState.reparentingNodeId != null) {
                  // tapped empty canvas → cancel
                  ref.read(dashboardUiProvider.notifier).stopReparenting();
                } else {
                  ref.read(dashboardUiProvider.notifier).selectNode(null);
                }
              },
              behavior: HitTestBehavior.deferToChild,
              child: InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(5000),
                minScale: 0.2,
                maxScale: 3.0,
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
                          activeNodeId: uiState.selectedNodeId,
                          theme: Theme.of(context),
                          animationValue: _animationController.value,
                        ),
                      ),

                      ...visibleNodes.map((node) {
                        final isReparenting =
                            uiState.reparentingNodeId == node.activity.id;

                        return Positioned(
                          // Centre the node card on node.x
                          left: node.x - TreeLayoutEngine.nodeWidth / 2,
                          top: node.y,
                          width: TreeLayoutEngine.nodeWidth,
                          // Height covers card + toggle area so hit-testing works
                          height: TreeLayoutEngine.nodeHeight,
                          child: TreeNode(
                            node: node,
                            isSelected:
                                uiState.selectedNodeId == node.activity.id,
                            isExpanded: uiState.expandedNodeIds
                                .contains(node.activity.id),
                            isReparenting: isReparenting,
                            onSelect: () {
                              if (uiState.reparentingNodeId != null) {
                                // Reparenting mode: this tap picks the target
                                _handleReparentAction(node.activity.id, layout);
                              } else {
                                ref
                                    .read(dashboardUiProvider.notifier)
                                    .selectNode(node.activity.id);
                              }
                            },
                            onToggle: () => ref
                                .read(dashboardUiProvider.notifier)
                                .toggleNodeExpansion(node.activity.id),
                            // Long-press activates reparenting mode (clear, unambiguous)
                            onLongPress: () => ref
                                .read(dashboardUiProvider.notifier)
                                .startReparenting(node.activity.id),
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
              right: 24,
              child: Align(
                alignment: Alignment.topLeft,
                child: DetailsPanel(
                  selectedNodeId: uiState.selectedNodeId,
                  onDetach: uiState.selectedNodeId != null
                      ? () => _handleDetach(uiState.selectedNodeId!)
                      : null,
                ),
              ),
            ),
            if (uiState.reparentingNodeId != null)
              Positioned(
                top: 24,
                right: 24,
                child: _buildReparentingBanner(),
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

  Widget _buildReparentingBanner() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_tree_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text('Long-press a node, then tap target',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () =>
                ref.read(dashboardUiProvider.notifier).stopReparenting(),
            child: const Icon(Icons.close, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// TreeNode – Column layout so toggle is INSIDE bounds
// ──────────────────────────────────────────────
class TreeNode extends StatelessWidget {
  final TreeLayoutNode node;
  final bool isSelected;
  final bool isExpanded;
  final bool isReparenting;
  final VoidCallback onSelect;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  const TreeNode({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isExpanded,
    this.isReparenting = false,
    required this.onSelect,
    required this.onToggle,
    required this.onLongPress,
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
      boxShadow = [
        BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2)
      ];
    } else if (isCompleted) {
      borderColor = colorScheme.secondary.withValues(alpha: 0.3);
      bgColor = colorScheme.secondary.withValues(alpha: 0.05);
      opacity = 0.7;
    }

    if (isReparenting) {
      borderColor = colorScheme.primary;
      bgColor = colorScheme.primary.withValues(alpha: 0.1);
    }

    // The node is a Column:
    //   [Card body — tappable for select/double-tap/long-press]
    //   [Toggle button row — only shown if node has children]
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Card body ──────────────────────────────
        GestureDetector(
          onTap: onSelect,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: TreeLayoutEngine.cardHeight,
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected || isReparenting
                    ? colorScheme.primary
                    : borderColor,
                width: isSelected || isReparenting ? 2 : 1,
              ),
              boxShadow: isSelected || isReparenting
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: isReparenting ? 20 : 10,
                        spreadRadius: isReparenting ? 4 : 2,
                      )
                    ]
                  : boxShadow,
            ),
            transform: isReparenting
                ? (Matrix4.identity()..scale(1.05))
                : Matrix4.identity(),
            child: Opacity(
              opacity: opacity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Status badge
                  Positioned(
                    top: -14,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _statusColor(colorScheme, activity.status),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Icon(_statusIcon(activity.status),
                          size: 12, color: Colors.white),
                    ),
                  ),
                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        activity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isRunning
                              ? colorScheme.primary
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 10, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(activity.totalSeconds),
                            style: TextStyle(
                                fontSize: 10,
                                color: theme.hintColor,
                                fontWeight: FontWeight.bold),
                          ),
                          if (isRunning) ...[
                            const Spacer(),
                            Icon(Icons.bolt,
                                size: 12, color: colorScheme.primary),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Toggle button ─ BELOW card, inside Column bounds ──
        if (node.children.isNotEmpty)
          SizedBox(
            height: TreeLayoutEngine.toggleHeight,
            child: Center(
              child: GestureDetector(
                // Stop tap propagating up to the canvas GestureDetector
                onTap: () => onToggle(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isExpanded
                          ? colorScheme.primary
                          : theme.dividerColor,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color:
                        isExpanded ? colorScheme.primary : theme.hintColor,
                  ),
                ),
              ),
            ),
          )
        else
          // Keep height consistent for leaf nodes
          SizedBox(height: TreeLayoutEngine.toggleHeight),
      ],
    );
  }

  Color _statusColor(ColorScheme cs, ActivityStatus s) {
    switch (s) {
      case ActivityStatus.running:
        return cs.primary;
      case ActivityStatus.paused:
        return Colors.orange;
      case ActivityStatus.completed:
        return cs.secondary;
      default:
        return cs.outline;
    }
  }

  IconData _statusIcon(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.running:
        return Icons.bolt;
      case ActivityStatus.paused:
        return Icons.pause;
      case ActivityStatus.completed:
        return Icons.check;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ──────────────────────────────────────────────
// TreePainter
// ──────────────────────────────────────────────
class TreePainter extends CustomPainter {
  final Map<String, TreeLayoutNode> layout;
  final Set<String> expandedNodes;
  final String? activeNodeId;
  final ThemeData theme;
  final double animationValue;

  TreePainter({
    required this.layout,
    required this.expandedNodes,
    this.activeNodeId,
    required this.theme,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;

    final Set<String> activePathNodeIds = {};
    if (activeNodeId != null) {
      String? currentId = activeNodeId;
      while (currentId != null) {
        activePathNodeIds.add(currentId);
        currentId = layout[currentId]?.activity.parentId;
      }
    }

    for (final node in layout.values) {
      if (!expandedNodes.contains(node.activity.id)) continue;
      for (final child in node.children) {
        // Edge starts at bottom of CARD (not bottom of full nodeHeight)
        final startX = node.x;
        final startY = node.y + TreeLayoutEngine.cardHeight;
        final endX = child.x;
        final endY = child.y;
        if (endX == 0 && endY == 0) continue;

        final midY = (startY + endY) / 2;
        final path = Path()
          ..moveTo(startX, startY)
          ..cubicTo(startX, midY, endX, midY, endX, endY);

        final isActivePath = activePathNodeIds.contains(child.activity.id);
        
        paint.color = isActivePath
            ? theme.colorScheme.primary.withValues(alpha: 0.8)
            : theme.colorScheme.onSurface.withValues(alpha: 0.4);
        paint.strokeWidth = isActivePath ? 4 : 2.5;
        canvas.drawPath(path, paint);

        if (isActivePath) {
          final dashPath = _createAnimatedDashPath(path, animationValue);
          canvas.drawPath(
              dashPath,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5
                ..color = theme.colorScheme.primary);
        }
      }
    }
  }

  Path _createAnimatedDashPath(Path source, double dashPhase) {
    final path = Path();
    for (final metric in source.computeMetrics()) {
      const dash = 10.0, gap = 10.0;
      final step = dash + gap;
      double start = (dashPhase * step) % step;
      if (start > 0) start -= step;
      for (double d = start; d < metric.length; d += step) {
        final s = math.max(0.0, d);
        final e = math.min(metric.length, d + dash);
        if (s < e) path.addPath(metric.extractPath(s, e), Offset.zero);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant TreePainter old) =>
      old.layout != layout ||
      old.expandedNodes != expandedNodes ||
      old.activeNodeId != activeNodeId ||
      old.animationValue != animationValue;
}

// ──────────────────────────────────────────────
// DetailsPanel
// ──────────────────────────────────────────────
class DetailsPanel extends ConsumerStatefulWidget {
  final String? selectedNodeId;
  final VoidCallback? onDetach;
  const DetailsPanel({super.key, this.selectedNodeId, this.onDetach});

  @override
  ConsumerState<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends ConsumerState<DetailsPanel> {
  bool _isManualOverride = false;
  bool _manualIsMobile = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final bool isAutoMobile = screenWidth < 600;
        final bool isMobileMode = _isManualOverride ? _manualIsMobile : isAutoMobile;

        // Scale down proportionally for smaller screens, max out at 280
        double panelWidth = isMobileMode ? constraints.maxWidth * 0.95 : constraints.maxWidth * 0.85;
        if (!isMobileMode && panelWidth > 280) panelWidth = 280;
        if (isMobileMode && panelWidth > 320) panelWidth = 320;

        final theme = Theme.of(context);
        if (widget.selectedNodeId == null) {
          return GestureDetector(
            onLongPress: () {
              setState(() {
                _isManualOverride = true;
                _manualIsMobile = !isMobileMode;
              });
            },
            child: Container(
              width: panelWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(isMobileMode ? 16 : 24),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.1))),
              child: Text(isMobileMode ? 'Select a node' : 'Select a node to view details',
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
            ),
          );
        }
        
        final activity =
            ref.watch(activityControllerProvider).activitiesMap[widget.selectedNodeId];
        if (activity == null) return const SizedBox.shrink();

        final colorScheme = theme.colorScheme;
        return GestureDetector(
          onLongPress: () {
            setState(() {
              _isManualOverride = true;
              _manualIsMobile = !isMobileMode;
            });
          },
          child: Container(
            width: panelWidth,
            padding: EdgeInsets.all(isMobileMode ? 12 : 20),
            decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: isMobileMode ? 10 : 20,
                      offset: Offset(0, isMobileMode ? 5 : 10))
                ]),
            child: isMobileMode ? _buildMobileContent(context, theme, colorScheme, activity) : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('EXPLORER DETAILS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: theme.hintColor)),
                ]),
                const Divider(height: 24),
                Text(activity.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _statusColor(colorScheme, activity.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _statusColor(colorScheme, activity.status)
                              .withValues(alpha: 0.3))),
                  child: Text(activity.status.name.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(colorScheme, activity.status))),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _stat(context, Icons.access_time, 'Duration',
                          _formatDuration(activity.totalSeconds)),
                    ),
                    if (activity.type == ActivityType.countBased)
                      Expanded(
                        child: _stat(context, Icons.numbers, 'Count',
                            ref.watch(activityControllerProvider).getCountTotalFor(activity.id).toStringAsFixed(0)),
                      ),
                  ],
                ),
                if (activity.status != ActivityStatus.completed) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (activity.status == ActivityStatus.paused || activity.status == ActivityStatus.idle)
                        Expanded(
                          child: _controlBtn(context, Icons.play_arrow, 'Resume', () {
                            ref.read(activityControllerProvider.notifier).startActivity(activity.id);
                          }),
                        ),
                      if (activity.status == ActivityStatus.running)
                        Expanded(
                          child: _controlBtn(context, Icons.pause, 'Pause', () {
                            ref.read(activityControllerProvider.notifier).pauseActivity(activity.id);
                          }),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _controlBtn(context, Icons.check, 'Finish', () {
                          ref.read(activityControllerProvider.notifier).completeActivity(activity.id);
                        }),
                      ),
                    ],
                  ),
                ],
                if (activity.type == ActivityType.countBased && activity.status != ActivityStatus.completed) ...[
                  const SizedBox(height: 16),
                  _CountInputContainer(activityId: activity.id),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        barrierColor: Colors.transparent,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        builder: (context) => CreateActivitySheet(parentId: activity.id),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Activity', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                // Detach button — only visible when node has a parent
                if (activity.parentId != null && widget.onDetach != null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: widget.onDetach,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_off, size: 12, color: Colors.red),
                          SizedBox(width: 6),
                          Text('Detach from parent',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/activity/${activity.id}');
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Visit Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileContent(BuildContext context, ThemeData theme, ColorScheme colorScheme, Activity activity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                activity.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(colorScheme, activity.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _statusColor(colorScheme, activity.status).withValues(alpha: 0.3)),
              ),
              child: Text(
                activity.status.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: _statusColor(colorScheme, activity.status),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.access_time, size: 12, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              _formatDuration(activity.totalSeconds),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor),
            ),
            if (activity.type == ActivityType.countBased) ...[
              const SizedBox(width: 12),
              Icon(Icons.numbers, size: 12, color: theme.hintColor),
              const SizedBox(width: 4),
              Text(
                ref.watch(activityControllerProvider).getCountTotalFor(activity.id).toStringAsFixed(0),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor),
              ),
            ],
          ],
        ),
        if (activity.status != ActivityStatus.completed) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (activity.status == ActivityStatus.paused || activity.status == ActivityStatus.idle)
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  color: colorScheme.primary,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.read(activityControllerProvider.notifier).startActivity(activity.id),
                ),
              if (activity.status == ActivityStatus.running)
                IconButton(
                  icon: const Icon(Icons.pause),
                  color: colorScheme.primary,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.read(activityControllerProvider.notifier).pauseActivity(activity.id),
                ),
              IconButton(
                icon: const Icon(Icons.check),
                color: colorScheme.primary,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => ref.read(activityControllerProvider.notifier).completeActivity(activity.id),
              ),
              if (widget.onDetach != null && activity.parentId != null)
                IconButton(
                  icon: const Icon(Icons.link_off),
                  color: Colors.red,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onDetach,
                ),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                color: Colors.blue,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pushNamed(context, '/activity/${activity.id}'),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: colorScheme.primary,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    barrierColor: Colors.transparent,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    builder: (context) => CreateActivitySheet(parentId: activity.id),
                  );
                },
              ),
            ],
          ),
          if (activity.type == ActivityType.countBased) ...[
            const SizedBox(height: 8),
            _CountInputContainer(activityId: activity.id),
          ],
        ],
      ],
    );
  }

  Widget _stat(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 10, color: theme.hintColor),
        const SizedBox(width: 4),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: theme.hintColor))
      ]),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _controlBtn(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme cs, ActivityStatus s) {
    switch (s) {
      case ActivityStatus.running:
        return cs.primary;
      case ActivityStatus.paused:
        return Colors.orange;
      case ActivityStatus.completed:
        return cs.secondary;
      default:
        return cs.outline;
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ──────────────────────────────────────────────
// CountInputContainer
// ──────────────────────────────────────────────
class _CountInputContainer extends ConsumerStatefulWidget {
  final String activityId;
  const _CountInputContainer({required this.activityId});

  @override
  ConsumerState<_CountInputContainer> createState() => _CountInputContainerState();
}

class _CountInputContainerState extends ConsumerState<_CountInputContainer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final val = double.tryParse(_controller.text);
    if (val != null && val != 0) {
      if (val > 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot insert values above 500.')),
        );
        return;
      }
      ref.read(activityControllerProvider.notifier).addCount(widget.activityId, val);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  final val = double.tryParse(newValue.text);
                  if (val != null && val > 500) return oldValue;
                  return newValue;
                }),
              ],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Add count value...',
                hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _submit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, size: 16, color: theme.colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// TreeControls
// ──────────────────────────────────────────────
class TreeControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  const TreeControls(
      {super.key,
      required this.onZoomIn,
      required this.onZoomOut,
      required this.onReset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      _btn(Icons.add, onZoomIn, theme),
      const SizedBox(height: 8),
      _btn(Icons.remove, onZoomOut, theme),
      const SizedBox(height: 8),
      _btn(Icons.fullscreen, onReset, theme, primary: true),
    ]);
  }

  Widget _btn(IconData icon, VoidCallback onPressed, ThemeData theme,
      {bool primary = false}) {
    return Container(
      decoration: BoxDecoration(
          color: primary ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: IconButton(
          icon: Icon(icon,
              color: primary ? Colors.white : theme.iconTheme.color),
          onPressed: onPressed),
    );
  }
}
