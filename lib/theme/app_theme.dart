import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_dimens.dart';
import 'app_typography.dart';

/// 预设主题风格
enum AppThemePreset {
  ink(
    key: 'ink',
    name: '黑白水墨',
    description: '极简墨韵，水墨留白，淡雅素净',
    lightPrimary: Color(0xFF22242A),
    darkPrimary: Color(0xFFEDEDF2),
    secondary: Color(0xFF5A616E),
    darkSecondary: Color(0xFFA1A1AA),
    previewColors: [Color(0xFF22242A), Color(0xFF5A5E6B), Color(0xFFE5E7EB)],
  ),
  biliPink(
    key: 'pink',
    name: '经典哔哩',
    description: '经典粉蓝，元气活泼，青春生动',
    // 浅色底选用加深玫红与深天蓝以满足 WCAG AA 4.5:1，暗色底维持经典高亮粉
    lightPrimary: Color(0xFFC9255E),
    darkPrimary: Color(0xFFFF6699),
    secondary: Color(0xFF006EA8),
    darkSecondary: Color(0xFF38BDF8),
    previewColors: [Color(0xFFC9255E), Color(0xFF00AEEC), Color(0xFFFFF0F5)],
  ),
  bamboo(
    key: 'bamboo',
    name: '竹青黛绿',
    description: '苍翠竹林，温润沉静，清雅自然',
    lightPrimary: Color(0xFF277063),
    darkPrimary: Color(0xFF4DB6AC),
    secondary: Color(0xFF2E7D32),
    darkSecondary: Color(0xFF66BB6A),
    previewColors: [Color(0xFF277063), Color(0xFF4DB6AC), Color(0xFFE0F2F1)],
  ),
  porcelain(
    key: 'porcelain',
    name: '霁蓝远山',
    description: '青花霁色，远山如黛，澄澈旷远',
    lightPrimary: Color(0xFF2A6F97),
    darkPrimary: Color(0xFF60A5FA),
    secondary: Color(0xFF006EA8),
    darkSecondary: Color(0xFF38BDF8),
    previewColors: [Color(0xFF2A6F97), Color(0xFF60A5FA), Color(0xFFEFF6FF)],
  ),
  cinnabar(
    key: 'cinnabar',
    name: '朱砂丹枫',
    description: '朱砂落印，层林尽染，古风典雅',
    lightPrimary: Color(0xFFB83B32),
    darkPrimary: Color(0xFFFB923C),
    secondary: Color(0xFFC62828),
    darkSecondary: Color(0xFFF87171),
    previewColors: [Color(0xFFB83B32), Color(0xFFFB923C), Color(0xFFFFF7ED)],
  ),
  wisteria(
    key: 'wisteria',
    name: '暮山幽紫',
    description: '暮霭微茫，山色空濛，风雅幽美',
    lightPrimary: Color(0xFF75549E),
    darkPrimary: Color(0xFFA78BFA),
    secondary: Color(0xFF6D28D9),
    darkSecondary: Color(0xFFC4B5FD),
    previewColors: [Color(0xFF75549E), Color(0xFFA78BFA), Color(0xFFF5F3FF)],
  );

  final String key;
  final String name;
  final String description;
  final Color lightPrimary;
  final Color darkPrimary;
  final Color secondary;
  final Color darkSecondary;
  final List<Color> previewColors;

  const AppThemePreset({
    required this.key,
    required this.name,
    required this.description,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.secondary,
    required this.darkSecondary,
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
  static const Color surfaceDarkAmoled = Color(0xFF1E1E24);
  static const Color dividerDark = Color(0xFF2C2C35);
  static const Color dividerDarkAmoled = Color(0xFF282832);
  static const Color darkOnAccent = Color(0xFF0D0E12);

  // Clean Light Mode Colors
  static const Color bgLight = Color(0xFFF7F8FA);
  static const Color cardLight = Colors.white;
  static const Color surfaceLight = Color(0xFFF1F2F5);
  static const Color textMainLight = Color(0xFF18191C);
  static const Color textSubLight = Color(0xFF52565E);
  static const Color textHintLight = Color(0xFF676C75);
  static const Color dividerLight = Color(0xFFEBECEF);

  // Dark Mode Typography Colors
  static const Color textMainDark = Color(0xFFF4F4F6);
  static const Color textSubDark = Color(0xFFACAEB8);
  static const Color textHintDark = Color(0xFF888894);

  // Semantic status colors
  static const Color warning = Color(0xFFFFB027);
  static const Color warningLight = Color(0xFF8F5200);
  static const Color dangerLight = Color(0xFFC62828);
  static const Color dangerDark = Color(0xFFFF6B6B);
  static const Color successLight = Color(0xFF226927);
  static const Color successDark = Color(0xFF66BB6A);

  // Skeleton shimmer highlight (lighter than fill)
  static const Color fillHighlightLight = Color(0xFFF7F8FA);
  static const Color fillHighlightDark = Color(0xFF2E2E38);
  static const Color fillHighlightDarkAmoled = Color(0xFF2A2A34);

  /// Helper to get current primary color from context
  static Color primary(BuildContext context) => Theme.of(context).colorScheme.primary;

  /// 按 WCAG 2.1 亮度阈值（~0.179）为底色自动挑选高对比度前景（深墨色或纯白）。
  static Color contrastOnColor(Color background) {
    return background.computeLuminance() > 0.179 ? darkOnAccent : Colors.white;
  }

  static PageTransitionsTheme _buildPageTransitionsTheme(bool enablePredictiveBack) {
    return PageTransitionsTheme(
      builders: {
        // 未启用系统预返回时，全平台统一采用平滑横向侧滑转场（替代生硬的缩放转场）
        TargetPlatform.android: enablePredictiveBack
            ? const PredictiveBackPageTransitionsBuilder()
            : const CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: const CupertinoPageTransitionsBuilder(),
      },
    );
  }

  /// 组件主题统一收口：组件默认长相由这里决定，页面不再手写。
  static ThemeData _polish(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill = scheme.surfaceContainer;
    final sub = isDark ? textSubDark : textSubLight;
    final hint = isDark ? textHintDark : textHintLight;
    final noInputBorder = OutlineInputBorder(
      borderRadius: AppRadius.of(AppRadius.sm),
      borderSide: BorderSide.none,
    );

    return theme.copyWith(
      hintColor: hint,
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.of(AppRadius.lg)),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: AppTypography.title3,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: sub,
          fontSize: AppTypography.body,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: fill,
        hintStyle: TextStyle(color: hint, fontSize: AppTypography.body),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
        border: noInputBorder,
        enabledBorder: noInputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.of(AppRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: sub,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: AppTypography.body,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(color: sub, fontSize: AppTypography.body2),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: fill,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: sub, fontSize: AppTypography.footnote),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.of(AppRadius.md)),
        textStyle: TextStyle(color: scheme.onSurface, fontSize: AppTypography.body),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF2E2E36) : const Color(0xFF33353D),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.of(AppRadius.sm)),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: AppTypography.body2),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontSize: AppTypography.body, fontWeight: FontWeight.w600),
        ),
      ),
      // 不在全局覆写 backgroundColor/foregroundColor，避免劫持 FilledButton.tonal 的 tonal 配色；
      // 常规 FilledButton 会自动读取 ColorScheme.primary / onPrimary。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          textStyle: const TextStyle(fontSize: AppTypography.body, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: scheme.primary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          textStyle: const TextStyle(fontSize: AppTypography.body, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return hint;
          }
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return sub;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return fill;
          }
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return fill;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return scheme.outline;
        }),
      ),
    );
  }

  static ThemeData lightTheme({
    AppThemePreset preset = AppThemePreset.ink,
    bool enablePredictiveBack = false,
  }) {
    final primary = preset.lightPrimary;
    final secondary = preset.secondary;
    final onPrimary = contrastOnColor(primary);
    final onSecondary = contrastOnColor(secondary);
    final primaryContainer = Color.alphaBlend(primary.withValues(alpha: 0.14), cardLight);
    final secondaryContainer = Color.alphaBlend(secondary.withValues(alpha: 0.14), cardLight);

    return _polish(ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      pageTransitionsTheme: _buildPageTransitionsTheme(enablePredictiveBack),
      textTheme: AppTypography.build(textMainLight),
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: textMainLight,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: textMainLight,
        error: dangerLight,
        onError: Colors.white,
        surface: cardLight,
        onSurface: textMainLight,
        surfaceContainerLowest: cardLight,
        surfaceContainerLow: bgLight,
        surfaceContainer: surfaceLight,
        surfaceContainerHigh: const Color(0xFFE7E9EE),
        surfaceContainerHighest: const Color(0xFFE0E2E8),
        onSurfaceVariant: textSubLight,
        outline: const Color(0xFF7D828B),
        outlineVariant: dividerLight,
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardLight,
        elevation: 0,
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
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
      dividerTheme: const DividerThemeData(
        color: dividerLight,
        thickness: 0.6,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
    ));
  }

  static ThemeData darkTheme({
    AppThemePreset preset = AppThemePreset.ink,
    bool isAmoled = false,
    bool enablePredictiveBack = false,
  }) {
    final bg = isAmoled ? pureBlack : inkBg;
    final cardBg = isAmoled ? cardDarkAmoled : cardDark;
    final fillBg = isAmoled ? surfaceDarkAmoled : surfaceDark;
    final dividerColor = isAmoled ? dividerDarkAmoled : dividerDark;
    final primary = preset.darkPrimary;
    final secondary = preset.darkSecondary;
    final onPrimary = contrastOnColor(primary);
    final onSecondary = contrastOnColor(secondary);
    final primaryContainer = Color.alphaBlend(primary.withValues(alpha: 0.22), cardBg);
    final onPrimaryContainer = Color.lerp(primary, textMainDark, 0.45)!;
    final secondaryContainer = Color.alphaBlend(secondary.withValues(alpha: 0.20), cardBg);
    final onSecondaryContainer = Color.lerp(secondary, textMainDark, 0.45)!;

    return _polish(ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      pageTransitionsTheme: _buildPageTransitionsTheme(enablePredictiveBack),
      textTheme: AppTypography.build(textMainDark),
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        error: dangerDark,
        onError: darkOnAccent,
        surface: cardBg,
        onSurface: textMainDark,
        surfaceContainerLowest: bg,
        surfaceContainerLow: cardBg,
        surfaceContainer: fillBg,
        surfaceContainerHigh: isAmoled ? const Color(0xFF26262F) : fillHighlightDark,
        surfaceContainerHighest: isAmoled ? fillHighlightDarkAmoled : const Color(0xFF343440),
        onSurfaceVariant: textSubDark,
        outline: isAmoled ? const Color(0xFF6B6B7A) : const Color(0xFF6E6E7D),
        outlineVariant: dividerColor,
        inverseSurface: textMainDark,
        onInverseSurface: bg,
        inversePrimary: preset.lightPrimary,
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg,
        elevation: 0,
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
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 0.6,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
    ));
  }
}

extension BuildContextThemeExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
