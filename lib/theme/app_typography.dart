import 'package:flutter/material.dart';

/// 字阶。
///
/// 全项目只允许以下字号（整数刻度）：
/// 10 极小徽标 · 11 计数/日期 · 12 辅助说明 · 13 次要正文 · 14 主正文 ·
/// 15 强调正文 · 16 区块标题 · 17 页面标题（与 AppBar 一致）。
/// 颜色不走这里，用 `context.colors.*` 明确指定。
abstract final class AppTypography {
  static const double tiny = 10;
  static const double caption = 11;
  static const double footnote = 12;
  static const double body2 = 13;
  static const double body = 14;
  static const double body1 = 15;
  static const double title3 = 16;
  static const double title = 17;

  /// 构建 ThemeData.textTheme：只定字号/字重，颜色统一走 token。
  static TextTheme build(Color baseColor) {
    return const TextTheme(
      titleLarge: TextStyle(fontSize: title, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: title3, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: body, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: body1),
      bodyMedium: TextStyle(fontSize: body),
      bodySmall: TextStyle(fontSize: body2),
      labelLarge: TextStyle(fontSize: body, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: footnote),
      labelSmall: TextStyle(fontSize: caption),
    ).apply(bodyColor: baseColor, displayColor: baseColor);
  }
}
