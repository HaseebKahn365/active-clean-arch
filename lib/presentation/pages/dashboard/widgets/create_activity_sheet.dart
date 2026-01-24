import 'package:duration_picker/duration_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/activity.dart';
import '../../../providers/activity_manager_provider.dart';

class CreateActivitySheet extends StatefulWidget {
  final String? parentId;
  const CreateActivitySheet({super.key, this.parentId});

  @override
  State<CreateActivitySheet> createState() => _CreateActivitySheetState();
}

class _CreateActivitySheetState extends State<CreateActivitySheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _expectedDurationController = TextEditingController(text: '00:00:00');
  final _formKey = GlobalKey<FormState>();
  int _goalSeconds = 0;
  ActivityType _type = ActivityType.timeBased;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _expectedDurationController.dispose();
    super.dispose();
  }

  String _formatToClock(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showDurationPicker() async {
    final resultingDuration = await showDurationPicker(
      context: context,
      initialTime: Duration(seconds: _goalSeconds),
      baseUnit: BaseUnit.minute,
    );

    if (resultingDuration != null && mounted) {
      setState(() {
        _goalSeconds = resultingDuration.inSeconds;
        _expectedDurationController.text = _formatToClock(_goalSeconds);
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<ActivityController>().createActivity(
        _nameController.text.trim(),
        parentId: widget.parentId,
        description: _descriptionController.text.trim(),
        goalSeconds: _goalSeconds,
        type: _type,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.parentId == null ? 'New Activity' : 'New Sub-Activity',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Define your activity details and set an optional goal.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SegmentedButton<ActivityType>(
                segments: const [
                  ButtonSegment(
                    value: ActivityType.timeBased,
                    label: Text('Time-Based'),
                    icon: Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment(
                    value: ActivityType.countBased,
                    label: Text('Count-Based'),
                    icon: Icon(Icons.numbers_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (val) {
                  setState(() {
                    _type = val.first;
                  });
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Reading, Deep Work',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.title),
                ),
                style: TextStyle(color: colorScheme.onSurface),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'What are you planning to do?',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
                maxLines: 2,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              if (_type == ActivityType.timeBased) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expectedDurationController,
                  readOnly: true,
                  onTap: _showDurationPicker,
                  decoration: InputDecoration(
                    labelText: 'Expected Duration',
                    hintText: 'Set a goal time',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.timer_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.watch_later_outlined),
                      onPressed: _showDurationPicker,
                    ),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Create Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
