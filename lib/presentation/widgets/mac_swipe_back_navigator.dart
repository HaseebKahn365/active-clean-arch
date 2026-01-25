import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A wrapper that enables two-finger swipe back navigation on macOS trackpads.
/// Mimics browser-style navigation behavior with an interactive overlay.
class MacSwipeBackNavigator extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  static bool isBlocked = false;

  const MacSwipeBackNavigator({super.key, required this.child, this.navigatorKey});

  @override
  State<MacSwipeBackNavigator> createState() => _MacSwipeBackNavigatorState();
}

class _MacSwipeBackNavigatorState extends State<MacSwipeBackNavigator> with SingleTickerProviderStateMixin {
  double _accumulatedPanX = 0;
  static const double _backThreshold = 300.0; // Increased for smoother tolerance
  static const double _maxVerticalThreshold = 80.0;
  bool _isNavigating = false;

  late AnimationController _overlayController;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  void _handlePointerEvent(PointerEvent event) {
    if (MacSwipeBackNavigator.isBlocked) {
      if (_accumulatedPanX != 0) {
        setState(() {
          _accumulatedPanX = 0;
          _isNavigating = false;
          _overlayController.reverse();
        });
      }
      return;
    }

    if (event is PointerPanZoomStartEvent) {
      _accumulatedPanX = 0;
      _isNavigating = false;
    } else if (event is PointerPanZoomUpdateEvent) {
      // Check for horizontal intent: Pan X must be dominant
      if (!_isNavigating && event.pan.dx > 1.0 && event.pan.dx.abs() > event.pan.dy.abs() * 2.0) {
        // Start showing overlay if we are at the start of navigation stack or can pop
        if (_canPop()) {
          _isNavigating = true;
        }
      }

      if (_isNavigating) {
        setState(() {
          _accumulatedPanX += event.pan.dx;
          // Clamp to positive side (Right swipe)
          _accumulatedPanX = math.max(0, _accumulatedPanX);

          // Check for vertical violation: if they suddenly scroll vertically, cancel navigation
          if (event.pan.dy.abs() > _maxVerticalThreshold) {
            _accumulatedPanX = 0;
            _isNavigating = false;
            _overlayController.reverse();
          }
        });

        // Use a power function for smoother "tolerance" at the beginning
        final rawProgress = (_accumulatedPanX / _backThreshold).clamp(0.0, 1.0);
        _overlayController.value = math.pow(rawProgress, 1.5).toDouble();
      }
    } else if (event is PointerPanZoomEndEvent) {
      if (_isNavigating) {
        if (_accumulatedPanX >= _backThreshold) {
          _triggerBack();
        }
        setState(() {
          _accumulatedPanX = 0;
          _isNavigating = false;
          _overlayController.reverse();
        });
      }
    }
  }

  bool _canPop() {
    final NavigatorState? navState = widget.navigatorKey?.currentState ?? Navigator.maybeOf(context);
    return navState != null && navState.canPop();
  }

  void _triggerBack() {
    try {
      final NavigatorState? navState = widget.navigatorKey?.currentState ?? Navigator.maybeOf(context);
      if (navState != null && navState.canPop()) {
        navState.pop();
      }
    } catch (e) {
      debugPrint('MacSwipeBackNavigator: Failed to pop: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return widget.child;
    }

    return Listener(
      onPointerPanZoomStart: _handlePointerEvent,
      onPointerPanZoomUpdate: _handlePointerEvent,
      onPointerPanZoomEnd: _handlePointerEvent,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          widget.child,
          _BackNavigationOverlay(controller: _overlayController),
        ],
      ),
    );
  }
}

class _BackNavigationOverlay extends AnimatedWidget {
  const _BackNavigationOverlay({required AnimationController controller}) : super(listenable: controller);

  Animation<double> get _progress => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    if (_progress.value == 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final double thresholdReached = _progress.value >= 1.0 ? 1.0 : 0.0;

    // Animate arrow and circle based on progress (non-linear growth for better feeel)
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 120,
      child: Center(
        child: Container(
          width: 60 * _progress.value,
          height: 60 * _progress.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              colorScheme.primary.withValues(alpha: 0.9),
              thresholdReached,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15 * _progress.value), blurRadius: 15, spreadRadius: 1),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 24 * _progress.value,
            color: thresholdReached > 0 ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
