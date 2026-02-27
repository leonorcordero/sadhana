import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/features/resources/application/resources_audio_controller.dart';

class AudioPlayerPage extends ConsumerStatefulWidget {
  const AudioPlayerPage({super.key});

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  List<MandalaResourceModel> _items = <MandalaResourceModel>[];
  Map<String, ResourceFolderModel> _folderById =
      <String, ResourceFolderModel>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repo = ref.read(repositoryProvider);
    var folders = repo.getResourceFolders();
    if (folders.isEmpty) {
      await repo.createResourceFolder(name: 'General', circle: 0);
      folders = repo.getResourceFolders();
    }

    final audios =
        repo
            .getMandalaResources()
            .where(
              (r) =>
                  r.type == MandalaResourceType.audio &&
                  (r.filePath?.trim().isNotEmpty ?? false),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _items = audios;
      _folderById = {for (final f in folders) f.id: f};
    });
  }

  String _resourceIdFor(MandalaResourceModel item) => item.id;

  Future<String?> _pickTargetFolderId() async {
    final repo = ref.read(repositoryProvider);
    var folders = repo.getResourceFolders();
    if (folders.isEmpty) {
      await repo.createResourceFolder(name: 'General', circle: 0);
      folders = repo.getResourceFolders();
    }
    if (!mounted) return null;

    String selected = folders.first.id;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Guardar audio en'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Carpeta'),
            items: folders
                .map(
                  (f) => DropdownMenuItem<String>(
                    value: f.id,
                    child: Text(_folderLabel(f)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              setModalState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Guardar aquí'),
            ),
          ],
        ),
      ),
    );
  }

  String _folderLabel(ResourceFolderModel folder) {
    if (folder.circle <= 0) return '${folder.name} · General';
    return '${folder.name} · Círculo ${_toRoman(folder.circle)}';
  }

  Future<void> _pickAudio() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final sourcePath = picked.files.first.path;
    if (sourcePath == null || sourcePath.isEmpty) return;

    final source = File(sourcePath);
    if (!await source.exists()) return;

    final folderId = await _pickTargetFolderId();
    if (folderId == null || folderId.isEmpty) return;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'resources', 'folders', folderId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final destPath = p.join(dir.path, filename);
    await source.copy(destPath);

    final title = p.basenameWithoutExtension(sourcePath).trim();
    final repo = ref.read(repositoryProvider);
    await repo.saveMandalaResource(
      MandalaResourceModel.create(
        cycleId: folderId,
        folderId: folderId,
        title: title.isEmpty ? 'Audio' : title,
        type: MandalaResourceType.audio,
        filePath: destPath,
      ),
    );

    await _reload();
  }

  Future<void> _togglePlay(MandalaResourceModel item) async {
    final path = item.filePath;
    if (path == null || path.isEmpty) return;
    final controller = ref.read(resourcesAudioControllerProvider);
    final state = controller.currentState;
    final resourceId = _resourceIdFor(item);
    if (state.activeResourceId != resourceId) {
      await controller.ensureLoaded(
        resourceId: resourceId,
        title: item.title,
        filePath: path,
      );
    }
    await controller.togglePlayPause();
  }

  Future<void> _seekRelative(int seconds) async {
    final controller = ref.read(resourcesAudioControllerProvider);
    await controller.seekRelative(Duration(seconds: seconds));
  }

  Future<void> _deleteAudio(MandalaResourceModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar audio guardado'),
        content: const Text('Este audio se eliminará de su carpeta.'),
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

    final controller = ref.read(resourcesAudioControllerProvider);
    final resourceId = _resourceIdFor(item);
    if (controller.currentState.activeResourceId == resourceId) {
      await controller.stopAndClear();
    }

    final repo = ref.read(repositoryProvider);
    await repo.deleteMandalaResource(item.id);
    final path = item.filePath;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = ref.read(resourcesAudioControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reproductor de audio'),
            Text(
              'Audios guardados por círculo o general',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: controller.stateStream,
        initialData: controller.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? controller.currentState;
          final total = state.duration ?? Duration.zero;
          final pos = state.position;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.activeTitle ?? 'Sin audio reproduciéndose',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: state.activeResourceId == null
                                ? null
                                : () => _seekRelative(-10),
                            icon: const Icon(Icons.replay_10),
                          ),
                          IconButton.filled(
                            onPressed: state.activeResourceId == null
                                ? null
                                : controller.togglePlayPause,
                            icon: Icon(
                              state.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                          IconButton(
                            onPressed: state.activeResourceId == null
                                ? null
                                : () => _seekRelative(10),
                            icon: const Icon(Icons.forward_10),
                          ),
                        ],
                      ),
                      Slider(
                        value: pos.inMilliseconds
                            .toDouble()
                            .clamp(
                              0,
                              total.inMilliseconds == 0
                                  ? 1
                                  : total.inMilliseconds.toDouble(),
                            )
                            .toDouble(),
                        min: 0,
                        max: total.inMilliseconds == 0
                            ? 1
                            : total.inMilliseconds.toDouble(),
                        onChanged: state.activeResourceId == null
                            ? null
                            : (v) => controller.seek(
                                Duration(milliseconds: v.round()),
                              ),
                      ),
                      Center(child: Text('${_fmt(pos)} / ${_fmt(total)}')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: state.activeResourceId == null
                                ? null
                                : controller.restart,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('Reiniciar'),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              _RepeatModeChip(
                                selected:
                                    state.repeatMode ==
                                    ResourcesAudioRepeatMode.none,
                                icon: Icons.repeat,
                                tooltip: 'Sin repetir',
                                onTap: () => controller.setRepeatMode(
                                  ResourcesAudioRepeatMode.none,
                                ),
                              ),
                              _RepeatModeChip(
                                selected:
                                    state.repeatMode ==
                                    ResourcesAudioRepeatMode.once,
                                icon: Icons.repeat_one,
                                tooltip: 'Repetir una vez',
                                onTap: () => controller.setRepeatMode(
                                  ResourcesAudioRepeatMode.once,
                                ),
                              ),
                              _RepeatModeChip(
                                selected:
                                    state.repeatMode ==
                                    ResourcesAudioRepeatMode.infinite,
                                icon: Icons.loop,
                                tooltip: 'Repetir infinito',
                                onTap: () => controller.setRepeatMode(
                                  ResourcesAudioRepeatMode.infinite,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                Text(
                  'No hay audios guardados.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                for (final item in _items)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.audiotrack_outlined,
                        color: cs.primary,
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                        _folderById[item.folderId] == null
                            ? 'Carpeta no encontrada'
                            : _folderLabel(_folderById[item.folderId]!),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Reproducir/Pausar',
                            icon: Icon(
                              state.activeResourceId == _resourceIdFor(item) &&
                                      state.isPlaying
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                            ),
                            onPressed: () => _togglePlay(item),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: Icon(Icons.delete_outline, color: cs.error),
                            onPressed: () => _deleteAudio(item),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAudio,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Agregar audio guardado'),
      ),
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
    required this.tooltip,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withValues(alpha: 0.14) : cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? cs.primary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

String _toRoman(int value) {
  switch (value) {
    case 1:
      return 'I';
    case 2:
      return 'II';
    case 3:
      return 'III';
    case 4:
      return 'IV';
    case 5:
      return 'V';
    case 6:
      return 'VI';
    case 7:
      return 'VII';
    default:
      return value.toString();
  }
}
