import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/utils/image_decode_sizing.dart';

void main() {
  group('ImageDecodeSizing.decodeWidthForDisplay', () {
    test('普通图片按显示宽度与 DPR 解码（上限内不做降采样）', () {
      // 768 逻辑像素宽、3x 屏 => 理想解码宽度 2304，被 maxWidth 限制到 1440
      final width = ImageDecodeSizing.decodeWidthForDisplay(
        displayWidth: 768,
        devicePixelRatio: 3.0,
        aspectRatio: 16 / 9,
      );
      expect(width, 1440);
    });

    test('长图按像素预算降采样，且不会超过高度上限', () {
      // 1080x4320 长图：像素预算 3MP => w <= sqrt(3MP * 0.25) ≈ 886
      final width = ImageDecodeSizing.decodeWidthForDisplay(
        displayWidth: 768,
        devicePixelRatio: 3.0,
        aspectRatio: 1080 / 4320,
      );
      expect(width, 886);
      expect(width * (width / (1080 / 4320)),
          lessThanOrEqualTo(ImageDecodeSizing.defaultMaxPixels.toDouble()));
    });

    test('极端长图受高度上限约束', () {
      const ratio = 1080 / 10800; // 1:10
      final width = ImageDecodeSizing.decodeWidthForDisplay(
        displayWidth: 768,
        devicePixelRatio: 3.0,
        aspectRatio: ratio,
      );
      expect(width * (width / ratio),
          lessThanOrEqualTo(ImageDecodeSizing.defaultMaxPixels.toDouble()));
      expect(width / ratio,
          lessThanOrEqualTo(ImageDecodeSizing.defaultMaxHeight.toDouble()));
    });

    test('极宽图片不会超过显示所需宽度', () {
      final width = ImageDecodeSizing.decodeWidthForDisplay(
        displayWidth: 360,
        devicePixelRatio: 2.0,
        aspectRatio: 5.0,
      );
      expect(width, 720);
    });

    test('缺少宽高信息时回退到显示宽度，且始终有下限', () {
      expect(
        ImageDecodeSizing.decodeWidthForDisplay(
          displayWidth: 0,
          devicePixelRatio: 1.0,
          aspectRatio: null,
        ),
        1080,
      );
      expect(
        ImageDecodeSizing.decodeWidthForDisplay(
          displayWidth: 400,
          devicePixelRatio: 2.0,
          aspectRatio: 0,
        ),
        800,
      );
      expect(
        ImageDecodeSizing.decodeWidthForDisplay(
          displayWidth: double.nan,
          devicePixelRatio: 0,
          aspectRatio: double.nan,
        ),
        1080,
      );
    });
  });
}
