import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:active/presentation/pages/home/models/activity.dart';

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
  /// Saturated throughout so neighbouring days stay distinguishable.
  static const List<Color> intensityRamp = [
    Color(0xFFE53935), // red
    Color(0xFFFB8C00), // orange
    Color(0xFFFDD835), // yellow
    Color(0xFF43A047), // green
  ];

  /// Colour for a day holding [qty], scaled across the month's own
  /// [minPositive]..[maxPositive] range.
  ///
  /// Scaling to the observed range rather than to zero is what makes the
  /// gradient legible: a month of 40..50 spans the full ramp instead of
  /// collapsing into one shade near the top.
  static Color colorForQuantity({
    required int qty,
    required int minPositive,
    required int maxPositive,
  }) {
    // A single distinct value has no range to interpolate across; show it at
    // full strength rather than arbitrarily calling it "lowest".
    if (maxPositive <= minPositive) return intensityRamp.last;

    final t = ((qty - minPositive) / (maxPositive - minPositive)).clamp(
      0.0,
      1.0,
    );
    return sampleRamp(t);
  }

  /// Samples [intensityRamp] at [t] in 0..1, interpolating between adjacent
  /// stops so the transition red→orange→yellow→green is continuous.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCount = activityType == ActivityType.count;
    final unit = isCount ? 'count' : 'min';

    final year = currentMonth.year;
    final month = currentMonth.month;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(
      year,
      month,
      1,
    ).weekday; // 1 = Mon ... 7 = Sun
    final leadingEmpty = firstWeekday - 1;

    final positives = dailyTotals.values.where((v) => v > 0);
    final maxPositive = positives.fold<int>(0, math.max);
    final minPositive = positives.isEmpty ? 0 : positives.reduce(math.min);

    Color getCellColor(int? qty) {
      if (qty == null || qty == 0) {
        return colorScheme.surfaceContainerLow;
      }
      if (qty < 0) {
        // Corrections sit outside the ramp: neutral grey, not "lowest".
        return colorScheme.surfaceContainerHighest;
      }
      return colorForQuantity(
        qty: qty,
        minPositive: minPositive,
        maxPositive: maxPositive,
      );
    }

    Color getCellTextColor(int? qty) {
      if (qty == null || qty == 0) {
        return colorScheme.onSurfaceVariant;
      }
      if (qty < 0) {
        return colorScheme.onSurfaceVariant;
      }
      // Yellow/orange mid-ramp needs dark text; red and green need light.
      // Decide from the rendered colour's own luminance rather than the
      // position on the ramp, so it stays correct if the ramp changes.
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
      // Horizontal-only so the enclosing vertical scroll still works.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // Ignore hesitant drags; require a deliberate flick.
        if (velocity.abs() < 100) return;
        // Swiping left moves forward in time, matching a calendar's feel.
        if (velocity < 0) {
          goToNextMonth();
        } else {
          goToPreviousMonth();
        }
      },
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Month navigation header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_monthNames[month - 1]} $year',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        visualDensity: VisualDensity.compact,
                        onPressed: goToPreviousMonth,
                        tooltip: 'Previous month',
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 22),
                        visualDensity: VisualDensity.compact,
                        onPressed: isCurrentOrFutureMonth
                            ? null
                            : goToNextMonth,
                        tooltip: isCurrentOrFutureMonth ? null : 'Next month',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weekday headers (M, T, W, T, F, S, S)
              Row(
                children: List.generate(7, (i) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        _weekDayHeaders[i],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Heat Map Calendar Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(6),
                        border: isToday
                            ? Border.all(color: colorScheme.primary, width: 1.5)
                            : Border.all(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          if (qty != null && qty != 0) ...[
                            Text(
                              qty > 0 ? '+$qty' : '$qty',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Legend: continuous ramp labelled with the month's own range.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (maxPositive > 0) ...[
                    Text(
                      '$minPositive',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 72,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(colors: intensityRamp),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$maxPositive $unit',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ] else
                    Text(
                      'No activity this month',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
