import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activity_manager_provider.dart';

class AddActivityPage extends StatefulWidget {
  final String? parentId;

  const AddActivityPage({super.key, this.parentId});

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        await context.read<ActivityController>().createActivity(
          _nameController.text.trim(),
          parentId: widget.parentId,
          description: _descriptionController.text.trim(),
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating activity: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Look up parent name if parentId is provided
    final controller = context.read<ActivityController>();
    String? parentName;
    if (widget.parentId != null) {
      final parent = controller.activitiesMap[widget.parentId];
      parentName = parent?.name;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: Text(widget.parentId == null ? 'New Activity' : 'New Sub-Activity')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (parentName != null) ...[
                Text(
                  'Creating sub-activity under: $parentName',
                  style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Activity Name', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Description (Optional - Not currently saved)', style: TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Create Activity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
