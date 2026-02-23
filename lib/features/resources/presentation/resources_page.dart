import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
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
                    side: BorderSide(color: cs.outlineVariant),
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
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteItem(item),
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

class ResourceViewerPage extends StatefulWidget {
  const ResourceViewerPage({required this.resource, super.key});

  final MandalaResourceModel resource;

  @override
  State<ResourceViewerPage> createState() => _ResourceViewerPageState();
}

class _ResourceViewerPageState extends State<ResourceViewerPage> {
  String? _textContent;
  String? _error;
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
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

      if (widget.resource.type == MandalaResourceType.audio) {
        final path = widget.resource.filePath;
        if (path == null) {
          _error = 'No se encontró el audio.';
          setState(() {});
          return;
        }
        _player = AudioPlayer();
        await _player!.setFilePath(path);
        setState(() {});
      }
    } catch (e) {
      _error = e.toString();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    return Scaffold(
      appBar: AppBar(title: Text(r.title)),
      body: Padding(padding: const EdgeInsets.all(16), child: _buildContent(r)),
    );
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
        final path = r.filePath;
        if (path == null) {
          return const Center(child: Text('Imagen no disponible'));
        }
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(child: Image.file(File(path))),
        );
      case MandalaResourceType.pdf:
        final path = r.filePath;
        if (path == null) return const Center(child: Text('PDF no disponible'));
        return SfPdfViewer.file(File(path));
      case MandalaResourceType.audio:
        return _AudioPlayerView(player: _player);
      case MandalaResourceType.other:
        final path = r.filePath;
        return Center(
          child: Text(
            path == null ? 'Archivo no disponible' : 'Archivo: $path',
          ),
        );
    }
  }
}

class _AudioPlayerView extends StatelessWidget {
  const _AudioPlayerView({required this.player});

  final AudioPlayer? player;

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<PlayerState>(
          stream: player!.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            return IconButton.filled(
              iconSize: 42,
              onPressed: () async {
                if (playing) {
                  await player!.pause();
                } else {
                  await player!.play();
                }
              },
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            );
          },
        ),
        const SizedBox(height: 14),
        StreamBuilder<Duration>(
          stream: player!.positionStream,
          builder: (context, posSnapshot) {
            final pos = posSnapshot.data ?? Duration.zero;
            final total = player!.duration ?? Duration.zero;
            final maxMs = total.inMilliseconds.toDouble();
            final value = pos.inMilliseconds
                .toDouble()
                .clamp(0, maxMs == 0 ? 1 : maxMs)
                .toDouble();
            return Column(
              children: [
                Slider(
                  value: value,
                  min: 0,
                  max: maxMs == 0 ? 1 : maxMs,
                  onChanged: (v) =>
                      player!.seek(Duration(milliseconds: v.round())),
                ),
                Text('${_fmt(pos)} / ${_fmt(total)}'),
              ],
            );
          },
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
