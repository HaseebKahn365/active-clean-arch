import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/riverpod_bridge.dart';
import '../../../providers/pause_notifier.dart';
import '../../../widgets/glowing_quote_text.dart';
import '../details/time_details_page.dart';
import '../details/counts_details_page.dart';
import '../details/pause_details_page.dart';
import '../details/done_details_page.dart';

class ProductivityContainers extends ConsumerWidget {
  const ProductivityContainers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: _PlanNameContainer()),
            SizedBox(width: 8),
            Flexible(child: _TimeContainer()),
            SizedBox(width: 8),
            Flexible(child: _CountsContainer()),
            SizedBox(width: 8),
            Flexible(child: _PauseResumeController()),
            SizedBox(width: 8),
            const Flexible(child: _DoneContainer()),
          ],
        ),
      ),
    );
  }
}

class _PlanNameContainer extends ConsumerWidget {
  const _PlanNameContainer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wrap GlowingQuoteText to allow it to expand
    return const GlowingQuoteText();
  }
}

class _ProductivityItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isActive;

  const _ProductivityItem({required this.child, this.onTap, this.onLongPress, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.onPrimary.withAlpha(50) : colorScheme.onPrimary.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? Colors.greenAccent.withAlpha(120) : colorScheme.onPrimary.withAlpha(40),
              width: 1.2,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _StatContent extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatContent({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? colorScheme.onPrimary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: (color ?? colorScheme.onPrimary).withAlpha(180),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(color: color ?? colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeContainer extends ConsumerWidget {
  const _TimeContainer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsControllerProvider);
    final seconds = stats.getTodayFocusTime();
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final secs = duration.inSeconds % 60;

    String formatted = hours > 0 ? '${hours}h ${minutes}m' : (minutes > 0 ? '${minutes}m ${secs}s' : '${secs}s');

    return _ProductivityItem(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeDetailsPage())),
      child: _StatContent(label: 'Today', value: formatted, icon: Icons.timer_outlined),
    );
  }
}

class _CountsContainer extends ConsumerWidget {
  const _CountsContainer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsControllerProvider);
    final count = stats.getTodayCounts();
    return _ProductivityItem(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CountsDetailsPage())),
      child: _StatContent(label: 'Counts', value: count.toInt().toString(), icon: Icons.add_circle_outline),
    );
  }
}

class _DoneContainer extends ConsumerWidget {
  const _DoneContainer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsControllerProvider);
    final count = stats.getTodayDoneCount();
    return _ProductivityItem(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoneDetailsPage())),
      child: _StatContent(label: 'Done', value: count.toString(), icon: Icons.check_circle_outline),
    );
  }
}

class _PauseResumeController extends ConsumerWidget {
  const _PauseResumeController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pausedIds = ref.watch(pauseStateProvider);
    final pauseNotifier = ref.read(pauseStateProvider.notifier);
    final activityController = ref.watch(activityControllerProvider);
    final hasRunning = activityController.hasRunningActivity;
    final isPausedViaController = pausedIds.isNotEmpty;

    return _ProductivityItem(
      isActive: hasRunning,
      onTap: () {
        if (hasRunning) {
          pauseNotifier.pauseAll();
        } else if (isPausedViaController) {
          pauseNotifier.resumeAll();
        }
      },
      onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PauseDetailsPage())),
      child: _StatContent(
        label: hasRunning ? 'Active' : (isPausedViaController ? 'Paused' : 'Global'),
        value: hasRunning ? 'Pause' : (isPausedViaController ? 'Resume' : 'Idle'),
        icon: hasRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: hasRunning ? Colors.greenAccent : null,
      ),
    );
  }
}
