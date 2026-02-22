import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:sadhana/data/models/calendar_custom_event.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/dashboard_snapshot.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/tasks/presentation/tasks_page.dart';

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

String _formatDate(DateTime d) => '${d.day} de ${_months[d.month - 1]}';

String _formatWeekday(DateTime d) => _weekdays[d.weekday - 1];
String _formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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

    final moonName = MoonPhaseUtils.phaseName(today);
    final lunarEvent = MoonPhaseUtils.lunarEvent(today);
    final customEvents = repo.getCustomEventsForDate(today);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // ── Cabecera: nombre + fecha ─────────────────────────────────────
          _Header(appName: settings.name, date: today),
          const SizedBox(height: 20),

          // ── Fase lunar ───────────────────────────────────────────────────
          _MoonCard(
            moonName: moonName,
            showNightWarning: moonName.toLowerCase().contains('creciente'),
          ),
          const SizedBox(height: 12),
          _SpecialDayCard(
            date: today,
            lunarEvent: lunarEvent,
            customEvents: customEvents,
          ),
          const SizedBox(height: 12),
          const _AffirmationsCard(),
          const SizedBox(height: 20),

          // ── Ciclos activos ───────────────────────────────────────────────
          if (cycles.isEmpty)
            _EmptyState(onCreateTap: () => showCreateCycleSheet(context, ref))
          else
            for (final cycle in cycles) ...[
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
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(date),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatWeekday(date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatTime(date),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(moonName, style: theme.textTheme.titleMedium),
                if (showNightWarning) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'NO HACER SADHANA DE NOCHE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            showNightWarning ? Icons.warning_amber_rounded : Icons.nights_stay_outlined,
            size: 32,
            color: showNightWarning ? cs.error : cs.primary,
          ),
        ],
      ),
    );
  }
}

class _SpecialDayCard extends StatelessWidget {
  const _SpecialDayCard({
    required this.date,
    required this.lunarEvent,
    required this.customEvents,
  });

  final DateTime date;
  final String? lunarEvent;
  final List<CalendarCustomEvent> customEvents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final byCalendar = AppConstants.specialDays[DateUtilsX.dateKey(date)];
    final special = byCalendar ??
        lunarEvent ??
        (customEvents.isNotEmpty
            ? 'Tienes eventos personalizados hoy'
            : 'Sin día especial hoy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        border: Border.all(color: cs.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🗓️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOY:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  special,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (customEvents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final event in customEvents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• ${event.title}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
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
    final typeLabel = archetype?.label ?? 'Personalizado';
    final pending = snapshot.tasks
        .where(
          (t) => !(snapshot.todayLog?.completedTaskIds.contains(t.id) ?? false),
        )
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de arquetipo (gradiente + emoji + nombre)
          if (archetype != null)
            Container(
              width: double.infinity,
              height: 72,
              decoration: BoxDecoration(gradient: archetype.gradient),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(archetype.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Text(
                    archetype.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: archetype.onColor,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre + día
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cycle.name,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      'Día ${cycle.currentDay}/${cycle.duration}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Tipo: $typeLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (!cycle.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Inactivo',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Resumen de propósito
                Text(
                  'Propósito: ${cycle.sankalpa}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Racha
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.local_fire_department,
                      iconColor: Colors.deepOrange,
                      label: 'Racha',
                      value: '${cycle.streakCurrent}',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.emoji_events,
                      iconColor: Colors.amber.shade700,
                      label: 'Máxima',
                      value: '${cycle.streakMax}',
                    ),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Text(
                        '${(value * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: value == 1 ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Barra de progreso animada
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
                const SizedBox(height: 10),
                if (pending.isNotEmpty)
                  Text(
                    'Pendientes: ${pending.map((t) => t.title).take(2).join(' • ')}'
                    '${pending.length > 2 ? '...' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Todas las tareas completas hoy.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TasksPage(focusCycleId: cycle.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.checklist_rounded, size: 16),
                      label: const Text('Ir a tareas'),
                    ),
                    const SizedBox(width: 8),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de estadística ───────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 4),
          Text('$label: $value', style: theme.textTheme.labelMedium),
        ],
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

class _AffirmationsCard extends StatelessWidget {
  const _AffirmationsCard();

  static const _affirmations = [
    'Hoy sostengo mi disciplina con calma.',
    'Mi constancia diaria transforma mi vida.',
    'Elijo presencia, enfoque y devocion.',
    'Cada accion consciente fortalece mi sankalpa.',
    'Soy estable en mi practica, incluso en dias dificiles.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final seed = DateTime.now().day + DateTime.now().month * 31;
    final affirmation = _affirmations[seed % _affirmations.length];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Afirmaciones', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              affirmation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
