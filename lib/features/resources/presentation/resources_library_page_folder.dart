part of 'resources_library_page.dart';

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
  bool _thumbView = false;
  final TextEditingController _nameSearchController = TextEditingController();
  String _nameSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    super.dispose();
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
    final query = _nameSearchQuery.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? _items
        : _items
              .where((item) => item.title.toLowerCase().contains(query))
              .toList(growable: false);
    final filteredChildFolders = query.isEmpty
        ? _childFolders
        : _childFolders
              .where((folder) => folder.name.toLowerCase().contains(query))
              .toList(growable: false);

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
            tooltip: 'Buscar archivos',
            onPressed: _openFilesSearch,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: _thumbView ? 'Ver como lista' : 'Ver miniaturas',
            onPressed: () => setState(() => _thumbView = !_thumbView),
            icon: Icon(
              _thumbView ? Icons.view_list_outlined : Icons.grid_view_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Ordenar recursos',
            onPressed: _openItemsOrderDialog,
            icon: const Icon(Icons.swap_vert_outlined),
          ),
        ],
      ),
      body: (filteredItems.isEmpty && filteredChildFolders.isEmpty)
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
                TextField(
                  controller: _nameSearchController,
                  onChanged: (value) =>
                      setState(() => _nameSearchQuery = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _nameSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            onPressed: () {
                              _nameSearchController.clear();
                              setState(() => _nameSearchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final folder in filteredChildFolders)
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
                if (filteredItems.isNotEmpty && query.isEmpty)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: filteredItems.length,
                    onReorder: _onReorderItems,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _thumbView
                          ? _buildThumbnailItemCard(
                              context: context,
                              item: item,
                              index: index,
                            )
                          : _buildListItemCard(
                              context: context,
                              item: item,
                              index: index,
                            );
                    },
                  ),
                if (filteredItems.isNotEmpty && query.isNotEmpty)
                  for (final item in filteredItems)
                    (_thumbView
                        ? _buildThumbnailItemCardReadOnly(
                            context: context,
                            item: item,
                          )
                        : _buildListItemCardReadOnly(
                            context: context,
                            item: item,
                          )),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openFilesSearch() async {
    if (_items.isEmpty) return;
    final selected = await showModalBottomSheet<MandalaResourceModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _items
                .where((item) => item.title.toLowerCase().contains(query))
                .toList(growable: false);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (value) =>
                        setModalState(() => query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Buscar archivo por nombre',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Sin resultados'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return ListTile(
                                onTap: () => Navigator.pop(ctx, item),
                                leading: Icon(_iconForResource(item)),
                                title: Text(item.title),
                                subtitle: Text(_labelForResource(item)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected == null || !mounted) return;
    await _handleItemTap(selected);
  }

  Widget _buildListItemCard({
    required BuildContext context,
    required MandalaResourceModel item,
    required int index,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(item.id),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: ListTile(
        onTap: () => _handleItemTap(item),
        leading: Icon(_iconForResource(item), color: cs.primary),
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
              tooltip: 'Renombrar',
              onPressed: () => _renameItem(item),
              icon: const Icon(Icons.edit_outlined),
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
  }

  Widget _buildThumbnailItemCard({
    required BuildContext context,
    required MandalaResourceModel item,
    required int index,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      key: ValueKey(item.id),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleItemTap(item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 76,
                  height: 76,
                  color: cs.surfaceContainerHighest,
                  child: _resourcePreview(item),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labelForResource(item),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle),
                ),
              ),
              IconButton(
                tooltip: 'Renombrar',
                onPressed: () => _renameItem(item),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => _deleteItem(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItemCardReadOnly({
    required BuildContext context,
    required MandalaResourceModel item,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('search_${item.id}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: ListTile(
        onTap: () => _handleItemTap(item),
        leading: Icon(_iconForResource(item), color: cs.primary),
        title: Text(item.title),
        subtitle: Text(_labelForResource(item)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Renombrar',
              onPressed: () => _renameItem(item),
              icon: const Icon(Icons.edit_outlined),
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
  }

  Widget _buildThumbnailItemCardReadOnly({
    required BuildContext context,
    required MandalaResourceModel item,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      key: ValueKey('search_thumb_${item.id}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleItemTap(item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 76,
                  height: 76,
                  color: cs.surfaceContainerHighest,
                  child: _resourcePreview(item),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labelForResource(item),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Renombrar',
                onPressed: () => _renameItem(item),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => _deleteItem(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resourcePreview(MandalaResourceModel item) {
    if (item.type != MandalaResourceType.image) {
      return Icon(_iconForResource(item), size: 30);
    }
    final path = (item.filePath ?? '').trim();
    if (path.isEmpty) {
      return const Icon(Icons.image_not_supported_outlined, size: 30);
    }
    if (_isWebUrl(path)) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image_outlined, size: 30),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.broken_image_outlined, size: 30),
    );
  }

  bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
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
    final filePaths = repo
        .getMandalaResources()
        .where((resource) => folderIds.contains(resource.folderId))
        .map((resource) => (resource.filePath ?? '').trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    await repo.deleteResourceFolder(folder.id);
    await _deleteLocalFilesBestEffort(filePaths);
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
      await _deleteLocalFilesBestEffort([path]);
    }

    _reload();
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

  Future<void> _renameItem(MandalaResourceModel item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar recurso'),
        content: TextField(
          controller: titleCtrl,
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
    if (ok != true) return;
    final name = titleCtrl.text.trim();
    if (name.isEmpty || name == item.title) return;
    final repo = ref.read(repositoryProvider);
    await repo.saveMandalaResource(item.copyWith(title: name));
    _reload();
  }
}
