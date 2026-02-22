import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/moon_phase_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/dashboard_snapshot.dart';

// ── Nombres localizados ────────────────────────────────────────────────────────

const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const _weekdays = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

String _formatDate(DateTime d) =>
    '${d.day} de ${_months[d.month - 1]}';

String _formatWeekday(DateTime d) => _weekdays[d.weekday - 1];

// ── Página ────────────────────────────────────────────────────────────────────

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final settings = ref.watch(appSettingsProvider);
    final activeCycles = state.activeCycles;
    final repo = ref.read(repositoryProvider);
    final today = DateTime.now();

    final moonName = MoonPhaseUtils.phaseName(today);
    final moonRec = MoonPhaseUtils.sadhanaRecommendation(today);
    final nightFav = MoonPhaseUtils.isNightFavorable(today);
    final lunarEvent = MoonPhaseUtils.lunarEvent(today);

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
            recommendation: moonRec,
            nightFavorable: nightFav,
            lunarEvent: lunarEvent,
          ),
          const SizedBox(height: 20),

          // ── Ciclos activos ───────────────────────────────────────────────
          if (activeCycles.isEmpty)
            const _EmptyState()
          else ...[
            for (final cycle in activeCycles) ...[
              _CycleCard(
                cycle: cycle,
                snapshot: repo.getDashboardSnapshotForCycle(
                  cycleId: cycle.id,
                  date: state.selectedDate,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Cierre manual como acción secundaria
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(appControllerProvider.notifier).closeDayNow(),
                icon: const Icon(Icons.nightlight_round, size: 16),
                label: const Text('Cerrar día manualmente'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
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
          ],
        ),
      ],
    );
  }
}

// ── Tarjeta de fase lunar ─────────────────────────────────────────────────────

class _MoonCard extends StatelessWidget {
  const _MoonCard({
    required this.moonName,
    required this.recommendation,
    required this.nightFavorable,
    required this.lunarEvent,
  });

  final String moonName;
  final String recommendation;
  final bool nightFavorable;
  final String? lunarEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(moonName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  recommendation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (lunarEvent != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✨ $lunarEvent',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            nightFavorable ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined,
            size: 32,
            color: cs.primary,
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
    final dayClosed = snapshot.todayLog?.closed ?? false;
    final ratio = snapshot.completionRatio;

    return Card(
      child: Padding(
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

            // Sankalpa (resumen)
            Text(
              cycle.sankalpa,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
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

            // Tareas
            if (snapshot.tasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              for (final task in snapshot.tasks) ...[
                _TaskTile(
                  task: task,
                  checked: snapshot.todayLog?.completedTaskIds.contains(task.id) ?? false,
                  disabled: dayClosed,
                  onChanged: dayClosed
                      ? null
                      : (value) {
                          ref
                              .read(appControllerProvider.notifier)
                              .toggleTaskForSelectedDate(
                                taskId: task.id,
                                completed: value ?? false,
                              );
                        },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tile de tarea con animación de texto ──────────────────────────────────────

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.checked,
    required this.disabled,
    required this.onChanged,
  });

  final dynamic task;
  final bool checked;
  final bool disabled;
  final void Function(bool?)? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: checked,
      onChanged: onChanged,
      title: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: theme.textTheme.bodyMedium!.copyWith(
          decoration: checked ? TextDecoration.lineThrough : null,
          color: checked
              ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
              : theme.colorScheme.onSurface,
        ),
        child: Text(task.title),
      ),
      subtitle: task.description == null
          ? null
          : Text(task.description!, style: theme.textTheme.bodySmall),
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
          Text(
            '$label: $value',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'Crea y activa un ciclo para comenzar.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
