import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 语义化颜色入口。
///
/// 用 `context.colors.textSub` 取代 `isDark ? AppTheme.textSubDark : AppTheme.textSubLight`。
/// bg / card / divider 走 ThemeData 本身（AMOLED 自动生效），其余按明暗解析。
class AppColors {
  /// 页面背景
  final Color bg;

  /// 卡片 / 浮层表面
  final Color card;

  /// 弱填充（输入框、胶囊、分段控件底）
  final Color fill;

  /// 弱填充高光（骨架屏 shimmer 扫过层）
  final Color fillHighlight;

  /// 分割线
  final Color divider;

  /// 主文字
  final Color textMain;

  /// 次要文字
  final Color textSub;

  /// 提示文字（计数、日期、占位）
  final Color textHint;

  /// 主题主色
  final Color primary;

  /// 主色上的文字
  final Color onPrimary;

  /// 错误
  final Color error;

  /// 警告
  final Color warning;

  /// 危险操作
  final Color danger;

  /// 成功 / 已完成
  final Color success;

  const AppColors({
    required this.bg,
    required this.card,
    required this.fill,
    required this.fillHighlight,
    required this.divider,
    required this.textMain,
    required this.textSub,
    required this.textHint,
    required this.primary,
    required this.onPrimary,
    required this.error,
    required this.warning,
    required this.danger,
    required this.success,
  });

  factory AppColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AppColors(
      bg: theme.scaffoldBackgroundColor,
      card: theme.colorScheme.surface,
      fill: dark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      fillHighlight:
          dark ? AppTheme.fillHighlightDark : AppTheme.fillHighlightLight,
      divider: theme.dividerTheme.color ?? AppTheme.dividerLight,
      textMain: theme.colorScheme.onSurface,
      textSub: dark ? AppTheme.textSubDark : AppTheme.textSubLight,
      textHint: dark ? AppTheme.textHintDark : AppTheme.textHintLight,
      primary: theme.colorScheme.primary,
      onPrimary: theme.colorScheme.onPrimary,
      error: theme.colorScheme.error,
      warning: AppTheme.warning,
      danger: dark ? AppTheme.dangerDark : AppTheme.dangerLight,
      success: dark ? AppTheme.successDark : AppTheme.successLight,
    );
  }
}

extension AppColorsExt on BuildContext {
  AppColors get colors => AppColors.of(this);
}
