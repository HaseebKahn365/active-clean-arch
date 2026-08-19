import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/theme/app_theme.dart';

class MonthlyHeatMap extends StatelessWidget {
  const MonthlyHeatMap({
    super.key,
    required this.currentMonth,
    required this.dailyTotals,
    required this.activityType,
    required this.onMonthChanged,
  });

  final DateTime currentMonth;
  final Map<int, int> dailyTotals;
  final ActivityType activityType;
  final ValueChanged<DateTime> onMonthChanged;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekDayHeaders = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  /// Intensity ramp: red (lowest) → orange → yellow → green (highest).
  static const List<Color> intensityRamp = [
    Color(0xFFE53935), // red
    Color(0xFFFB8C00), // orange
    Color(0xFFFDD835), // yellow
    Color(0xFF43A047), // green
  ];

  /// Colour for a day holding [qty], scaled across the month's own
  /// [minPositive]..[maxPositive] range.
  static Color colorForQuantity({
    required int qty,
    required int minPositive,
    required int maxPositive,
  }) {
    if (maxPositive <= minPositive) return intensityRamp.last;

    final t = ((qty - minPositive) / (maxPositive - minPositive)).clamp(
      0.0,
      1.0,
    );
    return sampleRamp(t);
  }

  /// Samples [intensityRamp] at [t] in 0..1.
  static Color sampleRamp(double t) {
    final clamped = t.clamp(0.0, 1.0);
    if (clamped >= 1.0) return intensityRamp.last;

    final segments = intensityRamp.length - 1;
    final scaled = clamped * segments;
    final index = scaled.floor();
    final localT = scaled - index;

    return Color.lerp(intensityRamp[index], intensityRamp[index + 1], localT)!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCount = activityType == ActivityType.count;
    final unit = isCount ? 'count' : 'min';

    final year = currentMonth.year;
    final month = currentMonth.month;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Mon ... 7 = Sun
    final leadingEmpty = firstWeekday - 1;

    final positives = dailyTotals.values.where((v) => v > 0);
    final maxPositive = positives.fold<int>(0, math.max);
    final minPositive = positives.isEmpty ? 0 : positives.reduce(math.min);

    Color getCellColor(int? qty) {
      if (qty == null || qty == 0) {
        return isDark ? const Color(0xFF1B1D28) : const Color(0xFFF0F0F1);
      }
      if (qty < 0) {
        return isDark ? const Color(0xFF2E1C20) : const Color(0xFFE4E4E7);
      }
      return colorForQuantity(
        qty: qty,
        minPositive: minPositive,
        maxPositive: maxPositive,
      );
    }

    Color getCellTextColor(int? qty) {
      if (qty == null || qty == 0) {
        return AppColors.getTextSubtle(isDark);
      }
      if (qty < 0) {
        return AppColors.getTextSecondary(isDark);
      }
      final background = getCellColor(qty);
      return background.computeLuminance() > 0.5
          ? Colors.black87
          : Colors.white;
    }

    final now = DateTime.now();
    final isCurrentOrFutureMonth =
        (year > now.year) || (year == now.year && month >= now.month);

    void goToPreviousMonth() => onMonthChanged(DateTime(year, month - 1, 1));
    void goToNextMonth() {
      if (isCurrentOrFutureMonth) return;
      onMonthChanged(DateTime(year, month + 1, 1));
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 100) return;
        if (velocity < 0) {
          goToNextMonth();
        } else {
          goToPreviousMonth();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCard(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.getBorderCard(isDark),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month navigation header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '${_monthNames[month - 1]} $year',
                    key: ValueKey('$month-$year'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.getBorderSubtle(isDark),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, size: 18),
                        padding: EdgeInsets.zero,
                        color: AppColors.getTextPrimary(isDark),
                        onPressed: goToPreviousMonth,
                        tooltip: 'Previous month',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.getBorderSubtle(isDark),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, size: 18),
                        padding: EdgeInsets.zero,
                        color: isCurrentOrFutureMonth ? AppColors.getTextSubtle(isDark) : AppColors.getTextPrimary(isDark),
                        onPressed: isCurrentOrFutureMonth ? null : goToNextMonth,
                        tooltip: isCurrentOrFutureMonth ? null : 'Next month',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Weekday headers (M, T, W, T, F, S, S)
            Row(
              children: List.generate(7, (i) {
                return Expanded(
                  child: Center(
                    child: Text(
                      _weekDayHeaders[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // Heat Map Calendar Grid with animated month transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey('grid_$year-$month'),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: leadingEmpty + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < leadingEmpty) {
                      return const SizedBox.shrink();
                    }

                    final dayNumber = index - leadingEmpty + 1;
                    final qty = dailyTotals[dayNumber];
                    final cellColor = getCellColor(qty);
                    final textColor = getCellTextColor(qty);

                    final isToday =
                        DateTime.now().year == year &&
                        DateTime.now().month == month &&
                        DateTime.now().day == dayNumber;

                    return Tooltip(
                      message: qty != null && qty != 0
                          ? 'Day $dayNumber: $qty $unit'
                          : 'Day $dayNumber: No activity',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(10),
                          border: isToday
                              ? Border.all(color: AppColors.goldAccent, width: 2.0)
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            if (qty != null && qty != 0) ...[
                              const SizedBox(height: 1),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    qty > 0 ? '+$qty' : '$qty',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (maxPositive > 0) ...[
                  Text(
                    '$minPositive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 72,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(colors: intensityRamp),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$maxPositive $unit',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ),
                ] else
                  Text(
                    'No activity this month',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
