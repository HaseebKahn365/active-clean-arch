import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MacSwipeBackNavigator extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  static bool isBlocked = false;

  const MacSwipeBackNavigator({super.key, required this.child, this.navigatorKey});

  @override
  State<MacSwipeBackNavigator> createState() => _MacSwipeBackNavigatorState();
}

class _MacSwipeBackNavigatorState extends State<MacSwipeBackNavigator> {
  double _dragDistance = 0;

  static const double _commitDistance = 7000.0;
  static const double _visualDeadZone = 24.0;
  static const double _maxVerticalTolerance = 80.0;

  static const double _forwardResistance = 0.55;
  static const double _reverseResistance = 2.4; // ← EASY CANCEL

  bool _tracking = false;

  void _handle(PointerEvent event) {
    if (MacSwipeBackNavigator.isBlocked || !_isAllowedRoute()) {
      _reset();
      return;
    }

    if (event is PointerPanZoomStartEvent) {
      _dragDistance = 0;
      _tracking = false;
      return;
    }

    if (event is PointerPanZoomUpdateEvent) {
      // Abort if strong vertical intent before tracking
      if (!_tracking && event.pan.dy.abs() > _maxVerticalTolerance) {
        return;
      }

      if (!_tracking) {
        if (event.pan.dx > 0 && _canPop()) {
          _tracking = true;
        } else {
          return;
        }
      }

      final bool reversing = event.pan.dx < 0;
      final double resistance = reversing ? _reverseResistance : _forwardResistance;

      _dragDistance += event.pan.dx * resistance;
      _dragDistance = math.max(0, _dragDistance);

      setState(() {});
      return;
    }

    if (event is PointerPanZoomEndEvent) {
      if (_dragDistance >= _commitDistance) {
        _triggerBack();
      }
      _reset();
    }
  }

  void _reset() {
    _dragDistance = 0;
    _tracking = false;
    setState(() {});
  }

  bool _isAllowedRoute() {
    final nav = widget.navigatorKey?.currentState;
    if (nav == null) return false;

    String? currentRouteName;
    nav.popUntil((route) {
      currentRouteName = route.settings.name;
      return true;
    });

    if (currentRouteName == null) return false;

    // Allowed Routes: Stats (Global & Activity) and Activity Details
    if (currentRouteName == '/stats/global') return true;
    if (currentRouteName!.startsWith('/stats/activity/')) return true;
    if (currentRouteName!.startsWith('/activity/')) return true;

    return false;
  }

  bool _canPop() {
    final nav = widget.navigatorKey?.currentState ?? Navigator.maybeOf(context);
    return nav != null && nav.canPop();
  }

  void _triggerBack() {
    final nav = widget.navigatorKey?.currentState ?? Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return widget.child;
    }

    return Listener(
      onPointerPanZoomStart: _handle,
      onPointerPanZoomUpdate: _handle,
      onPointerPanZoomEnd: _handle,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          widget.child,
          _BackOverlay(dragDistance: _dragDistance, commitDistance: _commitDistance, deadZone: _visualDeadZone),
        ],
      ),
    );
  }
}

class _BackOverlay extends StatelessWidget {
  final double dragDistance;
  final double commitDistance;
  final double deadZone;

  const _BackOverlay({required this.dragDistance, required this.commitDistance, required this.deadZone});

  @override
  Widget build(BuildContext context) {
    if (dragDistance <= 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    // -------- POSITION-BASED VISUAL MAPPING --------

    final double effective = math.max(0, dragDistance - deadZone);

    final double progress = (effective / (commitDistance - deadZone)).clamp(0.0, 1.0);

    // Slow early growth, stable mid, confident end
    final double scale = 0.08 + (progress * 0.92);

    final double opacity = math.min(1.0, progress * 1.1);

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 120,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 64 * scale,
            height: 64 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                colorScheme.primary.withValues(alpha: 0.95),
                progress >= 1.0 ? 1.0 : 0.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16 * scale),
                  blurRadius: 18 * scale,
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 26 * scale,
              color: progress >= 1.0 ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
