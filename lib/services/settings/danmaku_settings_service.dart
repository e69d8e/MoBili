import 'package:shared_preferences/shared_preferences.dart';

/// Global service for persisting Danmaku preferences across app sessions and video changes.
class DanmakuSettingsService {
  static const String _keyEnabled = 'danmaku_enabled';
  static const String _keyOpacity = 'danmaku_opacity';
  static const String _keyFontSizeScale = 'danmaku_font_size_scale';
  static const String _keyAreaRatio = 'danmaku_area_ratio';

  // In-memory cached values for synchronous instant retrieval
  static bool _enabled = true;
  static double _opacity = 0.65;
  static double _fontSizeScale = 1.0;
  static double _areaRatio = 0.5;

  static bool get enabled => _enabled;
  static double get opacity => _opacity;
  static double get fontSizeScale => _fontSizeScale;
  static double get areaRatio => _areaRatio;

  /// Preload preferences during app initialization
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? true;
      _opacity = (prefs.getDouble(_keyOpacity) ?? 0.65).clamp(0.1, 1.0);
      _fontSizeScale = (prefs.getDouble(_keyFontSizeScale) ?? 1.0).clamp(0.5, 2.0);
      _areaRatio = (prefs.getDouble(_keyAreaRatio) ?? 0.5).clamp(0.2, 1.0);
    } catch (_) {}
  }

  static Future<void> setEnabled(bool val) async {
    _enabled = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, val);
    } catch (_) {}
  }

  static Future<void> setOpacity(double val) async {
    _opacity = val.clamp(0.1, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyOpacity, _opacity);
    } catch (_) {}
  }

  static Future<void> setFontSizeScale(double val) async {
    _fontSizeScale = val.clamp(0.5, 2.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyFontSizeScale, _fontSizeScale);
    } catch (_) {}
  }

  static Future<void> setAreaRatio(double val) async {
    _areaRatio = val.clamp(0.2, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyAreaRatio, _areaRatio);
    } catch (_) {}
  }
}
