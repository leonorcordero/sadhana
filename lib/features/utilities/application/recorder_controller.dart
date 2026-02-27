import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecorderController {
  RecorderController();

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<RecorderState> _stateController =
      StreamController<RecorderState>.broadcast();

  bool _isRecording = false;
  String? _recordingPath;
  String? _error;

  Stream<RecorderState> get stateStream => _stateController.stream;

  RecorderState get currentState => RecorderState(
    isRecording: _isRecording,
    recordingPath: _recordingPath,
    error: _error,
  );

  Future<Directory> recordingsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'utilities', 'recordings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _isRecording = false;
      _recordingPath = path;
      _stateController.add(currentState);
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _error = 'No hay permiso de micrófono.';
      _stateController.add(currentState);
      return;
    }

    final dir = await recordingsDir();
    final filename =
        'grabacion_${DateTime.now().millisecondsSinceEpoch.toString()}.m4a';
    final outputPath = p.join(dir.path, filename);
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: outputPath,
    );
    _error = null;
    _isRecording = true;
    _recordingPath = outputPath;
    _stateController.add(currentState);
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    await _stateController.close();
  }
}

class RecorderState {
  const RecorderState({
    required this.isRecording,
    required this.recordingPath,
    required this.error,
  });

  final bool isRecording;
  final String? recordingPath;
  final String? error;
}
