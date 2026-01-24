import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerTick {
  final int elapsedSeconds;
  final bool shouldPersist;

  TimerTick({required this.elapsedSeconds, required this.shouldPersist});
}

class ActivityTimerService {
  Timer? _timer;
  int _seconds = 0;
  int _ticksSinceLastSave = 0;
  static const int persistenceIntervalSeconds = 5;

  final _tickController = StreamController<TimerTick>.broadcast();
  Stream<TimerTick> get onTick => _tickController.stream;

  void start(int initialSeconds) {
    debugPrint('TIMER_SERVICE: Starting timer for activity. Initial: $initialSeconds s');
    stop(); // Ensure old timer is cleaned up
    _seconds = initialSeconds;
    _ticksSinceLastSave = 0;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      _ticksSinceLastSave++;

      bool shouldPersist = false;
      if (_ticksSinceLastSave >= persistenceIntervalSeconds) {
        shouldPersist = true;
        _ticksSinceLastSave = 0;
        debugPrint('TIMER_SERVICE: 5-second threshold reached. Triggering persistence.');
      }

      _tickController.add(TimerTick(elapsedSeconds: _seconds, shouldPersist: shouldPersist));
    });
  }

  void stop() {
    if (_timer != null) {
      debugPrint('TIMER_SERVICE: Stopping timer.');
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() {
    stop();
    _tickController.close();
  }
}
