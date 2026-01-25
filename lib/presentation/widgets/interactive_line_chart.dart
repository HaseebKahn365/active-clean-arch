import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'mac_swipe_back_navigator.dart';

/// A wrapper for LineChart that adds horizontal panning and zooming.
class InteractiveLineChart extends StatefulWidget {
  final List<FlSpot> spots;
  final LineChartData Function(double minX, double maxX, double minY, double maxY) dataBuilder;
  final double initialWindowSize;
  final double? minXLimit;
  final double? maxXLimit;
  final double minWindowSize;
  final double maxWindowSize;

  const InteractiveLineChart({
    super.key,
    required this.spots,
    required this.dataBuilder,
    required this.initialWindowSize,
    this.minXLimit,
    this.maxXLimit,
    this.minWindowSize = 1.0,
    this.maxWindowSize = 100.0,
  });

  @override
  State<InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<InteractiveLineChart> {
  late double minX;
  late double maxX;
  late double minY;
  late double maxY;

  // For pinch-to-zoom and pan
  double _lastScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  bool _userHasInteracted = false;

  @override
  void initState() {
    super.initState();
    _resetToDefaults();
  }

  @override
  void didUpdateWidget(InteractiveLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spots != widget.spots) {
      if (!_userHasInteracted) {
        _resetToDefaults();
      } else {
        _calculateYRange();
      }
    }
  }

  void _resetToDefaults() {
    if (widget.spots.isNotEmpty) {
      double dataMaxX = widget.spots.last.x;
      double dataMinX = widget.spots.first.x;

      maxX = dataMaxX;
      minX = (maxX - widget.initialWindowSize).clamp(dataMinX, maxX);

      _calculateYRange();
    } else {
      minX = 0;
      maxX = 7;
      minY = 0;
      maxY = 10;
    }
  }

  void _calculateYRange() {
    final visibleSpots = widget.spots.where((s) => s.x >= minX && s.x <= maxX).toList();
    if (visibleSpots.isNotEmpty) {
      double currentMinY = visibleSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      double currentMaxY = visibleSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

      double range = currentMaxY - currentMinY;
      if (range == 0) range = currentMaxY != 0 ? currentMaxY * 0.2 : 1.0;

      // Add very generous headroom (30%) to prevent clipping of peaks and labels
      double buffer = range * 0.3;
      // Ensure a minimum constant floor so even small charts have breathing room
      if (buffer < 2.0) buffer = 2.0;

      minY = (currentMinY - (buffer * 0.3)).clamp(0.0, double.infinity);
      maxY = currentMaxY + buffer;

      // Minimum scale protection
      if (maxY - minY < 2.0) {
        maxY = minY + 2.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: GestureDetector(
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
                // 1. Handle Zoom (Scale)
                double scale = details.scale / _lastScale;
                _lastScale = details.scale;

                double currentWindowSize = maxX - minX;
                double newWindowSize = currentWindowSize / scale;

                // Clamp window size
                newWindowSize = newWindowSize.clamp(widget.minWindowSize, widget.maxWindowSize);

                // Zoom around the focal point (X only)
                double focalXPercent = _lastFocalPoint.dx / constraints.maxWidth;
                double focalXValue = minX + (currentWindowSize * focalXPercent);

                minX = focalXValue - (newWindowSize * focalXPercent);
                maxX = focalXValue + (newWindowSize * (1 - focalXPercent));

                // 2. Handle Panning
                double dx = details.localFocalPoint.dx - _lastFocalPoint.dx;
                _lastFocalPoint = details.localFocalPoint;

                double pixelsToUnits = (maxX - minX) / constraints.maxWidth;
                double deltaX = dx * pixelsToUnits;

                minX -= deltaX;
                maxX -= deltaX;

                // 3. Constrain to data limits (with generous horizontal breathing room for edge dots)
                double dataMinX = (widget.minXLimit ?? (widget.spots.isNotEmpty ? widget.spots.first.x : 0)) - 0.5;
                double dataMaxX = (widget.maxXLimit ?? (widget.spots.isNotEmpty ? widget.spots.last.x : 0)) + 0.5;

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

                if (maxX - minX < widget.minWindowSize) {
                  double center = (minX + maxX) / 2;
                  minX = center - widget.minWindowSize / 2;
                  maxX = center + widget.minWindowSize / 2;
                }

                _calculateYRange();
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 20, right: 20), // Headroom for tooltips and dots
              child: LineChart(widget.dataBuilder(minX, maxX, minY, maxY), duration: Duration.zero),
            ),
          ),
        );
      },
    );
  }
}
