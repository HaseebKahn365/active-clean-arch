import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:active/presentation/pages/agent/agent_page.dart';
import 'package:active/presentation/pages/home/home_page.dart';
import 'package:active/presentation/pages/stats/stats_page.dart';
import 'package:active/presentation/providers/nav_provider.dart';

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentTab.index,
        children: const [HomePage(), StatsPage(), AgentPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab.index,
        onDestinationSelected: (index) {
          ref.read(currentTabProvider.notifier).state = AppTab.values[index];
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'Agent'),
        ],
      ),
    );
  }
}
