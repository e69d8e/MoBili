import 'dart:math' as math;

/// 图片解码尺寸计算工具。
///
/// 图文详情里的长图（例如 1080x10800）如果按显示宽度原样解码，
/// 单张位图就要占用几十 MB；滚动时不断触发解码、图片缓存淘汰与 GC，
/// 表现为上下滑动明显卡顿。这里用一个「像素预算」给解码宽度封顶：
/// 始终保持原始宽高比（所以不会裁掉内容），只是限制分辨率上限。
class ImageDecodeSizing {
  const ImageDecodeSizing._();

  /// 单张图片解码像素预算（约 12MB / RGBA8888）。
  static const int defaultMaxPixels = 3 * 1024 * 1024;

  /// 解码宽度上限（物理像素）。
  static const int defaultMaxWidth = 1440;

  /// 解码高度上限（物理像素），避免生成超出常见 GPU 纹理上限的位图。
  static const int defaultMaxHeight = 4608;

  /// 解码宽度下限（物理像素），避免普通图片解码得过小。
  static const int defaultMinWidth = 96;

  /// 计算 [displayWidth]（逻辑像素）下应该使用的解码宽度（物理像素）。
  ///
  /// - [aspectRatio] 为图片原始宽高比（宽 / 高）；为空时按显示宽度计算理想值。
  /// - [maxPixels] 限制解码后的总像素数，长图会按比例缩小解码宽度。
  ///
  /// 返回值只会影响清晰度，不会改变显示时的宽高比。
  static int decodeWidthForDisplay({
    required double displayWidth,
    required double devicePixelRatio,
    double? aspectRatio,
    int maxPixels = defaultMaxPixels,
    int maxWidth = defaultMaxWidth,
    int maxHeight = defaultMaxHeight,
    int minWidth = defaultMinWidth,
  }) {
    final dpr = (devicePixelRatio.isFinite && devicePixelRatio > 0)
        ? devicePixelRatio
        : 2.0;
    final width = (displayWidth.isFinite && displayWidth > 0) ? displayWidth : 0.0;

    var idealWidth = (width * dpr).ceil();
    if (idealWidth <= 0) idealWidth = 1080;
    idealWidth = idealWidth.clamp(minWidth, maxWidth);

    if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) {
      return idealWidth;
    }

    // 解码像素数 = w * (w / aspectRatio) <= maxPixels
    final budgetWidth = math.sqrt(maxPixels * aspectRatio);
    final heightLimitedWidth = maxHeight * aspectRatio;
    final limited = math.min(budgetWidth, heightLimitedWidth);

    final target = math.min(idealWidth.toDouble(), limited).floor();
    return target < 1 ? 1 : target;
  }
}
