import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/models/danmaku_model.dart';
import 'package:mobili/services/settings/danmaku_settings_service.dart';
import 'package:mobili/widgets/player/danmaku_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Danmaku Settings & Controller Persistence Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DanmakuSettingsService.init();
    });

    test('Defaults are enabled=true, opacity=0.65, fontSizeScale=1.0, areaRatio=0.5', () {
      expect(DanmakuSettingsService.enabled, isTrue);
      expect(DanmakuSettingsService.opacity, 0.65);
      expect(DanmakuSettingsService.fontSizeScale, 1.0);
      expect(DanmakuSettingsService.areaRatio, 0.5);

      final controller = DanmakuController();
      expect(controller.enabled, isTrue);
      expect(controller.opacity, 0.65);
      expect(controller.fontSizeScale, 1.0);
      expect(controller.areaRatio, 0.5);
    });

    test('DanmakuController toggle and setEnabled persists to DanmakuSettingsService', () async {
      final controller = DanmakuController();
      controller.toggle();
      expect(controller.enabled, isFalse);
      expect(DanmakuSettingsService.enabled, isFalse);

      // Verify that a new controller instance inherits the persisted disabled state
      final newController = DanmakuController();
      expect(newController.enabled, isFalse);

      // Re-enable
      newController.setEnabled(true);
      expect(newController.enabled, isTrue);
      expect(DanmakuSettingsService.enabled, isTrue);
    });

    test('DanmakuController opacity, font size, and area ratio persist', () async {
      final controller = DanmakuController();
      controller.setOpacity(0.85);
      controller.setFontSizeScale(1.2);
      controller.setAreaRatio(0.75);

      expect(DanmakuSettingsService.opacity, 0.85);
      expect(DanmakuSettingsService.fontSizeScale, 1.2);
      expect(DanmakuSettingsService.areaRatio, 0.75);

      final newController = DanmakuController();
      expect(newController.opacity, 0.85);
      expect(newController.fontSizeScale, 1.2);
      expect(newController.areaRatio, 0.75);
    });

    test('DanmakuItem equality and layout caching works deterministically', () {
      final item1 = DanmakuItem.fromXml('12.5,1,25,16777215,1600000000,0,abc', '测试弹幕');
      final item2 = DanmakuItem.fromXml('12.5,1,25,16777215,1600000000,0,abc', '测试弹幕');
      expect(item1, isNotNull);
      expect(item2, isNotNull);
      expect(item1 == item2, isTrue);
      expect(item1.hashCode, item2.hashCode);

      final controller = DanmakuController();
      final painter1 = controller.getOrCreatePainter(item1!);
      final painter2 = controller.getOrCreatePainter(item2!);
      expect(identical(painter1, painter2), isTrue);

      controller.dispose();
    });

    test('DanmakuController 2x speed timing and monotonicity test', () async {
      final controller = DanmakuController();
      controller.syncPlayerState(
        positionSeconds: 10.0,
        isPlaying: true,
        playbackSpeed: 2.0,
      );

      expect(controller.playbackSpeed, 2.0);
      expect(controller.isPlaying, isTrue);
      expect(controller.currentPositionSeconds, greaterThanOrEqualTo(10.0));

      await Future.delayed(const Duration(milliseconds: 60));
      final pos1 = controller.currentPositionSeconds;
      // At 2x speed, in ~60ms it should advance ~0.12s
      expect(pos1, greaterThan(10.05));

      // Simulate minor player position update drift (coarse platform update reporting 10.08)
      controller.syncPlayerState(
        positionSeconds: 10.08,
        isPlaying: true,
        playbackSpeed: 2.0,
      );

      // Current position must remain monotonic and not snap backwards
      final pos2 = controller.currentPositionSeconds;
      expect(pos2, greaterThanOrEqualTo(pos1));

      // Simulate major seek to 50.0s
      controller.syncPlayerState(
        positionSeconds: 50.0,
        isPlaying: true,
        playbackSpeed: 2.0,
      );
      expect(controller.currentPositionSeconds, greaterThanOrEqualTo(50.0));

      controller.dispose();
    });
  });
}
