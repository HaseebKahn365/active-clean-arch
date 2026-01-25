import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'mac_swipe_back_navigator.dart';

/// A wrapper for BarChart that adds horizontal panning and zooming.
class InteractiveBarChart extends StatefulWidget {
  final int dataCount;
  final List<double> barValues;
  final BarChartData Function(double minX, double maxX, double minY, double maxY) dataBuilder;
  final double initialWindowSize;
  final double minWindowSize;
  final double maxWindowSize;
  final double topPadding;

  const InteractiveBarChart({
    super.key,
    required this.dataCount,
    required this.barValues,
    required this.dataBuilder,
    required this.initialWindowSize,
    this.minWindowSize = 2.0,
    this.maxWindowSize = 100.0,
    this.topPadding = 20.0,
  });

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart> {
  late double minX;
  late double maxX;
  late double minY;
  late double maxY;

  double _lastScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  bool _userHasInteracted = false;

  @override
  void initState() {
    super.initState();
    _resetToDefaults();
  }

  @override
  void didUpdateWidget(InteractiveBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataCount != widget.dataCount || oldWidget.barValues != widget.barValues) {
      if (!_userHasInteracted) {
        _resetToDefaults();
      } else {
        _calculateYRange();
      }
    }
  }

  void _resetToDefaults() {
    if (widget.dataCount > 0) {
      maxX = widget.dataCount.toDouble() - 0.5; // Offset for bars
      minX = (maxX - widget.initialWindowSize).clamp(-0.5, maxX);
      _calculateYRange();
    } else {
      minX = 0;
      maxX = 7;
      minY = 0;
      maxY = 10;
    }
  }

  void _calculateYRange() {
    if (widget.barValues.isEmpty) {
      minY = 0;
      maxY = 10;
      return;
    }

    final List<double> visibleValues = [];
    for (int i = 0; i < widget.barValues.length; i++) {
      if (i + 0.5 >= minX && i - 0.5 <= maxX) {
        visibleValues.add(widget.barValues[i]);
      }
    }

    double currentMaxY = visibleValues.isNotEmpty
        ? visibleValues.reduce((a, b) => a > b ? a : b)
        : (widget.barValues.isNotEmpty ? widget.barValues.reduce((a, b) => a > b ? a : b) : 10.0);

    // Add generous headroom (20%) to prevent clipping of bar tops
    double buffer = currentMaxY * 0.20;
    // Ensure a minimum constant floor
    if (buffer < 2.0) buffer = 2.0;

    minY = 0; // Bars always start at 0
    maxY = currentMaxY + buffer;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _lastScale = 1.0;
            _lastFocalPoint = details.localFocalPoint;
            _userHasInteracted = true;
            MacSwipeBackNavigator.isBlocked = true;
          },
          onScaleEnd: (details) {
            MacSwipeBackNavigator.isBlocked = false;
          },
          onScaleUpdate: (details) {
            setState(() {
              double scale = details.scale / _lastScale;
              _lastScale = details.scale;

              double currentWindowSize = maxX - minX;
              double newWindowSize = currentWindowSize / scale;
              newWindowSize = newWindowSize.clamp(widget.minWindowSize, widget.maxWindowSize);

              double focalXPercent = _lastFocalPoint.dx / constraints.maxWidth;
              double focalXValue = minX + (currentWindowSize * focalXPercent);

              minX = focalXValue - (newWindowSize * focalXPercent);
              maxX = focalXValue + (newWindowSize * (1 - focalXPercent));

              double dx = details.localFocalPoint.dx - _lastFocalPoint.dx;
              _lastFocalPoint = details.localFocalPoint;

              double pixelsToUnits = (maxX - minX) / constraints.maxWidth;
              double deltaX = dx * pixelsToUnits;

              minX -= deltaX;
              maxX -= deltaX;

              double dataMinX = -0.7; // Extra room for start bar
              double dataMaxX = widget.dataCount.toDouble() - 0.3; // Extra room for end bar

              if (minX < dataMinX) {
                double diff = dataMinX - minX;
                minX += diff;
                maxX += diff;
              }
              if (maxX > dataMaxX) {
                double diff = maxX - dataMaxX;
                minX -= diff;
                maxX -= diff;
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.only(top: widget.topPadding), // Headroom for max values
            child: BarChart(widget.dataBuilder(minX, maxX, minY, maxY), duration: Duration.zero),
          ),
        );
      },
    );
  }
}
