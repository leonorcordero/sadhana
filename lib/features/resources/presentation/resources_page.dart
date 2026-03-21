import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/features/resources/application/resources_audio_controller.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ResourcesPage extends ConsumerStatefulWidget {
  const ResourcesPage({
    required this.cycleId,
    required this.cycleName,
    super.key,
  });

  final String cycleId;
  final String cycleName;

  @override
  ConsumerState<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends ConsumerState<ResourcesPage> {
  List<MandalaResourceModel> _items = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(repositoryProvider);
    setState(() {
      _items = repo.getMandalaResources(cycleId: widget.cycleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Recursos'),
            Text(
              widget.cycleName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: _items.isEmpty
          ? Center(
              child: Text(
                'Sin recursos. Agrega audio, texto, imagen o PDF.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = _items[i];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide.none,
                  ),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResourceViewerPage(resource: item),
                      ),
                    ),
                    leading: Icon(_iconForType(item.type)),
                    title: Text(item.title),
                    subtitle: Text(_typeLabel(item.type)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Renombrar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _renameItem(item),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteItem(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _iconForType(MandalaResourceType type) {
    switch (type) {
      case MandalaResourceType.audio:
        return Icons.audiotrack_outlined;
      case MandalaResourceType.text:
        return Icons.notes_outlined;
      case MandalaResourceType.image:
        return Icons.image_outlined;
      case MandalaResourceType.pdf:
        return Icons.picture_as_pdf_outlined;
      case MandalaResourceType.other:
        return Icons.attach_file_outlined;
    }
  }

  String _typeLabel(MandalaResourceType type) {
    switch (type) {
      case MandalaResourceType.audio:
        return 'Audio';
      case MandalaResourceType.text:
        return 'Texto';
      case MandalaResourceType.image:
        return 'Imagen';
      case MandalaResourceType.pdf:
        return 'PDF';
      case MandalaResourceType.other:
        return 'Archivo';
    }
  }

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Agregar texto escrito'),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Agregar archivo (audio/imagen/pdf)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'text') {
      await _addTextResource();
    } else {
      await _addFileResource();
    }
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
        cycleId: widget.cycleId,
        folderId: widget.cycleId,
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
      p.join(docs.path, 'resources', widget.cycleId),
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
        cycleId: widget.cycleId,
        folderId: widget.cycleId,
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

class ResourceViewerPage extends ConsumerStatefulWidget {
  const ResourceViewerPage({required this.resource, super.key});

  final MandalaResourceModel resource;

  @override
  ConsumerState<ResourceViewerPage> createState() => _ResourceViewerPageState();
}

class _ResourceViewerPageState extends ConsumerState<ResourceViewerPage> {
  String? _textContent;
  String? _error;
  List<MandalaResourceModel> _imageGallery = const <MandalaResourceModel>[];
  int _currentImageIndex = 0;
  PageController? _imagePageController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.resource.type == MandalaResourceType.image) {
        final repo = ref.read(repositoryProvider);
        final imageItems = repo
            .getMandalaResourcesForFolderOrdered(widget.resource.folderId)
            .where((item) => item.type == MandalaResourceType.image)
            .toList(growable: false);
        final index = imageItems.indexWhere((r) => r.id == widget.resource.id);
        _imageGallery = imageItems;
        _currentImageIndex = index >= 0 ? index : 0;
        _imagePageController = PageController(initialPage: _currentImageIndex);
        setState(() {});
        return;
      }
      if (widget.resource.type == MandalaResourceType.text) {
        if ((widget.resource.inlineText ?? '').trim().isNotEmpty) {
          _textContent = widget.resource.inlineText!.trim();
          setState(() {});
          return;
        }
        final path = widget.resource.filePath;
        if (path == null) {
          _error = 'No se encontró el texto.';
          setState(() {});
          return;
        }
        _textContent = await File(path).readAsString();
        setState(() {});
        return;
      }
    } catch (e) {
      _error = e.toString();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _imagePageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    final title = _currentImageTitle(r);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(padding: const EdgeInsets.all(16), child: _buildContent(r)),
    );
  }

  String _currentImageTitle(MandalaResourceModel fallback) {
    if (_imageGallery.isEmpty) return fallback.title;
    if (_currentImageIndex < 0 || _currentImageIndex >= _imageGallery.length) {
      return fallback.title;
    }
    return _imageGallery[_currentImageIndex].title;
  }

  Widget _buildContent(MandalaResourceModel r) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    switch (r.type) {
      case MandalaResourceType.text:
        if (_textContent == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(child: SelectableText(_textContent!));
      case MandalaResourceType.image:
        if (_imageGallery.isNotEmpty && _imagePageController != null) {
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _imagePageController,
                  itemCount: _imageGallery.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _imageGallery[index];
                    final path = item.filePath;
                    if (path == null || path.isEmpty) {
                      return const Center(child: Text('Imagen no disponible'));
                    }
                    return InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(child: _buildImageByPath(path)),
                    );
                  },
                ),
              ),
              if (_imageGallery.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _currentImageIndex <= 0
                          ? null
                          : () => _goToImage(_currentImageIndex - 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${_currentImageIndex + 1}/${_imageGallery.length}'),
                    IconButton(
                      onPressed: _currentImageIndex >= _imageGallery.length - 1
                          ? null
                          : () => _goToImage(_currentImageIndex + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 74,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageGallery.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = _imageGallery[index];
                      final path = item.filePath;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _goToImage(index),
                        child: Container(
                          width: 74,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.transparent),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: path == null || path.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                )
                              : _buildThumbnailByPath(path),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        }
        final path = r.filePath;
        if (path == null || path.isEmpty) {
          return const Center(child: Text('Imagen no disponible'));
        }
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(child: _buildImageByPath(path)),
        );
      case MandalaResourceType.pdf:
        final path = r.filePath;
        if (path == null) return const Center(child: Text('PDF no disponible'));
        return SfPdfViewer.file(File(path));
      case MandalaResourceType.audio:
        return _SharedAudioPlayerView(resource: r);
      case MandalaResourceType.other:
        final path = r.filePath;
        return Center(
          child: Text(
            path == null ? 'Archivo no disponible' : 'Archivo: $path',
          ),
        );
    }
  }

  void _goToImage(int index) {
    if (_imagePageController == null) return;
    _imagePageController!.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _buildImageByPath(String path) {
    if (_isWebUrl(path)) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            const Center(child: Text('No se pudo cargar la imagen')),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Center(child: Text('No se pudo cargar la imagen')),
    );
  }

  Widget _buildThumbnailByPath(String path) {
    if (_isWebUrl(path)) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined, size: 20)),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 20)),
    );
  }

  bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}

class _SharedAudioPlayerView extends ConsumerStatefulWidget {
  const _SharedAudioPlayerView({required this.resource});

  final MandalaResourceModel resource;

  @override
  ConsumerState<_SharedAudioPlayerView> createState() =>
      _SharedAudioPlayerViewState();
}

class _SharedAudioPlayerViewState
    extends ConsumerState<_SharedAudioPlayerView> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_prepareAudio);
  }

  Future<void> _prepareAudio() async {
    final path = widget.resource.filePath;
    if (path == null || path.isEmpty) {
      setState(() => _error = 'No se encontró el audio.');
      return;
    }
    try {
      final controller = ref.read(resourcesAudioControllerProvider);
      await controller.ensureLoaded(
        resourceId: widget.resource.id,
        title: widget.resource.title,
        filePath: path,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final controller = ref.read(resourcesAudioControllerProvider);
    final ready =
        controller.currentState.activeResourceId == widget.resource.id;
    if (!ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder(
      stream: controller.stateStream,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? controller.currentState;
        final playing =
            state.activeResourceId == widget.resource.id && state.isPlaying;
        final pos = state.activeResourceId == widget.resource.id
            ? state.position
            : Duration.zero;
        final total = state.activeResourceId == widget.resource.id
            ? (state.duration ?? Duration.zero)
            : Duration.zero;
        final maxMs = total.inMilliseconds.toDouble();
        final value = pos.inMilliseconds
            .toDouble()
            .clamp(0, maxMs == 0 ? 1 : maxMs)
            .toDouble();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Retroceder 10s',
                  onPressed: () =>
                      controller.seekRelative(const Duration(seconds: -10)),
                  icon: const Icon(Icons.replay_10),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  iconSize: 42,
                  onPressed: controller.togglePlayPause,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Avanzar 10s',
                  onPressed: () =>
                      controller.seekRelative(const Duration(seconds: 10)),
                  icon: const Icon(Icons.forward_10),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: value,
              min: 0,
              max: maxMs == 0 ? 1 : maxMs,
              onChanged: (v) =>
                  controller.seek(Duration(milliseconds: v.round())),
            ),
            Text('${_fmt(pos)} / ${_fmt(total)}'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: controller.restart,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reiniciar'),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<double>(
                  tooltip: 'Velocidad',
                  onSelected: controller.setSpeed,
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 0.75, child: Text('0.75x')),
                    PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    PopupMenuItem(value: 1.25, child: Text('1.25x')),
                    PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    PopupMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed, size: 18),
                        const SizedBox(width: 6),
                        Text('Velocidad ${state.speed.toStringAsFixed(2)}x'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _RepeatModeChip(
                  selected: state.repeatMode == ResourcesAudioRepeatMode.none,
                  icon: Icons.repeat,
                  label: 'Sin repetir',
                  onTap: () =>
                      controller.setRepeatMode(ResourcesAudioRepeatMode.none),
                ),
                _RepeatModeChip(
                  selected: state.repeatMode == ResourcesAudioRepeatMode.once,
                  icon: Icons.repeat_one,
                  label: 'Repetir 1',
                  onTap: () =>
                      controller.setRepeatMode(ResourcesAudioRepeatMode.once),
                ),
                _RepeatModeChip(
                  selected:
                      state.repeatMode == ResourcesAudioRepeatMode.infinite,
                  icon: Icons.loop,
                  label: 'Infinito',
                  onTap: () => controller.setRepeatMode(
                    ResourcesAudioRepeatMode.infinite,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _RepeatModeChip extends StatelessWidget {
  const _RepeatModeChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.14) : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? cs.primary : cs.onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? cs.primary : cs.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
