import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/video_cache_model.dart';
import 'package:mobili/services/storage/video_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoCacheModel & Service Tests', () {
    test('VideoCacheItem model serialization and status getters', () {
      final item = VideoCacheItem(
        taskId: 'BV1abc_12345',
        bvid: 'BV1abc',
        aid: 99999,
        cid: 12345,
        title: '测试视频',
        cover: 'http://example.com/cover.jpg',
        ownerName: '测试UP',
        ownerFace: 'http://example.com/face.jpg',
        pageTitle: 'P1 序章',
        pageIndex: 0,
        pageCount: 3,
        duration: 180,
        quality: 80,
        qualityDesc: '1080P 高清',
        localVideoPath: '/path/to/video.mp4',
        localDanmakuPath: '/path/to/danmaku.xml',
        status: VideoCacheStatus.downloading,
        totalBytes: 1000000,
        downloadedBytes: 450000,
        createdAt: 1600000000,
      );

      expect(item.progress, closeTo(0.45, 0.01));
      expect(item.isDownloading, isTrue);
      expect(item.isCompleted, isFalse);

      final json = item.toJson();
      expect(json['taskId'], equals('BV1abc_12345'));
      expect(json['status'], equals('downloading'));
      expect(json['totalBytes'], equals(1000000));

      final fromJson = VideoCacheItem.fromJson(json);
      expect(fromJson.taskId, equals(item.taskId));
      expect(fromJson.bvid, equals(item.bvid));
      expect(fromJson.cid, equals(item.cid));
      expect(fromJson.title, equals(item.title));
      expect(fromJson.status, equals(VideoCacheStatus.downloading));
      expect(fromJson.downloadedBytes, equals(450000));
    });

    test('VideoCacheService formatBytes formatting', () {
      expect(VideoCacheService.formatBytes(0), equals('0 B'));
      expect(VideoCacheService.formatBytes(512), equals('512 B'));
      expect(VideoCacheService.formatBytes(1024), equals('1.0 KB'));
      expect(VideoCacheService.formatBytes(1536), equals('1.5 KB'));
      expect(VideoCacheService.formatBytes(1048576), equals('1.0 MB'));
      expect(VideoCacheService.formatBytes(104857600), equals('100.0 MB'));
      expect(VideoCacheService.formatBytes(1073741824), equals('1.00 GB'));
    });
  });
}
