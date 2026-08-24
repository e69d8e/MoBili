import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppThemePreset _themePreset = AppThemePreset.ink;
  bool _isAmoled = false;

  ThemeMode get themeMode => _themeMode;
  AppThemePreset get themePreset => _themePreset;
  bool get isAmoled => _isAmoled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode') ?? 'system';
    if (modeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (modeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    final presetStr = prefs.getString('theme_preset');
    _themePreset = AppThemePreset.fromKey(presetStr);

    _isAmoled = prefs.getBool('is_amoled') ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await prefs.setString('theme_mode', modeStr);
    notifyListeners();
  }

  Future<void> setThemePreset(AppThemePreset preset) async {
    _themePreset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset', preset.key);
    notifyListeners();
  }

  Future<void> setAmoled(bool val) async {
    _isAmoled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_amoled', val);
    notifyListeners();
  }
}
