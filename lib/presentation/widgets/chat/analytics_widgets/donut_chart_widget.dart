import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../infrastructure/ai/analytics_widget_models.dart';
import '../../../../presentation/theme/app_colors.dart';
import 'analytics_widget_container.dart';

class DonutChartWidget extends StatefulWidget {
  final DonutChartPayload payload;

  const DonutChartWidget({super.key, required this.payload});

  @override
  State<DonutChartWidget> createState() => _DonutChartWidgetState();
}

class _DonutChartWidgetState extends State<DonutChartWidget> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.payload.data;
    final isDonut = widget.payload.isDonut;

    final total = items.fold<double>(0, (s, i) => s + i.value);
    final isEmpty = total == 0 || items.isEmpty;

    final sections = List.generate(items.length, (i) {
      final item = items[i];
      final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
      final isTouched = i == _touchedIndex;
      final pct = total > 0 ? (item.value / total * 100) : 0.0;

      return PieChartSectionData(
        value: item.value,
        color: color,
        radius: isTouched ? 64 : 54,
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: TextStyle(
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.6,
      );
    });

    Widget? chartArea;
    if (!isEmpty) {
      chartArea = LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxWidth * 0.55).clamp(120.0, 200.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: isDonut ? size * 0.28 : 0,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = null;
                            return;
                          }
                          _touchedIndex = response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                  duration: const Duration(milliseconds: 200),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DonutLegend(
                  items: items,
                  total: total,
                  touchedIndex: _touchedIndex,
                ),
              ),
            ],
          );
        },
      );
    }

    final summaryFooter = widget.payload.footer != null
        ? Text(
            widget.payload.footer!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          )
        : null;

    return AnalyticsWidgetContainer(
      title: widget.payload.title,
      subtitle: widget.payload.description,
      icon: Icons.donut_large_rounded,
      chartArea: chartArea,
      summaryFooter: summaryFooter,
      insightsSection: widget.payload.insights,
      isEmpty: isEmpty,
      emptyMessage: 'No allocation data detected for this period.',
    );
  }
}

class _DonutLegend extends StatelessWidget {
  final List<DonutChartItem> items;
  final double total;
  final int? touchedIndex;

  const _DonutLegend({
    required this.items,
    required this.total,
    required this.touchedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(items.length, (i) {
        final item = items[i];
        final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
        final pct = total > 0 ? (item.value / total * 100) : 0.0;
        final isTouched = i == touchedIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
              color: isTouched
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isTouched ? FontWeight.w700 : FontWeight.normal,
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
