import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:active/presentation/pages/agent/agent_page.dart';
import 'package:active/presentation/pages/home/home_page.dart';
import 'package:active/presentation/pages/stats/stats_page.dart';
import 'package:active/presentation/providers/nav_provider.dart';
import 'package:active/presentation/theme/app_theme.dart';

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey(currentTab),
                child: switch (currentTab) {
                  AppTab.home => const HomePage(),
                  AppTab.stats => const StatsPage(),
                  AppTab.agent => const AgentPage(),
                },
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 22,
            child: _FloatingNavBar(
              currentTab: currentTab,
              onTabSelected: (tab) {
                ref.read(currentTabProvider.notifier).state = tab;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentTab,
    required this.onTabSelected,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.getBorderCard(isDark),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x77000000) : const Color(0x24000000),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth) / 3;

          return Stack(
            children: [
              // Smooth Sliding Pill Capsule
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: currentTab == AppTab.home
                    ? const Alignment(-1.0, 0.0)
                    : currentTab == AppTab.stats
                        ? const Alignment(0.0, 0.0)
                        : const Alignment(1.0, 0.0),
                child: Container(
                  width: itemWidth,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceDark(isDark),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Nav Buttons Row
              Row(
                children: [
                  Expanded(
                    child: _NavButton(
                      label: 'Home',
                      icon: Icons.home_rounded,
                      isActive: currentTab == AppTab.home,
                      onTap: () => onTabSelected(AppTab.home),
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      label: 'Stats',
                      icon: Icons.bar_chart_rounded,
                      isActive: currentTab == AppTab.stats,
                      onTap: () => onTabSelected(AppTab.stats),
                    ),
                  ),
                  Expanded(
                    child: _NavButton(
                      label: 'Agent',
                      icon: Icons.smart_toy_rounded,
                      isActive: currentTab == AppTab.agent,
                      onTap: () => onTabSelected(AppTab.agent),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeFg = AppColors.getTextOnDark(isDark);
    final inactiveFg = AppColors.getTextMuted(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  size: 20,
                  color: isActive ? activeFg : inactiveFg,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? activeFg : inactiveFg,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
