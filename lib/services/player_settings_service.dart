import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing video player settings and user preferences.
class PlayerSettingsService {
  static const String _keyAutoRotate = 'player_auto_rotate_fullscreen';

  static bool _autoRotateFullScreen = true;

  /// Whether tilting the phone in portrait video mode automatically enters landscape fullscreen.
  static bool get autoRotateFullScreen => _autoRotateFullScreen;

  /// Listenable for reactive UI updates when autoRotateFullScreen changes.
  static final ValueNotifier<bool> autoRotateListenable = ValueNotifier<bool>(true);

  /// Preload preferences during app initialization
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoRotateFullScreen = prefs.getBool(_keyAutoRotate) ?? true;
      autoRotateListenable.value = _autoRotateFullScreen;
    } catch (_) {}
  }

  /// Update auto rotate setting and persist to disk
  static Future<void> setAutoRotateFullScreen(bool val) async {
    _autoRotateFullScreen = val;
    autoRotateListenable.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoRotate, val);
    } catch (_) {}
  }
}
