import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/utilities/application/counter_controller.dart';

class CounterPage extends ConsumerStatefulWidget {
  const CounterPage({super.key});

  @override
  ConsumerState<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends ConsumerState<CounterPage> {
  CounterState _counterState = const CounterState(count: 0);
  bool _rapidMode = false;
  DateTime? _lastActionAt;
  DateTime? _lastTapAt;
  DateTime? _blockedUntil;
  final List<_CounterEvent> _history = [];

  static const _minTapGapMs = 300;

  bool _shouldBlockFastTap() {
    final effectiveMinGapMs = _rapidMode ? 0 : _minTapGapMs;
    if (effectiveMinGapMs <= 0) {
      _blockedUntil = null;
      _lastTapAt = DateTime.now();
      return false;
    }

    final now = DateTime.now();
    if (_blockedUntil != null && now.isBefore(_blockedUntil!)) {
      return true;
    }
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < effectiveMinGapMs) {
      _blockedUntil = now.add(Duration(milliseconds: effectiveMinGapMs));
      _showFastTapWarning();
      return true;
    }
    _lastTapAt = now;
    return false;
  }

  void _showFastTapWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ESPERA UN MOMENTO...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  String _formatClock(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _formatElapsed(Duration value) {
    if (value.inSeconds < 60) return '${value.inSeconds}s';
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    if (minutes < 60) return '${minutes}m ${seconds}s';
    final hours = value.inHours;
    final mins = value.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> _applyAction(_CounterAction action) async {
    if (_shouldBlockFastTap()) return;
    await HapticFeedback.lightImpact();

    final now = DateTime.now();
    final sincePrevious = _lastActionAt == null
        ? null
        : now.difference(_lastActionAt!);
    final controller = ref.read(counterControllerProvider);
    switch (action) {
      case _CounterAction.increment:
        await controller.increment();
      case _CounterAction.decrement:
        await controller.decrement();
      case _CounterAction.reset:
        await controller.reset();
    }

    setState(() {
      _counterState = controller.currentState;
      _history.insert(
        0,
        _CounterEvent(
          action: action,
          result: _counterState.count,
          at: now,
          sincePrevious: sincePrevious,
        ),
      );
      _lastActionAt = now;
    });
  }

  Future<void> _confirmReset() async {
    if (_shouldBlockFastTap()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar contador'),
        content: const Text(
          '¿Seguro que quieres reiniciar el contador a cero?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _applyAction(_CounterAction.reset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(counterControllerProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return StreamBuilder<CounterState>(
      stream: controller.stateStream,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        _counterState = snapshot.data ?? controller.currentState;
        return Scaffold(
          appBar: AppBar(title: const Text('Contador')),
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: FittedBox(
                              key: ValueKey<int>(_counterState.count),
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${_counterState.count}',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontFamily: 'JetBrainsMono',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 120,
                                  height: 0.95,
                                  letterSpacing: -2.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Modo rápido'),
                        subtitle: const Text(
                          'Permite taps continuos sin bloqueo',
                        ),
                        value: _rapidMode,
                        onChanged: (value) {
                          setState(() {
                            _rapidMode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: () =>
                                _applyAction(_CounterAction.increment),
                            style: FilledButton.styleFrom(
                              fixedSize: const Size(92, 92),
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.add, size: 34),
                          ),
                          const SizedBox(width: 18),
                          FilledButton(
                            onPressed: () =>
                                _applyAction(_CounterAction.decrement),
                            style: FilledButton.styleFrom(
                              fixedSize: const Size(92, 92),
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.remove, size: 34),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _confirmReset,
                        icon: const Icon(Icons.replay),
                        label: const Text('Reiniciar a cero'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.38,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(40),
                  ),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Historial de actividad',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _history.isEmpty
                                ? null
                                : () => setState(() => _history.clear()),
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 18,
                            ),
                            label: const Text('Limpiar todo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: _history.isEmpty
                            ? Center(
                                child: Text(
                                  'Aún no hay acciones.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _history.length,
                                separatorBuilder: (_, index) =>
                                    const Divider(height: 8),
                                itemBuilder: (context, index) {
                                  final item = _history[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      switch (item.action) {
                                        _CounterAction.increment =>
                                          Icons.add_circle_outline,
                                        _CounterAction.decrement =>
                                          Icons.remove_circle_outline,
                                        _CounterAction.reset =>
                                          Icons.replay_circle_filled_outlined,
                                      },
                                      color: switch (item.action) {
                                        _CounterAction.increment => cs.primary,
                                        _CounterAction.decrement => cs.error,
                                        _CounterAction.reset => cs.tertiary,
                                      },
                                    ),
                                    title: Text(
                                      'Valor: ${item.result}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    subtitle: Text(
                                      '${_formatClock(item.at)} · ${item.sincePrevious == null ? "Inicio" : _formatElapsed(item.sincePrevious!)}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Eliminar registro',
                                      onPressed: () => setState(
                                        () => _history.removeAt(index),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _CounterAction { increment, decrement, reset }

class _CounterEvent {
  const _CounterEvent({
    required this.action,
    required this.result,
    required this.at,
    required this.sincePrevious,
  });

  final _CounterAction action;
  final int result;
  final DateTime at;
  final Duration? sincePrevious;
}
