import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  int _selectedCycleIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final activeCycles = state.activeCycles;

    if (activeCycles.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Activa un ciclo para ver calendario.')),
      );
    }

    // Ajusta el indice si se desactivo el ciclo seleccionado
    final cycleIndex = _selectedCycleIndex.clamp(0, activeCycles.length - 1);
    final selectedCycle = activeCycles[cycleIndex];

    final repo = ref.read(repositoryProvider);
    final completionMap = repo.getCalendarCompletionMap(selectedCycle.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (activeCycles.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < activeCycles.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(activeCycles[i].name),
                        selected: cycleIndex == i,
                        onSelected: (_) =>
                            setState(() => _selectedCycleIndex = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: state.selectedDate,
                selectedDayPredicate: (day) =>
                    isSameDay(day, state.selectedDate),
                onDaySelected: (selected, _) {
                  ref.read(appControllerProvider.notifier).selectDate(selected);
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final key = DateTime(day.year, day.month, day.day);
                    final completed = completionMap[key];
                    if (completed == null) return null;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: completed ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Fase lunar'),
              subtitle: Text(
                MoonPhaseUtils.phaseName(state.selectedDate),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('Dia especial'),
              subtitle: Text(
                AppConstants.specialDays[DateUtilsX.dateKey(
                      state.selectedDate,
                    )] ??
                    'Sin evento especial',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
