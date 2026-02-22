import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/features/cycles/presentation/cycle_detail_page.dart';

class CyclesPage extends ConsumerWidget {
  const CyclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycles = ref.watch(appControllerProvider.select((s) => s.cycles));

    return Scaffold(
      appBar: AppBar(title: const Text('Ciclos')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: cycles.length,
        itemBuilder: (context, index) {
          final cycle = cycles[index];
          return Card(
            child: ListTile(
              title: Text(cycle.name),
              subtitle: Text('Dia ${cycle.currentDay}/${cycle.duration}'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  if (cycle.isActive)
                    const Chip(
                      label: Text('Activo'),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        _showCycleDialog(context, ref, cycle: cycle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => ref
                        .read(appControllerProvider.notifier)
                        .startCycle(cycle.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () => ref
                        .read(appControllerProvider.notifier)
                        .stopCycle(cycle.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref
                        .read(appControllerProvider.notifier)
                        .deleteCycle(cycle.id),
                  ),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CycleDetailPage(cycleId: cycle.id),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCycleDialog(context, ref, cycle: null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCycleDialog(
    BuildContext context,
    WidgetRef ref, {
    required CycleModel? cycle,
  }) async {
    final nameController = TextEditingController(text: cycle?.name ?? '');
    final sankalpaController = TextEditingController(
      text: cycle?.sankalpa ?? '',
    );
    final durationController = TextEditingController(
      text: (cycle?.duration ?? 40).toString(),
    );
    bool customDuration = cycle?.customDuration ?? false;
    final pendingTasks = <({String title, String? description})>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(cycle == null ? 'Nuevo ciclo' : 'Editar ciclo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: sankalpaController,
                      decoration:
                          const InputDecoration(labelText: 'Sankalpa'),
                    ),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duracion (dias)',
                      ),
                    ),
                    SwitchListTile(
                      value: customDuration,
                      onChanged: (value) =>
                          setState(() => customDuration = value),
                      title: const Text('Duracion personalizada'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (cycle == null) ...[
                      const Divider(height: 24),
                      const Text(
                        'Tareas',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < pendingTasks.length; i++)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(pendingTasks[i].title),
                          subtitle: pendingTasks[i].description != null
                              ? Text(pendingTasks[i].description!)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => pendingTasks.removeAt(i)),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () async {
                          final task = await _showAddTaskDialog(context);
                          if (task != null) {
                            setState(() => pendingTasks.add(task));
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar tarea'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (cycle == null) {
                      ref
                          .read(appControllerProvider.notifier)
                          .createCycle(
                            name: nameController.text.trim(),
                            duration:
                                int.tryParse(durationController.text) ?? 40,
                            customDuration: customDuration,
                            sankalpa: sankalpaController.text.trim(),
                            tasks: List.unmodifiable(pendingTasks),
                          );
                    } else {
                      ref
                          .read(appControllerProvider.notifier)
                          .updateCycle(
                            cycle.copyWith(
                              name: nameController.text.trim(),
                              duration:
                                  int.tryParse(durationController.text) ?? 40,
                              customDuration: customDuration,
                              sankalpa: sankalpaController.text.trim(),
                            ),
                          );
                    }
                    Navigator.pop(context);
                  },
                  child: Text(cycle == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<({String title, String? description})?> _showAddTaskDialog(
    BuildContext context,
  ) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog<({String title, String? description})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titulo'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripcion (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final description = descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim();
                Navigator.pop(
                  context,
                  (title: title, description: description),
                );
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}

CycleModel? findCycleById(List<CycleModel> cycles, String id) {
  for (final cycle in cycles) {
    if (cycle.id == id) return cycle;
  }
  return null;
}
