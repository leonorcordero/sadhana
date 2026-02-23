import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:sadhana/data/models/calendar_custom_event.dart';
import 'package:sadhana/data/models/calendar_external_event.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:table_calendar/table_calendar.dart';

class _CalendarActivityItem {
  const _CalendarActivityItem({
    required this.id,
    required this.title,
    required this.dateKey,
    required this.sourceLabel,
    required this.groupLabel,
    required this.isImported,
    this.description,
  });

  final String id;
  final String title;
  final String dateKey;
  final String sourceLabel;
  final String groupLabel;
  final bool isImported;
  final String? description;
}

class _ImportedGroupData {
  const _ImportedGroupData({
    required this.key,
    required this.label,
    required this.count,
    required this.titleCounts,
  });

  final String key;
  final String label;
  final int count;
  final Map<String, int> titleCounts;
}

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  int _selectedCycleIndex = -1;
  List<CalendarCustomEvent> _customEvents = [];
  List<CalendarExternalEvent> _externalEvents = [];
  Map<String, dynamic> _externalCalendarConfig = {};
  Set<String> _hiddenExternalGroupKeys = <String>{};
  bool _didInitialExternalSyncAttempt = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_reloadCalendarData);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final cycles = state.cycles;
    final repo = ref.read(repositoryProvider);
    final completionMap = _buildCompletionMap(repo, cycles);
    final customEventsToday = _customEvents
        .where((e) => e.dateKey == DateUtilsX.dateKey(state.selectedDate))
        .toList();
    final externalEventsToday = _externalEvents
        .where((e) => e.dateKey == DateUtilsX.dateKey(state.selectedDate))
        .toList();
    final selectedDayActivities = _buildSelectedDayActivities(
      selectedDate: state.selectedDate,
      customEvents: customEventsToday,
      importedEvents: externalEventsToday
          .where((e) => repo.isExternalEventVisibleModel(e))
          .toList(),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Calendario'),
            Text(
              'Eventos y fases lunares',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showExternalCalendarConfigDialog(repo),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Configuración de calendario'),
            ),
          ),
          const SizedBox(height: 8),
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
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
                    final cs = Theme.of(context).colorScheme;
                    final key = DateTime(day.year, day.month, day.day);
                    final completed = completionMap[key];
                    final hasCustomEvent = _customEvents.any(
                      (e) => e.dateKey == DateUtilsX.dateKey(key),
                    );
                    final hasExternalVisibleEvent = _externalEvents.any(
                      (e) =>
                          e.dateKey == DateUtilsX.dateKey(key) &&
                          repo.isExternalEventVisibleModel(e),
                    );
                    if (completed == null &&
                        !hasCustomEvent &&
                        !hasExternalVisibleEvent) {
                      return null;
                    }
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
                                color: completed ? cs.primary : cs.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasCustomEvent)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cs.tertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasExternalVisibleEvent)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(
                                color: cs.secondary,
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVIDADES DEL DÍA',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDayMonthYear(state.selectedDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  if (selectedDayActivities.isEmpty)
                    const Text('Sin actividades para este día.')
                  else
                    for (final activity in selectedDayActivities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Icon(Icons.circle, size: 7),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(activity.title)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUNA',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(MoonPhaseUtils.phaseName(state.selectedDate)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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

  Future<void> _reloadCalendarData() async {
    final repo = ref.read(repositoryProvider);
    var custom = repo.getCustomEvents();
    var external = repo.getExternalEvents();
    var config = repo.getExternalCalendarConfig();
    final hiddenGroupKeys = repo.getHiddenExternalGroupKeys();

    final shouldAutoSync =
        !_didInitialExternalSyncAttempt &&
        (config['connected'] == true) &&
        external.isEmpty;
    if (shouldAutoSync) {
      _didInitialExternalSyncAttempt = true;
      try {
        await repo.syncExternalCalendar();
        external = repo.getExternalEvents();
        config = repo.getExternalCalendarConfig();
      } catch (_) {
        // Evita romper la carga de pantalla si falla la red inicial.
      }
    }

    if (!mounted) return;
    setState(() {
      _customEvents = custom;
      _externalEvents = external;
      _externalCalendarConfig = config;
      _hiddenExternalGroupKeys = hiddenGroupKeys;
    });
  }

  Future<void> _showExternalCalendarConfigDialog(SadhanaRepository repo) async {
    final ctrl = TextEditingController(
      text: (_externalCalendarConfig['sourceUrl'] as String?) ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final grouped = _groupExternalEvents(repo, _externalEvents);
        final importedCount = _externalEvents.length;
        final visibleCount = _externalEvents
            .where((e) => repo.isExternalEventVisibleModel(e))
            .length;
        final localHidden = <String>{..._hiddenExternalGroupKeys};
        final localHiddenTitles = <String>{
          ...repo.getHiddenExternalTitleKeys(),
        };
        return StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: const Text('Configuración de calendario'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: ctrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Link del calendario',
                        hintText:
                            'Pega aquí el link (ICS o Google Calendar API)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pega el link de Google Calendar (embed) o URL .ics pública.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (_externalCalendarConfig['connected'] == true)
                          ? 'Conectado'
                          : 'Sin conexión',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Total importados: $importedCount'),
                    Text('Visibles: $visibleCount'),
                    Text('Grupos importados: ${grouped.length}'),
                    if ((_externalCalendarConfig['lastSyncAt'] as String?)
                            ?.isNotEmpty ==
                        true)
                      Text(
                        'Última sync: ${_formatSyncDate(_externalCalendarConfig['lastSyncAt'] as String)}',
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _syncExternalCalendar(repo);
                          if (!ctx.mounted) return;
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sincronizar ahora'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'GRUPOS IMPORTADOS',
                      style: theme.textTheme.titleSmall?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (grouped.isEmpty)
                      const Text(
                        'No hay grupos aún. Sincroniza primero para generar grupos.',
                      )
                    else
                      for (final group in grouped)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _groupColor(
                                    group.key,
                                    theme.colorScheme,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  group.label,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('${group.count} actividades'),
                          trailing: Switch(
                            value: !localHidden.contains(group.key),
                            onChanged: (value) async {
                              await repo.setExternalGroupVisible(
                                groupKey: group.key,
                                visible: value,
                              );
                              if (!ctx.mounted) return;
                              setModalState(() {
                                if (value) {
                                  localHidden.remove(group.key);
                                } else {
                                  localHidden.add(group.key);
                                }
                              });
                              await _reloadCalendarData();
                            },
                          ),
                          children: [
                            for (final entry
                                in group.titleCounts.entries.toList()
                                  ..sort((a, b) => b.value.compareTo(a.value)))
                              CheckboxListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.only(left: 8),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: !localHiddenTitles.contains(
                                  repo.externalTitleKeyFromTitle(entry.key),
                                ),
                                onChanged: (value) async {
                                  final titleKey = repo
                                      .externalTitleKeyFromTitle(entry.key);
                                  await repo.setExternalTitleVisible(
                                    titleKey: titleKey,
                                    visible: value ?? false,
                                  );
                                  if (!ctx.mounted) return;
                                  setModalState(() {
                                    if (value ?? false) {
                                      localHiddenTitles.remove(titleKey);
                                    } else {
                                      localHiddenTitles.add(titleKey);
                                    }
                                  });
                                  await _reloadCalendarData();
                                },
                                title: Text(
                                  entry.key,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text('${entry.value} eventos'),
                              ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  await repo.setExternalCalendarSourceUrl(ctrl.text.trim());
                  if (ctrl.text.trim().isEmpty) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _reloadCalendarData();
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _syncExternalCalendar(repo);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _syncExternalCalendar(SadhanaRepository repo) async {
    try {
      final count = await repo.syncExternalCalendar();
      await _reloadCalendarData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronización completada ($count eventos).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo sincronizar: $e')));
    }
  }

  List<_ImportedGroupData> _groupExternalEvents(
    SadhanaRepository repo,
    List<CalendarExternalEvent> events,
  ) {
    final grouped =
        <String, ({String label, int count, Map<String, int> titleCounts})>{};
    for (final event in events) {
      final key = repo.externalGroupKeyFromTitle(event.title);
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = (
          label: _groupDisplayNameFromKey(key),
          count: 1,
          titleCounts: <String, int>{event.title: 1},
        );
      } else {
        final nextTitles = <String, int>{...existing.titleCounts};
        nextTitles[event.title] = (nextTitles[event.title] ?? 0) + 1;
        grouped[key] = (
          label: existing.label,
          count: existing.count + 1,
          titleCounts: nextTitles,
        );
      }
    }
    final result = grouped.entries
        .map(
          (entry) => _ImportedGroupData(
            key: entry.key,
            label: entry.value.label,
            count: entry.value.count,
            titleCounts: entry.value.titleCounts,
          ),
        )
        .toList();
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return result;
  }

  String _groupDisplayNameFromKey(String key) {
    if (key.trim().isEmpty || key == 'sin titulo') return 'Sin título';
    final words = key.split(' ');
    return words
        .map((w) {
          if (w.isEmpty) return w;
          if (w.length <= 2) return w.toUpperCase();
          return '${w[0].toUpperCase()}${w.substring(1)}';
        })
        .join(' ');
  }

  List<_CalendarActivityItem> _buildSelectedDayActivities({
    required DateTime selectedDate,
    required List<CalendarCustomEvent> customEvents,
    required List<CalendarExternalEvent> importedEvents,
  }) {
    final items = <_CalendarActivityItem>[
      ...customEvents.map(
        (e) => _CalendarActivityItem(
          id: 'day_manual_${e.id}',
          title: e.title,
          description: e.description,
          dateKey: e.dateKey,
          sourceLabel: 'Manual',
          groupLabel: 'Manual',
          isImported: false,
        ),
      ),
      ...importedEvents.map((e) {
        final key = ref
            .read(repositoryProvider)
            .externalGroupKeyFromTitle(e.title);
        return _CalendarActivityItem(
          id: 'day_imported_${e.id}',
          title: e.title,
          description: e.description,
          dateKey: e.dateKey,
          sourceLabel: e.sourceLabel,
          groupLabel: _groupDisplayNameFromKey(key),
          isImported: true,
        );
      }),
    ];
    items.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return items;
  }

  Color _groupColor(String groupKey, ColorScheme cs) {
    const palette = [
      Color(0xFF5A7D5A),
      Color(0xFF6F98A1),
      Color(0xFF8B95B5),
      Color(0xFFB38A73),
      Color(0xFFA38EA8),
      Color(0xFF7FA184),
      Color(0xFF5D6678),
      Color(0xFF8E9A7A),
    ];
    final index = groupKey.hashCode.abs() % palette.length;
    final base = palette[index];
    return Color.alphaBlend(base.withValues(alpha: 0.78), cs.surface);
  }

  String _formatSyncDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatDayMonthYear(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
