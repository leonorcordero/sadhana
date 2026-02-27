import 'dart:async';

import 'package:just_audio/just_audio.dart';

enum ResourcesAudioRepeatMode { none, once, infinite }

class ResourcesAudioController {
  ResourcesAudioController() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_handlePlaybackCompleted());
      }
      _stateController.add(currentState);
    });
    _positionSub = _player.positionStream.listen((_) {
      _stateController.add(currentState);
    });
    _durationSub = _player.durationStream.listen((_) {
      _stateController.add(currentState);
    });
    _speedSub = _player.speedStream.listen((_) {
      _stateController.add(currentState);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<ResourcesAudioState> _stateController =
      StreamController<ResourcesAudioState>.broadcast();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<double>? _speedSub;

  String? _activeResourceId;
  String? _activeTitle;
  ResourcesAudioRepeatMode _repeatMode = ResourcesAudioRepeatMode.none;
  bool _repeatOncePending = false;
  bool _handlingCompletion = false;

  Stream<ResourcesAudioState> get stateStream => _stateController.stream;

  ResourcesAudioState get currentState => ResourcesAudioState(
    activeResourceId: _activeResourceId,
    activeTitle: _activeTitle,
    isPlaying: _player.playing,
    position: _player.position,
    duration: _player.duration,
    speed: _player.speed,
    repeatMode: _repeatMode,
  );

  Future<void> ensureLoaded({
    required String resourceId,
    required String title,
    required String filePath,
  }) async {
    if (_activeResourceId == resourceId && _player.audioSource != null) {
      return;
    }
    await _player.setFilePath(filePath);
    _activeResourceId = resourceId;
    _activeTitle = title;
    _repeatOncePending = _repeatMode == ResourcesAudioRepeatMode.once;
    _stateController.add(currentState);
  }

  Future<void> togglePlayPause() async {
    if (_player.audioSource == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
      if (_repeatMode == ResourcesAudioRepeatMode.once) {
        _repeatOncePending = true;
      }
    }
    _stateController.add(currentState);
  }

  Future<void> seek(Duration position) async {
    if (_player.audioSource == null) return;
    await _player.seek(position);
    _stateController.add(currentState);
  }

  Future<void> seekRelative(Duration delta) async {
    if (_player.audioSource == null) return;
    final duration = _player.duration ?? Duration.zero;
    final currentMs = _player.position.inMilliseconds;
    final deltaMs = delta.inMilliseconds;
    final totalMs = duration.inMilliseconds;
    var nextMs = currentMs + deltaMs;
    if (nextMs < 0) nextMs = 0;
    if (totalMs > 0 && nextMs > totalMs) nextMs = totalMs;
    await _player.seek(Duration(milliseconds: nextMs));
    _stateController.add(currentState);
  }

  Future<void> restart() async {
    if (_player.audioSource == null) return;
    await _player.seek(Duration.zero);
    if (_repeatMode == ResourcesAudioRepeatMode.once) {
      _repeatOncePending = true;
    }
    _stateController.add(currentState);
  }

  Future<void> setSpeed(double speed) async {
    if (_player.audioSource == null) return;
    await _player.setSpeed(speed);
    _stateController.add(currentState);
  }

  Future<void> setRepeatMode(ResourcesAudioRepeatMode mode) async {
    _repeatMode = mode;
    _repeatOncePending = mode == ResourcesAudioRepeatMode.once;
    _stateController.add(currentState);
  }

  Future<void> stopAndClear() async {
    if (_player.audioSource != null) {
      await _player.stop();
    }
    _activeResourceId = null;
    _activeTitle = null;
    _repeatOncePending = _repeatMode == ResourcesAudioRepeatMode.once;
    _stateController.add(currentState);
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_handlingCompletion) return;
    _handlingCompletion = true;
    try {
      if (_player.audioSource == null) return;
      switch (_repeatMode) {
        case ResourcesAudioRepeatMode.none:
          return;
        case ResourcesAudioRepeatMode.once:
          if (!_repeatOncePending) return;
          _repeatOncePending = false;
          await _player.seek(Duration.zero);
          await _player.play();
          return;
        case ResourcesAudioRepeatMode.infinite:
          await _player.seek(Duration.zero);
          await _player.play();
          return;
      }
    } finally {
      _handlingCompletion = false;
      _stateController.add(currentState);
    }
  }

  Future<void> dispose() async {
    await _playerStateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _speedSub?.cancel();
    await _stateController.close();
    await _player.dispose();
  }
}

class ResourcesAudioState {
  const ResourcesAudioState({
    required this.activeResourceId,
    required this.activeTitle,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
    required this.repeatMode,
  });

  final String? activeResourceId;
  final String? activeTitle;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final double speed;
  final ResourcesAudioRepeatMode repeatMode;
}
