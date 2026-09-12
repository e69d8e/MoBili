import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing video player settings and user preferences.
class PlayerSettingsService {
  static const String _keyAutoRotate = 'player_auto_rotate_fullscreen';
  static const String _keyDefaultQuality = 'player_default_quality';
  static const String _keyDefaultSpeed = 'player_default_speed';
  static const String _keyDoubleTapSeek = 'player_double_tap_seek';
  static const String _keyLongPressSpeed = 'player_enable_long_press_speed';
  static const String _keyVerticalPan = 'player_enable_vertical_pan';
  static const String _keyHorizontalPan = 'player_enable_horizontal_pan';
  static const String _keyAutoPlayNext = 'player_auto_play_next_episode';
  static const String _keyIncognito = 'player_incognito_mode';
  static const String _keySubtitleEnabled = 'player_subtitle_enabled';
  static const String _keyPreferredSubtitleLan = 'player_preferred_subtitle_lan';

  static bool _autoRotateFullScreen = true;
  static int _defaultQuality = 80; // 80 = 1080P default (server auto-downgrades on fnval=0)
  static double _defaultPlaybackSpeed = 1.0;
  static int _doubleTapSeekSeconds = 10;
  static bool _enableLongPressSpeed = true;
  static bool _enableVerticalPanVolumeBrightness = true;
  static bool _enableHorizontalPanSeek = true;
  static bool _autoPlayNextEpisode = true;
  static bool _incognitoMode = false;
  static bool _subtitleEnabled = true;
  static String _preferredSubtitleLanguage = '';

  /// Whether tilting the phone in portrait video mode automatically enters landscape fullscreen.
  static bool get autoRotateFullScreen => _autoRotateFullScreen;
  static int get defaultQuality => _defaultQuality;
  static double get defaultPlaybackSpeed => _defaultPlaybackSpeed;
  static int get doubleTapSeekSeconds => _doubleTapSeekSeconds;
  static bool get enableLongPressSpeed => _enableLongPressSpeed;
  static bool get enableVerticalPanVolumeBrightness => _enableVerticalPanVolumeBrightness;
  static bool get enableHorizontalPanSeek => _enableHorizontalPanSeek;
  static bool get autoPlayNextEpisode => _autoPlayNextEpisode;
  static bool get incognitoMode => _incognitoMode;
  static bool get subtitleEnabled => _subtitleEnabled;
  static String get preferredSubtitleLanguage => _preferredSubtitleLanguage;

  /// Listenables for reactive UI updates
  static final ValueNotifier<bool> autoRotateListenable = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> incognitoListenable = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> subtitleEnabledListenable = ValueNotifier<bool>(true);
  static final ValueNotifier<int> qualityListenable = ValueNotifier<int>(80);

  /// Preload preferences during app initialization
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoRotateFullScreen = prefs.getBool(_keyAutoRotate) ?? true;
      _defaultQuality = prefs.getInt(_keyDefaultQuality) ?? 80;
      _defaultPlaybackSpeed = prefs.getDouble(_keyDefaultSpeed) ?? 1.0;
      _doubleTapSeekSeconds = prefs.getInt(_keyDoubleTapSeek) ?? 10;
      _enableLongPressSpeed = prefs.getBool(_keyLongPressSpeed) ?? true;
      _enableVerticalPanVolumeBrightness = prefs.getBool(_keyVerticalPan) ?? true;
      _enableHorizontalPanSeek = prefs.getBool(_keyHorizontalPan) ?? true;
      _autoPlayNextEpisode = prefs.getBool(_keyAutoPlayNext) ?? true;
      _incognitoMode = prefs.getBool(_keyIncognito) ?? false;
      _subtitleEnabled = prefs.getBool(_keySubtitleEnabled) ?? true;
      _preferredSubtitleLanguage = prefs.getString(_keyPreferredSubtitleLan) ?? '';

      autoRotateListenable.value = _autoRotateFullScreen;
      incognitoListenable.value = _incognitoMode;
      subtitleEnabledListenable.value = _subtitleEnabled;
      qualityListenable.value = _defaultQuality;
    } catch (_) {}
  }

  static Future<void> setAutoRotateFullScreen(bool val) async {
    _autoRotateFullScreen = val;
    autoRotateListenable.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoRotate, val);
    } catch (_) {}
  }

  static Future<void> setDefaultQuality(int val) async {
    _defaultQuality = val;
    qualityListenable.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyDefaultQuality, val);
    } catch (_) {}
  }

  static Future<void> setSubtitleEnabled(bool val) async {
    _subtitleEnabled = val;
    subtitleEnabledListenable.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySubtitleEnabled, val);
    } catch (_) {}
  }

  static Future<void> setPreferredSubtitleLanguage(String val) async {
    _preferredSubtitleLanguage = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPreferredSubtitleLan, val);
    } catch (_) {}
  }

  static Future<void> setDefaultPlaybackSpeed(double val) async {
    _defaultPlaybackSpeed = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyDefaultSpeed, val);
    } catch (_) {}
  }

  static Future<void> setDoubleTapSeekSeconds(int val) async {
    _doubleTapSeekSeconds = val.clamp(3, 60);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyDoubleTapSeek, _doubleTapSeekSeconds);
    } catch (_) {}
  }

  static Future<void> setEnableLongPressSpeed(bool val) async {
    _enableLongPressSpeed = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLongPressSpeed, val);
    } catch (_) {}
  }

  static Future<void> setEnableVerticalPan(bool val) async {
    _enableVerticalPanVolumeBrightness = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVerticalPan, val);
    } catch (_) {}
  }

  static Future<void> setEnableHorizontalPan(bool val) async {
    _enableHorizontalPanSeek = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHorizontalPan, val);
    } catch (_) {}
  }

  static Future<void> setAutoPlayNextEpisode(bool val) async {
    _autoPlayNextEpisode = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoPlayNext, val);
    } catch (_) {}
  }

  static Future<void> setIncognitoMode(bool val) async {
    _incognitoMode = val;
    incognitoListenable.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIncognito, val);
    } catch (_) {}
  }
}
