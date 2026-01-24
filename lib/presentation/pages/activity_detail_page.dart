import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/activity.dart';
import '../providers/activity_provider.dart';
import './dashboard/widgets/activity_tile.dart';
import './dashboard/widgets/create_activity_sheet.dart';

class ActivityDetailPage extends StatefulWidget {
  final String activityId;

  const ActivityDetailPage({super.key, required this.activityId});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late String _currentActivityId;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _currentActivityId = widget.activityId;
  }

  void _navigateTo(String id, {bool? forward}) {
    if (_currentActivityId == id) return;

    forward ??= false;

    setState(() {
      _isForward = forward!;
      _currentActivityId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ActivityController>();
    final activity = controller.activitiesMap[_currentActivityId];

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Not Found')),
        body: Center(
          child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
        ),
      );
    }

    final children = controller.getChildrenOf(_currentActivityId);
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: activity.parentId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (activity.parentId != null) {
          _navigateTo(activity.parentId!, forward: false);
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (activity.parentId != null) {
                _navigateTo(activity.parentId!, forward: false);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: _Breadcrumbs(
            currentId: _currentActivityId,
            onTap: (id) => _navigateTo(id, forward: false),
            onHome: () => Navigator.pop(context),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            if (_isForward) {
              // Forward: Only cross-fade (no ensemble slide as requested)
              return FadeTransition(opacity: animation, child: child);
            } else {
              // Backward: Slide from left ensemble
              final offsetAnimation = Tween<Offset>(begin: const Offset(-0.1, 0), end: Offset.zero).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            }
          },
          child: KeyedSubtree(
            key: ValueKey(_currentActivityId),
            child: children.isEmpty
                ? _buildEmptyState(colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      return ActivityTile(activity: child, onTap: () => _navigateTo(child.id, forward: true));
                    },
                  ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: colorScheme.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (context) => CreateActivitySheet(parentId: _currentActivityId),
            );
          },
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_outlined, size: 80, color: colorScheme.onSurfaceVariant.withAlpha(50)),
          const SizedBox(height: 16),
          Text(
            'No sub-activities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  final String currentId;
  final ValueChanged<String> onTap;
  final VoidCallback onHome;

  const _Breadcrumbs({required this.currentId, required this.onTap, required this.onHome});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ActivityController>();
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Activity>>(
      future: controller.getBreadcrumbs(currentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final breadcrumbs = snapshot.data!;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 24),
          child: Row(
            children: [
              _breadcrumbItem(context, 'Home', null, isLink: true),
              ...breadcrumbs.map((a) {
                final isLast = a.id == currentId;
                return Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right, size: 16, color: colorScheme.onSurfaceVariant.withAlpha(100)),
                    ),
                    _breadcrumbItem(context, a.name, a.id, isLink: !isLast),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _breadcrumbItem(BuildContext context, String title, String? id, {required bool isLink}) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<Activity>(
      onWillAcceptWithDetails: (details) {
        // Can drop any activity onto a breadcrumb level unless it's itself
        return details.data.id != id;
      },
      onAcceptWithDetails: (details) {
        context.read<ActivityController>().moveActivity(details.data.id, id);
      },
      builder: (context, candidateData, _) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHighlighted ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isHighlighted ? Border.all(color: colorScheme.primary) : null,
          ),
          child: InkWell(
            onTap: isLink ? () => id == null ? onHome() : onTap(id) : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                title,
                style: TextStyle(
                  color: isLink ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: isLink ? FontWeight.normal : FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
