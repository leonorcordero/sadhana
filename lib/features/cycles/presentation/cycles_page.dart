import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';

// ── Página principal ──────────────────────────────────────────────────────────

class CyclesPage extends ConsumerWidget {
  const CyclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycles = ref.watch(appControllerProvider.select((s) => s.cycles));

    return Scaffold(
      appBar: AppBar(title: const Text('Mándalas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          for (final cycle in cycles)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                    ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Creación: bottom sheet ────────────────────────────────────────────────

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCycleSheet(ref: ref),
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
      await onConfirm();
    }
  }
}

// ── Tarjeta de mandala activo (expandida, con tareas) ─────────────────────────

class _ActiveMandalaCard extends ConsumerWidget {
  const _ActiveMandalaCard({required this.cycle, required this.onRestart});

  final CycleModel cycle;
  final VoidCallback onRestart;

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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de arquetipo con nombre del ciclo
          if (archetype != null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(gradient: archetype.gradient),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(archetype.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          archetype.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: archetype.onColor.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          cycle.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: archetype.onColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Día ${cycle.currentDay}/${cycle.duration}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: archetype.onColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(cycle.name, style: theme.textTheme.titleLarge),
                  ),
                  Text(
                    'Día ${cycle.currentDay}/${cycle.duration}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
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
                // Sankalpa
                Text(
                  cycle.sankalpa,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Racha + progreso %
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
                    TextButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.replay, size: 16),
                      label: const Text('Reiniciar'),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Eliminar'),
                      style: TextButton.styleFrom(foregroundColor: cs.error),
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
  });

  final CycleModel cycle;
  final VoidCallback onRestart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final archetype = MandalaArchetype.fromKey(cycle.archetype);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra lateral de color
            if (archetype != null)
              Container(
                width: 6,
                decoration: BoxDecoration(gradient: archetype.gradient),
              ),
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
                        child: Text(
                          archetype.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cycle.name, style: theme.textTheme.titleMedium),
                          Text(
                            '${cycle.duration} días · ${cycle.sankalpa}',
                            style: theme.textTheme.bodySmall?.copyWith(
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
                          icon: const Icon(Icons.replay),
                          tooltip: 'Reiniciar',
                          onPressed: onRestart,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar',
                          onPressed: onDelete,
                          visualDensity: VisualDensity.compact,
                          color: cs.error,
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
          Text('$label: $value', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

// ── Bottom sheet de creación ──────────────────────────────────────────────────

class _CreateCycleSheet extends StatefulWidget {
  const _CreateCycleSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_CreateCycleSheet> createState() => _CreateCycleSheetState();
}

class _CreateCycleSheetState extends State<_CreateCycleSheet> {
  final _nameController = TextEditingController();
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
  String? _nameError;
  String? _sankalpaError;
  String? _durationError;

  static const _presetDurations = [7, 14, 21, 42];
  static const _templates = <_MandalaTemplate>[
    _MandalaTemplate(
      name: 'Sadhana matutina',
      sankalpa: 'Comenzar el dia con presencia y devocion.',
      defaultTasks: ['Meditación', 'Japa'],
      duration: 21,
    ),
    _MandalaTemplate(
      name: 'Bhakti diaria',
      sankalpa: 'Cultivar corazon abierto y gratitud.',
      defaultTasks: ['Japa', 'Fuego'],
      duration: 40,
    ),
    _MandalaTemplate(
      name: 'Purificacion',
      sankalpa: 'Sostener disciplina interna con claridad.',
      defaultTasks: ['Kriyas', 'Meditación'],
      duration: 14,
    ),
  ];

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
    _nameController.dispose();
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
                Text('Nuevo mandala', style: theme.textTheme.headlineSmall),
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

                  // ── Nombre ────────────────────────────────────────────
                  _SectionLabel('Nombre', theme),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _templates
                        .map(
                          (t) => ActionChip(
                            label: Text(t.name),
                            onPressed: () => _applyTemplate(t),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Ej. Meditación matutina',
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 20),

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
                  ..._defaultTaskTitles.map(
                    (title) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: _defaultTaskSelected[title] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _defaultTaskSelected[title] = value ?? false;
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(title),
                            ),
                            TextField(
                              controller: _defaultTaskCommentControllers[title],
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
                      title: Text(_pendingTasks[i].title),
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
                      child: const Text('Crear mandala'),
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
    final name = _nameController.text.trim();
    final sankalpa = _sankalpaController.text.trim();
    final duration = _effectiveDuration;

    setState(() {
      _nameError = name.isEmpty ? 'El nombre es obligatorio' : null;
      _sankalpaError = sankalpa.isEmpty ? 'El sankalpa es obligatorio' : null;
      _durationError = duration < 1 ? 'Duración inválida' : null;
    });
    if (_nameError != null ||
        _sankalpaError != null ||
        _durationError != null) {
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

    final defaultTasks = <({String title, String? description})>[];
    for (final title in _defaultTaskTitles) {
      if (_defaultTaskSelected[title] ?? false) {
        final comment = _defaultTaskCommentControllers[title]?.text.trim();
        defaultTasks.add((
          title: title,
          description: (comment == null || comment.isEmpty) ? null : comment,
        ));
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
          tasks: List.unmodifiable([...defaultTasks, ..._pendingTasks]),
        );
    Navigator.pop(context);
  }

  Future<void> _addTask() async {
    final task = await _showAddTaskDialog(context);
    if (task != null) setState(() => _pendingTasks.add(task));
  }

  void _applyTemplate(_MandalaTemplate template) {
    setState(() {
      _nameController.text = template.name;
      _sankalpaController.text = template.sankalpa;
      _selectedDuration = template.duration;
      _showCustomDuration = false;
      for (final title in _defaultTaskTitles) {
        _defaultTaskSelected[title] = template.defaultTasks.contains(title);
      }
    });
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
              Navigator.pop(ctx, (title: title, description: description));
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

class _MandalaTemplate {
  const _MandalaTemplate({
    required this.name,
    required this.sankalpa,
    required this.defaultTasks,
    required this.duration,
  });

  final String name;
  final String sankalpa;
  final List<String> defaultTasks;
  final int duration;
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
  const _ArchetypeGrid({required this.selected, required this.onSelected});

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
      itemCount: MandalaArchetype.all.length,
      itemBuilder: (context, index) {
        final archetype = MandalaArchetype.all[index];
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
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          width: 88,
          height: 88,
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
              Text(archetype.emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(height: 1),
              Text(
                archetype.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
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

CycleModel? findCycleById(List<CycleModel> cycles, String id) {
  for (final cycle in cycles) {
    if (cycle.id == id) return cycle;
  }
  return null;
}
