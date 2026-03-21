part of 'resources_library_page.dart';

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
        side: BorderSide.none,
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
