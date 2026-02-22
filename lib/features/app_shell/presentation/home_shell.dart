import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/calendar/presentation/calendar_page.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/dashboard/presentation/dashboard_page.dart';
import 'package:sadhana/features/tasks/presentation/tasks_page.dart';

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
    TasksPage(),
    CalendarPage(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appControllerProvider.notifier).initialize(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(appControllerProvider.select((s) => s.error));

    ref.listen(appControllerProvider.select((s) => s.error), (previous, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
      }
    });

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.all_inclusive),
            label: 'Ciclos',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendario',
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
