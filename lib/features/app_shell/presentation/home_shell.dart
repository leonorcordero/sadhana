import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/dashboard/presentation/dashboard_page.dart';
import 'package:sadhana/features/diary/presentation/diary_page.dart';
import 'package:sadhana/features/notes/presentation/notes_page.dart';
import 'package:sadhana/features/settings/presentation/settings_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 2;

  final _pages = const [
    CyclesPage(),
    DiaryPage(),
    DashboardPage(),
    NotesPage(),
    SettingsPage(),
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
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(appControllerProvider.select((s) => s.error));
    ref.watch(appSettingsProvider);
    final cs = Theme.of(context).colorScheme;

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
          previous.reminderHours.toString() != next.reminderHours.toString()) {
        ref
            .read(appControllerProvider.notifier)
            .reconfigureNotifications(
              enabled: next.remindersEnabled,
              hours: next.reminderHours,
            );
      }
    });

    return Scaffold(
      // Sin extendBody para que los FABs de las páginas internas
      // no queden tapados por la NavigationBar.
      body: _pages[_index],
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          height: 122,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              NavigationBar(
                height: 98,
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
                    fontSize: 13,
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
                    label: 'Mándalas',
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
                      Icons.note_alt_outlined,
                      color: cs.onPrimary.withValues(alpha: 0.76),
                    ),
                    selectedIcon: Icon(Icons.note_alt, color: cs.onPrimary),
                    label: 'Notas',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: cs.onPrimary.withValues(alpha: 0.76),
                    ),
                    selectedIcon: Icon(Icons.settings, color: cs.onPrimary),
                    label: 'Ajustes',
                  ),
                ],
              ),
              Positioned(
                top: -22,
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
                        radius: 38,
                        customBorder: const CircleBorder(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 3.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: CustomPaint(
                              size: const Size(32, 32),
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
