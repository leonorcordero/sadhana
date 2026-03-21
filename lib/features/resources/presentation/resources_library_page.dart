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

part 'resources_library_page_components.dart';
part 'resources_library_page_folder.dart';

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
const _resourcesCirculosRootId = 'recursos-circulos-root';
const _resourcesCirculosRootName = 'Recursos círculos';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<MandalaResourceType> _quickFilters = <MandalaResourceType>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final repo = ref.read(repositoryProvider);

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

  void _toggleQuickFilter(MandalaResourceType type) {
    setState(() {
      if (_quickFilters.contains(type)) {
        _quickFilters.remove(type);
      } else {
        _quickFilters.add(type);
      }
    });
  }

  bool _matchesResourceSearch({
    required MandalaResourceModel item,
    required String query,
    required Map<String, ResourceFolderModel> folderById,
  }) {
    if (_quickFilters.isNotEmpty && !_quickFilters.contains(item.type)) {
      return false;
    }
    if (query.isEmpty) return true;
    final title = item.title.toLowerCase();
    final folder = (folderById[item.folderId]?.name ?? '').toLowerCase();
    final type = _labelForType(item.type).toLowerCase();
    return title.contains(query) ||
        folder.contains(query) ||
        type.contains(query);
  }

  Future<void> _openResourceFromSearch(MandalaResourceModel item) async {
    if (_isLinkResource(item)) {
      await _openLinkResource(item);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResourceViewerPage(resource: item)),
    );
  }

  String _labelForType(MandalaResourceType type) {
    switch (type) {
      case MandalaResourceType.audio:
        return 'Audio';
      case MandalaResourceType.image:
        return 'Imagen';
      case MandalaResourceType.text:
        return 'Texto';
      case MandalaResourceType.pdf:
        return 'PDF';
      case MandalaResourceType.other:
        return 'Archivo';
    }
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
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final folderById = <String, ResourceFolderModel>{
      for (final folder in _folders) folder.id: folder,
    };
    final query = _searchQuery.trim().toLowerCase();
    final allResources = repo.getMandalaResources();
    final matchedResources = allResources
        .where(
          (item) => _matchesResourceSearch(
            item: item,
            query: query,
            folderById: folderById,
          ),
        )
        .toList(growable: false);
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
                TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar por título, tipo o carpeta',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Audio'),
                      selected: _quickFilters.contains(
                        MandalaResourceType.audio,
                      ),
                      onSelected: (_) =>
                          _toggleQuickFilter(MandalaResourceType.audio),
                    ),
                    FilterChip(
                      label: const Text('Imagen'),
                      selected: _quickFilters.contains(
                        MandalaResourceType.image,
                      ),
                      onSelected: (_) =>
                          _toggleQuickFilter(MandalaResourceType.image),
                    ),
                    FilterChip(
                      label: const Text('Texto'),
                      selected: _quickFilters.contains(
                        MandalaResourceType.text,
                      ),
                      onSelected: (_) =>
                          _toggleQuickFilter(MandalaResourceType.text),
                    ),
                  ],
                ),
                if (query.isNotEmpty || _quickFilters.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Resultados (${matchedResources.length})',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (matchedResources.isEmpty)
                    Text(
                      'No se encontraron recursos con esos filtros.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final item in matchedResources.take(60))
                      Card(
                        child: ListTile(
                          leading: Icon(_iconForType(item.type)),
                          title: Text(item.title),
                          subtitle: Text(
                            '${_labelForType(item.type)} · ${folderById[item.folderId]?.name ?? 'Sin carpeta'}',
                          ),
                          onTap: () => _openResourceFromSearch(item),
                        ),
                      ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                ],
                if (query.isEmpty && _quickFilters.isEmpty)
                  const SizedBox(height: 12),
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
                    side: BorderSide.none,
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
    final filePaths = repo
        .getMandalaResources()
        .where((resource) => folderIds.contains(resource.folderId))
        .map((resource) => (resource.filePath ?? '').trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    await repo.deleteResourceFolder(folder.id);
    await _deleteLocalFilesBestEffort(filePaths);
    await _reload();
  }

  Future<void> _deleteLocalFilesBestEffort(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // No bloquea la eliminación lógica del recurso.
      }
    }
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
