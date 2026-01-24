import 'dart:async';

class TimerTick {
  final bool shouldPersist;

  TimerTick({required this.shouldPersist});
}

class ActivityTimerService {
  Timer? _timer;
  int _ticksSinceLastSave = 0;
  static const int persistenceIntervalSeconds = 5;

  final _tickController = StreamController<TimerTick>.broadcast();
  Stream<TimerTick> get onTick => _tickController.stream;

  void start() {
    if (_timer != null) return;

    _ticksSinceLastSave = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _ticksSinceLastSave++;

      bool shouldPersist = false;
      if (_ticksSinceLastSave >= persistenceIntervalSeconds) {
        shouldPersist = true;
        _ticksSinceLastSave = 0;
      }

      _tickController.add(TimerTick(shouldPersist: shouldPersist));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _tickController.close();
  }
}
