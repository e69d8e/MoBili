import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/providers/theme_provider.dart';
import 'package:mobili/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemePreset Tests', () {
    test('Default preset should be ink (黑白水墨)', () {
      expect(AppThemePreset.ink.name, '黑白水墨');
      expect(AppThemePreset.ink.key, 'ink');
      expect(AppThemePreset.fromKey('unknown'), AppThemePreset.ink);
      expect(AppThemePreset.fromKey('ink'), AppThemePreset.ink);
    });

    test('All presets are properly resolved from key', () {
      expect(AppThemePreset.fromKey('pink'), AppThemePreset.biliPink);
      expect(AppThemePreset.fromKey('bamboo'), AppThemePreset.bamboo);
      expect(AppThemePreset.fromKey('porcelain'), AppThemePreset.porcelain);
      expect(AppThemePreset.fromKey('cinnabar'), AppThemePreset.cinnabar);
      expect(AppThemePreset.fromKey('wisteria'), AppThemePreset.wisteria);
    });

    test('lightTheme and darkTheme generate valid ThemeData for each preset', () {
      for (final preset in AppThemePreset.values) {
        final light = AppTheme.lightTheme(preset: preset);
        final dark = AppTheme.darkTheme(preset: preset, isAmoled: false);
        final amoled = AppTheme.darkTheme(preset: preset, isAmoled: true);

        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);
        expect(amoled.brightness, Brightness.dark);
        expect(amoled.scaffoldBackgroundColor, Colors.black);
        expect(light.colorScheme.primary, preset.lightPrimary);
        expect(dark.colorScheme.primary, preset.darkPrimary);
      }
    });
  });

  group('ThemeProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ThemeProvider initializes with ink preset by default', () async {
      final provider = ThemeProvider();
      await provider.init();

      expect(provider.themePreset, AppThemePreset.ink);
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isAmoled, isFalse);
    });

    test('ThemeProvider switches and persists preset', () async {
      final provider = ThemeProvider();
      await provider.init();

      await provider.setThemePreset(AppThemePreset.bamboo);
      expect(provider.themePreset, AppThemePreset.bamboo);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preset'), 'bamboo');

      // Verify new instance loads persisted preset
      final newProvider = ThemeProvider();
      await newProvider.init();
      expect(newProvider.themePreset, AppThemePreset.bamboo);
    });
  });
}
