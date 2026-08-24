import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/dynamic_model.dart';

void main() {
  group('DynamicPicture Tests', () {
    test('DynamicPicture computes aspect ratio correctly', () {
      const pic = DynamicPicture(url: 'https://example.com/a.jpg', width: 1920, height: 1080);
      expect(pic.aspectRatio, closeTo(1.777, 0.001));
      expect(pic.isLongImage, isFalse);
    });

    test('DynamicPicture identifies long images correctly', () {
      const pic = DynamicPicture(url: 'https://example.com/long.jpg', width: 600, height: 1800);
      expect(pic.aspectRatio, closeTo(0.333, 0.001));
      expect(pic.isLongImage, isTrue);
    });

    test('DynamicPicture handles null dimensions gracefully', () {
      const pic = DynamicPicture(url: 'https://example.com/b.jpg');
      expect(pic.aspectRatio, isNull);
      expect(pic.isLongImage, isFalse);
    });

    test('DynamicPicture.fromJson parses DRAW item map', () {
      final json = {
        'src': '//i0.hdslb.com/bfs/new_dyn/abc.jpg',
        'width': 1080,
        'height': 1920,
        'size': 512.0,
      };
      final pic = DynamicPicture.fromJson(json);
      expect(pic.url, 'https://i0.hdslb.com/bfs/new_dyn/abc.jpg');
      expect(pic.width, 1080.0);
      expect(pic.height, 1920.0);
      expect(pic.size, 512.0);
      expect(pic.isLongImage, isFalse); // 1920/1080 = 1.77 < 2.0
    });

    test('DynamicPicture.fromJson parses OPUS pic map', () {
      final json = {
        'url': 'http://i0.hdslb.com/bfs/new_dyn/xyz.png',
        'width': 800,
        'height': 2400,
      };
      final pic = DynamicPicture.fromJson(json);
      expect(pic.url, 'https://i0.hdslb.com/bfs/new_dyn/xyz.png');
      expect(pic.width, 800.0);
      expect(pic.height, 2400.0);
      expect(pic.isLongImage, isTrue); // 2400/800 = 3.0 >= 2.0
    });
  });

  group('DynamicItem JSON Parsing Tests', () {
    test('DynamicItem parses MAJOR_TYPE_DRAW images', () {
      final json = {
        'id_str': '123456',
        'type': 'DYNAMIC_TYPE_DRAW',
        'modules': {
          'module_author': {'mid': 1001, 'name': 'Tester', 'face': ''},
          'module_stat': {'like': {'count': 10}},
          'module_dynamic': {
            'desc': {'text': 'Dynamic with draw pics'},
            'major': {
              'type': 'MAJOR_TYPE_DRAW',
              'draw': {
                'items': [
                  {'src': 'https://example.com/1.jpg', 'width': 1200, 'height': 800},
                  {'src': 'https://example.com/2.jpg', 'width': 600, 'height': 1500},
                ],
              },
            },
          },
        },
      };

      final item = DynamicItem.fromJson(json);
      expect(item.id, '123456');
      expect(item.text, 'Dynamic with draw pics');
      expect(item.pictures.length, 2);
      expect(item.images.length, 2);
      expect(item.pictures[0].url, 'https://example.com/1.jpg');
      expect(item.pictures[0].aspectRatio, closeTo(1.5, 0.01));
      expect(item.pictures[1].isLongImage, isTrue);
    });

    test('DynamicItem parses MAJOR_TYPE_OPUS images', () {
      final json = {
        'id_str': '654321',
        'type': 'DYNAMIC_TYPE_OPUS',
        'modules': {
          'module_author': {'mid': 1002, 'name': 'OpusTester'},
          'module_stat': {},
          'module_dynamic': {
            'major': {
              'type': 'MAJOR_TYPE_OPUS',
              'opus': {
                'summary': {'text': 'Opus content'},
                'pics': [
                  {'url': 'https://example.com/opus1.jpg', 'width': 1080, 'height': 1080},
                ],
              },
            },
          },
        },
      };

      final item = DynamicItem.fromJson(json);
      expect(item.id, '654321');
      expect(item.text, 'Opus content');
      expect(item.pictures.length, 1);
      expect(item.pictures[0].aspectRatio, 1.0);
      expect(item.pictures[0].isLongImage, isFalse);
    });
  });
}
