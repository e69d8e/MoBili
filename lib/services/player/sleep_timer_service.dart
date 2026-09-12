import 'dart:async';
import 'package:flutter/foundation.dart';

enum SleepTimerMode {
  none,
  duration,
  endOfVideo,
}

/// Global service for managing sleep timer and auto-stop playback.
class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService _instance = SleepTimerService._internal();
  factory SleepTimerService() => _instance;
  SleepTimerService._internal();

  SleepTimerMode _mode = SleepTimerMode.none;
  int _remainingSeconds = 0;
  int _initialSeconds = 0;
  Timer? _ticker;

  final Set<VoidCallback> _pauseCallbacks = {};

  SleepTimerMode get mode => _mode;
  bool get isActive => _mode != SleepTimerMode.none;
  bool get isDurationMode => _mode == SleepTimerMode.duration;
  bool get isEndOfVideoMode => _mode == SleepTimerMode.endOfVideo;
  int get remainingSeconds => _remainingSeconds;
  int get initialSeconds => _initialSeconds;

  double get progress {
    if (_initialSeconds <= 0 || _remainingSeconds <= 0) return 0.0;
    return (_remainingSeconds / _initialSeconds).clamp(0.0, 1.0);
  }

  /// Register a listener to be called when timer fires or episode completes
  void registerPauseCallback(VoidCallback callback) {
    _pauseCallbacks.add(callback);
  }

  /// Unregister callback
  void unregisterPauseCallback(VoidCallback callback) {
    _pauseCallbacks.remove(callback);
  }

  /// Start a countdown timer for the specified duration
  void startTimer(Duration duration) {
    _ticker?.cancel();
    _initialSeconds = duration.inSeconds;
    _remainingSeconds = _initialSeconds;
    _mode = SleepTimerMode.duration;
    notifyListeners();

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _remainingSeconds = 0;
        timer.cancel();
        _triggerPauseAction('定时时间已到，已自动暂停播放');
      }
    });
  }

  /// Set mode to stop after current video or episode finishes
  void setEndOfVideoMode() {
    _ticker?.cancel();
    _remainingSeconds = 0;
    _initialSeconds = 0;
    _mode = SleepTimerMode.endOfVideo;
    notifyListeners();
  }

  /// Cancel any active sleep timer
  void cancelTimer() {
    _ticker?.cancel();
    _ticker = null;
    _mode = SleepTimerMode.none;
    _remainingSeconds = 0;
    _initialSeconds = 0;
    notifyListeners();
  }

  /// Invoked by video detail or player when an episode/video reaches the end
  bool notifyVideoFinished() {
    if (_mode == SleepTimerMode.endOfVideo) {
      _triggerPauseAction('视频已播放完毕，已为您自动停止');
      return true; // handled
    }
    return false;
  }

  void _triggerPauseAction(String message) {
    _mode = SleepTimerMode.none;
    _ticker?.cancel();
    _ticker = null;
    _remainingSeconds = 0;
    _initialSeconds = 0;
    notifyListeners();

    // Call all registered pause callbacks
    final callbacks = List<VoidCallback>.from(_pauseCallbacks);
    for (final cb in callbacks) {
      try {
        cb();
      } catch (_) {}
    }
  }

  String formatRemaining() {
    if (_mode == SleepTimerMode.endOfVideo) {
      return '播完当前视频后停止';
    }
    if (_remainingSeconds <= 0) {
      return '已关闭';
    }
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pauseCallbacks.clear();
    super.dispose();
  }
}
