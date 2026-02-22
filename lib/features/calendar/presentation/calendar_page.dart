import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:sadhana/data/models/calendar_custom_event.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  int _selectedCycleIndex = -1;
  List<CalendarCustomEvent> _customEvents = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_reloadCustomEvents);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final cycles = state.cycles;

    if (cycles.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Crea un ciclo para ver calendario.')),
      );
    }

    final repo = ref.read(repositoryProvider);
    final completionMap = _buildCompletionMap(repo, cycles);
    final customEventsToday = _customEvents
        .where((e) => e.dateKey == DateUtilsX.dateKey(state.selectedDate))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (cycles.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _selectedCycleIndex == -1,
                      onSelected: (_) =>
                          setState(() => _selectedCycleIndex = -1),
                    ),
                  ),
                  for (int i = 0; i < cycles.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cycles[i].name),
                        selected: _selectedCycleIndex == i,
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
                    final hasCustomEvent = _customEvents.any(
                      (e) => e.dateKey == DateUtilsX.dateKey(key),
                    );
                    if (completed == null && !hasCustomEvent) return null;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (completed != null)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: completed ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasCustomEvent)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Eventos personalizados',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _createOrEditEvent(repo),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (customEventsToday.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('Sin eventos personalizados para este día.'),
                    )
                  else
                    for (final event in customEventsToday)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.title),
                        subtitle: event.description == null
                            ? null
                            : Text(event.description!),
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () =>
                                  _createOrEditEvent(repo, event: event),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Google Calendar',
                              onPressed: () =>
                                  _openInGoogleCalendar(repo, event),
                              icon: const Icon(Icons.open_in_new),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              onPressed: () async {
                                await repo.deleteCustomEvent(event.id);
                                await _reloadCustomEvents();
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Fase lunar'),
              subtitle: Text(MoonPhaseUtils.phaseName(state.selectedDate)),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle del día',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final cycle in _filteredCycles(cycles))
                    Builder(
                      builder: (context) {
                        final summary = repo.getDaySummary(
                          cycleId: cycle.id,
                          date: state.selectedDate,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${cycle.name}: ${summary.completed}/${summary.total} '
                            '${summary.complete ? '(completo)' : '(pendiente)'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime, bool> _buildCompletionMap(
    SadhanaRepository repo,
    List<CycleModel> cycles,
  ) {
    if (_selectedCycleIndex >= 0 && _selectedCycleIndex < cycles.length) {
      return repo.getCalendarCompletionMap(cycles[_selectedCycleIndex].id);
    }
    final merged = <DateTime, bool>{};
    for (final cycle in cycles) {
      final map = repo.getCalendarCompletionMap(cycle.id);
      for (final entry in map.entries) {
        final day = DateTime(entry.key.year, entry.key.month, entry.key.day);
        final prev = merged[day];
        if (prev == null) {
          merged[day] = entry.value;
        } else {
          // Si alguna vez quedó incompleto, prima rojo.
          merged[day] = prev && entry.value;
        }
      }
    }
    return merged;
  }

  List<CycleModel> _filteredCycles(List<CycleModel> cycles) {
    if (_selectedCycleIndex >= 0 && _selectedCycleIndex < cycles.length) {
      return [cycles[_selectedCycleIndex]];
    }
    return cycles;
  }

  Future<void> _reloadCustomEvents() async {
    final repo = ref.read(repositoryProvider);
    setState(() {
      _customEvents = repo.getCustomEvents();
    });
  }

  Future<void> _createOrEditEvent(
    SadhanaRepository repo, {
    CalendarCustomEvent? event,
  }) async {
    final state = ref.read(appControllerProvider);
    final titleCtrl = TextEditingController(text: event?.title ?? '');
    final descriptionCtrl = TextEditingController(
      text: event?.description ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(event == null ? 'Nuevo evento' : 'Editar evento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final next =
                  (event ??
                          CalendarCustomEvent.create(
                            title: title,
                            dateKey: DateUtilsX.dateKey(state.selectedDate),
                          ))
                      .copyWith(
                        title: title,
                        description: descriptionCtrl.text.trim().isEmpty
                            ? null
                            : descriptionCtrl.text.trim(),
                        dateKey: DateUtilsX.dateKey(state.selectedDate),
                      );
              await repo.upsertCustomEvent(next);
              if (ctx.mounted) Navigator.pop(ctx);
              await _reloadCustomEvents();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInGoogleCalendar(
    SadhanaRepository repo,
    CalendarCustomEvent event,
  ) async {
    final url = Uri.parse(repo.googleCalendarCreateUrl(event));
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Calendar')),
      );
    }
  }
}
