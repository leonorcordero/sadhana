import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/utilities/application/recorder_controller.dart';

class AudioRecorderPage extends ConsumerStatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  ConsumerState<AudioRecorderPage> createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends ConsumerState<AudioRecorderPage> {
  final AudioPlayer _player = AudioPlayer();

  List<FileSystemEntity> _recordings = <FileSystemEntity>[];
  RecorderState _recorderState = const RecorderState(
    isRecording: false,
    recordingPath: null,
    error: null,
  );
  String? _activePath;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    final recorder = ref.read(recorderControllerProvider);
    final dir = await recorder.recordingsDir();
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => p.extension(f.path).toLowerCase() == '.m4a')
            .toList(growable: false)
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );
    if (!mounted) return;
    setState(() {
      _recordings = files;
    });
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(recorderControllerProvider);
    await recorder.toggleRecording();
    if (!mounted) return;
    setState(() {
      _recorderState = recorder.currentState;
    });
    await _loadRecordings();
  }

  Future<void> _togglePlayback(String path) async {
    if (_activePath == path && _player.playing) {
      await _player.pause();
      if (!mounted) return;
      setState(() {});
      return;
    }

    if (_activePath != path) {
      await _player.setFilePath(path);
      _activePath = path;
    }
    await _player.play();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteRecording(File file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar audio'),
        content: const Text('Esta grabación se eliminará de Utilitarios.'),
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

    if (_activePath == file.path) {
      await _player.stop();
      _activePath = null;
    }
    await file.delete();
    await _loadRecordings();
  }

  @override
  Widget build(BuildContext context) {
    final recorder = ref.read(recorderControllerProvider);
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<RecorderState>(
      stream: recorder.stateStream,
      initialData: recorder.currentState,
      builder: (context, snapshot) {
        _recorderState = snapshot.data ?? recorder.currentState;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Grabador de audio'),
                Text(
                  'Graba y guarda audios en Utilitarios',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recorderState.isRecording
                            ? 'Grabando...'
                            : 'Pulsa el botón para iniciar una grabación',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _recorderState.isRecording ? cs.error : null,
                        ),
                      ),
                      if (_recorderState.recordingPath != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          p.basename(_recorderState.recordingPath!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                      if (_recorderState.error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _recorderState.error!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: cs.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_recordings.isEmpty)
                Text(
                  'No hay grabaciones todavía.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                for (final entry in _recordings)
                  if (entry is File)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Icon(Icons.mic_outlined, color: cs.primary),
                        title: Text(p.basenameWithoutExtension(entry.path)),
                        subtitle: Text(p.basename(entry.path)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Reproducir/Pausar',
                              icon: Icon(
                                _activePath == entry.path && _player.playing
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                              ),
                              onPressed: () => _togglePlayback(entry.path),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () => _deleteRecording(entry),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _toggleRecording,
            icon: Icon(
              _recorderState.isRecording
                  ? Icons.stop
                  : Icons.fiber_manual_record,
            ),
            label: Text(_recorderState.isRecording ? 'Detener' : 'Grabar'),
          ),
        );
      },
    );
  }
}
