import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final cycle = state.activeCycle;

    if (cycle == null) {
      return const Scaffold(
        body: Center(child: Text('Activa un ciclo para gestionar tareas.')),
      );
    }

    final tasks = state.tasks.where((t) => t.cycleId == cycle.id).toList();
    final repo = ref.read(repositoryProvider);
    final log = repo.getOrCreateDayLog(
      cycleId: cycle.id,
      date: state.selectedDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas diarias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            onPressed: () => ref
                .read(appControllerProvider.notifier)
                .selectDate(DateTime.now()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: const Text('Fecha seleccionada'),
              subtitle: Text(
                '${state.selectedDate.year}-${state.selectedDate.month}-${state.selectedDate.day}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: state.selectedDate,
                  );
                  if (selected != null) {
                    ref
                        .read(appControllerProvider.notifier)
                        .selectDate(selected);
                  }
                },
              ),
            ),
          ),
          ...tasks.map(
            (task) => Card(
              child: CheckboxListTile(
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
                title: Text(task.title),
                subtitle: task.description == null
                    ? null
                    : Text(task.description!),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(appControllerProvider.notifier)
                      .deleteTask(task.id),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(context, ref, cycle.id),
        child: const Icon(Icons.add_task),
      ),
    );
  }

  Future<void> _showTaskDialog(
    BuildContext context,
    WidgetRef ref,
    String cycleId,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
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
                ref
                    .read(appControllerProvider.notifier)
                    .createTask(
                      cycleId: cycleId,
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                    );
                Navigator.pop(context);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }
}
