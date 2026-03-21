import 'dart:async';

class CounterController {
  CounterController();

  final StreamController<CounterState> _stateController =
      StreamController<CounterState>.broadcast();
  int _count = 0;
  DateTime? _lastActionAt;
  final List<CounterHistoryEvent> _history = <CounterHistoryEvent>[];

  Stream<CounterState> get stateStream => _stateController.stream;

  CounterState get currentState =>
      CounterState(count: _count, history: List.unmodifiable(_history));

  Future<void> increment() async {
    await _applyAction(CounterHistoryAction.increment);
  }

  Future<void> decrement() async {
    await _applyAction(CounterHistoryAction.decrement);
  }

  Future<void> reset() async {
    await _applyAction(CounterHistoryAction.reset);
  }

  Future<void> clearHistory() async {
    if (_history.isEmpty) return;
    _history.clear();
    _stateController.add(currentState);
  }

  Future<void> removeHistoryAt(int index) async {
    if (index < 0 || index >= _history.length) return;
    _history.removeAt(index);
    _stateController.add(currentState);
  }

  Future<void> dispose() async {
    await _stateController.close();
  }

  Future<void> _applyAction(CounterHistoryAction action) async {
    final now = DateTime.now();
    final sincePrevious = _lastActionAt == null
        ? null
        : now.difference(_lastActionAt!);

    switch (action) {
      case CounterHistoryAction.increment:
        _count += 1;
      case CounterHistoryAction.decrement:
        _count -= 1;
      case CounterHistoryAction.reset:
        _count = 0;
    }

    _history.insert(
      0,
      CounterHistoryEvent(
        action: action,
        result: _count,
        at: now,
        sincePrevious: sincePrevious,
      ),
    );
    _lastActionAt = now;
    _stateController.add(currentState);
  }
}

class CounterState {
  const CounterState({required this.count, this.history = const []});

  final int count;
  final List<CounterHistoryEvent> history;
}

enum CounterHistoryAction { increment, decrement, reset }

class CounterHistoryEvent {
  const CounterHistoryEvent({
    required this.action,
    required this.result,
    required this.at,
    required this.sincePrevious,
  });

  final CounterHistoryAction action;
  final int result;
  final DateTime at;
  final Duration? sincePrevious;
}
