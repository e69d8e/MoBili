import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 预设主题风格
enum AppThemePreset {
  ink(
    key: 'ink',
    name: '黑白水墨',
    description: '极简墨韵，水墨留白，淡雅素净',
    lightPrimary: Color(0xFF22242A),
    darkPrimary: Color(0xFFEDEDF2),
    secondary: Color(0xFF6B7280),
    previewColors: [Color(0xFF22242A), Color(0xFF5A5E6B), Color(0xFFE5E7EB)],
  ),
  biliPink(
    key: 'pink',
    name: '经典哔哩',
    description: '经典粉蓝，元气活泼，青春生动',
    lightPrimary: Color(0xFFFF6699),
    darkPrimary: Color(0xFFFF6699),
    secondary: Color(0xFF00AEEC),
    previewColors: [Color(0xFFFF6699), Color(0xFF00AEEC), Color(0xFFFFF0F5)],
  ),
  bamboo(
    key: 'bamboo',
    name: '竹青黛绿',
    description: '苍翠竹林，温润沉静，清雅自然',
    lightPrimary: Color(0xFF2E7D6F),
    darkPrimary: Color(0xFF4DB6AC),
    secondary: Color(0xFF388E3C),
    previewColors: [Color(0xFF2E7D6F), Color(0xFF4DB6AC), Color(0xFFE0F2F1)],
  ),
  porcelain(
    key: 'porcelain',
    name: '霁蓝远山',
    description: '青花霁色，远山如黛，澄澈旷远',
    lightPrimary: Color(0xFF2A6F97),
    darkPrimary: Color(0xFF60A5FA),
    secondary: Color(0xFF0284C7),
    previewColors: [Color(0xFF2A6F97), Color(0xFF60A5FA), Color(0xFFEFF6FF)],
  ),
  cinnabar(
    key: 'cinnabar',
    name: '朱砂丹枫',
    description: '朱砂落印，层林尽染，古风典雅',
    lightPrimary: Color(0xFFC0483E),
    darkPrimary: Color(0xFFFB923C),
    secondary: Color(0xFFDC2626),
    previewColors: [Color(0xFFC0483E), Color(0xFFFB923C), Color(0xFFFFF7ED)],
  ),
  wisteria(
    key: 'wisteria',
    name: '暮山幽紫',
    description: '暮霭微茫，山色空濛，风雅幽美',
    lightPrimary: Color(0xFF75549E),
    darkPrimary: Color(0xFFA78BFA),
    secondary: Color(0xFF8B5CF6),
    previewColors: [Color(0xFF75549E), Color(0xFFA78BFA), Color(0xFFF5F3FF)],
  );

  final String key;
  final String name;
  final String description;
  final Color lightPrimary;
  final Color darkPrimary;
  final Color secondary;
  final List<Color> previewColors;

  const AppThemePreset({
    required this.key,
    required this.name,
    required this.description,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.secondary,
    required this.previewColors,
  });

  static AppThemePreset fromKey(String? key) {
    return AppThemePreset.values.firstWhere(
      (e) => e.key == key,
      orElse: () => AppThemePreset.ink,
    );
  }
}

class AppTheme {
  // Legacy Accent Colors
  static const Color biliPink = Color(0xFFFF6699);
  static const Color biliPinkLight = Color(0xFFFF80AB);
  static const Color biliPinkMuted = Color(0xFFFFF0F5);
  static const Color biliBlue = Color(0xFF00AEEC);
  static const Color biliYellow = Color(0xFFFFB027);

  // Modern Ink Minimalist Colors (Dark / AMOLED)
  static const Color inkBg = Color(0xFF0F0F12);
  static const Color pureBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF18181C);
  static const Color cardDarkAmoled = Color(0xFF121215);
  static const Color surfaceDark = Color(0xFF222228);
  static const Color dividerDark = Color(0xFF26262D);

  // Clean Light Mode Colors
  static const Color bgLight = Color(0xFFF7F8FA);
  static const Color cardLight = Colors.white;
  static const Color surfaceLight = Color(0xFFF1F2F5);
  static const Color textMainLight = Color(0xFF18191C);
  static const Color textSubLight = Color(0xFF61666D);
  static const Color textHintLight = Color(0xFF9499A0);
  static const Color dividerLight = Color(0xFFEBECEF);

  // Dark Mode Typography Colors
  static const Color textMainDark = Color(0xFFF4F4F6);
  static const Color textSubDark = Color(0xFF9898A0);
  static const Color textHintDark = Color(0xFF5E5E68);

  /// Helper to get current primary color from context
  static Color primary(BuildContext context) => Theme.of(context).colorScheme.primary;

  static PageTransitionsTheme _buildPageTransitionsTheme(bool enablePredictiveBack) {
    return PageTransitionsTheme(
      builders: {
        TargetPlatform.android: enablePredictiveBack
            ? const PredictiveBackPageTransitionsBuilder()
            : const ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: const ZoomPageTransitionsBuilder(),
      },
    );
  }

  static ThemeData lightTheme({
    AppThemePreset preset = AppThemePreset.ink,
    bool enablePredictiveBack = false,
  }) {
    final primary = preset.lightPrimary;
    final secondary = preset.secondary;
    final onPrimary = (primary.computeLuminance() > 0.5) ? Colors.black : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      pageTransitionsTheme: _buildPageTransitionsTheme(enablePredictiveBack),
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: cardLight,
        onPrimary: onPrimary,
        onSurface: textMainLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textMainLight,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textMainLight, size: 22),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: primary,
        unselectedItemColor: textSubLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: textSubLight, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textSubLight, fontSize: 11, fontWeight: FontWeight.normal);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: primary,
        unselectedLabelColor: textSubLight,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.25),
        selectionHandleColor: primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary.withValues(alpha: 0.4);
          return null;
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerLight,
        thickness: 0.6,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData darkTheme({
    AppThemePreset preset = AppThemePreset.ink,
    bool isAmoled = false,
    bool enablePredictiveBack = false,
  }) {
    final bg = isAmoled ? pureBlack : inkBg;
    final cardBg = isAmoled ? cardDarkAmoled : cardDark;
    final primary = preset.darkPrimary;
    final secondary = preset.secondary;
    final onPrimary = (primary.computeLuminance() > 0.5) ? Colors.black : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      pageTransitionsTheme: _buildPageTransitionsTheme(enablePredictiveBack),
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: cardBg,
        onPrimary: onPrimary,
        onSurface: textMainDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: textMainDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: textMainDark, size: 22),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primary,
        unselectedItemColor: textSubDark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: textSubDark, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textSubDark, fontSize: 11, fontWeight: FontWeight.normal);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: primary,
        unselectedLabelColor: textSubDark,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.25),
        selectionHandleColor: primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary.withValues(alpha: 0.4);
          return null;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: isAmoled ? const Color(0xFF1B1B1F) : dividerDark,
        thickness: 0.6,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

extension BuildContextThemeExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
