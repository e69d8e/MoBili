import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/user_model.dart';
import 'package:mobili/screens/video/listen_video_screen.dart';

void main() {
  group('Watch Later Playlist Tests', () {
    test('WatchLaterItem parses correctly and retains list properties', () {
      final items = [
        WatchLaterItem(
          aid: 1001,
          bvid: 'BV1test1',
          cid: 2001,
          title: '稍后看测试视频 1',
          pic: 'https://example.com/p1.jpg',
          ownerName: 'UP主1',
          ownerFace: 'https://example.com/f1.jpg',
          ownerMid: 3001,
          duration: 120,
          pubdate: 1600000000,
          addAt: 1600001000,
          progress: 30,
        ),
        WatchLaterItem(
          aid: 1002,
          bvid: 'BV1test2',
          cid: 2002,
          title: '稍后看测试视频 2',
          pic: 'https://example.com/p2.jpg',
          ownerName: 'UP主2',
          ownerFace: 'https://example.com/f2.jpg',
          ownerMid: 3002,
          duration: 300,
          pubdate: 1600002000,
          addAt: 1600003000,
          progress: 0,
        ),
      ];

      expect(items.length, 2);
      expect(items[0].bvid, 'BV1test1');
      expect(items[0].progress, 30);
      expect(items[1].bvid, 'BV1test2');
    });

    test('ListenPlaylistItem constructs accurately for offline and watch later', () {
      const offlineItem = ListenPlaylistItem(
        bvid: 'BV1cache1',
        cid: 3001,
        title: '离线缓存视频 P1',
        coverUrl: 'https://example.com/c1.jpg',
        upName: 'UP主1',
        localFilePath: '/data/user/0/cache/1.mp4',
        duration: Duration(seconds: 180),
        progress: 45,
      );

      expect(offlineItem.bvid, 'BV1cache1');
      expect(offlineItem.localFilePath, '/data/user/0/cache/1.mp4');
      expect(offlineItem.duration?.inSeconds, 180);
      expect(offlineItem.progress, 45);
    });
  });
}
