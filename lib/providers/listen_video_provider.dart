import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api/video_api_service.dart';

class ListenVideoProvider extends ChangeNotifier {
  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;
  int _playToken = 0;

  // Audio track metadata
  String? _bvid;
  int? _cid;
  String? _title;
  String? _coverUrl;
  String? _upName;
  String? _audioUrl;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  bool _isBuffering = false;
  bool _isPlaying = false;
  bool _isDisposed = false;

  // Sleep Timer
  Timer? _sleepTimer;
  Timer? _sleepCountdownTicker;
  Duration? _sleepTimerRemaining;
  bool _sleepEndOfTrack = false;

  ListenVideoProvider() {
    _initAudioSession();
  }

  // Getters
  VideoPlayerController? get controller => _controller;
  String? get bvid => _bvid;
  int? get cid => _cid;
  String? get title => _title;
  String? get coverUrl => _coverUrl;
  String? get upName => _upName;
  String? get audioUrl => _audioUrl;

  bool get hasAudio => _audioUrl != null && _audioUrl!.isNotEmpty;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;
  bool get isBuffering => _isBuffering;

  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  bool get isSleepTimerActive => _sleepTimer != null;
  bool get isSleepEndOfTrack => _sleepEndOfTrack;

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (e) {
      debugPrint('AudioSession configure error: $e');
    }
  }

  void _onControllerUpdate() {
    if (_controller == null || _isDisposed) return;

    final val = _controller!.value;
    _position = val.position;
    if (val.duration > Duration.zero) {
      _duration = val.duration;
    }
    _isPlaying = val.isPlaying;
    _isBuffering = val.isBuffering;

    if (val.isCompleted) {
      if (_sleepEndOfTrack) {
        pause();
        cancelSleepTimer();
      }
    }

    notifyListeners();
  }

  /// Start playing a video stream in audio background mode
  Future<void> playAudio({
    required String bvid,
    required int cid,
    required String title,
    required String coverUrl,
    required String upName,
    String? audioUrl,
    Duration? startPosition,
    Duration? totalDuration,
    double speed = 1.0,
  }) async {
    final token = ++_playToken;
    _bvid = bvid;
    _cid = cid;
    _title = title;
    _coverUrl = coverUrl;
    _upName = upName;
    _speed = speed;
    _position = startPosition ?? Duration.zero;
    if (totalDuration != null && totalDuration > Duration.zero) {
      _duration = totalDuration;
    }
    _isBuffering = true;
    _isPlaying = true;

    // In listen mode, disable screen wakelock to allow screen to sleep/lock normally
    try {
      WakelockPlus.disable();
    } catch (_) {}

    notifyListeners();

    try {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await session.setActive(true);
      } catch (e) {
        debugPrint('AudioSession configuration non-fatal error: $e');
      }

      // Clean up previous active and pending controllers
      if (_controller != null) {
        _controller!.removeListener(_onControllerUpdate);
        try {
          await _controller!.pause();
          await _controller!.dispose();
        } catch (_) {}
        _controller = null;
      }
      if (_pendingController != null) {
        try {
          await _pendingController!.pause();
          await _pendingController!.dispose();
        } catch (_) {}
        _pendingController = null;
      }

      if (_isDisposed || _playToken != token) return;

      String? streamUrl = audioUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        final info = await VideoApiService().getVideoPlayUrl(bvid: bvid, cid: cid);
        streamUrl = info?.primaryAudioUrl ?? info?.primaryVideoUrl;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        debugPrint('ListenVideoProvider: Failed to obtain stream URL for $bvid / $cid');
        if (_playToken == token) {
          _isBuffering = false;
          _isPlaying = false;
          notifyListeners();
        }
        return;
      }

      if (_isDisposed || _playToken != token) return;

      _audioUrl = streamUrl;

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: true,
          mixWithOthers: true,
          preventsDisplaySleepDuringVideoPlayback: false,
        ),
        httpHeaders: const {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );
      _pendingController = ctrl;

      await ctrl.initialize();
      await ctrl.setVolume(1.0);

      // Guard: Check if replaced or stopped during network initialization
      if (_isDisposed || _playToken != token || _pendingController != ctrl) {
        try {
          await ctrl.pause();
          await ctrl.dispose();
        } catch (_) {}
        return;
      }

      if (startPosition != null && startPosition > Duration.zero) {
        await ctrl.seekTo(startPosition);
      }
      await ctrl.setPlaybackSpeed(speed);
      await ctrl.play();

      // Guard: Check again after async play
      if (_isDisposed || _playToken != token) {
        try {
          await ctrl.pause();
          await ctrl.dispose();
        } catch (_) {}
        return;
      }

      _pendingController = null;
      _controller = ctrl;
      _isPlaying = ctrl.value.isPlaying;
      _isBuffering = ctrl.value.isBuffering;
      if (ctrl.value.duration > Duration.zero) {
        _duration = ctrl.value.duration;
      }

      ctrl.addListener(_onControllerUpdate);
    } catch (e, stack) {
      debugPrint('Error starting audio playback: $e\n$stack');
      if (_playToken == token) {
        _isPlaying = false;
      }
    } finally {
      if (_playToken == token) {
        _isBuffering = false;
        if (!_isDisposed) {
          notifyListeners();
        }
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    _isPlaying = _controller?.value.isPlaying ?? false;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> play() async {
    if (_controller != null) {
      await _controller!.play();
      _isPlaying = true;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_controller != null) {
      await _controller!.pause();
      _isPlaying = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> seek(Duration pos) async {
    if (_controller != null) {
      await _controller!.seekTo(pos);
      _position = pos;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> seekRelative(int seconds) async {
    final newPos = _position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && newPos > _duration ? _duration : newPos);
    await seek(clamped);
  }

  Future<void> setSpeed(double newSpeed) async {
    _speed = newSpeed;
    if (_controller != null) {
      await _controller!.setPlaybackSpeed(newSpeed);
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Sleep Timer (定时关闭)
  void setSleepTimer(Duration? duration, {bool endOfTrack = false}) {
    cancelSleepTimer();

    _sleepEndOfTrack = endOfTrack;
    if (endOfTrack) {
      _sleepTimerRemaining = null;
      notifyListeners();
      return;
    }

    if (duration == null || duration <= Duration.zero) {
      notifyListeners();
      return;
    }

    _sleepTimerRemaining = duration;
    _sleepTimer = Timer(duration, () {
      pause();
      cancelSleepTimer();
    });

    _sleepCountdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemaining != null && _sleepTimerRemaining! > Duration.zero) {
        _sleepTimerRemaining = _sleepTimerRemaining! - const Duration(seconds: 1);
        if (!_isDisposed) notifyListeners();
      } else {
        timer.cancel();
      }
    });

    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepCountdownTicker?.cancel();
    _sleepCountdownTicker = null;
    _sleepTimerRemaining = null;
    _sleepEndOfTrack = false;
    if (!_isDisposed) notifyListeners();
  }

  /// Stop and clear audio playback
  Future<void> stopAndClear() async {
    _playToken++;
    cancelSleepTimer();
    if (_controller != null) {
      _controller!.removeListener(_onControllerUpdate);
      try {
        await _controller!.pause();
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
    if (_pendingController != null) {
      try {
        await _pendingController!.pause();
        await _pendingController!.dispose();
      } catch (_) {}
      _pendingController = null;
    }
    _bvid = null;
    _cid = null;
    _title = null;
    _coverUrl = null;
    _upName = null;
    _audioUrl = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    _isBuffering = false;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playToken++;
    cancelSleepTimer();
    if (_controller != null) {
      _controller!.removeListener(_onControllerUpdate);
      try {
        _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
    if (_pendingController != null) {
      try {
        _pendingController!.dispose();
      } catch (_) {}
      _pendingController = null;
    }
    super.dispose();
  }
}
