import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/utils/responsive_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';
import 'package:sadhana/features/resources/presentation/resources_library_page.dart';

// ── Página principal ──────────────────────────────────────────────────────────

class CyclesPage extends ConsumerWidget {
  const CyclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycles = ref.watch(appControllerProvider.select((s) => s.cycles));
    final repo = ref.read(repositoryProvider);
    final spacingScale = ResponsiveUtils.spacingScale(context);
    final isNarrow = ResponsiveUtils.isNarrowPhone(context);
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16 * spacingScale,
          20 * spacingScale,
          16 * spacingScale,
          32 * spacingScale,
        ),
        children: [
          for (final cycle in cycles)
            Padding(
              padding: EdgeInsets.only(bottom: 12 * spacingScale),
              child: cycle.isActive
                  ? _ActiveMandalaCard(
                      cycle: cycle,
                      onRestart: () => _confirmAction(
                        context,
                        title: 'Reiniciar mandala',
                        message: 'Se reiniciará al día 1 y quedará activo.',
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
                    )
                  : _InactiveMandalaCard(
                      cycle: cycle,
                      onRestart: () => _confirmAction(
                        context,
                        title: 'Reiniciar mandala',
                        message: 'Se reiniciará al día 1 y quedará activo.',
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
                    ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 74 * spacingScale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'create_mandala_fab',
              tooltip: 'Crear Mandala',
              onPressed: () =>
                  _showCreateSheet(context, ref, kind: _CreationKind.mandala),
              icon: const Icon(Icons.add),
              label: const Text('Mandala'),
            ),
            SizedBox(height: 10 * spacingScale),
            FloatingActionButton.extended(
              heroTag: 'create_tapasya_fab',
              tooltip: 'Crear Tapasya',
              onPressed: () =>
                  _showCreateSheet(context, ref, kind: _CreationKind.tapasya),
              icon: const Icon(Icons.add),
              label: const Text('Tapasya'),
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
    final circle = _circleForArchetype(cycle.archetype);
    if (circle == null) return null;
    final folderId = 'recursos-circulos-circle-$circle';
    final folder = folderById[folderId];
    if (folder == null) return null;
    return () {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResourceFolderPage(folder: folder)),
      );
    };
  }

  // ── Creación: bottom sheet ────────────────────────────────────────────────

  Future<void> _showCreateSheet(
    BuildContext context,
    WidgetRef ref, {
    _CreationKind kind = _CreationKind.mandala,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCycleSheet(ref: ref, kind: kind),
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
}

// ── Tarjeta de mandala activo (expandida, con tareas) ─────────────────────────

class _ActiveMandalaCard extends ConsumerWidget {
  const _ActiveMandalaCard({
    required this.cycle,
    required this.onRestart,
    required this.onDelete,
    this.onCircleResources,
  });

  final CycleModel cycle;
  final VoidCallback onRestart;
  final VoidCallback onDelete;
  final VoidCallback? onCircleResources;

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
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
                  const Divider(height: 1),
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
    required this.onRestart,
    required this.onDelete,
    this.onCircleResources,
  });

  final CycleModel cycle;
  final VoidCallback onRestart;
  final VoidCallback onDelete;
  final VoidCallback? onCircleResources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final displayName = _normalizedMandalaName(cycle.name);
    final range = _cycleDateRange(cycle);
    final sideColor =
        archetype?.softHeaderColor(cs) ?? cs.primary.withValues(alpha: 0.22);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra lateral de color
            if (archetype != null) Container(width: 5, color: sideColor),
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
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
  });
  final WidgetRef ref;
  final _CreationKind kind;

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
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
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
          const Divider(height: 1),
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
                            border: Border.all(color: cs.outlineVariant),
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
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2.5,
                  )
                : null,
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
