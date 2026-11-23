import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Platform and responsive screen utilities for MoBili
class ResponsiveUtil {
  /// Whether the platform is a desktop operating system (macOS, Windows, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// Whether the platform is a mobile device (Android, iOS)
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Whether current viewport width represents a tablet or wide device
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 && width < 960;
  }

  /// Whether current viewport width represents a desktop or wide landscape screen
  static bool isWideScreen(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 960;
  }

  /// Max readable width constraint for lists, forms and profile screens
  static const double maxContentWidth = 1120.0;
}

/// Adaptive grid layout configurations for video feeds
class ResponsiveGridConfig {
  /// Calculate column count for an explicit width (useful inside LayoutBuilder / NavigationRail shells)
  static int calculateCrossAxisCountForWidth(double width) {
    if (width < 600) {
      return 2; // Phones portrait / small screens
    } else if (width < 960) {
      return 3; // Tablets portrait / foldables / split screens
    } else if (width < 1320) {
      return 4; // Desktops standard / tablets landscape
    } else {
      return 5; // Wide monitors
    }
  }

  /// Calculate appropriate number of columns based on viewport width
  static int calculateCrossAxisCount(BuildContext context) {
    return calculateCrossAxisCountForWidth(MediaQuery.sizeOf(context).width);
  }

  /// Calculate aspect ratio matching the calculated column count (legacy fallback)
  static double calculateChildAspectRatio(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      return 0.95;
    } else if (width < 960) {
      return 0.98;
    } else {
      return 1.02;
    }
  }

  /// 计算随字号缩放与实际可用宽度自适应的卡片行高，防止大字体(1.4x)或窄屏下卡片底部文字溢出。
  static double calculateMainAxisExtent(
    BuildContext context, {
    double? availableWidth,
    double horizontalPadding = 24.0,
    double crossAxisSpacing = 10.0,
    int? crossAxisCount,
  }) {
    final width = availableWidth ?? MediaQuery.sizeOf(context).width;
    final cols = crossAxisCount ?? calculateCrossAxisCountForWidth(width);
    final cardWidth =
        ((width - horizontalPadding - crossAxisSpacing * (cols - 1)) / cols)
            .clamp(120.0, 600.0);
    // 封面比例统一 16 / 10，贴近国际版 B 站宽敞视觉
    final coverHeight = cardWidth / (16 / 10);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
    // 内边距(8+8) + 2行标题(13*1.35*2) + 间距(6) + UP主元信息行(最小24)
    final metaHeight =
        16.0 + (36.0 * textScale) + 6.0 + math.max(24.0, 18.0 * textScale);
    return coverHeight + metaHeight + 4.0;
  }
}

/// Helper widget to constrain and center wide layouts on ultra-wide desktop displays
class ResponsiveMaxConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveMaxConstraint({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveUtil.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
