import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key, this.focusCycleId});

  final String? focusCycleId;

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appControllerProvider.notifier).selectDate(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final state = ref.watch(appControllerProvider);
    final activeCycles = state.activeCycles;
    final focusCycle = widget.focusCycleId == null
        ? null
        : state.cycles.where((c) => c.id == widget.focusCycleId).firstOrNull;
    final visibleCycles = focusCycle == null ? activeCycles : [focusCycle];

    if (visibleCycles.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Activa un ciclo para gestionar tareas.')),
      );
    }

    final repo = ref.read(repositoryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = state.selectedDate;
    final dateLabel =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tareas diarias'),
            Text(
              'Registro de tu día',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
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
          // ── Fecha seleccionada ──────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              title: Text(
                'FECHA',
                style: theme.textTheme.titleSmall?.copyWith(
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                dateLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: Icon(Icons.today, color: cs.primary),
            ),
          ),
          const SizedBox(height: 16),

          // ── Ciclos ─────────────────────────────────────────────────────
          for (final cycle in visibleCycles) ...[
            _CycleDivider(cycle: cycle),
            const SizedBox(height: 10),
            _CycleTasksSection(
              cycle: cycle,
              tasks: state.tasks.where((t) => t.cycleId == cycle.id).toList(),
              log: repo.getOrCreateDayLog(
                cycleId: cycle.id,
                date: state.selectedDate,
              ),
              ref: ref,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ── Separador de ciclo ────────────────────────────────────────────────────────

class _CycleDivider extends StatelessWidget {
  const _CycleDivider({required this.cycle});

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
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
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

// ── Sección de tareas de un ciclo ─────────────────────────────────────────────

class _CycleTasksSection extends StatelessWidget {
  const _CycleTasksSection({
    required this.cycle,
    required this.tasks,
    required this.log,
    required this.ref,
  });

  final CycleModel cycle;
  final List<TaskModel> tasks;
  final DayLogModel log;
  final WidgetRef ref;

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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del ciclo
          _CycleHeader(cycle: cycle),

          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                'Sin tareas. Agrégalas desde Mandalas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final task in tasks)
              CheckboxListTile(
                value: log.completedTaskIds.contains(task.id),
                onChanged: log.closed
                    ? null
                    : (value) {
                        ref
                            .read(appControllerProvider.notifier)
                            .toggleTaskForSelectedDate(
                              taskId: task.id,
                              completed: value ?? false,
                            );
                      },
                title: Text(
                  task.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: task.description == null
                    ? null
                    : Text(
                        task.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                dense: true,
                controlAffinity: ListTileControlAffinity.trailing,
              ),
        ],
      ),
    );
  }
}

// ── Cabecera interna del ciclo ────────────────────────────────────────────────

class _CycleHeader extends StatelessWidget {
  const _CycleHeader({required this.cycle});

  final CycleModel cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final headerColor =
        archetype?.softHeaderColor(cs) ?? cs.primary.withValues(alpha: 0.22);

    return Container(
      width: double.infinity,
      height: 56,
      color: headerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            archetype?.minimalIcon ?? Icons.self_improvement_outlined,
            size: 18,
            color: cs.onSurface,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cycle.name,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          Text(
            'Día ${cycle.currentDay}/${cycle.duration}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
