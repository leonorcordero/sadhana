import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/core/utils/responsive_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/mandala_template_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';
import 'package:sadhana/features/resources/presentation/resources_library_page.dart';

// ── Página principal ──────────────────────────────────────────────────────────

enum _CycleCreateAction { mandala, tapasya, template }

class CyclesPage extends ConsumerWidget {
  const CyclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycles = ref.watch(appControllerProvider.select((s) => s.cycles));
    final repo = ref.read(repositoryProvider);
    final spacingScale = ResponsiveUtils.spacingScale(context);
    final isNarrow = ResponsiveUtils.isNarrowPhone(context);
    final activeCount = cycles.where((cycle) => cycle.isActive).length;
    final plannedCount = cycles.length - activeCount;
    final folderById = <String, ResourceFolderModel>{
      for (final folder in repo.getResourceFolders()) folder.id: folder,
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isNarrow ? 60 : 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mandalas y Tapasyas'),
            Text(
              'Tus ciclos de práctica',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_CycleCreateAction>(
            tooltip: 'Crear o usar plantilla',
            icon: const Icon(Icons.add_circle_outline),
            onSelected: (action) {
              switch (action) {
                case _CycleCreateAction.mandala:
                  _showCreateSheet(context, ref, kind: _CreationKind.mandala);
                  break;
                case _CycleCreateAction.tapasya:
                  _showCreateSheet(context, ref, kind: _CreationKind.tapasya);
                  break;
                case _CycleCreateAction.template:
                  _openTemplatesPage(context, ref);
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _CycleCreateAction.mandala,
                child: Text('Crear mandala'),
              ),
              PopupMenuItem(
                value: _CycleCreateAction.tapasya,
                child: Text('Crear tapasya'),
              ),
              PopupMenuItem(
                value: _CycleCreateAction.template,
                child: Text('Usar plantilla'),
              ),
            ],
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                Theme.of(context).scaffoldBackgroundColor,
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16 * spacingScale,
            20 * spacingScale,
            16 * spacingScale,
            32 * spacingScale,
          ),
          children: [
            _CycleOverviewCard(
              total: cycles.length,
              active: activeCount,
              planned: plannedCount,
            ),
            SizedBox(height: 12 * spacingScale),
            if (cycles.isEmpty)
              _CyclesEmptyState(
                onCreate: () =>
                    _showCreateSheet(context, ref, kind: _CreationKind.mandala),
              ),
            for (var index = 0; index < cycles.length; index++)
              Padding(
                padding: EdgeInsets.only(bottom: 12 * spacingScale),
                child: _StaggeredReveal(
                  index: index,
                  child: () {
                    final cycle = cycles[index];
                    return cycle.isActive
                        ? _ActiveMandalaCard(
                            cycle: cycle,
                            onRestart: () => _confirmAction(
                              context,
                              title: 'Reiniciar mandala',
                              message:
                                  'Se reiniciará al día 1 y quedará activo.',
                              onConfirm: () => ref
                                  .read(appControllerProvider.notifier)
                                  .restartCycle(cycle.id),
                            ),
                            onDelete: () => _confirmAction(
                              context,
                              title: 'Eliminar mandala',
                              message: 'Esta acción no se puede deshacer.',
                              onConfirm: () => ref
                                  .read(appControllerProvider.notifier)
                                  .deleteCycle(cycle.id),
                            ),
                            onCircleResources: _buildCircleResourcesAction(
                              context: context,
                              cycle: cycle,
                              folderById: folderById,
                            ),
                            onEditResources: () =>
                                _openCycleResourcesEditor(context, ref, cycle),
                            onOrderTasks: () =>
                                _openCycleTasksOrderEditor(context, ref, cycle),
                          )
                        : _InactiveMandalaCard(
                            cycle: cycle,
                            onStart: () => ref
                                .read(appControllerProvider.notifier)
                                .startCycle(cycle.id),
                            onEditMandala: () => _openScheduledMandalaEditor(
                              context,
                              ref,
                              cycle,
                            ),
                            onRestart: () => _confirmAction(
                              context,
                              title: 'Reiniciar mandala',
                              message:
                                  'Se reiniciará al día 1 y quedará activo.',
                              onConfirm: () => ref
                                  .read(appControllerProvider.notifier)
                                  .restartCycle(cycle.id),
                            ),
                            onDelete: () => _confirmAction(
                              context,
                              title: 'Eliminar mandala',
                              message: 'Esta acción no se puede deshacer.',
                              onConfirm: () => ref
                                  .read(appControllerProvider.notifier)
                                  .deleteCycle(cycle.id),
                            ),
                            onCircleResources: _buildCircleResourcesAction(
                              context: context,
                              cycle: cycle,
                              folderById: folderById,
                            ),
                            onEditResources: () =>
                                _openCycleResourcesEditor(context, ref, cycle),
                            onOrderTasks: () =>
                                _openCycleTasksOrderEditor(context, ref, cycle),
                          );
                  }(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _buildCircleResourcesAction({
    required BuildContext context,
    required CycleModel cycle,
    required Map<String, ResourceFolderModel> folderById,
  }) {
    var circle = cycle.circle > 0 ? cycle.circle : null;
    circle ??= _circleForArchetype(cycle.archetype);
    ResourceFolderModel? folder;
    if (circle != null) {
      final folderId = 'recursos-circulos-circle-$circle';
      folder = folderById[folderId];
      folder ??= folderById.values
          .where((item) => item.circle == circle)
          .firstOrNull;
    }
    folder ??= cycle.linkedResourceFolderIds
        .map((id) => folderById[id])
        .whereType<ResourceFolderModel>()
        .where((item) => item.circle > 0)
        .firstOrNull;
    if (folder == null) return null;
    final resolvedFolder = folder;
    return () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResourceFolderPage(folder: resolvedFolder),
        ),
      );
    };
  }

  // ── Creación: bottom sheet ────────────────────────────────────────────────

  Future<void> _showCreateSheet(
    BuildContext context,
    WidgetRef ref, {
    _CreationKind kind = _CreationKind.mandala,
    MandalaTemplateModel? initialTemplate,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCycleSheet(
        ref: ref,
        kind: kind,
        initialTemplate: initialTemplate,
      ),
    );
  }

  Future<void> _openTemplatesPage(BuildContext context, WidgetRef ref) async {
    final template = await Navigator.of(context).push<MandalaTemplateModel>(
      MaterialPageRoute(builder: (_) => const _MandalaTemplatesPage()),
    );
    if (template == null || !context.mounted) return;
    await _showCreateSheet(
      context,
      ref,
      kind: _CreationKind.mandala,
      initialTemplate: template,
    );
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await onConfirm();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo completar: $e')));
      }
    }
  }

  Future<void> _openCycleResourcesEditor(
    BuildContext context,
    WidgetRef ref,
    CycleModel cycle,
  ) async {
    final repo = ref.read(repositoryProvider);
    final allFolders = repo.getResourceFolders().toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final folderNameById = <String, String>{
      for (final folder in allFolders) folder.id: folder.name,
    };
    final allResources = repo.getMandalaResources();
    final resourcesByType = <MandalaResourceType, List<MandalaResourceModel>>{};
    for (final item in allResources) {
      resourcesByType.putIfAbsent(item.type, () => <MandalaResourceModel>[]);
      resourcesByType[item.type]!.add(item);
    }
    for (final list in resourcesByType.values) {
      list.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }

    final tasks = ref
        .read(appControllerProvider)
        .tasks
        .where((t) => t.cycleId == cycle.id)
        .toList(growable: false);

    final selectedFolders = Set<String>.from(cycle.linkedResourceFolderIds);
    final selectedByTask = <String, Set<String>>{
      for (final t in tasks) t.id: Set<String>.from(t.linkedResourceIds),
    };

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Editar recursos: ${_normalizedMandalaName(cycle.name)}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Carpetas vinculadas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final folder in allFolders)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selectedFolders.contains(folder.id),
                      onChanged: (value) {
                        setLocalState(() {
                          if (value == true) {
                            selectedFolders.add(folder.id);
                          } else {
                            selectedFolders.remove(folder.id);
                          }
                        });
                      },
                      title: Text(folder.name),
                      subtitle: Text(
                        folder.circle <= 0
                            ? 'Sin círculo'
                            : 'Círculo ${folder.circle}',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Recursos por tarea',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final task in tasks) ...[
                    Text(
                      _normalizedTaskTitle(task.title),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    for (final type in MandalaResourceType.values)
                      if ((resourcesByType[type] ??
                              const <MandalaResourceModel>[])
                          .isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Text(
                            _resourceTypeLabel(type),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        for (final item in resourcesByType[type]!)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selectedByTask[task.id]!.contains(item.id),
                            onChanged: (value) {
                              setLocalState(() {
                                if (value == true) {
                                  selectedByTask[task.id]!.add(item.id);
                                } else {
                                  selectedByTask[task.id]!.remove(item.id);
                                }
                              });
                            },
                            title: Text(item.title),
                            subtitle: Text(
                              folderNameById[item.folderId] ?? 'Sin carpeta',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      ],
                    const SizedBox(height: 8),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;

    await ref
        .read(appControllerProvider.notifier)
        .updateCycle(
          cycle.copyWith(
            linkedResourceFolderIds: selectedFolders.toList(growable: false),
          ),
        );
    for (final task in tasks) {
      await ref
          .read(appControllerProvider.notifier)
          .updateTask(
            task.copyWith(
              linkedResourceIds: selectedByTask[task.id]!.toList(
                growable: false,
              ),
            ),
          );
    }
  }

  Future<void> _openCycleTasksOrderEditor(
    BuildContext context,
    WidgetRef ref,
    CycleModel cycle,
  ) async {
    final tasks = ref
        .read(appControllerProvider)
        .tasks
        .where((t) => t.cycleId == cycle.id)
        .toList(growable: true);
    if (tasks.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se necesitan al menos 2 tareas.')),
      );
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Ordenar tareas'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: tasks.length,
              onReorder: (oldIndex, newIndex) {
                setLocalState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = tasks.removeAt(oldIndex);
                  tasks.insert(newIndex, moved);
                });
              },
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ListTile(
                  key: ValueKey(task.id),
                  dense: true,
                  title: Text(_normalizedTaskTitle(task.title)),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    await ref
        .read(appControllerProvider.notifier)
        .saveTaskOrderForCycle(
          cycle.id,
          tasks.map((task) => task.id).toList(growable: false),
        );
  }

  Future<void> _openScheduledMandalaEditor(
    BuildContext context,
    WidgetRef ref,
    CycleModel cycle,
  ) async {
    final nameCtrl = TextEditingController(text: cycle.name);
    final sankalpaCtrl = TextEditingController(text: cycle.sankalpa);
    final durationCtrl = TextEditingController(text: '${cycle.duration}');
    DateTime planned;
    final raw = cycle.plannedStartDateKey?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        planned = DateUtilsX.fromDateKey(raw);
      } catch (_) {
        final now = DateTime.now();
        planned = DateTime(now.year, now.month, now.day);
      }
    } else {
      final now = DateTime.now();
      planned = DateTime(now.year, now.month, now.day);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Editar mandala programado'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sankalpaCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Sankalpa'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duración'),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: planned,
                          firstDate: DateTime(now.year - 2, 1, 1),
                          lastDate: DateTime(now.year + 5, 12, 31),
                        );
                        if (picked == null) return;
                        setLocalState(() {
                          planned = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                        });
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text('Inicio: ${_formatDate(planned)}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final duration = int.tryParse(durationCtrl.text.trim()) ?? cycle.duration;
    final normalizedDuration = duration < 1 ? cycle.duration : duration;
    final updated = cycle.copyWith(
      name: nameCtrl.text.trim().isEmpty ? cycle.name : nameCtrl.text.trim(),
      sankalpa: sankalpaCtrl.text.trim().isEmpty
          ? cycle.sankalpa
          : sankalpaCtrl.text.trim(),
      duration: normalizedDuration,
      plannedStartDateKey: DateUtilsX.dateKey(planned),
    );
    await ref.read(appControllerProvider.notifier).updateCycle(updated);
  }

  String _resourceTypeLabel(MandalaResourceType type) {
    switch (type) {
      case MandalaResourceType.audio:
        return 'Audios';
      case MandalaResourceType.image:
        return 'Imágenes';
      case MandalaResourceType.text:
        return 'Textos';
      case MandalaResourceType.pdf:
        return 'PDF';
      case MandalaResourceType.other:
        return 'Otros';
    }
  }
}

class _CycleOverviewCard extends StatelessWidget {
  const _CycleOverviewCard({
    required this.total,
    required this.active,
    required this.planned,
  });

  final int total;
  final int active;
  final int planned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vista general',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mantén el control de tus ciclos activos y programados.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OverviewStatChip(
                  label: 'Total',
                  value: '$total',
                  color: cs.primary,
                ),
                _OverviewStatChip(
                  label: 'Activos',
                  value: '$active',
                  color: const Color(0xFF2E7D32),
                ),
                _OverviewStatChip(
                  label: 'Programados',
                  value: '$planned',
                  color: const Color(0xFF1565C0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStatChip extends StatelessWidget {
  const _OverviewStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CyclesEmptyState extends StatelessWidget {
  const _CyclesEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          children: [
            SizedBox(
              width: 82,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.self_improvement_outlined,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Aún no tienes mandalas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Crea tu primer ciclo para comenzar la práctica.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Comenzar ciclo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredReveal extends StatelessWidget {
  const _StaggeredReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clamped = index.clamp(0, 8);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + (clamped * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

// ── Tarjeta de mandala activo (expandida, con tareas) ─────────────────────────
class _ActiveMandalaCard extends ConsumerWidget {
  const _ActiveMandalaCard({
    required this.cycle,
    required this.onRestart,
    required this.onDelete,
    this.onCircleResources,
    this.onEditResources,
    this.onOrderTasks,
  });

  final CycleModel cycle;
  final VoidCallback onRestart;
  final VoidCallback onDelete;
  final VoidCallback? onCircleResources;
  final VoidCallback? onEditResources;
  final VoidCallback? onOrderTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final repo = ref.read(repositoryProvider);
    final snapshot = repo.getDashboardSnapshotForCycle(
      cycleId: cycle.id,
      date: state.selectedDate,
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final dayClosed = snapshot.todayLog?.closed ?? false;
    final ratio = snapshot.completionRatio;
    final displayName = _normalizedMandalaName(cycle.name);
    final range = _cycleDateRange(cycle);
    final headerColor =
        archetype?.softHeaderColor(cs) ?? cs.primary.withValues(alpha: 0.22);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de arquetipo con nombre del ciclo
          if (archetype != null)
            Container(
              width: double.infinity,
              height: 66,
              color: headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    archetype.minimalIcon,
                    size: 20,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Día ${cycle.currentDay}/${cycle.duration}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo: Personalizado',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
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
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sankalpa
                Text(
                  'Sankalpa: ${cycle.sankalpa}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inicio: ${_formatDate(range.start)}   Fin: ${_formatDate(range.end)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Racha + progreso %
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.local_fire_department,
                      iconColor: cs.primary,
                      label: 'Racha',
                      value: '${cycle.streakCurrent}',
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

                // Barra de progreso
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

                // Lista de tareas
                if (snapshot.tasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  for (final task in snapshot.tasks)
                    _TaskTile(
                      task: task,
                      checked:
                          snapshot.todayLog?.completedTaskIds.contains(
                            task.id,
                          ) ??
                          false,
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

                const SizedBox(height: 4),
                // Acciones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onCircleResources != null) ...[
                      TextButton.icon(
                        onPressed: onCircleResources,
                        icon: const Icon(Icons.hub_outlined, size: 16),
                        label: const Text('Recursos círculo'),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (onEditResources != null) ...[
                      TextButton.icon(
                        onPressed: onEditResources,
                        icon: const Icon(Icons.folder_open_outlined, size: 16),
                        label: const Text('Recursos'),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (onOrderTasks != null) ...[
                      TextButton.icon(
                        onPressed: onOrderTasks,
                        icon: const Icon(Icons.reorder_outlined, size: 16),
                        label: const Text('Ordenar'),
                      ),
                      const SizedBox(width: 4),
                    ],
                    PopupMenuButton<_CycleCardAction>(
                      tooltip: 'Acciones',
                      onSelected: (action) {
                        switch (action) {
                          case _CycleCardAction.restart:
                            onRestart();
                            break;
                          case _CycleCardAction.delete:
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _CycleCardAction.restart,
                          child: Text('Reiniciar'),
                        ),
                        PopupMenuItem(
                          value: _CycleCardAction.delete,
                          child: Text(
                            'Eliminar',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            const Text('Acciones'),
                          ],
                        ),
                      ),
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

// ── Tarjeta de mandala inactivo (compacta) ────────────────────────────────────

class _InactiveMandalaCard extends StatelessWidget {
  const _InactiveMandalaCard({
    required this.cycle,
    required this.onStart,
    required this.onEditMandala,
    required this.onRestart,
    required this.onDelete,
    this.onCircleResources,
    this.onEditResources,
    this.onOrderTasks,
  });

  final CycleModel cycle;
  final VoidCallback onStart;
  final VoidCallback onEditMandala;
  final VoidCallback onRestart;
  final VoidCallback onDelete;
  final VoidCallback? onCircleResources;
  final VoidCallback? onEditResources;
  final VoidCallback? onOrderTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final displayName = _normalizedMandalaName(cycle.name);
    final range = _cycleDateRange(cycle);
    String? plannedStartText;
    final rawPlanned = cycle.plannedStartDateKey?.trim();
    if (rawPlanned != null && rawPlanned.isNotEmpty) {
      try {
        final planned = DateUtilsX.fromDateKey(rawPlanned);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final normalizedPlanned = DateTime(
          planned.year,
          planned.month,
          planned.day,
        );
        if (normalizedPlanned.isAfter(today)) {
          plannedStartText =
              'Programado para iniciar el ${_formatDate(normalizedPlanned)}';
        }
      } catch (_) {
        plannedStartText = null;
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (archetype != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          archetype.minimalIcon,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayName, style: theme.textTheme.titleMedium),
                          Text(
                            'Tipo: ${archetype?.label ?? 'Personalizado'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${cycle.duration} días · Sankalpa: ${cycle.sankalpa}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Inicio: ${_formatDate(range.start)} · Fin: ${_formatDate(range.end)}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (plannedStartText != null)
                            Text(
                              plannedStartText,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow_rounded),
                          tooltip: 'Iniciar',
                          onPressed: onStart,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar mandala',
                          onPressed: onEditMandala,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (onEditResources != null)
                          IconButton(
                            icon: const Icon(Icons.folder_open_outlined),
                            tooltip: 'Editar recursos',
                            onPressed: onEditResources,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (onOrderTasks != null)
                          IconButton(
                            icon: const Icon(Icons.reorder_outlined),
                            tooltip: 'Ordenar tareas',
                            onPressed: onOrderTasks,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (onCircleResources != null)
                          IconButton(
                            icon: const Icon(Icons.hub_outlined),
                            tooltip: 'Recursos del círculo',
                            onPressed: onCircleResources,
                            visualDensity: VisualDensity.compact,
                          ),
                        PopupMenuButton<_CycleCardAction>(
                          tooltip: 'Acciones',
                          onSelected: (action) {
                            switch (action) {
                              case _CycleCardAction.restart:
                                onRestart();
                                break;
                              case _CycleCardAction.delete:
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: _CycleCardAction.restart,
                              child: Text('Reiniciar'),
                            ),
                            PopupMenuItem(
                              value: _CycleCardAction.delete,
                              child: Text(
                                'Eliminar',
                                style: TextStyle(color: cs.error),
                              ),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.more_horiz,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                const Text('Acciones'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _circleForArchetype(String? archetypeKey) {
  switch (archetypeKey) {
    case 'fuego':
      return 1;
    case 'luz':
      return 2;
    case 'cosmico':
      return 3;
    case 'estelar':
      return 4;
    case 'madre':
      return 5;
    case 'padre':
      return 6;
    case 'fuente':
      return 7;
    default:
      return null;
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

({DateTime start, DateTime end}) _cycleDateRange(CycleModel cycle) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dayInCycle = cycle.currentDay.clamp(1, cycle.duration);
  final start = today.subtract(Duration(days: dayInCycle - 1));
  final end = start.add(Duration(days: cycle.duration - 1));
  return (start: start, end: end);
}

String _formatDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}

String _normalizedTaskTitle(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return 'Tarea';
  return cleaned
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        if (word.length <= 2) return word.toUpperCase();
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

// ── Tile de tarea con animación ───────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.checked,
    required this.disabled,
    required this.onChanged,
  });

  final TaskModel task;
  final bool checked;
  final bool disabled;
  final void Function(bool?)? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: checked,
      onChanged: onChanged,
      title: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: theme.textTheme.bodyLarge!.copyWith(
          fontWeight: FontWeight.w700,
          decoration: checked ? TextDecoration.lineThrough : null,
          color: checked ? cs.onSurface.withValues(alpha: 0.45) : cs.onSurface,
        ),
        child: Text(_normalizedTaskTitle(task.title)),
      ),
      subtitle: task.description == null
          ? null
          : Text(
              task.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
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

// ── Bottom sheet de creación ──────────────────────────────────────────────────

enum _CreationKind { mandala, tapasya }

enum _CycleCardAction { restart, delete }

class _CreateCycleSheet extends StatefulWidget {
  const _CreateCycleSheet({
    required this.ref,
    this.kind = _CreationKind.mandala,
    this.initialTemplate,
  });
  final WidgetRef ref;
  final _CreationKind kind;
  final MandalaTemplateModel? initialTemplate;

  @override
  State<_CreateCycleSheet> createState() => _CreateCycleSheetState();
}

class _CreateCycleSheetState extends State<_CreateCycleSheet> {
  final _sankalpaController = TextEditingController();
  final _customDurationController = TextEditingController();
  final _customArchetypeController = TextEditingController();

  MandalaArchetype? _selectedArchetype;
  int _selectedDuration = 21;
  bool _showCustomDuration = false;
  final _pendingTasks = <({String title, String? description})>[];
  static const _defaultTaskTitles = ['Meditación', 'Japa', 'Kriyas', 'Fuego'];
  late final Map<String, bool> _defaultTaskSelected;
  late final Map<String, TextEditingController> _defaultTaskCommentControllers;
  String? _sankalpaError;
  String? _durationError;

  static const _presetDurations = [7, 14, 21, 42];

  String get _entityLabel =>
      widget.kind == _CreationKind.tapasya ? 'tapasya' : 'mandala';

  String get _entityLabelCapitalized =>
      widget.kind == _CreationKind.tapasya ? 'Tapasya' : 'Mandala';

  @override
  void initState() {
    super.initState();
    _defaultTaskSelected = {
      for (final title in _defaultTaskTitles) title: false,
    };
    _defaultTaskCommentControllers = {
      for (final title in _defaultTaskTitles) title: TextEditingController(),
    };

    final template = widget.initialTemplate;
    if (template == null) return;

    _sankalpaController.text = template.sankalpa;
    _selectedDuration = template.duration;
    _showCustomDuration = template.customDuration;
    if (template.customDuration) {
      _customDurationController.text = '${template.duration}';
    }

    final options = widget.kind == _CreationKind.tapasya
        ? MandalaArchetype.tapasyaOptions
        : MandalaArchetype.mandalaOptions;
    _selectedArchetype = _findArchetypeByKey(options, template.archetype);

    _pendingTasks.addAll(
      template.tasks.map(
        (task) => (
          title: task.title,
          description: task.description?.trim().isEmpty == true
              ? null
              : task.description?.trim(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sankalpaController.dispose();
    _customDurationController.dispose();
    _customArchetypeController.dispose();
    for (final controller in _defaultTaskCommentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _effectiveDuration => _showCustomDuration
      ? (int.tryParse(_customDurationController.text) ?? 21)
      : _selectedDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Nuevo $_entityLabel',
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Contenido scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Arquetipo ─────────────────────────────────────────
                  const SizedBox(height: 4),
                  _ArchetypeGrid(
                    options: widget.kind == _CreationKind.tapasya
                        ? MandalaArchetype.tapasyaOptions
                        : MandalaArchetype.mandalaOptions,
                    selected: _selectedArchetype,
                    onSelected: (a) => setState(() => _selectedArchetype = a),
                  ),
                  if (_selectedArchetype?.key == 'otro') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customArchetypeController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Ej. Saraswati, Shakti…',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Duración ──────────────────────────────────────────
                  _SectionLabel('Duración', theme),
                  const SizedBox(height: 12),
                  _DurationSelector(
                    selected: _showCustomDuration ? null : _selectedDuration,
                    presets: _presetDurations,
                    showCustom: _showCustomDuration,
                    customController: _customDurationController,
                    onPreset: (d) => setState(() {
                      _selectedDuration = d;
                      _showCustomDuration = false;
                    }),
                    onCustomToggle: () => setState(
                      () => _showCustomDuration = !_showCustomDuration,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Sankalpa ──────────────────────────────────────────
                  _SectionLabel('Sankalpa', theme),
                  const SizedBox(height: 4),
                  Text(
                    'Intención o propósito del ciclo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sankalpaController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej. Cultivar silencio interior cada día',
                      errorText: _sankalpaError,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Tareas ────────────────────────────────────────────
                  _SectionLabel('Tareas', theme),
                  const SizedBox(height: 4),
                  Text(
                    'Prácticas diarias de este ciclo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.kind == _CreationKind.mandala)
                    ..._defaultTaskTitles.map(
                      (title) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                value: _defaultTaskSelected[title] ?? false,
                                onChanged: (value) {
                                  setState(() {
                                    _defaultTaskSelected[title] =
                                        value ?? false;
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: cs.primary,
                                checkColor: cs.onPrimary,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF1D2A1D),
                                    fontWeight: FontWeight.w800,
                                    fontSize:
                                        (theme.textTheme.bodyLarge?.fontSize ??
                                            16) -
                                        0.8,
                                  ),
                                ),
                              ),
                              TextField(
                                controller:
                                    _defaultTaskCommentControllers[title],
                                enabled: _defaultTaskSelected[title] ?? false,
                                decoration: const InputDecoration(
                                  labelText: 'Comentario',
                                  hintText: 'Opcional',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  for (int i = 0; i < _pendingTasks.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.circle,
                        size: 8,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(
                        _normalizedTaskTitle(_pendingTasks[i].title),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: _pendingTasks[i].description != null
                          ? Text(_pendingTasks[i].description!)
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setState(() => _pendingTasks.removeAt(i)),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar tarea'),
                  ),
                  const SizedBox(height: 20),

                  // ── Botón crear ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text('Crear $_entityLabel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final sankalpa = _sankalpaController.text.trim();
    final duration = _effectiveDuration;

    setState(() {
      _sankalpaError = sankalpa.isEmpty ? 'El sankalpa es obligatorio' : null;
      _durationError = duration < 1 ? 'Duración inválida' : null;
    });
    if (_sankalpaError != null || _durationError != null) {
      if (_durationError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La duración debe ser mayor a 0')),
        );
      }
      return;
    }

    String? archetypeKey = _selectedArchetype?.key;
    if (_selectedArchetype?.key == 'otro') {
      final custom = _customArchetypeController.text.trim();
      archetypeKey = custom.isNotEmpty ? custom : 'otro';
    }
    final generatedTypeLabel = _selectedArchetype?.key == 'otro'
        ? (_customArchetypeController.text.trim().isEmpty
              ? 'Otro'
              : _customArchetypeController.text.trim())
        : (_selectedArchetype?.label ?? 'Libre');
    final name = '$_entityLabelCapitalized $generatedTypeLabel';

    final defaultTasks = <({String title, String? description})>[];
    if (widget.kind == _CreationKind.mandala) {
      for (final title in _defaultTaskTitles) {
        if (_defaultTaskSelected[title] ?? false) {
          final comment = _defaultTaskCommentControllers[title]?.text.trim();
          defaultTasks.add((
            title: title,
            description: (comment == null || comment.isEmpty) ? null : comment,
          ));
        }
      }
    }

    widget.ref
        .read(appControllerProvider.notifier)
        .createCycle(
          name: name,
          duration: duration,
          customDuration: _showCustomDuration,
          sankalpa: sankalpa,
          archetype: archetypeKey,
          selectedSavedAudioIds: const [],
          tasks: List.unmodifiable([...defaultTasks, ..._pendingTasks]),
        );
    Navigator.pop(context);
  }

  Future<void> _addTask() async {
    final task = await _showAddTaskDialog(context);
    if (task != null) setState(() => _pendingTasks.add(task));
  }

  Future<({String title, String? description})?> _showAddTaskDialog(
    BuildContext context,
  ) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    return showDialog<({String title, String? description})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva tarea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
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
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final description = descCtrl.text.trim().isEmpty
                  ? null
                  : descCtrl.text.trim();
              Navigator.pop(ctx, (
                title: _normalizedTaskTitle(title),
                description: description,
              ));
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  MandalaArchetype? _findArchetypeByKey(
    List<MandalaArchetype> options,
    String? raw,
  ) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    for (final option in options) {
      if (option.key == normalized) return option;
    }
    return null;
  }
}

// ── Etiqueta de sección ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.theme);
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: theme.textTheme.titleSmall);
}

// ── Grid de arquetipos ────────────────────────────────────────────────────────

class _ArchetypeGrid extends StatelessWidget {
  const _ArchetypeGrid({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<MandalaArchetype> options;
  final MandalaArchetype? selected;
  final void Function(MandalaArchetype) onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final archetype = options[index];
        return _ArchetypeCard(
          archetype: archetype,
          isSelected: selected?.key == archetype.key,
          onTap: () => onSelected(archetype),
        );
      },
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  const _ArchetypeCard({
    required this.archetype,
    required this.isSelected,
    required this.onTap,
  });

  final MandalaArchetype archetype;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor = archetype.onColor;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          width: 92,
          height: 92,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: archetype.gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: archetype.colors.last.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(archetype.minimalIcon, size: 18, color: onColor),
              const SizedBox(height: 1),
              Text(
                archetype.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: onColor,
                  shadows: [
                    Shadow(
                      blurRadius: 2,
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 13, color: onColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Selector de duración ──────────────────────────────────────────────────────

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({
    required this.selected,
    required this.presets,
    required this.showCustom,
    required this.customController,
    required this.onPreset,
    required this.onCustomToggle,
  });

  final int? selected;
  final List<int> presets;
  final bool showCustom;
  final TextEditingController customController;
  final void Function(int) onPreset;
  final VoidCallback onCustomToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.map((d) {
              final sel = !showCustom && selected == d;
              return ChoiceChip(
                label: Text('$d días'),
                selected: sel,
                onSelected: (_) => onPreset(d),
                selectedColor: cs.primaryContainer,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: sel ? cs.onPrimaryContainer : null,
                ),
              );
            }),
            ChoiceChip(
              label: const Text('Otro'),
              selected: showCustom,
              onSelected: (_) => onCustomToggle(),
              selectedColor: cs.primaryContainer,
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: showCustom ? cs.onPrimaryContainer : null,
              ),
            ),
          ],
        ),
        if (showCustom) ...[
          const SizedBox(height: 12),
          TextField(
            controller: customController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Número de días',
              hintText: 'Ej. 90',
            ),
          ),
        ],
      ],
    );
  }
}

class _MandalaTemplatesPage extends ConsumerStatefulWidget {
  const _MandalaTemplatesPage();

  @override
  ConsumerState<_MandalaTemplatesPage> createState() =>
      _MandalaTemplatesPageState();
}

class _MandalaTemplatesPageState extends ConsumerState<_MandalaTemplatesPage> {
  String _kind = 'mandala';

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final templates = repo.getMandalaTemplates(kind: _kind);
    final title = _kind == 'mandala' ? 'Plantillas de mandala' : 'Plantillas';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tipo',
            initialValue: _kind,
            onSelected: (value) => setState(() => _kind = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'mandala', child: Text('Mandalas')),
              PopupMenuItem(value: 'tapasya', child: Text('Tapasyas')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: templates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no hay plantillas guardadas.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).pop(template),
                    title: Text(template.name),
                    subtitle: Text(
                      '${template.duration} días · ${template.tasks.length} tareas',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar plantilla',
                      onPressed: () async {
                        await repo.deleteMandalaTemplate(template.id);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Abre el sheet de creación de mandala desde cualquier página.
Future<void> showCreateCycleSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateCycleSheet(ref: ref),
  );
}

Future<void> showCreateTapasyaSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateCycleSheet(ref: ref, kind: _CreationKind.tapasya),
  );
}

CycleModel? findCycleById(List<CycleModel> cycles, String id) {
  for (final cycle in cycles) {
    if (cycle.id == id) return cycle;
  }
  return null;
}
