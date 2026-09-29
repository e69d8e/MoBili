import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.parseTarget', () {
    test('https www.bilibili.com BV link', () {
      final t = DeepLinkService.parseTarget(
        Uri.parse(
            'https://www.bilibili.com/video/BV1GJ411x7h7/?spm_id_from=333.337'),
      );
      expect(t, isNotNull);
      expect(t!.bvid, 'BV1GJ411x7h7');
      expect(t.aid, isNull);
    });

    test('m.bilibili.com BV link with query', () {
      final t = DeepLinkService.parseTarget(
        Uri.parse('https://m.bilibili.com/video/BV1xx411c7mD?p=1&share_source=qq'),
      );
      expect(t, isNotNull);
      expect(t!.bvid, 'BV1xx411c7mD');
    });

    test('av link resolves to aid', () {
      final t = DeepLinkService.parseTarget(
        Uri.parse('https://www.bilibili.com/video/av170001'),
      );
      expect(t, isNotNull);
      expect(t!.bvid, isNull);
      expect(t.aid, 170001);
    });

    test('space.bilibili.com resolves to mid', () {
      final t = DeepLinkService.parseTarget(
        Uri.parse('https://space.bilibili.com/9469741/dynamic'),
      );
      expect(t, isNotNull);
      expect(t!.mid, 9469741);
    });

    test('search link resolves to keyword', () {
      final t = DeepLinkService.parseTarget(
        Uri.parse(
            'https://search.bilibili.com/all?keyword=%E6%89%8B%E4%B9%A6&order=click'),
      );
      expect(t, isNotNull);
      expect(t!.keyword, '手书');
    });

    test('custom scheme video requires valid bvid format', () {
      // 非法 bvid 不得注入路由/API 参数
      expect(
        DeepLinkService.parseTarget(Uri.parse('mobili://video?bvid=../../evil')),
        isNull,
      );
      final ok = DeepLinkService.parseTarget(
        Uri.parse('mobili://video?bvid=BV1GJ411x7h7'),
      );
      expect(ok, isNotNull);
      expect(ok!.bvid, 'BV1GJ411x7h7');
    });

    test('custom scheme space and search', () {
      final space = DeepLinkService.parseTarget(Uri.parse('mobili://space?mid=42'));
      expect(space, isNotNull);
      expect(space!.mid, 42);

      final search =
          DeepLinkService.parseTarget(Uri.parse('mobili://search?keyword=abc'));
      expect(search, isNotNull);
      expect(search!.keyword, 'abc');
    });

    test('unrecognized link returns null', () {
      expect(
        DeepLinkService.parseTarget(
          Uri.parse('https://www.bilibili.com/blackboard/topic.html'),
        ),
        isNull,
      );
      expect(
        DeepLinkService.parseTarget(Uri.parse('mobili://video?bvid=empty')),
        isNull,
      );
    });
  });
}
