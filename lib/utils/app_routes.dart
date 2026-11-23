import 'package:flutter/material.dart';

/// 统一路由动画工厂：常规页面沿用主题侧滑转场，听视频等沉浸面板使用模态上滑。
abstract final class AppRoutes {
  /// 常规入栈路由：继承 ThemeData.pageTransitionsTheme（各平台统一丝滑侧滑，或系统预返回）
  static Route<T> page<T>(Widget page) {
    return MaterialPageRoute<T>(builder: (_) => page);
  }

  /// 底部弹出模态路由：用于听视频等全屏播放器抽屉，配合下拉收起手势
  static Route<T> slideUpModal<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      barrierColor: Colors.black38,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}
