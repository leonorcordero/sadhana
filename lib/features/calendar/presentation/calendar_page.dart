import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final active = state.activeCycle;

    if (active == null) {
      return const Scaffold(
        body: Center(child: Text('Activa un ciclo para ver calendario.')),
      );
    }

    final repo = ref.read(repositoryProvider);
    final completionMap = repo.getCalendarCompletionMap(active.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
              subtitle: Text(MoonPhaseUtils.phaseEmoji(state.selectedDate)),
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
