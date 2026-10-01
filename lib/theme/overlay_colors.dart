import 'package:flutter/material.dart';

/// 播放器 / 图片查看器覆盖层专用色。
///
/// 覆盖层永远压在视频或图片之上，不随应用主题变化（恒暗），
/// 因此不使用 context.colors，统一从这里取值。
abstract final class OverlayColors {
  /// 悬浮控制条底
  static const Color bar = Color(0xE614141C);

  /// 进度气泡 / 胶囊提示底
  static const Color bubble = Color(0xD9101016);

  /// 圆形控件未激活底（如锁屏按钮）
  static const Color circle = Color(0x99101016);

  /// 浮动面板底（倍速 / 清晰度等）
  static const Color panel = Color(0xF0181820);

  /// 底部弹层底（弹幕设置等）
  static const Color sheet = Color(0xFF18181C);

  /// 弹层内未选中项底
  static const Color sheetItem = Color(0xFF262630);

  /// 图片查看器弹层底
  static const Color viewerSheet = Color(0xFF222228);
}
