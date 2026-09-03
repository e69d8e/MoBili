import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/play_url_model.dart';
import 'package:mobili/models/video_model.dart';

void main() {
  group('VideoModel Unit Tests', () {
    group('Owner & Stat Tests', () {
      test('Owner fromJson and toJson handles string types and nulls', () {
        final owner1 = Owner.fromJson(null);
        expect(owner1.mid, equals(0));
        expect(owner1.name, isEmpty);
        expect(owner1.face, isEmpty);

        final owner2 = Owner.fromJson({
          'mid': '123456',
          'name': '科技UP',
          'face': 'https://i0.hdslb.com/avatar.jpg',
        });
        expect(owner2.mid, equals(123456));
        expect(owner2.name, equals('科技UP'));
        expect(owner2.face, equals('https://i0.hdslb.com/avatar.jpg'));

        final json = owner2.toJson();
        expect(json['mid'], equals(123456));
        expect(json['name'], equals('科技UP'));
      });

      test('Stat fromJson parses numbers and string fallbacks properly', () {
        final statDefault = Stat.fromJson(null);
        expect(statDefault.view, equals(0));
        expect(statDefault.danmaku, equals(0));
        expect(statDefault.like, equals(0));

        final statParsed = Stat.fromJson({
          'view': '10000',
          'danmaku': 500,
          'reply': '250',
          'favorite': 120,
          'coin': '88',
          'share': 10,
          'like': 999,
          'his_rank': 42,
        });
        expect(statParsed.view, equals(10000));
        expect(statParsed.danmaku, equals(500));
        expect(statParsed.reply, equals(250));
        expect(statParsed.favorite, equals(120));
        expect(statParsed.coin, equals(88));
        expect(statParsed.like, equals(999));
        expect(statParsed.hisRank, equals(42));
      });
    });

    group('VideoItem Parsing Tests', () {
      test('cleans HTML tags and fixes URL protocols', () {
        final json = {
          'aid': 112233,
          'bvid': 'BV1a2b3c4d',
          'cid': 998877,
          'title': '<em class="keyword">Flutter</em> 框架核心与性能实战',
          'pic': '//i0.hdslb.com/bfs/archive/cover1.jpg',
          'desc': '深入学习 Flutter 架构设计',
          'duration': 180,
          'pubdate': 1700000000,
          'ctime': 1700000000,
          'owner': {
            'mid': 8888,
            'name': 'Dart专家',
            'face': 'http://i0.hdslb.com/bfs/face/up.jpg',
          },
          'stat': {
            'view': 50000,
            'danmaku': 200,
          },
          'rcmd_reason': {'content': '热门推荐'},
        };

        final item = VideoItem.fromJson(json);
        expect(item.aid, equals(112233));
        expect(item.bvid, equals('BV1a2b3c4d'));
        expect(item.title, equals('Flutter 框架核心与性能实战'));
        expect(item.pic, equals('https://i0.hdslb.com/bfs/archive/cover1.jpg'));
        expect(item.duration, equals(180));
        expect(item.rcmdReason, equals('热门推荐'));
        expect(item.owner.name, equals('Dart专家'));
      });

      test('parses various duration string formats correctly', () {
        // mm:ss format
        final json1 = {
          'aid': 1,
          'bvid': 'BV1',
          'title': '测试1',
          'duration': '04:15',
        };
        expect(VideoItem.fromJson(json1).duration, equals(255));

        // hh:mm:ss format
        final json2 = {
          'aid': 2,
          'bvid': 'BV2',
          'title': '测试2',
          'duration': '01:10:05',
        };
        expect(VideoItem.fromJson(json2).duration, equals(4205));

        // string integer format
        final json3 = {
          'aid': 3,
          'bvid': 'BV3',
          'title': '测试3',
          'duration': '600',
        };
        expect(VideoItem.fromJson(json3).duration, equals(600));
      });

      test('supports search API fallback attributes', () {
        final searchJson = {
          'aid': 999,
          'bvid': 'BVsearch1',
          'title': '搜索结果视频',
          'cover': 'https://i2.hdslb.com/cover.jpg',
          'author': '搜索UP主',
          'mid': 54321,
          'up_face': 'https://i2.hdslb.com/up.jpg',
          'play': 12345,
          'video_review': 67,
          'rcmd_reason': '推荐原因纯文本',
        };

        final item = VideoItem.fromJson(searchJson);
        expect(item.owner.name, equals('搜索UP主'));
        expect(item.owner.mid, equals(54321));
        expect(item.owner.face, equals('https://i2.hdslb.com/up.jpg'));
        expect(item.stat.view, equals(12345));
        expect(item.stat.danmaku, equals(67));
        expect(item.rcmdReason, equals('推荐原因纯文本'));
      });
    });

    group('VideoDetail and Chapter Parsing Tests', () {
      test('parses video chapters from description timestamps via regex', () {
        final detailJson = {
          'aid': 100,
          'bvid': 'BVdetail1',
          'cid': 200,
          'title': '超长视频精读',
          'duration': 600,
          'desc': '本期视频时间轴：\n00:00 导语与背景\n01:30 第一阶段原理\n04:15 第二阶段实战演示\n08:30 结语总结',
          'pages': [
            {'cid': 200, 'page': 1, 'part': 'P1', 'duration': 600}
          ],
        };

        final detail = VideoDetail.fromJson(detailJson);
        expect(detail.pages.length, equals(1));
        expect(detail.pages.first.part, equals('P1'));

        // Should extract 4 chapters from description
        expect(detail.chapters.length, equals(4));

        expect(detail.chapters[0].from, equals(0));
        expect(detail.chapters[0].to, equals(90));
        expect(detail.chapters[0].title, equals('导语与背景'));

        expect(detail.chapters[1].from, equals(90));
        expect(detail.chapters[1].to, equals(255));
        expect(detail.chapters[1].title, equals('第一阶段原理'));

        expect(detail.chapters[2].from, equals(255));
        expect(detail.chapters[2].to, equals(510));
        expect(detail.chapters[2].title, equals('第二阶段实战演示'));

        expect(detail.chapters[3].from, equals(510));
        expect(detail.chapters[3].to, equals(600));
        expect(detail.chapters[3].title, equals('结语总结'));
      });

      test('VideoRelation parses boolean and numeric flag representations', () {
        final rel1 = VideoRelation.fromJson(null);
        expect(rel1.attention, isFalse);
        expect(rel1.favorite, isFalse);
        expect(rel1.like, isFalse);

        final rel2 = VideoRelation.fromJson({
          'attention': 1,
          'favorite': true,
          'like': 1,
          'dislike': false,
          'coin': 2,
        });
        expect(rel2.attention, isTrue);
        expect(rel2.favorite, isTrue);
        expect(rel2.like, isTrue);
        expect(rel2.dislike, isFalse);
        expect(rel2.coin, equals(2));
      });
    });

    group('PlayUrlInfo Parsing Tests', () {
      test('parses progressive durl play url info', () {
        final json = {
          'quality': 80,
          'format': 'mp4',
          'timelength': 180000,
          'accept_quality': [80, 64, 32, 16],
          'accept_description': ['1080P 高清', '720P 高清', '480P 清晰', '360P 流畅'],
          'durl': [
            {
              'order': 1,
              'length': 180000,
              'size': 25000000,
              'url': 'https://cn-video.bilibili.com/video.mp4',
              'backup_url': ['https://backup1.com/v.mp4', 'https://backup2.com/v.mp4'],
            }
          ],
          'support_formats': [
            {'quality': 80, 'format': 'mp4', 'new_description': '1080P 高清', 'display_desc': '1080P'},
            {'quality': 64, 'format': 'mp4', 'new_description': '720P 高清', 'display_desc': '720P'},
          ],
        };

        final playUrl = PlayUrlInfo.fromJson(json);
        expect(playUrl.currentQuality, equals(80));
        expect(playUrl.format, equals('mp4'));
        expect(playUrl.durls.length, equals(1));
        expect(playUrl.primaryVideoUrl, equals('https://cn-video.bilibili.com/video.mp4'));
        expect(playUrl.acceptQuality.length, equals(4));
        expect(playUrl.supportFormats.length, equals(2));
      });

      test('parses DASH pure audio and video streams', () {
        final json = {
          'quality': 80,
          'dash': {
            'video': [
              {
                'id': 80,
                'baseUrl': 'https://dash-video-1080p.m4s',
                'mimeType': 'video/mp4',
                'codecs': 'avc1.640028',
                'width': 1920,
                'height': 1080,
                'bandwidth': 3000000,
              },
            ],
            'audio': [
              {
                'id': 30280,
                'baseUrl': 'https://dash-audio-high.m4s',
                'mimeType': 'audio/mp4',
                'codecs': 'mp4a.40.2',
                'bandwidth': 320000,
              },
            ],
          },
        };

        final playUrl = PlayUrlInfo.fromJson(json);
        expect(playUrl.videoTracks.length, equals(1));
        expect(playUrl.audioTracks.length, equals(1));
        expect(playUrl.primaryAudioUrl, equals('https://dash-audio-high.m4s'));
        expect(playUrl.primaryVideoUrl, equals('https://dash-video-1080p.m4s'));
      });
    });
  });
}
