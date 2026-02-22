import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';

class CycleDetailPage extends ConsumerWidget {
  const CycleDetailPage({super.key, required this.cycleId});

  final String cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final cycle = state.cycles.where((c) => c.id == cycleId).firstOrNull;

    if (cycle == null) {
      return const Scaffold(body: Center(child: Text('Ciclo no encontrado')));
    }

    final tasks = state.tasks.where((t) => t.cycleId == cycle.id).toList();

    return Scaffold(
      appBar: AppBar(title: Text(cycle.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sankalpa',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(cycle.sankalpa),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: cycle.progress),
                  const SizedBox(height: 8),
                  Text('Dia ${cycle.currentDay} de ${cycle.duration}'),
                  const SizedBox(height: 8),
                  Text(
                    'Racha actual: ${cycle.streakCurrent} | Maxima: ${cycle.streakMax}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tareas del ciclo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...tasks.map(
            (task) => Card(
              child: ListTile(
                title: Text(task.title),
                subtitle: task.description == null
                    ? null
                    : Text(task.description!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
