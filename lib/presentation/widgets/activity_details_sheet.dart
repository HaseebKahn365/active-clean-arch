import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/activity.dart';
import '../providers/activity_provider.dart';
import '../pages/add_activity_page.dart';

class ActivityDetailsSheet extends StatefulWidget {
  final Activity activity;
  final ActivityController controller;

  const ActivityDetailsSheet({super.key, required this.activity, required this.controller});

  @override
  State<ActivityDetailsSheet> createState() => _ActivityDetailsSheetState();
}

class _ActivityDetailsSheetState extends State<ActivityDetailsSheet> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activity.name);
    _descriptionController = TextEditingController(text: widget.activity.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      await widget.controller.updateActivity(
        widget.activity.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      setState(() {
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleLarge = theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodySmall = theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final titleMedium = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isEditing) ...[
                      // View Mode Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Selector<ActivityController, String>(
                              selector: (_, ctrl) =>
                                  ctrl.activitiesMap[widget.activity.id]?.name ?? widget.activity.name,
                              builder: (context, name, _) {
                                return Row(
                                  children: [
                                    Expanded(child: Text(name, style: titleLarge)),
                                    Selector<ActivityController, bool>(
                                      selector: (_, ctrl) =>
                                          ctrl.activitiesMap[widget.activity.id]?.isPinned ?? widget.activity.isPinned,
                                      builder: (context, isPinned, _) {
                                        return IconButton(
                                          icon: Icon(
                                            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                            size: 20,
                                            color: isPinned ? colorScheme.primary : null,
                                          ),
                                          onPressed: () => widget.controller.togglePin(widget.activity.id),
                                          visualDensity: VisualDensity.compact,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      onPressed: () => setState(() => _isEditing = true),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          // Ticking Duration
                          ListenableBuilder(
                            listenable: widget.controller,
                            builder: (context, _) {
                              final currentSeconds = widget.controller.getEffectiveSeconds(widget.activity.id);
                              return Text(
                                _formatDuration(currentSeconds),
                                style: bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  fontFamily: 'Monospace',
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Path display
                      FutureBuilder<List<Activity>>(
                        future: widget.controller.getBreadcrumbs(widget.activity.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final pathDetails = snapshot.data!.map((a) => a.name).join(' > ');
                          return Text(pathDetails, style: bodySmall);
                        },
                      ),

                      const Divider(height: 32),

                      // Description
                      Selector<ActivityController, String>(
                        selector: (_, ctrl) => ctrl.activitiesMap[widget.activity.id]?.description ?? '',
                        builder: (context, desc, _) {
                          if (desc.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Description", style: titleMedium),
                              const SizedBox(height: 4),
                              Text(desc, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),

                      // Main Actions
                      Row(
                        children: [
                          // Toggle Start/Pause
                          Expanded(
                            child: Selector<ActivityController, ActivityStatus>(
                              selector: (_, ctrl) =>
                                  ctrl.activitiesMap[widget.activity.id]?.status ?? ActivityStatus.idle,
                              builder: (context, status, _) {
                                final isRunning = status == ActivityStatus.running;
                                return OutlinedButton.icon(
                                  onPressed: () {
                                    if (isRunning) {
                                      widget.controller.pauseActivity(widget.activity.id);
                                    } else {
                                      widget.controller.startActivity(widget.activity.id);
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                                  icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                                  label: Text(isRunning ? "Pause" : "Start"),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Add Sub-Activity Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddActivityPage(parentId: widget.activity.id)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                minimumSize: const Size(0, 48),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text("Add Sub-Activity"),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Edit Mode
                      Text("Edit Activity", style: titleLarge),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Name cannot be empty' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _nameController.text = widget.activity.name;
                                  _descriptionController.text = widget.activity.description;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                minimumSize: const Size(0, 48),
                              ),
                              child: const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          widget.controller.deleteActivity(widget.activity.id);
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.delete_outline, color: colorScheme.error),
                        label: Text('Delete', style: TextStyle(color: colorScheme.error)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
