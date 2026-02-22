import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final activeCycles = state.activeCycles;

    if (activeCycles.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Activa un ciclo para gestionar tareas.')),
      );
    }

    final repo = ref.read(repositoryProvider);

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
                '${state.selectedDate.year}-${state.selectedDate.month.toString().padLeft(2, '0')}-${state.selectedDate.day.toString().padLeft(2, '0')}',
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
          const SizedBox(height: 8),
          for (final cycle in activeCycles) ...[
            _CycleTasksSection(
              cycle: cycle,
              tasks: state.tasks.where((t) => t.cycleId == cycle.id).toList(),
              log: repo.getOrCreateDayLog(
                cycleId: cycle.id,
                date: state.selectedDate,
              ),
              ref: ref,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cycle.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showTaskDialog(context, cycle.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tarea'),
            ),
          ],
        ),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin tareas. Agrega una con el boton "Tarea".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final task in tasks)
            Card(
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
                subtitle:
                    task.description == null ? null : Text(task.description!),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(appControllerProvider.notifier)
                      .deleteTask(task.id),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _showTaskDialog(BuildContext context, String cycleId) async {
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
                if (titleController.text.trim().isEmpty) return;
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
