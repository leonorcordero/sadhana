import 'dart:async';

class CounterController {
  CounterController();

  final StreamController<CounterState> _stateController =
      StreamController<CounterState>.broadcast();
  int _count = 0;

  Stream<CounterState> get stateStream => _stateController.stream;

  CounterState get currentState => CounterState(count: _count);

  Future<void> increment() async {
    _count += 1;
    _stateController.add(currentState);
  }

  Future<void> decrement() async {
    _count -= 1;
    _stateController.add(currentState);
  }

  Future<void> reset() async {
    _count = 0;
    _stateController.add(currentState);
  }

  Future<void> dispose() async {
    await _stateController.close();
  }
}

class CounterState {
  const CounterState({required this.count});

  final int count;
}
