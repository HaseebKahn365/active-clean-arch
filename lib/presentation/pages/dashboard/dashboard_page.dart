import 'package:active/presentation/providers/activity_manager_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_notifier.dart';
import '../../theme/app_color_schemes.dart';
import 'widgets/activity_list.dart';
import 'widgets/pinned_activity_list.dart';
import 'widgets/create_activity_sheet.dart';
import '../backup/backup_page.dart';

import 'widgets/productivity_containers.dart';
import 'widgets/tree/activity_tree.dart';
import '../../providers/dashboard_ui_notifier.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        context.read<ActivityController>().searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppAuthProvider>().user;
    final colorScheme = Theme.of(context).colorScheme;
    final uiState = ref.watch(dashboardUiProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, user),
          if (uiState.viewMode == DashboardViewMode.list)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            )
          else
            const SliverFillRemaining(child: ActivityTree()),
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
      expandedHeight: _isSearching ? 100 : 180, // Increased to fix 32px overflow
      pinned: true,
      elevation: 0,
      centerTitle: false,
      backgroundColor: colorScheme.primary,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: colorScheme.onPrimary),
              decoration: InputDecoration(
                hintText: 'Search activities...',
                hintStyle: TextStyle(color: colorScheme.onPrimary.withAlpha(150)),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: colorScheme.onPrimary),
                  onPressed: () {
                    _searchController.clear();
                    context.read<ActivityController>().searchQuery = '';
                  },
                ),
              ),
              onChanged: (value) {
                context.read<ActivityController>().searchQuery = value;
              },
            )
          : null,
      leading: _isSearching
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
              onPressed: _toggleSearch,
            )
          : null,
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.search, color: colorScheme.onPrimary),
            onPressed: _toggleSearch,
          ),
        IconButton(
          icon: Icon(Icons.cloud_upload_outlined, color: colorScheme.onPrimary),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupPage()));
          },
        ),
        _buildViewModeToggle(context),
        IconButton(
          icon: Icon(Icons.bar_chart_rounded, color: colorScheme.onPrimary),
          onPressed: () => Navigator.pushNamed(context, '/stats/global'),
        ),
        _buildThemeSelector(context),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin, // Remove "fancy" parallax scroll effect
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.primary.withAlpha(220)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _isSearching
              ? const SizedBox.shrink()
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 50, 24, 0), // Slightly reduced padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
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
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.greenAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Local Mode (Backup Only)',
                                      style: TextStyle(color: colorScheme.onPrimary.withAlpha(200), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const ProductivityContainers(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(BuildContext context) {
    final uiState = ref.watch(dashboardUiProvider);
    final uiNotifier = ref.read(dashboardUiProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.list_alt_rounded,
            color: uiState.viewMode == DashboardViewMode.list ? Colors.white : colorScheme.onPrimary.withOpacity(0.5),
          ),
          onPressed: () => uiNotifier.setViewMode(DashboardViewMode.list),
        ),
        IconButton(
          icon: Icon(
            Icons.account_tree_outlined,
            color: uiState.viewMode == DashboardViewMode.tree ? Colors.white : colorScheme.onPrimary.withOpacity(0.5),
          ),
          onPressed: () => uiNotifier.setViewMode(DashboardViewMode.tree),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    ref.watch(themeNotifierProvider);
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<dynamic>(
      icon: Icon(Icons.palette_outlined, color: colorScheme.onPrimary),
      onSelected: (value) {
        if (value is ThemeMode) {
          themeNotifier.setThemeMode(value);
        } else if (value is ColorProfile) {
          themeNotifier.setColorProfile(value);
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
}
