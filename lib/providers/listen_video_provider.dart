import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api/video_api_service.dart';
import '../services/player/bili_stream_proxy.dart';

class ListenVideoProvider extends ChangeNotifier {
  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;
  int _playToken = 0;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _isRecovering = false;

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
  bool _wasPlayingBeforeInterruption = false;

  // Audio session subscriptions
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  // Sleep Timer
  Timer? _sleepTimer;
  Timer? _sleepCountdownTicker;
  Duration? _sleepTimerRemaining;
  bool _sleepEndOfTrack = false;

  static const Map<String, String> _biliHeaders = {
    'Referer': 'https://www.bilibili.com',
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

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
      // Do not activate audio session at startup; only activate when audio actually plays

      _noisySub = session.becomingNoisyEventStream.listen((_) {
        pause();
      });

      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _controller?.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _wasPlayingBeforeInterruption = _isPlaying;
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _controller?.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_wasPlayingBeforeInterruption) {
                play();
              }
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('AudioSession configure error: $e');
    }
  }

  Duration _lastNotifiedPosition = Duration.zero;

  void _onControllerUpdate() {
    if (_controller == null || _isDisposed) return;

    final val = _controller!.value;

    // Check for player error and attempt auto-recovery
    if (val.hasError) {
      debugPrint('ListenVideoProvider controller error: ${val.errorDescription}');
      if (!_isRecovering) {
        _handlePlaybackError();
      }
      return;
    }

    final newPos = val.position;
    final newDur = val.duration;
    final newPlaying = val.isPlaying;
    final newBuffering = val.isBuffering;

    bool needsNotify = false;

    if (newPlaying != _isPlaying) {
      _isPlaying = newPlaying;
      needsNotify = true;
    }

    if (newBuffering != _isBuffering) {
      _isBuffering = newBuffering;
      needsNotify = true;
    }

    if (newDur > Duration.zero && newDur != _duration) {
      _duration = newDur;
      needsNotify = true;
    }

    // Throttle position updates to at most once per 250ms to prevent UI thread flooding
    if ((newPos - _lastNotifiedPosition).abs() >= const Duration(milliseconds: 250) ||
        newPos == Duration.zero ||
        (newDur > Duration.zero && newPos >= newDur)) {
      _position = newPos;
      _lastNotifiedPosition = newPos;
      needsNotify = true;
    }

    if (val.isCompleted) {
      if (_sleepEndOfTrack) {
        pause();
        cancelSleepTimer();
      }
    }

    if (needsNotify) {
      notifyListeners();
    }
  }

  VideoPlayerController _createController(String streamUrl) {
    if (!kIsWeb && (streamUrl.startsWith('/') || streamUrl.startsWith('file:'))) {
      final cleanPath = streamUrl.replaceFirst('file://', '');
      if (File(cleanPath).existsSync()) {
        return VideoPlayerController.file(
          File(cleanPath),
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: true,
            mixWithOthers: true,
            preventsDisplaySleepDuringVideoPlayback: false,
          ),
        );
      }
    }
    return VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: true,
        mixWithOthers: true,
        preventsDisplaySleepDuringVideoPlayback: false,
      ),
      httpHeaders: _biliHeaders,
    );
  }

  Future<void> _handlePlaybackError() async {
    if (_isDisposed || _bvid == null || _cid == null || _isRecovering) return;
    _isRecovering = true;
    // 恢复期间用户手动切歌/切集会推进 _playToken，过期的恢复流程必须立即中止
    final token = _playToken;

    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint(
          'ListenVideoProvider: Auto-reconnecting attempt $_retryCount/$_maxRetries at position $_position...');
      _isBuffering = true;
      notifyListeners();

      try {
        await Future.delayed(Duration(milliseconds: 600 * _retryCount));
        if (_isDisposed ||
            _playToken != token ||
            _bvid == null ||
            _cid == null) {
          _isRecovering = false;
          return;
        }

        // Re-fetch fresh unsegmented DASH audio stream to recover from CDN token expiration
        String? freshUrl;
        try {
          freshUrl = await VideoApiService().getVideoAudioUrl(bvid: _bvid!, cid: _cid!);
        } catch (_) {}

        if (freshUrl == null || freshUrl.isEmpty) {
          final info = await VideoApiService().getVideoPlayUrl(bvid: _bvid!, cid: _cid!, qn: 16);
          freshUrl = info?.primaryAudioUrl ?? info?.primaryVideoUrl;
        }

        if (freshUrl != null &&
            freshUrl.isNotEmpty &&
            !_isDisposed &&
            _playToken == token) {
          _audioUrl = freshUrl;
          final savedPos = _position;

          if (_controller != null) {
            _controller!.removeListener(_onControllerUpdate);
            try {
              await _controller!.pause();
              await _controller!.dispose();
            } catch (_) {}
            _controller = null;
          }

          String playFreshUrl = freshUrl;
          if (!kIsWeb && (freshUrl.startsWith('http://') || freshUrl.startsWith('https://'))) {
            playFreshUrl = await BiliStreamProxy().getProxyUrl(
              freshUrl,
              isAudio: true,
              cacheKey: 'listen|$_bvid|$_cid',
            );
          }
          if (_isDisposed || _playToken != token) {
            _isRecovering = false;
            return;
          }
          final newCtrl = _createController(playFreshUrl);

          await newCtrl.initialize();
          await newCtrl.setVolume(1.0);
          if (savedPos > Duration.zero) {
            await newCtrl.seekTo(savedPos);
          }
          await newCtrl.setPlaybackSpeed(_speed);
          await newCtrl.play();

          if (_isDisposed || _playToken != token) {
            try {
              await newCtrl.dispose();
            } catch (_) {}
            _isRecovering = false;
            return;
          }

          _controller = newCtrl;
          _isPlaying = newCtrl.value.isPlaying;
          _isBuffering = newCtrl.value.isBuffering;
          if (newCtrl.value.duration > Duration.zero) {
            _duration = newCtrl.value.duration;
          }
          _controller!.addListener(_onControllerUpdate);

          _retryCount = 0;
          _isRecovering = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('ListenVideoProvider: Reconnect failed: $e');
      }
    }

    _isRecovering = false;
    // 令牌已过期说明有新的 playAudio 在途，播放状态归它管，不能在这里清掉
    if (_playToken == token && !_isDisposed) {
      _isBuffering = false;
      _isPlaying = false;
      notifyListeners();
    }
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
    _retryCount = 0;
    _isRecovering = false;
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

      String? streamUrl;
      // 1. If audioUrl is a valid local cached file, use it directly
      if (audioUrl != null &&
          audioUrl.isNotEmpty &&
          !kIsWeb &&
          (audioUrl.startsWith('/') || audioUrl.startsWith('file:'))) {
        final cleanPath = audioUrl.replaceFirst('file://', '');
        if (File(cleanPath).existsSync()) {
          streamUrl = cleanPath;
        }
      }

      // 2. Fetch unsegmented continuous DASH audio stream (fnval=16) for listen mode
      if (streamUrl == null || streamUrl.isEmpty) {
        try {
          streamUrl = await VideoApiService().getVideoAudioUrl(bvid: bvid, cid: cid);
        } catch (e) {
          debugPrint('ListenVideoProvider: Failed to fetch DASH audio URL: $e');
        }
      }

      // 3. Fallback to provided audioUrl if DASH stream retrieval failed
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = audioUrl;
      }

      // 4. Final fallback: standard play url (360P smooth stream)
      if (streamUrl == null || streamUrl.isEmpty) {
        try {
          final info = await VideoApiService().getVideoPlayUrl(bvid: bvid, cid: cid, qn: 16);
          streamUrl = info?.primaryAudioUrl ?? info?.primaryVideoUrl;
        } catch (_) {}
      }
      if (streamUrl == null || streamUrl.isEmpty) {
        try {
          final info = await VideoApiService().getVideoPlayUrl(bvid: bvid, cid: cid);
          streamUrl = info?.primaryAudioUrl ?? info?.primaryVideoUrl;
        } catch (_) {}
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

      String playStreamUrl = streamUrl;
      if (!kIsWeb && (streamUrl.startsWith('http://') || streamUrl.startsWith('https://'))) {
        playStreamUrl = await BiliStreamProxy().getProxyUrl(
          streamUrl,
          isAudio: true,
          cacheKey: 'listen|$bvid|$cid',
        );
      }
      if (_isDisposed || _playToken != token) return;

      final ctrl = _createController(playStreamUrl);
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
      // 兜底：清理在途期间被其他流程写入的控制器，避免双路音频同时出声
      if (_controller != null) {
        _controller!.removeListener(_onControllerUpdate);
        try {
          await _controller!.pause();
          await _controller!.dispose();
        } catch (_) {}
      }
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
    _position = pos;
    if (_controller != null) {
      try {
        await _controller!.seekTo(pos);
      } catch (_) {}
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<void> seekTo(Duration pos) => seek(pos);

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
    _retryCount = 0;
    _isRecovering = false;
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
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playToken++;
    cancelSleepTimer();
    _noisySub?.cancel();
    _interruptionSub?.cancel();
    try {
      AudioSession.instance.then((s) => s.setActive(false));
    } catch (_) {}
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
