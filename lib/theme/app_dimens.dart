import 'package:flutter/material.dart';

/// 间距刻度（4 的倍数）。
///
/// 页面左右留白用 [lg]（16）；同组卡片间距用 [md]（12）；卡片内边距用 [md] / [lg]。
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;
}

/// 圆角刻度。
///
/// 小徽标用 [xs]（4），胶囊/小控件用 [sm]（8），卡片统一 [md]（12），
/// 大面板与对话框 [lg]（16），底部面板 [xl]（20），全圆角用 [pill]。
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  /// 全圆角（圆形/胶囊），用足够大的值。
  static const double pill = 999;

  /// 卡片圆角（全项目统一）。
  static BorderRadius get card => BorderRadius.circular(md);

  /// 底部面板顶部圆角。
  static BorderRadius get sheet =>
      const BorderRadius.vertical(top: Radius.circular(xl));

  static BorderRadius of(double value) => BorderRadius.circular(value);
}
