import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Service to interface directly with system screen brightness and media volume.
class SystemMediaControlService {
  SystemMediaControlService._();
  static final SystemMediaControlService instance = SystemMediaControlService._();

  /// Whether we are executing in a Flutter test environment where native channels are absent.
  static bool get isTesting =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  double? _mockBrightness = 1.0;
  double? _mockVolume = 1.0;
  void Function(double)? _mockVolumeListener;

  /// Session-level brightness memory (in-memory only, cleared upon exiting the app).
  double? _sessionBrightness;
  double? get sessionBrightness => _sessionBrightness;

  void rememberBrightness(double value) {
    _sessionBrightness = value.clamp(0.0, 1.0);
  }

  void clearSessionBrightness() {
    _sessionBrightness = null;
  }

  static const int _volumeThrottleIntervalMs = 60;

  DateTime _lastSetBrightnessTime = DateTime.fromMillisecondsSinceEpoch(0);
  double? _pendingBrightness;
  Timer? _brightnessThrottleTimer;

  DateTime _lastSetVolumeTime = DateTime.fromMillisecondsSinceEpoch(0);
  double? _pendingVolume;
  Timer? _volumeThrottleTimer;

  /// Retrieve current brightness (0.0 ~ 1.0). Returns null if unsupported or errored.
  Future<double?> getBrightness() async {
    if (isTesting) return _mockBrightness;
    try {
      final appVal = await ScreenBrightness.instance.application;
      if (appVal > 0) return appVal;
      return await ScreenBrightness.instance.system;
    } catch (e) {
      debugPrint('[SystemMediaControlService] getBrightness error: $e');
      return null;
    }
  }

  /// Sets application-level screen brightness (0.0 ~ 1.0).
  /// When [immediate] is true, dispatches immediately without throttling.
  Future<void> setBrightness(double value, {bool immediate = false}) async {
    final clamped = value.clamp(0.0, 1.0);
    if (isTesting) {
      _mockBrightness = clamped;
      return;
    }

    _pendingBrightness = clamped;
    final now = DateTime.now();
    final diff = now.difference(_lastSetBrightnessTime).inMilliseconds;

    if (immediate || diff >= 35) {
      _brightnessThrottleTimer?.cancel();
      _brightnessThrottleTimer = null;
      _lastSetBrightnessTime = now;
      final target = _pendingBrightness!;
      _pendingBrightness = null;
      try {
        await ScreenBrightness.instance.setApplicationScreenBrightness(target);
      } catch (e) {
        debugPrint('[SystemMediaControlService] setBrightness error: $e');
      }
    } else {
      _brightnessThrottleTimer ??= Timer(Duration(milliseconds: 35 - diff), () async {
        _brightnessThrottleTimer = null;
        if (_pendingBrightness != null) {
          final target = _pendingBrightness!;
          _pendingBrightness = null;
          _lastSetBrightnessTime = DateTime.now();
          try {
            await ScreenBrightness.instance.setApplicationScreenBrightness(target);
          } catch (e) {
            debugPrint('[SystemMediaControlService] setBrightness error: $e');
          }
        }
      });
    }
  }

  /// Restores system default screen brightness when leaving the player.
  Future<void> resetBrightness() async {
    _brightnessThrottleTimer?.cancel();
    _brightnessThrottleTimer = null;
    _pendingBrightness = null;
    if (isTesting) {
      _mockBrightness = 1.0;
      return;
    }
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (e) {
      debugPrint('[SystemMediaControlService] resetBrightness error: $e');
    }
  }

  /// Retrieve current system media volume (0.0 ~ 1.0). Returns null if unsupported or errored.
  Future<double?> getVolume() async {
    if (isTesting) return _mockVolume;
    try {
      return await FlutterVolumeController.getVolume();
    } catch (e) {
      debugPrint('[SystemMediaControlService] getVolume error: $e');
      return null;
    }
  }

  /// Sets system media volume (0.0 ~ 1.0).
  /// When [immediate] is true, dispatches immediately without throttling.
  Future<void> setVolume(double value, {bool immediate = false}) async {
    final clamped = value.clamp(0.0, 1.0);
    if (isTesting) {
      _mockVolume = clamped;
      return;
    }

    _pendingVolume = clamped;
    final now = DateTime.now();
    final diff = now.difference(_lastSetVolumeTime).inMilliseconds;

    if (immediate || diff >= _volumeThrottleIntervalMs) {
      _volumeThrottleTimer?.cancel();
      _volumeThrottleTimer = null;
      _lastSetVolumeTime = now;
      final target = _pendingVolume!;
      _pendingVolume = null;
      try {
        await FlutterVolumeController.setVolume(target);
      } catch (e) {
        debugPrint('[SystemMediaControlService] setVolume error: $e');
      }
    } else {
      _volumeThrottleTimer ??= Timer(Duration(milliseconds: _volumeThrottleIntervalMs - diff), () async {
        _volumeThrottleTimer = null;
        if (_pendingVolume != null) {
          final target = _pendingVolume!;
          _pendingVolume = null;
          _lastSetVolumeTime = DateTime.now();
          try {
            await FlutterVolumeController.setVolume(target);
          } catch (e) {
            debugPrint('[SystemMediaControlService] setVolume error: $e');
          }
        }
      });
    }
  }

  /// Sets whether native system volume UI is shown during volume changes.
  Future<void> updateShowSystemUI(bool show) async {
    if (isTesting) return;
    try {
      await FlutterVolumeController.updateShowSystemUI(show);
    } catch (e) {
      debugPrint('[SystemMediaControlService] updateShowSystemUI error: $e');
    }
  }

  StreamSubscription<double>? _volumeSubscription;

  /// Listen for system volume changes (e.g. physical volume buttons).
  void addVolumeListener(void Function(double volume) onVolumeChanged) {
    if (isTesting) {
      _mockVolumeListener = onVolumeChanged;
      return;
    }
    try {
      removeVolumeListener();
      _volumeSubscription = FlutterVolumeController.addListener(
        onVolumeChanged,
        emitOnStart: false,
      );
      _volumeSubscription?.onError((error) {
        debugPrint('[SystemMediaControlService] volume listener stream error: $error');
      });
    } catch (e) {
      debugPrint('[SystemMediaControlService] addVolumeListener error: $e');
    }
  }

  /// Removes volume change listener safely catching any async channel errors.
  Future<void> removeVolumeListener() async {
    _volumeThrottleTimer?.cancel();
    _volumeThrottleTimer = null;
    _pendingVolume = null;
    if (isTesting) {
      _mockVolumeListener = null;
      return;
    }
    try {
      if (_volumeSubscription != null) {
        final sub = _volumeSubscription;
        _volumeSubscription = null;
        await sub?.cancel().catchError((error) {
          debugPrint('[SystemMediaControlService] volume listener cancel ignored: $error');
        });
      }
    } catch (e) {
      debugPrint('[SystemMediaControlService] removeVolumeListener error: $e');
    }
  }

  /// Simulate volume change in test environment
  @visibleForTesting
  void simulateVolumeChangedForTesting(double volume) {
    _mockVolume = volume;
    _mockVolumeListener?.call(volume);
  }
}
