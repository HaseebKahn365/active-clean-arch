import 'package:flutter/material.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

export 'package:active/presentation/pages/home/models/activity.dart' show ActivityType;

class CreateActivityField extends StatefulWidget {
  const CreateActivityField({super.key, required this.onCreate});

  final void Function(String name, ActivityType type) onCreate;

  @override
  State<CreateActivityField> createState() => _CreateActivityFieldState();
}

class _CreateActivityFieldState extends State<CreateActivityField> {
  final _nameController = TextEditingController();
  ActivityType _type = ActivityType.count;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    widget.onCreate(name, _type);
    _nameController.clear();
    setState(() => _type = ActivityType.count);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Activity name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<ActivityType>(
          segments: const [
            ButtonSegment(
              value: ActivityType.count,
              icon: Icon(Icons.tag),
            ),
            ButtonSegment(
              value: ActivityType.time,
              icon: Icon(Icons.schedule),
            ),
          ],
          selected: {_type},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            setState(() => _type = selection.first);
          },
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _submit,
          icon: const Icon(Icons.check),
        ),
      ],
    );
  }
}
