import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/backup_provider.dart';
import '../../providers/activity_manager_provider.dart';
import '../../providers/stats_provider.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackupController>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BackupController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backups'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => controller.loadHistory())],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: controller.history.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: controller.history.length,
                          itemBuilder: (context, index) {
                            final backup = controller.history[index];
                            return _BackupListItem(backup: backup);
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ElevatedButton.icon(
          onPressed: controller.isLoading
              ? null
              : () async {
                  try {
                    await controller.createBackup();
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Backup created successfully')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Failed to create backup: $e')));
                    }
                  }
                },
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Create New Backup'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keep your data safe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Backups are stored securely in the cloud. You can restore your data at any time.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _showClearDataDialog(context),
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    final TextEditingController confirmController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is IRREVERSIBLE. All your activities, events, and records will be deleted forever.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('To confirm, type "haseeb" below:', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(hintText: 'Type haseeb here', border: OutlineInputBorder()),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: confirmController,
            builder: (context, value, child) {
              final bool isConfirmed = value.text.toLowerCase() == 'haseeb';
              return ElevatedButton(
                onPressed: isConfirmed
                    ? () async {
                        Navigator.pop(dialogContext);
                        final activityController = context.read<ActivityController>();
                        final statsController = context.read<StatsController>();
                        try {
                          await activityController.clearAllData();
                          await statsController.loadData();
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('All data has been cleared.')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Failed to clear data: $e')));
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConfirmed ? Colors.red : null,
                  foregroundColor: isConfirmed ? Colors.white : null,
                ),
                child: const Text('Clear Everything'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('No backups found'),
        ],
      ),
    );
  }
}

class _BackupListItem extends StatelessWidget {
  final dynamic backup;

  const _BackupListItem({required this.backup});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(backup.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.backup_outlined)),
        title: Text(backup.fileName),
        subtitle: Text('Created on $dateStr'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'restore',
              child: Row(children: [Icon(Icons.restore, size: 20), SizedBox(width: 8), Text('Restore')]),
            ),
          ],
          onSelected: (value) {
            if (value == 'restore') {
              _showRestoreDialog(context);
            }
          },
        ),
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text(
          'This will merge the backup with your current activities. Conflicts will be resolved by keeping the version with more data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final controller = context.read<BackupController>();
              final activityController = context.read<ActivityController>();

              try {
                await controller.restoreFrom(backup);
                // Refresh activity controller to reflect merged data
                await activityController.loadActivities();

                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Restore completed successfully')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                }
              }
            },
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );
  }
}
