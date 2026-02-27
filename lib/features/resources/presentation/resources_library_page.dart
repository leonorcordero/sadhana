import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/resources/presentation/resources_page.dart';
import 'package:sadhana/features/resources/presentation/wednesday_affirmation_page.dart';
import 'package:url_launcher/url_launcher.dart';

const _romanByCircle = {
  1: 'I',
  2: 'II',
  3: 'III',
  4: 'IV',
  5: 'V',
  6: 'VI',
  7: 'VII',
};
const _audioosVariosFolderId = 'audioos-varios';
const _audioosVariosFolderName = 'Audios varios';
const _notesFolderId = 'notas-root';
const _notesFolderName = 'Notas';
const _resourcesCirculosRootId = 'recursos-circulos-root';
const _resourcesCirculosRootName = 'Recursos círculos';
const _resourcesCircleFolderPrefix = 'recursos-circulos-circle-';
const _legacyMandalaAudiosRootId = 'audios-mandalas-root';
const _legacyMandalaCircleFolderPrefix = 'audios-mandalas-circle-';

String _circleLabel(int circle) {
  if (circle <= 0) return 'Sin círculo';
  return '${_romanByCircle[circle] ?? 'I'} ($circle)';
}

class ResourcesLibraryPage extends ConsumerStatefulWidget {
  const ResourcesLibraryPage({super.key});

  @override
  ConsumerState<ResourcesLibraryPage> createState() =>
      _ResourcesLibraryPageState();
}

class _ResourcesLibraryPageState extends ConsumerState<ResourcesLibraryPage> {
  List<ResourceFolderModel> _folders = <ResourceFolderModel>[];
  Map<String, int> _countsByFolder = <String, int>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repo = ref.read(repositoryProvider);
    await _ensureBaseline(repo);

    final folders = repo.getResourceFolders();
    final items = repo.getMandalaResources();
    final counts = <String, int>{};
    for (final item in items) {
      final key = item.folderId.trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    if (!mounted) return;
    setState(() {
      _folders = folders;
      _countsByFolder = counts;
    });
  }

  Future<void> _ensureBaseline(SadhanaRepository repo) async {
    var folders = repo.getResourceFolders();
    final resources = repo.getMandalaResources();
    final cycles = repo.getCycles();
    final cycleNameById = <String, String>{
      for (final c in cycles) c.id: c.name,
    };

    if (folders.isEmpty) {
      await repo.createResourceFolder(name: 'General', circle: 1);
      folders = repo.getResourceFolders();
    }

    final hasAudioosVarios = folders.any((f) => f.id == _audioosVariosFolderId);
    if (!hasAudioosVarios) {
      await repo.saveResourceFolder(
        ResourceFolderModel(
          id: _audioosVariosFolderId,
          name: _audioosVariosFolderName,
          circle: 0,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    } else {
      final existing = folders.firstWhere(
        (f) => f.id == _audioosVariosFolderId,
      );
      if (existing.name != _audioosVariosFolderName) {
        await repo.saveResourceFolder(
          existing.copyWith(name: _audioosVariosFolderName),
        );
      }
    }

    final hasNotesFolder = folders.any((f) => f.id == _notesFolderId);
    if (!hasNotesFolder) {
      await repo.saveResourceFolder(
        ResourceFolderModel(
          id: _notesFolderId,
          name: _notesFolderName,
          circle: 0,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    } else {
      final existing = folders.firstWhere((f) => f.id == _notesFolderId);
      if (existing.name != _notesFolderName) {
        await repo.saveResourceFolder(
          existing.copyWith(name: _notesFolderName),
        );
      }
    }

    final hasResourcesCirculosRoot = folders.any(
      (f) => f.id == _resourcesCirculosRootId,
    );
    if (!hasResourcesCirculosRoot) {
      await repo.saveResourceFolder(
        ResourceFolderModel(
          id: _resourcesCirculosRootId,
          name: _resourcesCirculosRootName,
          circle: 0,
          createdAt: DateTime.now().toIso8601String(),
          parentId: null,
        ),
      );
    } else {
      final existing = folders.firstWhere(
        (f) => f.id == _resourcesCirculosRootId,
      );
      if (existing.name != _resourcesCirculosRootName ||
          existing.parentId != null) {
        await repo.saveResourceFolder(
          existing.copyWith(
            name: _resourcesCirculosRootName,
            clearParentId: true,
          ),
        );
      }
    }

    for (var circle = 1; circle <= 7; circle++) {
      final id = '$_resourcesCircleFolderPrefix$circle';
      final name =
          '$_resourcesCirculosRootName / Círculo ${_romanByCircle[circle]}';
      final hasFolder = folders.any((f) => f.id == id);
      if (!hasFolder) {
        await repo.saveResourceFolder(
          ResourceFolderModel(
            id: id,
            name: name,
            circle: circle,
            createdAt: DateTime.now().toIso8601String(),
            parentId: _resourcesCirculosRootId,
          ),
        );
      } else {
        final existing = folders.firstWhere((f) => f.id == id);
        if (existing.name != name ||
            existing.parentId != _resourcesCirculosRootId) {
          await repo.saveResourceFolder(
            existing.copyWith(name: name, parentId: _resourcesCirculosRootId),
          );
        }
      }
    }

    final legacyToNewFolderId = <String, String>{
      _legacyMandalaAudiosRootId: _resourcesCirculosRootId,
      for (var circle = 1; circle <= 7; circle++)
        '$_legacyMandalaCircleFolderPrefix$circle':
            '$_resourcesCircleFolderPrefix$circle',
    };

    for (final resource in resources) {
      final legacyMapped = legacyToNewFolderId[resource.folderId];
      if (legacyMapped != null) {
        await repo.saveMandalaResource(
          resource.copyWith(folderId: legacyMapped),
        );
      }
    }

    folders = repo.getResourceFolders();
    final legacyFolderIds = <String>[
      _legacyMandalaAudiosRootId,
      for (var circle = 1; circle <= 7; circle++)
        '$_legacyMandalaCircleFolderPrefix$circle',
    ];
    for (final legacyId in legacyFolderIds) {
      if (folders.any((f) => f.id == legacyId)) {
        await repo.deleteResourceFolder(legacyId);
      }
    }

    folders = repo.getResourceFolders();
    final folderById = <String, ResourceFolderModel>{
      for (final folder in folders) folder.id: folder,
    };

    final fallbackFolder = folders.first;
    for (final resource in resources) {
      var targetFolderId = resource.folderId.trim();
      if (targetFolderId.isEmpty) {
        targetFolderId = fallbackFolder.id;
      }

      if (!folderById.containsKey(targetFolderId)) {
        final folder = ResourceFolderModel(
          id: targetFolderId,
          name: cycleNameById[targetFolderId] ?? 'Carpeta',
          circle: 1,
          createdAt: DateTime.now().toIso8601String(),
        );
        await repo.saveResourceFolder(folder);
        folderById[targetFolderId] = folder;
      }

      if (resource.folderId != targetFolderId) {
        await repo.saveMandalaResource(
          resource.copyWith(folderId: targetFolderId),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final circleFolders =
        _folders
            .where((folder) => folder.parentId == _resourcesCirculosRootId)
            .toList()
          ..sort((a, b) => a.circle.compareTo(b.circle));
    final visibleFolders = _folders
        .where(
          (folder) =>
              folder.parentId == null || folder.parentId!.trim().isEmpty,
        )
        .toList();
    ResourceFolderModel? circlesRootFolder;
    ResourceFolderModel? audiosVariosFolder;
    final reorderableFolders = <ResourceFolderModel>[];
    for (final folder in visibleFolders) {
      if (folder.id == _resourcesCirculosRootId) {
        circlesRootFolder = folder;
        continue;
      }
      if (folder.id == _audioosVariosFolderId) {
        audiosVariosFolder = folder;
        continue;
      }
      reorderableFolders.add(folder);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Recursos'),
            Text(
              'Carpetas con audios, fotos, PDF y textos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ordenar carpetas',
            onPressed: _openFolderOrderDialog,
            icon: const Icon(Icons.swap_vert_outlined),
          ),
        ],
      ),
      body: _folders.isEmpty
          ? Center(
              child: Text(
                'No hay carpetas.\nToca + para crear una.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (circlesRootFolder != null)
                  _FolderTile(
                    key: ValueKey(circlesRootFolder.id),
                    folder: circlesRootFolder,
                    resourceCount: _countsByFolder[circlesRootFolder.id] ?? 0,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _CircleFoldersPage(
                            folders: circleFolders,
                            countsByFolder: _countsByFolder,
                          ),
                        ),
                      );
                      await _reload();
                    },
                  ),
                if (audiosVariosFolder != null)
                  _FolderTile(
                    key: ValueKey(audiosVariosFolder.id),
                    folder: audiosVariosFolder,
                    resourceCount: _countsByFolder[audiosVariosFolder.id] ?? 0,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ResourceFolderPage(folder: audiosVariosFolder!),
                        ),
                      );
                      await _reload();
                    },
                    onEdit: () =>
                        _openFolderDialog(existing: audiosVariosFolder),
                    onDelete: () => _deleteFolder(audiosVariosFolder!),
                  ),
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: ListTile(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WednesdayAffirmationPage(),
                        ),
                      );
                    },
                    leading: Icon(
                      Icons.auto_awesome_outlined,
                      color: cs.primary,
                    ),
                    title: Text(
                      'Afirmación miércoles',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize:
                            (theme.textTheme.bodyLarge?.fontSize ?? 16) - 1.2,
                      ),
                    ),
                    subtitle: Text(
                      'Fecha, nombre opcional y texto o imagen',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize:
                            (theme.textTheme.bodySmall?.fontSize ?? 14) - 0.6,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: reorderableFolders.length,
                  onReorder: (oldIndex, newIndex) => _onReorderVisibleFolders(
                    reorderableFolders,
                    oldIndex,
                    newIndex,
                  ),
                  itemBuilder: (context, index) {
                    final folder = reorderableFolders[index];
                    return _FolderTile(
                      key: ValueKey(folder.id),
                      folder: folder,
                      resourceCount: _countsByFolder[folder.id] ?? 0,
                      reorderIndex: index,
                      onTap: () async {
                        if (folder.id == _resourcesCirculosRootId) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _CircleFoldersPage(
                                folders: circleFolders,
                                countsByFolder: _countsByFolder,
                              ),
                            ),
                          );
                        } else {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ResourceFolderPage(folder: folder),
                            ),
                          );
                        }
                        await _reload();
                      },
                      onEdit: folder.id == _resourcesCirculosRootId
                          ? null
                          : () => _openFolderDialog(existing: folder),
                      onDelete: folder.id == _resourcesCirculosRootId
                          ? null
                          : () => _deleteFolder(folder),
                    );
                  },
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFolderDialog(),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Carpeta'),
      ),
    );
  }

  Future<void> _openFolderDialog({ResourceFolderModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int circle = existing?.circle ?? 0;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Nueva carpeta' : 'Editar carpeta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: circle,
                decoration: const InputDecoration(labelText: 'Círculo'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sin círculo')),
                  DropdownMenuItem(value: 1, child: Text('Círculo I')),
                  DropdownMenuItem(value: 2, child: Text('Círculo II')),
                  DropdownMenuItem(value: 3, child: Text('Círculo III')),
                  DropdownMenuItem(value: 4, child: Text('Círculo IV')),
                  DropdownMenuItem(value: 5, child: Text('Círculo V')),
                  DropdownMenuItem(value: 6, child: Text('Círculo VI')),
                  DropdownMenuItem(value: 7, child: Text('Círculo VII')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setModalState(() => circle = value);
                },
              ),
            ],
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
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    if (existing == null) {
      await repo.createResourceFolder(name: name, circle: circle);
    } else {
      await repo.saveResourceFolder(
        existing.copyWith(name: name, circle: circle),
      );
    }

    await _reload();
  }

  Future<void> _deleteFolder(ResourceFolderModel folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar carpeta'),
        content: const Text(
          'Se eliminará la carpeta y todos sus recursos. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final repo = ref.read(repositoryProvider);
    final allFolders = repo.getResourceFolders();
    final descendantIds = <String>{};
    final queue = <String>[folder.id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final candidate in allFolders) {
        if (candidate.parentId != current) continue;
        if (descendantIds.add(candidate.id)) {
          queue.add(candidate.id);
        }
      }
    }
    final folderIds = <String>{folder.id, ...descendantIds};
    final items = repo
        .getMandalaResources()
        .where((resource) => folderIds.contains(resource.folderId))
        .toList(growable: false);

    for (final item in items) {
      final path = item.filePath;
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await repo.deleteResourceFolder(folder.id);
    await _reload();
  }

  Future<void> _openFolderOrderDialog() async {
    final rootFolders = _folders
        .where(
          (folder) =>
              folder.id != _resourcesCirculosRootId &&
              (folder.parentId == null || folder.parentId!.trim().isEmpty),
        )
        .toList(growable: false);
    final folderIds = rootFolders
        .map((folder) => folder.id)
        .toList(growable: false);
    if (folderIds.length < 2) return;
    final ordered = await _showReorderDialog(
      context: context,
      title: 'Ordenar carpetas',
      items: rootFolders,
      idOf: (folder) => folder.id,
      labelOf: (folder) => folder.name,
    );
    if (ordered == null) return;

    final repo = ref.read(repositoryProvider);
    await _saveSubsetFolderOrder(repo, ordered);
    await _reload();
  }

  Future<void> _saveSubsetFolderOrder(
    SadhanaRepository repo,
    List<String> orderedSubset,
  ) async {
    final current = repo
        .getResourceFolders()
        .map((folder) => folder.id)
        .toList();
    final subset = orderedSubset.toSet();
    var pointer = 0;
    final merged = <String>[];
    for (final id in current) {
      if (subset.contains(id)) {
        merged.add(orderedSubset[pointer]);
        pointer += 1;
      } else {
        merged.add(id);
      }
    }
    await repo.saveResourceFoldersOrderIds(merged);
  }

  Future<void> _onReorderVisibleFolders(
    List<ResourceFolderModel> visibleFolders,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<ResourceFolderModel>.from(visibleFolders);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final repo = ref.read(repositoryProvider);
    await _saveSubsetFolderOrder(
      repo,
      reordered.map((folder) => folder.id).toList(growable: false),
    );
    await _reload();
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.resourceCount,
    required this.onTap,
    this.reorderIndex,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final ResourceFolderModel folder;
  final int resourceCount;
  final VoidCallback onTap;
  final int? reorderIndex;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final circleLabel = _circleLabel(folder.circle);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.folder_outlined, color: cs.primary),
        title: Text(
          folder.name,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) - 1.2,
          ),
        ),
        subtitle: Text(
          '${folder.name} · $circleLabel · $resourceCount recursos',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: (theme.textTheme.bodySmall?.fontSize ?? 14) - 0.6,
          ),
        ),
        trailing: (onEdit == null && onDelete == null)
            ? const Icon(Icons.chevron_right)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (reorderIndex != null)
                    ReorderableDragStartListener(
                      index: reorderIndex!,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Editar carpeta',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Eliminar carpeta',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CircleFoldersPage extends ConsumerStatefulWidget {
  const _CircleFoldersPage({
    required this.folders,
    required this.countsByFolder,
  });

  final List<ResourceFolderModel> folders;
  final Map<String, int> countsByFolder;

  @override
  ConsumerState<_CircleFoldersPage> createState() => _CircleFoldersPageState();
}

class _CircleFoldersPageState extends ConsumerState<_CircleFoldersPage> {
  late Map<String, int> _countsByFolder;

  @override
  void initState() {
    super.initState();
    _countsByFolder = Map<String, int>.from(widget.countsByFolder);
  }

  void _reloadCounts() {
    final repo = ref.read(repositoryProvider);
    final items = repo.getMandalaResources();
    final counts = <String, int>{};
    for (final item in items) {
      final key = item.folderId.trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (!mounted) return;
    setState(() {
      _countsByFolder = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_resourcesCirculosRootName),
        actions: [
          IconButton(
            tooltip: 'Ordenar círculos',
            onPressed: _openCircleOrderDialog,
            icon: const Icon(Icons.swap_vert_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          for (final folder in widget.folders)
            _FolderTile(
              folder: folder.copyWith(
                name:
                    'Círculo ${_romanByCircle[folder.circle] ?? folder.circle}',
              ),
              resourceCount: _countsByFolder[folder.id] ?? 0,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResourceFolderPage(folder: folder),
                  ),
                );
                _reloadCounts();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openCircleOrderDialog() async {
    if (widget.folders.length < 2) return;
    final ordered = await _showReorderDialog(
      context: context,
      title: 'Ordenar círculos',
      items: widget.folders,
      idOf: (folder) => folder.id,
      labelOf: (folder) =>
          'Círculo ${_romanByCircle[folder.circle] ?? folder.circle}',
    );
    if (ordered == null) return;
    final repo = ref.read(repositoryProvider);
    final current = repo
        .getResourceFolders()
        .map((folder) => folder.id)
        .toList();
    final subset = ordered.toSet();
    var pointer = 0;
    final merged = <String>[];
    for (final id in current) {
      if (subset.contains(id)) {
        merged.add(ordered[pointer]);
        pointer += 1;
      } else {
        merged.add(id);
      }
    }
    await repo.saveResourceFoldersOrderIds(merged);
    _reloadCounts();
  }
}

Future<List<String>?> _showReorderDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T item) idOf,
  required String Function(T item) labelOf,
}) async {
  final working = List<T>.from(items);
  return showModalBottomSheet<List<String>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    working.map(idOf).toList(growable: false),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: working.length,
                onReorder: (oldIndex, newIndex) {
                  setModalState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final moved = working.removeAt(oldIndex);
                    working.insert(newIndex, moved);
                  });
                },
                itemBuilder: (ctx, index) {
                  final item = working[index];
                  return ListTile(
                    key: ValueKey(idOf(item)),
                    title: Text(labelOf(item)),
                    leading: const Icon(Icons.drag_handle),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.unfold_more),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ResourceFolderPage extends ConsumerStatefulWidget {
  const ResourceFolderPage({required this.folder, super.key});

  final ResourceFolderModel folder;

  @override
  ConsumerState<ResourceFolderPage> createState() => _ResourceFolderPageState();
}

class _ResourceFolderPageState extends ConsumerState<ResourceFolderPage> {
  List<MandalaResourceModel> _items = <MandalaResourceModel>[];
  List<ResourceFolderModel> _childFolders = <ResourceFolderModel>[];
  Map<String, int> _countsByFolder = <String, int>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(repositoryProvider);
    final allItems = repo.getMandalaResources();
    final counts = <String, int>{};
    for (final item in allItems) {
      final key = item.folderId.trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    setState(() {
      _items = repo.getMandalaResourcesForFolderOrdered(widget.folder.id);
      _childFolders = repo.getChildResourceFolders(widget.folder.id);
      _countsByFolder = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.folder.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) - 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${widget.folder.name}'
              ' · ${_circleLabel(widget.folder.circle)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: (theme.textTheme.bodySmall?.fontSize ?? 14) - 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ordenar recursos',
            onPressed: _openItemsOrderDialog,
            icon: const Icon(Icons.swap_vert_outlined),
          ),
        ],
      ),
      body: (_items.isEmpty && _childFolders.isEmpty)
          ? Center(
              child: Text(
                'Esta carpeta está vacía.\nToca + para agregar recursos.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                for (final folder in _childFolders)
                  _FolderTile(
                    key: ValueKey(folder.id),
                    folder: folder,
                    resourceCount: _countsByFolder[folder.id] ?? 0,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ResourceFolderPage(folder: folder),
                        ),
                      );
                      _reload();
                    },
                    onEdit: () => _openSubfolderDialog(existing: folder),
                    onDelete: () => _deleteSubfolder(folder),
                  ),
                if (_items.isNotEmpty)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _items.length,
                    onReorder: _onReorderItems,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        key: ValueKey(item.id),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        child: ListTile(
                          onTap: () => _handleItemTap(item),
                          leading: Icon(
                            _iconForResource(item),
                            color: cs.primary,
                          ),
                          title: Text(item.title),
                          subtitle: Text(_labelForResource(item)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteItem(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openSubfolderDialog({ResourceFolderModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nueva carpeta' : 'Editar carpeta'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre'),
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
    );
    if (save != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    if (existing == null) {
      await repo.createResourceFolder(
        name: name,
        circle: widget.folder.circle,
        parentId: widget.folder.id,
      );
    } else {
      await repo.saveResourceFolder(existing.copyWith(name: name));
    }
    _reload();
  }

  Future<void> _deleteSubfolder(ResourceFolderModel folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar carpeta'),
        content: const Text(
          'Se eliminará esta carpeta, sus subcarpetas y todos sus recursos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(repositoryProvider);
    final allFolders = repo.getResourceFolders();
    final descendantIds = <String>{};
    final queue = <String>[folder.id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final candidate in allFolders) {
        if (candidate.parentId != current) continue;
        if (descendantIds.add(candidate.id)) {
          queue.add(candidate.id);
        }
      }
    }
    final folderIds = <String>{folder.id, ...descendantIds};
    final resources = repo
        .getMandalaResources()
        .where((resource) => folderIds.contains(resource.folderId))
        .toList(growable: false);
    for (final item in resources) {
      final path = item.filePath;
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await repo.deleteResourceFolder(folder.id);
    _reload();
  }

  Future<void> _onReorderItems(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
    });
    final repo = ref.read(repositoryProvider);
    await repo.saveResourceItemsOrderForFolder(
      widget.folder.id,
      _items.map((item) => item.id).toList(growable: false),
    );
    _reload();
  }

  IconData _iconForType(MandalaResourceType type) {
    switch (type) {
      case MandalaResourceType.audio:
        return Icons.audiotrack_outlined;
      case MandalaResourceType.image:
        return Icons.image_outlined;
      case MandalaResourceType.pdf:
        return Icons.picture_as_pdf_outlined;
      case MandalaResourceType.text:
        return Icons.notes_outlined;
      case MandalaResourceType.other:
        return Icons.attach_file_outlined;
    }
  }

  IconData _iconForResource(MandalaResourceModel item) {
    if (_isLinkResource(item)) return Icons.link_outlined;
    return _iconForType(item.type);
  }

  String _labelForType(MandalaResourceType type) {
    switch (type) {
      case MandalaResourceType.audio:
        return 'Audio';
      case MandalaResourceType.image:
        return 'Imagen';
      case MandalaResourceType.pdf:
        return 'PDF';
      case MandalaResourceType.text:
        return 'Texto';
      case MandalaResourceType.other:
        return 'Archivo';
    }
  }

  String _labelForResource(MandalaResourceModel item) {
    if (_isLinkResource(item)) return 'Link';
    return _labelForType(item.type);
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

  Future<void> _openLinkResource(MandalaResourceModel item) async {
    final raw = (item.inlineText ?? '').trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(_normalizeUrl(raw));
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link inválido')));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el link')));
  }

  Future<void> _openItemsOrderDialog() async {
    if (_items.length < 2) return;
    final ordered = await _showReorderDialog(
      context: context,
      title: 'Ordenar recursos',
      items: _items,
      idOf: (item) => item.id,
      labelOf: (item) => item.title,
    );
    if (ordered == null) return;
    final repo = ref.read(repositoryProvider);
    await repo.saveResourceItemsOrderForFolder(widget.folder.id, ordered);
    _reload();
  }

  void _openResource(MandalaResourceModel item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResourceViewerPage(resource: item)),
    );
  }

  Future<void> _handleItemTap(MandalaResourceModel item) async {
    if (_isLinkResource(item)) {
      await _openLinkResource(item);
      return;
    }
    _openResource(item);
  }

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Agregar carpeta'),
              onTap: () => Navigator.pop(ctx, 'folder'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Agregar texto'),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Agregar archivo'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.link_outlined),
              title: const Text('Agregar link'),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'folder') {
      await _openSubfolderDialog();
    } else if (choice == 'text') {
      await _addTextResource();
    } else if (choice == 'link') {
      await _addLinkResource();
    } else {
      await _addFileResource();
    }
  }

  Future<void> _addLinkResource() async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
            ),
          ],
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
    );
    if (result != true) return;

    final rawUrl = urlCtrl.text.trim();
    if (rawUrl.isEmpty) return;
    final normalized = _normalizeUrl(rawUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link inválido')));
      return;
    }

    final title = titleCtrl.text.trim();
    final repo = ref.read(repositoryProvider);
    await repo.saveMandalaResource(
      MandalaResourceModel.create(
        cycleId: widget.folder.id,
        folderId: widget.folder.id,
        title: title.isEmpty ? normalized : title,
        type: MandalaResourceType.other,
        inlineText: normalized,
      ),
    );
    _reload();
  }

  Future<void> _addTextResource() async {
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo texto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Contenido'),
              ),
            ],
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
    );
    if (result != true) return;

    final title = titleCtrl.text.trim();
    final content = textCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    await repo.saveMandalaResource(
      MandalaResourceModel.create(
        cycleId: widget.folder.id,
        folderId: widget.folder.id,
        title: title,
        type: MandalaResourceType.text,
        inlineText: content,
      ),
    );
    _reload();
  }

  Future<void> _addFileResource() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'flac',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'pdf',
        'txt',
      ],
    );
    if (picked == null || picked.files.isEmpty) return;

    final sourcePath = picked.files.first.path;
    if (sourcePath == null || sourcePath.isEmpty) return;

    final source = File(sourcePath);
    if (!await source.exists()) return;

    final docs = await getApplicationDocumentsDirectory();
    final resourcesDir = Directory(
      p.join(docs.path, 'resources', 'folders', widget.folder.id),
    );
    if (!await resourcesDir.exists()) {
      await resourcesDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).toLowerCase();
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final destPath = p.join(resourcesDir.path, filename);
    await source.copy(destPath);

    final type = _detectType(ext);
    final title = p.basenameWithoutExtension(sourcePath).trim();

    final repo = ref.read(repositoryProvider);
    await repo.saveMandalaResource(
      MandalaResourceModel.create(
        cycleId: widget.folder.id,
        folderId: widget.folder.id,
        title: title.isEmpty ? 'Recurso' : title,
        type: type,
        filePath: destPath,
      ),
    );
    _reload();
  }

  MandalaResourceType _detectType(String ext) {
    if (['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'].contains(ext)) {
      return MandalaResourceType.audio;
    }
    if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext)) {
      return MandalaResourceType.image;
    }
    if (ext == '.pdf') return MandalaResourceType.pdf;
    if (ext == '.txt') return MandalaResourceType.text;
    return MandalaResourceType.other;
  }

  Future<void> _deleteItem(MandalaResourceModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar recurso'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final repo = ref.read(repositoryProvider);
    await repo.deleteMandalaResource(item.id);

    final path = item.filePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _reload();
  }
}
