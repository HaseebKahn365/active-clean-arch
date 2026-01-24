import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A wrapper that enables two-finger swipe back navigation on macOS trackpads.
/// Mimics browser-style navigation behavior.
class MacSwipeBackNavigator extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MacSwipeBackNavigator({super.key, required this.child, this.navigatorKey});

  @override
  State<MacSwipeBackNavigator> createState() => _MacSwipeBackNavigatorState();
}

class _MacSwipeBackNavigatorState extends State<MacSwipeBackNavigator> {
  double _accumulatedPanX = 0;
  static const double _backThreshold = 200.0; // Positive for swiping fingers Right (to go back)
  static const double _maxVerticalThreshold = 100.0;
  bool _hasTriggered = false;

  void _handlePointerEvent(PointerEvent event) {
    if (event is PointerPanZoomStartEvent) {
      _accumulatedPanX = 0;
      _hasTriggered = false;
    } else if (event is PointerPanZoomUpdateEvent) {
      if (_hasTriggered) return;

      // Check if vertical movement is excessive (ignore vertical scrolls)
      if (event.pan.dy.abs() > _maxVerticalThreshold) {
        return;
      }

      // We only care about horizontal movement
      if (event.pan.dx.abs() > event.pan.dy.abs() * 1.5) {
        _accumulatedPanX += event.pan.dx;

        // Swiping fingers Left -> Right results in positive DX (Back)
        if (_accumulatedPanX >= _backThreshold) {
          _triggerBack();
          _hasTriggered = true; // Prevent multiple pops in one gesture
        }
      }
    } else if (event is PointerPanZoomEndEvent) {
      _accumulatedPanX = 0;
      _hasTriggered = false;
    }
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
    // Only enable on macOS hardware
    if (kIsWeb || !Platform.isMacOS) {
      return widget.child;
    }

    return Listener(
      onPointerPanZoomStart: _handlePointerEvent,
      onPointerPanZoomUpdate: _handlePointerEvent,
      onPointerPanZoomEnd: _handlePointerEvent,
      // We use HitTestBehavior.translucent to ensure we don't block other listeners
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
