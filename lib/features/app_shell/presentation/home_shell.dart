import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/responsive_utils.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/dashboard/presentation/dashboard_page.dart';
import 'package:sadhana/features/diary/presentation/diary_page.dart';
import 'package:sadhana/features/resources/presentation/resources_library_page.dart';
import 'package:sadhana/features/utilities/presentation/audio_recorder_page.dart';
import 'package:sadhana/features/utilities/presentation/audio_player_page.dart';
import 'package:sadhana/features/utilities/presentation/counter_page.dart';
import 'package:sadhana/features/utilities/presentation/stopwatch_page.dart';
import 'package:sadhana/features/utilities/presentation/utilities_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 2;
  Offset? _miniPlayerPosition;
  Offset? _stopwatchPopupPosition;
  Offset? _recorderPopupPosition;
  Offset? _counterPopupPosition;
  bool _hideStopwatchPopup = false;
  bool _hideRecorderPopup = false;
  bool _hideCounterPopup = false;
  bool _stopwatchPopupSessionVisible = false;
  bool _recorderPopupSessionVisible = false;
  bool _counterPopupSessionVisible = false;
  bool _wasStopwatchRunning = false;
  bool _wasRecorderRecording = false;
  bool _wasCounterNonZero = false;

  final _pages = const [
    CyclesPage(),
    DiaryPage(),
    DashboardPage(),
    ResourcesLibraryPage(),
    UtilitiesPage(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final settings = ref.read(appSettingsProvider);
      ref
          .read(appControllerProvider.notifier)
          .initialize(
            remindersEnabled: settings.remindersEnabled,
            reminderHours: settings.reminderHours,
            reminderContentType: settings.reminderContentType,
            customReminderText: settings.customReminderText,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(appControllerProvider.select((s) => s.error));
    ref.watch(appSettingsProvider);
    final cs = Theme.of(context).colorScheme;
    final spacingScale = ResponsiveUtils.spacingScale(context);
    final isNarrow = ResponsiveUtils.isNarrowPhone(context);

    ref.listen(appControllerProvider.select((s) => s.error), (previous, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
      }
    });

    ref.listen(appSettingsProvider, (previous, next) {
      if (previous == null ||
          previous.remindersEnabled != next.remindersEnabled ||
          previous.reminderHours.toString() != next.reminderHours.toString() ||
          previous.reminderContentType != next.reminderContentType ||
          previous.customReminderText != next.customReminderText) {
        ref
            .read(appControllerProvider.notifier)
            .reconfigureNotifications(
              enabled: next.remindersEnabled,
              hours: next.reminderHours,
              contentType: next.reminderContentType,
              customText: next.customReminderText,
            );
      }
    });

    return Scaffold(
      // Sin extendBody para que los FABs de las páginas internas
      // no queden tapados por la NavigationBar.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final audioController = ref.read(resourcesAudioControllerProvider);
          final stopwatchController = ref.read(stopwatchControllerProvider);
          final recorderController = ref.read(recorderControllerProvider);
          final counterController = ref.read(counterControllerProvider);
          const audioWidth = 192.0;
          const popupWidth = 206.0;
          const popupHeight = 56.0;
          final maxAudioLeft = math.max(
            0.0,
            constraints.maxWidth - audioWidth - 8,
          );
          final maxPopupLeft = math.max(
            0.0,
            constraints.maxWidth - popupWidth - 8,
          );
          final maxTop = math.max(0.0, constraints.maxHeight - popupHeight - 8);
          final minAudioLeft = math.min(8.0, maxAudioLeft);
          final minPopupLeft = math.min(8.0, maxPopupLeft);
          final minTop = math.min(8.0, maxTop);
          _miniPlayerPosition ??= Offset(maxAudioLeft, maxTop);
          _stopwatchPopupPosition ??= Offset(maxPopupLeft, maxTop - 186);
          _recorderPopupPosition ??= Offset(maxPopupLeft, maxTop - 124);
          _counterPopupPosition ??= Offset(maxPopupLeft, maxTop - 62);

          final miniLeft = _miniPlayerPosition!.dx.clamp(
            minAudioLeft,
            maxAudioLeft,
          );
          final miniTop = _miniPlayerPosition!.dy.clamp(minTop, maxTop);
          return StreamBuilder(
            stream: audioController.stateStream,
            initialData: audioController.currentState,
            builder: (context, snapshot) {
              final audioState = snapshot.data ?? audioController.currentState;
              return StreamBuilder(
                stream: stopwatchController.stateStream,
                initialData: stopwatchController.currentState,
                builder: (context, stopwatchSnapshot) {
                  final stopwatchState =
                      stopwatchSnapshot.data ??
                      stopwatchController.currentState;
                  return StreamBuilder(
                    stream: recorderController.stateStream,
                    initialData: recorderController.currentState,
                    builder: (context, recorderSnapshot) {
                      final recorderState =
                          recorderSnapshot.data ??
                          recorderController.currentState;
                      return StreamBuilder(
                        stream: counterController.stateStream,
                        initialData: counterController.currentState,
                        builder: (context, counterSnapshot) {
                          final counterState =
                              counterSnapshot.data ??
                              counterController.currentState;
                          final isStopwatchRunning = stopwatchState.isRunning;
                          final isRecorderRecording = recorderState.isRecording;
                          final isCounterNonZero = counterState.count != 0;

                          if (isStopwatchRunning && !_wasStopwatchRunning) {
                            _stopwatchPopupSessionVisible = true;
                            _hideStopwatchPopup = false;
                          }
                          if (isRecorderRecording && !_wasRecorderRecording) {
                            _recorderPopupSessionVisible = true;
                            _hideRecorderPopup = false;
                          }
                          if (isCounterNonZero && !_wasCounterNonZero) {
                            _counterPopupSessionVisible = true;
                            _hideCounterPopup = false;
                          }
                          _wasStopwatchRunning = isStopwatchRunning;
                          _wasRecorderRecording = isRecorderRecording;
                          _wasCounterNonZero = isCounterNonZero;

                          final isStopwatchVisible =
                              _stopwatchPopupSessionVisible &&
                              !_hideStopwatchPopup;
                          final isRecorderVisible =
                              _recorderPopupSessionVisible &&
                              !_hideRecorderPopup;
                          final isCounterVisible =
                              _counterPopupSessionVisible && !_hideCounterPopup;
                          return Stack(
                            children: [
                              _pages[_index],
                              if (audioState.activeResourceId != null)
                                Positioned(
                                  left: miniLeft,
                                  top: miniTop,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AudioPlayerPage(),
                                        ),
                                      );
                                    },
                                    onPanUpdate: (details) {
                                      setState(() {
                                        final nextX =
                                            (_miniPlayerPosition!.dx +
                                                    details.delta.dx)
                                                .clamp(
                                                  minAudioLeft,
                                                  maxAudioLeft,
                                                );
                                        final nextY =
                                            (_miniPlayerPosition!.dy +
                                                    details.delta.dy)
                                                .clamp(minTop, maxTop);
                                        _miniPlayerPosition = Offset(
                                          nextX,
                                          nextY,
                                        );
                                      });
                                    },
                                    child: Material(
                                      elevation: 5,
                                      borderRadius: BorderRadius.circular(12),
                                      color: cs.surface,
                                      child: Container(
                                        width: audioWidth,
                                        height: popupHeight,
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          6,
                                          4,
                                          6,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: cs.outlineVariant,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.graphic_eq_outlined,
                                              size: 16,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                audioState.activeTitle ??
                                                    'Audio',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              constraints: const BoxConstraints(
                                                minWidth: 30,
                                                minHeight: 30,
                                              ),
                                              padding: EdgeInsets.zero,
                                              onPressed: audioController
                                                  .togglePlayPause,
                                              icon: Icon(
                                                audioState.isPlaying
                                                    ? Icons.pause_circle_outline
                                                    : Icons.play_circle_outline,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              constraints: const BoxConstraints(
                                                minWidth: 30,
                                                minHeight: 30,
                                              ),
                                              padding: EdgeInsets.zero,
                                              onPressed:
                                                  audioController.stopAndClear,
                                              icon: const Icon(
                                                Icons.close,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (isStopwatchVisible)
                                Positioned(
                                  left: _stopwatchPopupPosition!.dx.clamp(
                                    minPopupLeft,
                                    maxPopupLeft,
                                  ),
                                  top: _stopwatchPopupPosition!.dy.clamp(
                                    minTop,
                                    maxTop,
                                  ),
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        final nextX =
                                            (_stopwatchPopupPosition!.dx +
                                                    details.delta.dx)
                                                .clamp(
                                                  minPopupLeft,
                                                  maxPopupLeft,
                                                );
                                        final nextY =
                                            (_stopwatchPopupPosition!.dy +
                                                    details.delta.dy)
                                                .clamp(minTop, maxTop);
                                        _stopwatchPopupPosition = Offset(
                                          nextX,
                                          nextY,
                                        );
                                      });
                                    },
                                    child: _MiniUtilityCard(
                                      icon: Icons.timer_outlined,
                                      title: 'Cronómetro',
                                      subtitle: _formatElapsed(
                                        stopwatchState.elapsed,
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _hideStopwatchPopup = true;
                                          _stopwatchPopupSessionVisible = false;
                                        });
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const StopwatchPage(),
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
                              if (isRecorderVisible)
                                Positioned(
                                  left: _recorderPopupPosition!.dx.clamp(
                                    minPopupLeft,
                                    maxPopupLeft,
                                  ),
                                  top: _recorderPopupPosition!.dy.clamp(
                                    minTop,
                                    maxTop,
                                  ),
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        final nextX =
                                            (_recorderPopupPosition!.dx +
                                                    details.delta.dx)
                                                .clamp(
                                                  minPopupLeft,
                                                  maxPopupLeft,
                                                );
                                        final nextY =
                                            (_recorderPopupPosition!.dy +
                                                    details.delta.dy)
                                                .clamp(minTop, maxTop);
                                        _recorderPopupPosition = Offset(
                                          nextX,
                                          nextY,
                                        );
                                      });
                                    },
                                    child: _MiniUtilityCard(
                                      icon: Icons.mic,
                                      title: recorderState.isRecording
                                          ? 'Grabando'
                                          : 'Grabador',
                                      subtitle: recorderState.isRecording
                                          ? 'Audio en curso'
                                          : 'Listo para grabar',
                                      onTap: () {
                                        setState(() {
                                          _hideRecorderPopup = true;
                                          _recorderPopupSessionVisible = false;
                                        });
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const AudioRecorderPage(),
                                          ),
                                        );
                                      },
                                      primaryIcon: recorderState.isRecording
                                          ? Icons.stop
                                          : Icons.play_arrow,
                                      onPrimaryTap: () {
                                        recorderController.toggleRecording();
                                      },
                                      showDismiss: true,
                                      onDismissTap: () {
                                        setState(() {
                                          _hideRecorderPopup = true;
                                          _recorderPopupSessionVisible = false;
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
                                  top: _counterPopupPosition!.dy.clamp(
                                    minTop,
                                    maxTop,
                                  ),
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        final nextX =
                                            (_counterPopupPosition!.dx +
                                                    details.delta.dx)
                                                .clamp(
                                                  minPopupLeft,
                                                  maxPopupLeft,
                                                );
                                        final nextY =
                                            (_counterPopupPosition!.dy +
                                                    details.delta.dy)
                                                .clamp(minTop, maxTop);
                                        _counterPopupPosition = Offset(
                                          nextX,
                                          nextY,
                                        );
                                      });
                                    },
                                    child: _MiniUtilityCard(
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
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: EdgeInsets.only(bottom: 4 * spacingScale),
        child: SizedBox(
          height: isNarrow ? 108 : 122,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              NavigationBar(
                height: isNarrow ? 86 : 98,
                backgroundColor: cs.primary,
                indicatorColor: _index == 2
                    ? Colors.transparent
                    : cs.onPrimary.withValues(alpha: 0.16),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? cs.onPrimary
                        : cs.onPrimary.withValues(alpha: 0.76),
                    fontSize: isNarrow ? 11.5 : 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  );
                }),
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  NavigationDestination(
                    icon: Icon(
                      Icons.all_inclusive,
                      color: cs.onPrimary.withValues(alpha: 0.76),
                    ),
                    selectedIcon: Icon(
                      Icons.all_inclusive,
                      color: cs.onPrimary,
                    ),
                    label: 'Mandalas',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.menu_book_outlined,
                      color: cs.onPrimary.withValues(alpha: 0.76),
                    ),
                    selectedIcon: Icon(Icons.menu_book, color: cs.onPrimary),
                    label: 'Resumen',
                  ),
                  const NavigationDestination(
                    icon: SizedBox.shrink(),
                    selectedIcon: SizedBox.shrink(),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.folder_open_outlined,
                      color: cs.onPrimary.withValues(alpha: 0.76),
                    ),
                    selectedIcon: Icon(Icons.folder_open, color: cs.onPrimary),
                    label: 'Recursos',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.build_outlined,
                      color: cs.onPrimary.withValues(alpha: 0.76),
                    ),
                    selectedIcon: Icon(Icons.build, color: cs.onPrimary),
                    label: 'Útiles',
                  ),
                ],
              ),
              Positioned(
                top: isNarrow ? -18 : -22,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Inicio',
                    child: Material(
                      color: Colors.transparent,
                      child: InkResponse(
                        onTap: () => setState(() => _index = 2),
                        radius: isNarrow ? 34 : 38,
                        customBorder: const CircleBorder(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: isNarrow ? 60 : 68,
                          height: isNarrow ? 60 : 68,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: isNarrow ? 2.8 : 3.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: isNarrow ? 10 : 14,
                                offset: Offset(0, isNarrow ? 4 : 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: CustomPaint(
                              size: Size(
                                isNarrow ? 28 : 32,
                                isNarrow ? 28 : 32,
                              ),
                              painter: _DodecahedronPainter(
                                color: cs.onPrimary,
                                emphasized: _index == 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: error != null
          ? FloatingActionButton.small(
              onPressed: () =>
                  ref.read(appControllerProvider.notifier).closePendingDays(),
              child: const Icon(Icons.refresh),
            )
          : null,
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

class _MiniUtilityCard extends StatelessWidget {
  const _MiniUtilityCard({
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
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: cs.surface,
      child: Container(
        width: 206,
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
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

class _DodecahedronPainter extends CustomPainter {
  _DodecahedronPainter({required this.color, required this.emphasized});

  final Color color;
  final bool emphasized;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color.withValues(alpha: emphasized ? 0.95 : 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasized ? 2.1 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.34;

    final points = List<Offset>.generate(5, (i) {
      final a = -1.57 + (i * 2 * 3.1415926535 / 5);
      return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
    });

    final innerR = r * 0.55;
    final inner = List<Offset>.generate(5, (i) {
      final a = -1.57 + ((i + 0.5) * 2 * 3.1415926535 / 5);
      return Offset(cx + innerR * math.cos(a), cy + innerR * math.sin(a));
    });

    final outer = Path()..addPolygon(points, true);
    final mid = Path()..addPolygon(inner, true);

    canvas.drawPath(outer, stroke);
    canvas.drawPath(mid, stroke);

    for (int i = 0; i < 5; i++) {
      canvas.drawLine(points[i], inner[i], stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DodecahedronPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.emphasized != emphasized;
  }
}
