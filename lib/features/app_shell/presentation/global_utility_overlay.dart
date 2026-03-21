import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/utilities/presentation/counter_page.dart';
import 'package:sadhana/features/utilities/presentation/stopwatch_page.dart';

class GlobalUtilityOverlay extends ConsumerStatefulWidget {
  const GlobalUtilityOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlobalUtilityOverlay> createState() =>
      _GlobalUtilityOverlayState();
}

class _GlobalUtilityOverlayState extends ConsumerState<GlobalUtilityOverlay> {
  Offset? _stopwatchPopupPosition;
  Offset? _counterPopupPosition;
  bool _hideStopwatchPopup = false;
  bool _hideCounterPopup = false;
  bool _stopwatchPopupSessionVisible = false;
  bool _counterPopupSessionVisible = false;
  bool _wasStopwatchRunning = false;
  bool _wasCounterNonZero = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stopwatchController = ref.read(stopwatchControllerProvider);
        final counterController = ref.read(counterControllerProvider);
        const popupWidth = 206.0;
        const popupHeight = 56.0;

        final maxPopupLeft = math.max(
          0.0,
          constraints.maxWidth - popupWidth - 8,
        );
        final maxTop = math.max(0.0, constraints.maxHeight - popupHeight - 8);
        final minPopupLeft = math.min(8.0, maxPopupLeft);
        final minTop = math.min(8.0, maxTop);

        _stopwatchPopupPosition ??= Offset(maxPopupLeft, maxTop - 124);
        _counterPopupPosition ??= Offset(maxPopupLeft, maxTop - 62);

        return StreamBuilder(
          stream: stopwatchController.stateStream,
          initialData: stopwatchController.currentState,
          builder: (context, stopwatchSnapshot) {
            final stopwatchState =
                stopwatchSnapshot.data ?? stopwatchController.currentState;
            return StreamBuilder(
              stream: counterController.stateStream,
              initialData: counterController.currentState,
              builder: (context, counterSnapshot) {
                final counterState =
                    counterSnapshot.data ?? counterController.currentState;

                final isStopwatchRunning = stopwatchState.isRunning;
                final isCounterNonZero = counterState.count != 0;

                if (isStopwatchRunning && !_wasStopwatchRunning) {
                  _stopwatchPopupSessionVisible = true;
                  _hideStopwatchPopup = false;
                }
                if (isCounterNonZero && !_wasCounterNonZero) {
                  _counterPopupSessionVisible = true;
                  _hideCounterPopup = false;
                }

                _wasStopwatchRunning = isStopwatchRunning;
                _wasCounterNonZero = isCounterNonZero;

                final isStopwatchVisible =
                    _stopwatchPopupSessionVisible && !_hideStopwatchPopup;
                final isCounterVisible =
                    _counterPopupSessionVisible && !_hideCounterPopup;

                return Stack(
                  children: [
                    widget.child,
                    if (isStopwatchVisible)
                      Positioned(
                        left: _stopwatchPopupPosition!.dx.clamp(
                          minPopupLeft,
                          maxPopupLeft,
                        ),
                        top: _stopwatchPopupPosition!.dy.clamp(minTop, maxTop),
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              final nextX =
                                  (_stopwatchPopupPosition!.dx +
                                          details.delta.dx)
                                      .clamp(minPopupLeft, maxPopupLeft);
                              final nextY =
                                  (_stopwatchPopupPosition!.dy +
                                          details.delta.dy)
                                      .clamp(minTop, maxTop);
                              _stopwatchPopupPosition = Offset(nextX, nextY);
                            });
                          },
                          child: _GlobalMiniUtilityCard(
                            icon: Icons.timer_outlined,
                            title: 'Cronómetro',
                            subtitle: _formatElapsed(stopwatchState.elapsed),
                            onTap: () {
                              setState(() {
                                _hideStopwatchPopup = true;
                                _stopwatchPopupSessionVisible = false;
                              });
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const StopwatchPage(),
                                ),
                              );
                            },
                            primaryIcon: stopwatchState.isRunning
                                ? Icons.pause
                                : Icons.play_arrow,
                            onPrimaryTap: () {
                              stopwatchController.toggle();
                            },
                            showDismiss: true,
                            onDismissTap: () {
                              setState(() {
                                _hideStopwatchPopup = true;
                                _stopwatchPopupSessionVisible = false;
                              });
                            },
                          ),
                        ),
                      ),
                    if (isCounterVisible)
                      Positioned(
                        left: _counterPopupPosition!.dx.clamp(
                          minPopupLeft,
                          maxPopupLeft,
                        ),
                        top: _counterPopupPosition!.dy.clamp(minTop, maxTop),
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              final nextX =
                                  (_counterPopupPosition!.dx + details.delta.dx)
                                      .clamp(minPopupLeft, maxPopupLeft);
                              final nextY =
                                  (_counterPopupPosition!.dy + details.delta.dy)
                                      .clamp(minTop, maxTop);
                              _counterPopupPosition = Offset(nextX, nextY);
                            });
                          },
                          child: _GlobalMiniUtilityCard(
                            icon: Icons.exposure_plus_1_outlined,
                            title: 'Contador',
                            subtitle: '${counterState.count}',
                            onTap: () {
                              setState(() {
                                _hideCounterPopup = true;
                                _counterPopupSessionVisible = false;
                              });
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CounterPage(),
                                ),
                              );
                            },
                            primaryIcon: Icons.add,
                            secondaryIcon: Icons.remove,
                            onPrimaryTap: () {
                              counterController.increment();
                            },
                            onSecondaryTap: () {
                              counterController.decrement();
                            },
                            showDismiss: true,
                            onDismissTap: () {
                              setState(() {
                                _hideCounterPopup = true;
                                _counterPopupSessionVisible = false;
                              });
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hh = two(d.inHours);
    final mm = two(d.inMinutes.remainder(60));
    final ss = two(d.inSeconds.remainder(60));
    return '$hh:$mm:$ss';
  }
}

class _GlobalMiniUtilityCard extends StatelessWidget {
  const _GlobalMiniUtilityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.primaryIcon,
    required this.onPrimaryTap,
    this.secondaryIcon,
    this.onSecondaryTap,
    this.showDismiss = false,
    this.onDismissTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData primaryIcon;
  final VoidCallback onPrimaryTap;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryTap;
  final bool showDismiss;
  final VoidCallback? onDismissTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      color: cs.surface,
      child: Container(
        width: 206,
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (secondaryIcon != null && onSecondaryTap != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: onSecondaryTap,
                icon: Icon(secondaryIcon, size: 18),
              ),
            if (secondaryIcon != null && onSecondaryTap != null)
              const SizedBox(width: 10),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: onPrimaryTap,
              icon: Icon(primaryIcon, size: 18),
            ),
            if (showDismiss && onDismissTap != null) const SizedBox(width: 10),
            if (showDismiss && onDismissTap != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: onDismissTap,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
