import 'dart:io' show Platform;

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
  /// Calculate appropriate number of columns based on viewport width
  static int calculateCrossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
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

  /// Calculate aspect ratio matching the calculated column count
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
