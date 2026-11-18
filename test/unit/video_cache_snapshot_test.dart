import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/video_cache_model.dart';
import 'package:mobili/models/video_model.dart';

void main() {
  group('离线缓存详情快照', () {
    VideoDetail buildDetail() {
      return VideoDetail(
        videoItem: VideoItem(
          aid: 112233,
          bvid: 'BV1a2b3c4d',
          cid: 998877,
          title: 'Flutter 性能优化实战',
          pic: 'https://i0.hdslb.com/bfs/archive/cover.jpg',
          desc: '本期内容包含完整简介与 UP 信息',
          duration: 600,
          pubdate: 1700000000,
          ctime: 1699999000,
          owner: Owner(
            mid: 8888,
            name: 'Dart专家',
            face: 'https://i0.hdslb.com/bfs/face/up.jpg',
          ),
          stat: Stat(
            view: 50000,
            danmaku: 200,
            reply: 30,
            favorite: 120,
            coin: 88,
            share: 10,
            like: 999,
            hisRank: 42,
          ),
          rcmdReason: '热门推荐',
        ),
        pages: [
          VideoPage(
            cid: 998877,
            page: 1,
            from: 'vupload',
            part: 'P1',
            duration: 600,
            vid: 'vid1',
          ),
          VideoPage(
            cid: 998878,
            page: 2,
            from: 'vupload',
            part: 'P2',
            duration: 300,
          ),
        ],
      );
    }

    test('VideoDetail.toJson 经 JSON 往返后能完整还原', () {
      final original = buildDetail();
      final decoded =
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final restored = VideoDetail.fromJson(decoded);
      final item = restored.videoItem;

      expect(item.aid, equals(112233));
      expect(item.bvid, equals('BV1a2b3c4d'));
      expect(item.cid, equals(998877));
      expect(item.title, equals('Flutter 性能优化实战'));
      expect(item.pic, equals('https://i0.hdslb.com/bfs/archive/cover.jpg'));
      expect(item.desc, equals('本期内容包含完整简介与 UP 信息'));
      expect(item.duration, equals(600));
      expect(item.pubdate, equals(1700000000));
      expect(item.ctime, equals(1699999000));
      expect(item.owner.mid, equals(8888));
      expect(item.owner.name, equals('Dart专家'));
      expect(item.owner.face, equals('https://i0.hdslb.com/bfs/face/up.jpg'));
      expect(item.stat.view, equals(50000));
      expect(item.stat.danmaku, equals(200));
      expect(item.stat.reply, equals(30));
      expect(item.stat.favorite, equals(120));
      expect(item.stat.coin, equals(88));
      expect(item.stat.share, equals(10));
      expect(item.stat.like, equals(999));
      expect(item.stat.hisRank, equals(42));
      expect(item.rcmdReason, equals('热门推荐'));

      expect(restored.pages.length, equals(2));
      expect(restored.pages[0].cid, equals(998877));
      expect(restored.pages[0].part, equals('P1'));
      expect(restored.pages[0].vid, equals('vid1'));
      expect(restored.pages[1].part, equals('P2'));
      expect(restored.pages[1].vid, isNull);
    });

    test('copyWith 只替换本地已缓存的分 P，其余详情沿用快照', () {
      final original = buildDetail();
      final localPages = [
        VideoPage(
          cid: 998877,
          page: 1,
          from: 'vupload',
          part: '本地已缓存',
          duration: 600,
        ),
      ];
      final offline = original.copyWith(pages: localPages);

      expect(offline.pages.length, equals(1));
      expect(offline.pages.first.part, equals('本地已缓存'));
      expect(offline.videoItem.desc, equals(original.videoItem.desc));
      expect(offline.videoItem.owner.mid, equals(8888));
      expect(offline.videoItem.stat.view, equals(50000));
      // 原对象不受影响
      expect(original.pages.length, equals(2));
    });

    test('VideoCacheItem 保存并读回详情快照', () {
      final snapshot = jsonEncode(buildDetail().toJson());
      final item = VideoCacheItem(
        taskId: 'task_1',
        bvid: 'BV1a2b3c4d',
        cid: 998877,
        title: 'Flutter 性能优化实战',
        createdAt: 1700000000,
        status: VideoCacheStatus.completed,
        detailJsonRaw: snapshot,
      );

      final restored = VideoCacheItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(restored.detailJsonRaw, equals(snapshot));
      expect(
        VideoDetail.fromJson(
          jsonDecode(restored.detailJsonRaw) as Map<String, dynamic>,
        ).videoItem.owner.mid,
        equals(8888),
      );
    });

    test('老缓存条目缺少 detailJsonRaw 时回落空字符串', () {
      final legacyJson = <String, dynamic>{
        'taskId': 'task_old',
        'bvid': 'BVold',
        'cid': 1,
        'title': '旧缓存',
        'status': 'completed',
        'createdAt': 1600000000,
      };
      final restored = VideoCacheItem.fromJson(legacyJson);
      expect(restored.detailJsonRaw, isEmpty);
      expect(restored.copyWith(title: '改名').detailJsonRaw, isEmpty);
    });
  });
}
