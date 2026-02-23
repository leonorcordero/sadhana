import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';

class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key});

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appControllerProvider.notifier).selectDate(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final repo = ref.read(repositoryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = state.selectedDate;

    final entry = repo.getDiaryEntry(date);
    final completedTasks = repo.getCompletedMandalaTasksForDay(date);

    final dateLabel =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Resumen del día'),
            Text(
              'Tu registro personal',
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
          // ── Fecha ────────────────────────────────────────────────────────
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: Icon(Icons.today, color: cs.primary),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  ref.read(appControllerProvider.notifier).selectDate(picked);
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Prácticas del día ─────────────────────────────────────────────
          _SectionCard(
            label: 'PRÁCTICAS DEL DÍA',
            trailing: completedTasks.isEmpty
                ? null
                : Text(
                    '${completedTasks.length} completadas',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            child: completedTasks.isEmpty
                ? Text(
                    'Sin tareas completadas para este día.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: completedTasks
                        .map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.taskTitle,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.cycleName,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // ── Tareas extras ─────────────────────────────────────────────────
          _SectionCard(
            label: 'TAREAS EXTRAS',
            trailing: IconButton(
              onPressed: () => _addExtraTask(date),
              icon: const Icon(Icons.add_task_outlined),
              visualDensity: VisualDensity.compact,
              tooltip: 'Agregar tarea extra',
            ),
            child: entry.extraTasks.isEmpty
                ? Text(
                    'Sin tareas extras para este día.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      entry.extraTasks.length,
                      (i) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          Icons.task_alt_outlined,
                          size: 18,
                          color: cs.tertiary,
                        ),
                        title: Text(
                          entry.extraTasks[i],
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: cs.error,
                          ),
                          tooltip: 'Eliminar',
                          onPressed: () async {
                            await ref
                                .read(repositoryProvider)
                                .removeExtraDiaryTask(date, i);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // ── Notas libres ──────────────────────────────────────────────────
          _SectionCard(
            label: 'NOTAS LIBRES',
            trailing: IconButton(
              onPressed: () => _addManualEntry(date),
              icon: const Icon(Icons.add_circle_outline),
              visualDensity: VisualDensity.compact,
              tooltip: 'Agregar nota',
            ),
            child: entry.manualEntries.isEmpty
                ? Text(
                    'Sin notas para este día.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      entry.manualEntries.length,
                      (i) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          Icons.edit_note_outlined,
                          size: 18,
                          color: cs.primary,
                        ),
                        title: Text(
                          entry.manualEntries[i],
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: cs.error,
                          ),
                          tooltip: 'Eliminar',
                          onPressed: () async {
                            await ref
                                .read(repositoryProvider)
                                .removeManualDiaryEntry(date, i);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExtraTask(DateTime date) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarea extra'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 1,
          decoration: const InputDecoration(hintText: 'Nombre de la tarea...'),
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
              await ref.read(repositoryProvider).addExtraDiaryTask(date, text);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualEntry(DateTime date) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva nota'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Escribe aquí...'),
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
              await ref
                  .read(repositoryProvider)
                  .addManualDiaryEntry(date, text);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final Widget? trailing;

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
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
