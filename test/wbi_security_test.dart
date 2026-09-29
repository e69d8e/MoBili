import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/api/bili_security_service.dart';
import 'package:mobili/utils/formatters.dart';
import 'package:mobili/models/danmaku_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Security & WBI Tests', () {
    test('Mixin Key generation works with fixed permutation table', () {
      final mixinKey = BiliSecurityService.getMixinKey(
        '7cd084941338484aae1ad9425b84077c',
        '4932caff0ff746eab6f01bf08b70ac45',
      );
      expect(mixinKey.length, 32);
    });

    test('WBI signing throws when keys are not initialized', () {
      final service = BiliSecurityService();
      service.resetForTesting();

      expect(
        () => service.signWbi({'keyword': 'Flutter', 'page': 1}),
        throwsStateError,
      );
    });

    test('WBI signing generates w_rid and wts after keys are set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BiliSecurityService();
      await service.updateWbiKeys(
        'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png',
        'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png',
      );

      final signed = service.signWbi({
        'keyword': 'Flutter',
        'page': 1,
      });

      expect(signed.containsKey('w_rid'), isTrue);
      expect(signed.containsKey('wts'), isTrue);
      expect(signed['keyword'], 'Flutter');
    });
  });

  group('Formatters Tests', () {
    test('formatCount formats wan and yi correctly', () {
      expect(Formatters.formatCount(500), '500');
      expect(Formatters.formatCount(12345), '1.2万');
      expect(Formatters.formatCount(123456789), '1.2亿');
    });

    test('formatDuration formats seconds to mm:ss or hh:mm:ss', () {
      expect(Formatters.formatDuration(0), '00:00');
      expect(Formatters.formatDuration(65), '01:05');
      expect(Formatters.formatDuration(3665), '01:01:05');
    });
  });

  group('Danmaku Parsing Tests', () {
    test('DanmakuItem parses XML p-attribute correctly', () {
      const pAttr = '12.345,1,25,16777215,1680000000,0,abcdef,123456789';
      const text = '弹幕测试内容';
      final item = DanmakuItem.fromXml(pAttr, text);

      expect(item, isNotNull);
      expect(item!.text, '弹幕测试内容');
      expect(item.timePoint, closeTo(12.345, 0.001));
      expect(item.mode, DanmakuMode.scroll);
    });
  });
}
