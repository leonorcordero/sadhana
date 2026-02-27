import 'dart:async';

class StopwatchController {
  StopwatchController();

  final Stopwatch _stopwatch = Stopwatch();
  final StreamController<StopwatchState> _stateController =
      StreamController<StopwatchState>.broadcast();
  Timer? _ticker;

  Stream<StopwatchState> get stateStream => _stateController.stream;

  StopwatchState get currentState => StopwatchState(
    isRunning: _stopwatch.isRunning,
    elapsed: _stopwatch.elapsed,
  );

  Future<void> toggle() async {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _ticker?.cancel();
      _ticker = null;
    } else {
      _stopwatch.start();
      _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        _stateController.add(currentState);
      });
    }
    _stateController.add(currentState);
  }

  Future<void> reset() async {
    _stopwatch
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
    _stateController.add(currentState);
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    await _stateController.close();
  }
}

class StopwatchState {
  const StopwatchState({required this.isRunning, required this.elapsed});

  final bool isRunning;
  final Duration elapsed;
}
