import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/activity.dart';
import '../providers/activity_provider.dart';
import '../pages/dashboard/widgets/create_activity_sheet.dart';
import 'package:duration_picker/duration_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  late TextEditingController _durationController;
  late TextEditingController _goalDurationController;
  final _formKey = GlobalKey<FormState>();
  bool _showTimeAgo = true;
  late int _goalSeconds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activity.name);
    _descriptionController = TextEditingController(text: widget.activity.description);
    _durationController = TextEditingController(text: _formatToClock(widget.activity.totalSeconds));
    _goalSeconds = widget.activity.goalSeconds;
    _goalDurationController = TextEditingController(text: _formatToClock(_goalSeconds));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _goalDurationController.dispose();
    super.dispose();
  }

  String _formatToClock(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int? _parseClock(String clock) {
    final parts = clock.split(':');
    if (parts.length != 3) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = int.tryParse(parts[2]);
    if (h == null || m == null || s == null) return null;
    if (m >= 60 || s >= 60) return null;
    return (h * 3600) + (m * 60) + s;
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  Future<void> _showDurationPicker() async {
    final currentSeconds = _parseClock(_durationController.text) ?? widget.activity.totalSeconds;
    final resultingDuration = await showDurationPicker(
      context: context,
      initialTime: Duration(seconds: currentSeconds),
      baseUnit: BaseUnit.minute,
    );

    if (resultingDuration != null && mounted) {
      setState(() {
        _durationController.text = _formatToClock(resultingDuration.inSeconds);
      });
    }
  }

  Future<void> _showGoalDurationPicker() async {
    final resultingDuration = await showDurationPicker(
      context: context,
      initialTime: Duration(seconds: _goalSeconds),
      baseUnit: BaseUnit.minute,
    );

    if (resultingDuration != null && mounted) {
      setState(() {
        _goalSeconds = resultingDuration.inSeconds;
        _goalDurationController.text = _formatToClock(_goalSeconds);
      });
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity? All progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              widget.controller.deleteActivity(widget.activity.id);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close sheet
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final activity = widget.controller.activitiesMap[widget.activity.id] ?? widget.activity;

      // Update basic details
      await widget.controller.updateActivity(
        widget.activity.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        goalSeconds: _goalSeconds,
      );

      // Update duration if changed and valid
      final newSeconds = _parseClock(_durationController.text);
      if (newSeconds != null && newSeconds != activity.totalSeconds) {
        if (activity.status == ActivityStatus.running) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Cannot edit duration while activity is running.')));
          }
        } else {
          await widget.controller.updateActivityDuration(widget.activity.id, newSeconds);
        }
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: titleLarge),
                                          Text(
                                            widget.activity.type == ActivityType.timeBased
                                                ? "Type: Time-Based"
                                                : "Type: Count-Based",
                                            style: bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      widget.activity.type == ActivityType.timeBased
                                          ? Icons.timer_outlined
                                          : Icons.numbers_rounded,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 8),
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
                      FutureBuilder<List<Activity>>(
                        future: widget.controller.getBreadcrumbs(widget.activity.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                          final pathDetails = snapshot.data!.map((a) => a.name).join(' > ');
                          return Text(pathDetails, style: bodySmall);
                        },
                      ),
                      const Divider(height: 32),
                      // Description and Goal
                      Selector<ActivityController, Activity?>(
                        selector: (_, ctrl) => ctrl.activitiesMap[widget.activity.id],
                        builder: (context, activity, _) {
                          final desc = activity?.description ?? '';
                          final goal = activity?.goalSeconds ?? 0;

                          if (desc.isEmpty && goal == 0) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (desc.isNotEmpty) ...[
                                Text("Description", style: titleMedium),
                                const SizedBox(height: 4),
                                Text(desc, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 16),
                              ],
                              if (goal > 0) ...[
                                Row(
                                  children: [
                                    Icon(Icons.flag_outlined, size: 16, color: colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Goal: ${_formatDuration(goal)}",
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          );
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Selector<ActivityController, ActivityStatus>(
                              selector: (_, ctrl) =>
                                  ctrl.activitiesMap[widget.activity.id]?.status ?? ActivityStatus.idle,
                              builder: (context, status, _) {
                                final isRunning = status == ActivityStatus.running;
                                final isCompleted = status == ActivityStatus.completed;
                                if (isCompleted) {
                                  return OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text("Completed"),
                                  );
                                }
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
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: colorScheme.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  builder: (context) => CreateActivitySheet(parentId: widget.activity.id),
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

                      const SizedBox(height: 16),
                      // Created At Label
                      InkWell(
                        onTap: () => setState(() => _showTimeAgo = !_showTimeAgo),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _showTimeAgo
                                    ? 'Created ${timeago.format(widget.activity.createdAt)}'
                                    : 'Created on ${DateFormat('d MMM yyyy, h:m:a').format(widget.activity.createdAt)}',
                                style: bodySmall?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      // Duration Edit
                      Selector<ActivityController, ActivityStatus>(
                        selector: (_, ctrl) => ctrl.activitiesMap[widget.activity.id]?.status ?? ActivityStatus.idle,
                        builder: (context, status, _) {
                          final isRunning = status == ActivityStatus.running;
                          return TextFormField(
                            controller: _durationController,
                            enabled: !isRunning,
                            decoration: InputDecoration(
                              labelText: 'Total Duration (HH:MM:SS)',
                              border: const OutlineInputBorder(),
                              helperText: isRunning
                                  ? 'Cannot edit duration while running'
                                  : 'Adjust HH:MM:SS or use the picker',
                              prefixIcon: const Icon(Icons.timer_outlined),
                              suffixIcon: isRunning
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.watch_later_outlined),
                                      onPressed: _showDurationPicker,
                                    ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                              DurationInputFormatter(),
                            ],
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Duration is required';
                              if (_parseClock(value) == null) return 'Invalid format (use HH:MM:SS)';
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _goalDurationController,
                        readOnly: true,
                        onTap: _showGoalDurationPicker,
                        decoration: InputDecoration(
                          labelText: 'Expected Duration (Goal)',
                          border: const OutlineInputBorder(),
                          helperText: 'Tap to open duration picker',
                          prefixIcon: const Icon(Icons.flag_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.watch_later_outlined),
                            onPressed: _showGoalDurationPicker,
                          ),
                        ),
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
                                  _durationController.text = _formatToClock(widget.activity.totalSeconds);
                                  _goalSeconds = widget.activity.goalSeconds;
                                  _goalDurationController.text = _formatToClock(_goalSeconds);
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
                        onPressed: _confirmDelete,
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

class DurationInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(':', '');
    if (text.length > 6) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if ((i == 1 || i == 3) && i != text.length - 1) {
        formatted += ':';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
