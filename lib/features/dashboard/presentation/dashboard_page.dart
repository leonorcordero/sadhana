import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/dashboard_snapshot.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/calendar/presentation/calendar_page.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/diary/presentation/diary_page.dart';

// ── Nombres localizados ────────────────────────────────────────────────────────

const _months = [
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

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const _affirmationOptions = [
  'Hoy sostengo mi disciplina con calma.',
  'Mi constancia diaria transforma mi vida.',
  'Elijo presencia, enfoque y devoción.',
  'Cada acción consciente fortalece mi sankalpa.',
  'Soy estable en mi práctica, incluso en días difíciles.',
];

const _emanationOptions = [
  'Emano serenidad y claridad en cada paso.',
  'Emano gratitud, paciencia y buena voluntad.',
  'Emano luz interior para sostener mi práctica.',
  'Emano disciplina amorosa, sin rigidez.',
  'Emano coherencia entre lo que siento, pienso y hago.',
];

String _formatWeekday(DateTime d) => _weekdays[d.weekday - 1];
String _formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

// ── Página ────────────────────────────────────────────────────────────────────

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final settings = ref.watch(appSettingsProvider);
    final cycles = state.activeCycles;
    final repo = ref.read(repositoryProvider);
    final today = DateTime.now();
    final calendarDay = state.selectedDate;

    final moonName = MoonPhaseUtils.phaseName(today);
    final calendarDayEventTitles = repo.getVisibleEventTitlesForDate(
      calendarDay,
    );
    final diaryEntry = repo.getDiaryEntry(today);
    final completedMandalaCount = repo
        .getCompletedMandalaTasksForDay(today)
        .length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _Header(appName: settings.name, date: today),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MoonCard(
                  moonName: moonName,
                  showNightWarning: moonName.toLowerCase().contains(
                    'creciente',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SpecialDayCard(
                  date: calendarDay,
                  eventTitles: calendarDayEventTitles,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AffirmationsCard(),
          const SizedBox(height: 12),
          _DiaryTodayCard(
            taskCount: completedMandalaCount,
            extraTaskCount: diaryEntry.extraTasks.length,
            noteCount: diaryEntry.manualEntries.length,
          ),
          const SizedBox(height: 20),
          const _MandalasSectionBand(),
          const SizedBox(height: 12),

          // ── Ciclos activos ───────────────────────────────────────────────
          if (cycles.isEmpty)
            _EmptyState(onCreateTap: () => showCreateCycleSheet(context, ref))
          else
            for (final cycle in cycles) ...[
              _CycleBadge(cycle: cycle),
              const SizedBox(height: 10),
              _CycleCard(
                cycle: cycle,
                snapshot: repo.getDashboardSnapshotForCycle(
                  cycleId: cycle.id,
                  date: state.selectedDate,
                ),
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

// ── Cabecera ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.appName, required this.date});

  final String appName;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            appName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              fontSize: 38,
              height: 1,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_capitalize(_formatWeekday(date))}, ${date.day} De ${_capitalize(_months[date.month - 1])}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta de fase lunar ─────────────────────────────────────────────────────

class _MoonCard extends StatelessWidget {
  const _MoonCard({required this.moonName, required this.showNightWarning});

  final String moonName;
  final bool showNightWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MoonPhaseUtils.phaseEmoji(DateTime.now()),
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cleanMoonName(moonName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showNightWarning) ...[
                  const SizedBox(height: 6),
                  Text(
                    'NO SE PUEDE HACER SADHANA DE NOCHE.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _cleanMoonName(String value) {
  return value
      .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
      .trimLeft();
}

class _SpecialDayCard extends StatelessWidget {
  const _SpecialDayCard({required this.date, required this.eventTitles});

  final DateTime date;
  final List<String> eventTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_outlined, size: 20, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HOY',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateUtilsX.dateKey(date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (eventTitles.isNotEmpty) ...[
                  for (final title in eventTitles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $title',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ] else ...[
                  Text(
                    'Sin actividades para este día.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de ciclo ──────────────────────────────────────────────────────────

class _CycleCard extends ConsumerWidget {
  const _CycleCard({required this.cycle, required this.snapshot});

  final CycleModel cycle;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ratio = snapshot.completionRatio;

    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final pending = snapshot.tasks
        .where(
          (t) => !(snapshot.todayLog?.completedTaskIds.contains(t.id) ?? false),
        )
        .toList();
    final displayName = _normalizedMandalaName(cycle.name);

    final stripeColor =
        archetype?.softHeaderColor(cs) ?? cs.primary.withValues(alpha: 0.22);
    final archetypeIcon =
        archetype?.minimalIcon ?? Icons.self_improvement_outlined;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CyclesPage()));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 66,
              color: stripeColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(archetypeIcon, size: 20, color: cs.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Día ${cycle.currentDay}/${cycle.duration}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: pending.isNotEmpty
                            ? Text(
                                'Pendientes: ${pending.map((t) => t.title).take(2).join(' • ')}'
                                '${pending.length > 2 ? '...' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                'Todas las tareas completas hoy.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const SizedBox(width: 10),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ratio),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${(value * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: value == 1
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if ((snapshot.todayLog?.closed ?? false) == false &&
                      pending.isEmpty)
                    FilledButton(
                      onPressed: () => ref
                          .read(appControllerProvider.notifier)
                          .closeTodayForActiveCycles(),
                      child: const Text('Cerrar día'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🪷', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes mandalas activos.',
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Crear primer mandala'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffirmationsCard extends ConsumerStatefulWidget {
  const _AffirmationsCard();

  @override
  ConsumerState<_AffirmationsCard> createState() => _AffirmationsCardState();
}

class _AffirmationsCardState extends ConsumerState<_AffirmationsCard> {
  String _type = 'affirmation';
  String? _text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final repo = ref.read(repositoryProvider);
    final saved = repo.getHomePhraseSelection();
    final seed = DateTime.now().day + DateTime.now().month * 31;
    final fallback = _affirmationOptions[seed % _affirmationOptions.length];

    final type = _text == null ? (saved?.type ?? _type) : _type;
    final phrase = _text ?? saved?.text ?? fallback;
    final title = type == 'emanation' ? 'EMANACIONES' : 'AFIRMACIONES';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openPhraseMenu(context, repo),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Elegir'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '"$phrase"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 18,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhraseMenu(
    BuildContext context,
    SadhanaRepository repo,
  ) async {
    final saved = repo.getHomePhraseSelection();
    String workingType = _text == null ? (saved?.type ?? _type) : _type;
    String workingText = _text ?? saved?.text ?? _affirmationOptions.first;

    if (workingType == 'emanation' &&
        !_emanationOptions.contains(workingText)) {
      workingText = _emanationOptions.first;
    }
    if (workingType != 'emanation' &&
        !_affirmationOptions.contains(workingText)) {
      workingText = _affirmationOptions.first;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final baseOptions = workingType == 'emanation'
                ? _emanationOptions
                : _affirmationOptions;
            final customOptions = repo.getCustomHomePhrases(type: workingType);
            final options = <String>[...baseOptions, ...customOptions];

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menú de afirmaciones y emanaciones',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'affirmation',
                        label: Text('Afirmaciones'),
                      ),
                      ButtonSegment<String>(
                        value: 'emanation',
                        label: Text('Emanaciones'),
                      ),
                    ],
                    selected: {workingType},
                    onSelectionChanged: (value) {
                      setModalState(() {
                        workingType = value.first;
                        workingText = workingType == 'emanation'
                            ? _emanationOptions.first
                            : _affirmationOptions.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final added = await _showAddPhraseDialog(
                          ctx,
                          type: workingType,
                        );
                        if (!mounted) return;
                        if (added != null && added.isNotEmpty) {
                          setModalState(() {
                            workingText = added;
                          });
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Agregar frase escrita'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: options
                          .map(
                            (option) => ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              onTap: () =>
                                  setModalState(() => workingText = option),
                              leading: Icon(
                                workingText == option
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: workingText == option
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                size: 20,
                              ),
                              title: Text(
                                option,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          await repo.saveHomePhraseSelection(
                            type: workingType,
                            text: workingText,
                          );
                          if (!mounted) return;
                          setState(() {
                            _type = workingType;
                            _text = workingText;
                          });
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _showAddPhraseDialog(
    BuildContext context, {
    required String type,
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          type == 'emanation' ? 'Agregar emanación' : 'Agregar afirmación',
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Frase escrita',
            hintText: 'Escribe tu frase',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final repo = ref.read(repositoryProvider);
              await repo.addCustomHomePhrase(type: type, text: text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ── Logros de hoy ─────────────────────────────────────────────────────────────

class _DiaryTodayCard extends StatelessWidget {
  const _DiaryTodayCard({
    required this.taskCount,
    required this.extraTaskCount,
    required this.noteCount,
  });

  final int taskCount;
  final int extraTaskCount;
  final int noteCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'LOGROS DE HOY',
                    style: theme.textTheme.titleSmall?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DiaryPage()),
                    );
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text('Ver resumen'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _LogroChip(
                    icon: Icons.check_circle_outline,
                    label: '$taskCount práctica${taskCount == 1 ? '' : 's'}',
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  _LogroChip(
                    icon: Icons.task_alt_outlined,
                    label:
                        '$extraTaskCount extra${extraTaskCount == 1 ? '' : 's'}',
                    color: cs.tertiary,
                  ),
                  const SizedBox(width: 8),
                  _LogroChip(
                    icon: Icons.edit_note_outlined,
                    label: '$noteCount nota${noteCount == 1 ? '' : 's'}',
                    color: cs.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogroChip extends StatelessWidget {
  const _LogroChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _MandalasSectionBand extends StatelessWidget {
  const _MandalasSectionBand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.primary.withValues(alpha: 0.72),
          cs.surfaceContainerHigh,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.34)),
      ),
      child: Center(
        child: Text(
          'MÁNDALAS',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w800,
            color: cs.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _CycleBadge extends StatelessWidget {
  const _CycleBadge({required this.cycle});

  final CycleModel cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final label = (archetype?.label ?? cycle.name).toUpperCase();

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: cs.outlineVariant.withValues(alpha: 0.65),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: cs.outlineVariant.withValues(alpha: 0.65),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

String _normalizedMandalaName(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return 'Mandala';
  return cleaned
      .split(' ')
      .map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      })
      .join(' ');
}
