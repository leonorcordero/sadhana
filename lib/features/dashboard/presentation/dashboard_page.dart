import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/dashboard_snapshot.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final activeCycles = state.activeCycles;

    if (activeCycles.isEmpty) {
      return const _EmptyDashboard();
    }

    final repo = ref.read(repositoryProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final cycle in activeCycles) ...[
            _CycleDashboardCard(
              cycle: cycle,
              snapshot: repo.getDashboardSnapshotForCycle(
                cycleId: cycle.id,
                date: state.selectedDate,
              ),
              repo: repo,
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: () =>
                ref.read(appControllerProvider.notifier).closeDayNow(),
            icon: const Icon(Icons.nightlight_round),
            label: const Text('Cerrar dia manualmente'),
          ),
        ],
      ),
    );
  }
}

class _CycleDashboardCard extends ConsumerWidget {
  const _CycleDashboardCard({
    required this.cycle,
    required this.snapshot,
    required this.repo,
  });

  final CycleModel cycle;
  final DashboardSnapshot snapshot;
  final SadhanaRepository repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complete = snapshot.completionRatio == 1;
    final dayClosed = snapshot.todayLog?.closed ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cycle.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              cycle.sankalpa,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    title: 'Dia',
                    value: '${cycle.currentDay}/${cycle.duration}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    title: 'Racha actual',
                    value: '${cycle.streakCurrent}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    title: 'Racha max',
                    value: '${cycle.streakMax}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Progreso diario',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: snapshot.completionRatio),
            const SizedBox(height: 4),
            Text(
              '${(snapshot.completionRatio * 100).toStringAsFixed(0)}% completado',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (snapshot.tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              for (final task in snapshot.tasks)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: snapshot.todayLog?.completedTaskIds.contains(task.id) ??
                      false,
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
                  title: Text(task.title),
                  subtitle: task.description == null
                      ? null
                      : Text(task.description!),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              repo.motivationalQuote(dayComplete: complete),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Crea y activa un ciclo para ver tu dashboard.'),
        ),
      ),
    );
  }
}
