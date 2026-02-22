import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/calendar/presentation/calendar_page.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/dashboard/presentation/dashboard_page.dart';
import 'package:sadhana/features/settings/presentation/settings_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  final _pages = const [
    DashboardPage(),
    CyclesPage(),
    CalendarPage(),
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
    final settings = ref.watch(appSettingsProvider);
    final onNavColor =
        ThemeData.estimateBrightnessForColor(settings.themeColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;

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
      bottomNavigationBar: NavigationBar(
        backgroundColor: settings.themeColor,
        indicatorColor: onNavColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: onNavColor,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined, color: onNavColor),
            selectedIcon: Icon(Icons.space_dashboard, color: onNavColor),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.all_inclusive, color: onNavColor),
            selectedIcon: Icon(Icons.all_inclusive, color: onNavColor),
            label: 'Mándalas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: onNavColor),
            selectedIcon: Icon(Icons.calendar_month, color: onNavColor),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: onNavColor),
            selectedIcon: Icon(Icons.settings, color: onNavColor),
            label: 'Ajustes',
          ),
        ],
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
