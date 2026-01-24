import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_color_schemes.dart';
import 'widgets/activity_list.dart';
import 'widgets/pinned_activity_list.dart';
import 'widgets/create_activity_sheet.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppAuthProvider>().user;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, user),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(context),
                  const SizedBox(height: 32),
                  const PinnedActivityList(),
                  const SizedBox(height: 24),
                  Text(
                    'Current Activities',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  const ActivityList(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            barrierColor: Colors.transparent,

            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            builder: (context) => const CreateActivitySheet(),
          );
        },
        backgroundColor: colorScheme.primary,
        icon: Icon(Icons.add, color: colorScheme.onPrimary),
        label: Text(
          'New Activity',
          style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, dynamic user) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: colorScheme.primary,
      actions: [_buildThemeSelector(context)],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.primary.withAlpha(200)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (user?.photoURL != null)
                        CircleAvatar(backgroundImage: NetworkImage(user.photoURL!), radius: 24)
                      else
                        CircleAvatar(
                          backgroundColor: colorScheme.onPrimary.withAlpha(40),
                          child: Icon(Icons.person, color: colorScheme.onPrimary),
                        ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${user?.displayName?.split(" ").first ?? "User"}!',
                            style: TextStyle(color: colorScheme.onPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Consumer<SyncController>(
                            builder: (context, sync, _) {
                              return Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: sync.isSyncing ? Colors.orange : Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sync.isSyncing ? 'Syncing...' : 'Cloud Synced',
                                    style: TextStyle(color: colorScheme.onPrimary.withAlpha(200), fontSize: 12),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<dynamic>(
      icon: Icon(Icons.palette_outlined, color: colorScheme.onPrimary),
      onSelected: (value) {
        if (value is ThemeMode) {
          themeProvider.setThemeMode(value);
        } else if (value is ColorProfile) {
          themeProvider.setColorProfile(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        PopupMenuItem(
          value: ThemeMode.system,
          child: Row(
            children: [
              Icon(Icons.brightness_auto, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('System'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: Row(
            children: [
              Icon(Icons.light_mode, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Always Light'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Row(
            children: [
              Icon(Icons.dark_mode, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Always Dark'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Text('Color Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        PopupMenuItem(
          value: ColorProfile.activeBlue,
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFF6366F1), radius: 8),
              const SizedBox(width: 8),
              const Text('Active Blue'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ColorProfile.deepForest,
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFF15803D), radius: 8),
              const SizedBox(width: 8),
              const Text('Deep Forest'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ColorProfile.sunsetOrange,
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFF97316), radius: 8),
              const SizedBox(width: 8),
              const Text('Sunset Orange'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => context.read<AppAuthProvider>().signOut(),
          child: Row(
            children: [
              const Icon(Icons.logout, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Sign Out'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatsCard(
            title: 'Active Today',
            value: '4.5h',
            icon: Icons.timer,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatsCard(title: 'Streak', value: '12 Days', icon: Icons.local_fire_department, color: Colors.orange),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: cardTheme.shape is RoundedRectangleBorder
            ? Border.fromBorderSide((cardTheme.shape as RoundedRectangleBorder).side)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
