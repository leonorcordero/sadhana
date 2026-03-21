import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/features/cycles/domain/mandala_archetype.dart';
import 'package:sadhana/features/resources/presentation/resources_library_page.dart';
import 'package:sadhana/features/resources/presentation/resources_page.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final archetype = MandalaArchetype.fromKey(cycle.archetype);
    final repo = ref.read(repositoryProvider);
    final resourcesById = <String, MandalaResourceModel>{
      for (final item in repo.getMandalaResources()) item.id: item,
    };
    final foldersById = <String, ResourceFolderModel>{
      for (final folder in repo.getResourceFolders()) folder.id: folder,
    };
    final linkedFolders = cycle.linkedResourceFolderIds
        .map((id) => foldersById[id])
        .whereType<ResourceFolderModel>()
        .toList(growable: false);

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
                  Row(
                    children: [
                      Icon(
                        archetype?.minimalIcon ??
                            Icons.self_improvement_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tipo: ${archetype?.label ?? 'Personalizado'}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
          if (linkedFolders.isNotEmpty) ...[
            Text(
              'Carpetas vinculadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final folder in linkedFolders)
                  ActionChip(
                    avatar: const Icon(Icons.folder_outlined, size: 16),
                    label: Text(folder.name),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResourceFolderPage(folder: folder),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Tareas del ciclo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...tasks.map((task) {
            final linked = task.linkedResourceIds
                .map((id) => resourcesById[id])
                .whereType<MandalaResourceModel>()
                .toList(growable: false);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(task.title),
                      subtitle: task.description == null
                          ? null
                          : Text(task.description!),
                      trailing: linked.isEmpty
                          ? null
                          : Text('${linked.length} recursos'),
                    ),
                    if (linked.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final resource in linked)
                            ActionChip(
                              label: Text(resource.title),
                              onPressed: () => _openResource(context, resource),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openResource(
    BuildContext context,
    MandalaResourceModel resource,
  ) async {
    if (_isLinkResource(resource)) {
      final url = _normalizeUrl(resource.inlineText ?? '');
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (opened || !context.mounted) return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el link.')),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResourceViewerPage(resource: resource)),
    );
  }

  bool _isLinkResource(MandalaResourceModel item) {
    if (item.type != MandalaResourceType.other) return false;
    final raw = (item.inlineText ?? '').trim();
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(_normalizeUrl(raw));
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
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
