import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/utilities/application/stopwatch_controller.dart';

class StopwatchPage extends ConsumerStatefulWidget {
  const StopwatchPage({super.key});

  @override
  ConsumerState<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends ConsumerState<StopwatchPage> {
  final List<Duration> _laps = [];
  Duration? _target;
  bool _targetNotified = false;
  StopwatchState _state = const StopwatchState(
    isRunning: false,
    elapsed: Duration.zero,
  );
  StreamSubscription<StopwatchState>? _sub;

  static const _presetTargets = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 20),
    Duration(minutes: 40),
  ];

  @override
  void initState() {
    super.initState();
    final controller = ref.read(stopwatchControllerProvider);
    _state = controller.currentState;
    _sub = controller.stateStream.listen((next) {
      if (!mounted) return;
      if (_target != null && !_targetNotified && next.elapsed >= _target!) {
        _targetNotified = true;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objetivo alcanzado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _state = next;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final controller = ref.read(stopwatchControllerProvider);
    await controller.toggle();
    await HapticFeedback.selectionClick();
    setState(() {
      _state = controller.currentState;
    });
  }

  Future<void> _reset() async {
    final controller = ref.read(stopwatchControllerProvider);
    await controller.reset();
    _laps.clear();
    _targetNotified = false;
    await HapticFeedback.lightImpact();
    setState(() {
      _state = controller.currentState;
    });
  }

  Future<void> _addLap() async {
    if (!_state.isRunning) return;
    _laps.insert(0, _state.elapsed);
    await HapticFeedback.selectionClick();
    setState(() {});
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hh = two(d.inHours);
    final mm = two(d.inMinutes.remainder(60));
    final ss = two(d.inSeconds.remainder(60));
    final cs = two((d.inMilliseconds.remainder(1000) ~/ 10));
    return '$hh:$mm:$ss.$cs';
  }

  Future<void> _saveSessionToDiary() async {
    final elapsed = _state.elapsed;
    if (elapsed.inMilliseconds == 0) return;
    final message = 'Cronómetro: ${_format(elapsed)}';
    await ref
        .read(repositoryProvider)
        .addExtraDiaryTask(DateTime.now(), message);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesión guardada en Resumen'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final elapsed = _state.elapsed;
    final progress = _target == null
        ? null
        : (elapsed.inMilliseconds / _target!.inMilliseconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Cronómetro')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetTargets
                  .map(
                    (d) => ChoiceChip(
                      label: Text('${d.inMinutes}m'),
                      selected: _target == d,
                      onSelected: (_) {
                        setState(() {
                          _target = _target == d ? null : d;
                          _targetNotified = false;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            if (_target != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text(
                'Objetivo: ${_format(_target!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Text(
                  _format(elapsed),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_state.isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_state.isRunning ? 'Pausar' : 'Iniciar'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.replay),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _addLap,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Vuelta'),
                ),
                OutlinedButton.icon(
                  onPressed: _saveSessionToDiary,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar en Resumen'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _laps.isEmpty
                    ? Center(
                        child: Text(
                          'Sin vueltas registradas.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _laps.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final lap = _laps[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              '#${_laps.length - index}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            title: Text(
                              _format(lap),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'JetBrainsMono',
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  setState(() => _laps.removeAt(index)),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
