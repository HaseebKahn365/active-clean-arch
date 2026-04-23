import '../../../../../domain/entities/activity.dart';

class TreeLayoutNode {
  final Activity activity;
  final List<TreeLayoutNode> children;
  double x;
  double y;
  double subtreeWidth;

  TreeLayoutNode({
    required this.activity,
    required this.children,
    this.x = 0,
    this.y = 0,
    this.subtreeWidth = 0,
  });
}

class TreeLayoutEngine {
  static const double nodeWidth = 200;
  static const double cardHeight = 80;   // card body height
  static const double toggleHeight = 36; // toggle button area below card
  static const double nodeHeight = cardHeight + toggleHeight; // total node height
  static const double horizontalGap = 60;
  static const double verticalGap = 160;

  static Map<String, TreeLayoutNode> calculateLayout(
    List<Activity> activities,
    Set<String> expandedNodes,
  ) {
    final Map<String, TreeLayoutNode> layoutMap = {};
    
    // Create nodes
    for (final activity in activities) {
      layoutMap[activity.id] = TreeLayoutNode(
        activity: activity,
        children: [],
      );
    }

    final List<TreeLayoutNode> roots = [];
    for (final activity in activities) {
      final node = layoutMap[activity.id]!;
      if (activity.parentId != null) {
        layoutMap[activity.parentId]?.children.add(node);
      } else {
        roots.add(node);
      }
    }

    // Step 1: Calculate subtree widths
    double calculateWidths(TreeLayoutNode node) {
      if (!expandedNodes.contains(node.activity.id) || node.children.isEmpty) {
        node.subtreeWidth = nodeWidth;
        return nodeWidth;
      }
      
      double childrenWidth = 0;
      for (int i = 0; i < node.children.length; i++) {
        childrenWidth += calculateWidths(node.children[i]);
        if (i < node.children.length - 1) {
          childrenWidth += horizontalGap;
        }
      }
      
      node.subtreeWidth = childrenWidth.clamp(nodeWidth, double.infinity);
      return node.subtreeWidth;
    }

    for (final root in roots) {
      calculateWidths(root);
    }

    // Step 2: Assign positions
    void assignPositions(TreeLayoutNode node, double startX, int depth) {
      node.y = depth * verticalGap;
      node.x = startX + (node.subtreeWidth / 2);
      // Edges connect from bottom of card, not bottom of full node height
      // (handled in TreePainter via cardHeight)

      if (expandedNodes.contains(node.activity.id)) {
        double currentX = startX;
        for (final child in node.children) {
          assignPositions(child, currentX, depth + 1);
          currentX += child.subtreeWidth + horizontalGap;
        }
      }
    }

    double totalX = 0;
    for (final root in roots) {
      assignPositions(root, totalX, 0);
      totalX += root.subtreeWidth + horizontalGap * 2;
    }

    return layoutMap;
  }
}
