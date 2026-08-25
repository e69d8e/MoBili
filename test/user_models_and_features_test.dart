import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/dynamic_model.dart';
import 'package:mobili/models/search_model.dart';
import 'package:mobili/models/user_model.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/services/api/api_endpoints.dart';

void main() {
  group('UserModel and History Tests', () {
    test('HistoryItem parses pic, cover, and // protocol properly', () {
      final json1 = {
        'title': '测试历史视频 1',
        'pic': 'http://i0.hdslb.com/bfs/archive/abc.jpg',
        'history': {
          'oid': 123456,
          'bvid': 'BV1xx411c7mD',
          'cid': 987654,
        },
        'author_name': '测试UP主',
        'author_mid': 10001,
        'view_at': 1700000000,
        'progress': 120,
        'duration': 300,
      };

      final item1 = HistoryItem.fromJson(json1);
      expect(item1.title, '测试历史视频 1');
      expect(item1.cover, 'https://i0.hdslb.com/bfs/archive/abc.jpg');
      expect(item1.bvid, 'BV1xx411c7mD');
      expect(item1.ownerName, '测试UP主');
      expect(item1.progress, 120);

      final json2 = {
        'title': '测试历史视频 2',
        'cover': '//i1.hdslb.com/bfs/archive/def.jpg',
        'oid': 654321,
        'bvid': 'BV1yy411c7mE',
        'owner': {
          'name': '另一个UP主',
          'mid': 10002,
        },
      };

      final item2 = HistoryItem.fromJson(json2);
      expect(item2.title, '测试历史视频 2');
      expect(item2.cover, 'https://i1.hdslb.com/bfs/archive/def.jpg');
      expect(item2.bvid, 'BV1yy411c7mE');
      expect(item2.ownerName, '另一个UP主');
    });

    test('RelationUser parses followings and followers correctly', () {
      final jsonFollower = {
        'mid': 12345,
        'uname': '粉丝小明',
        'face': 'http://i2.hdslb.com/bfs/face/xxx.jpg',
        'sign': '热爱生活',
        'vip': {
          'type': 2,
          'label': {'text': '年度大会员'},
        },
        'attribute': 0,
      };

      final relation1 = RelationUser.fromJson(jsonFollower, defaultFollowing: false);
      expect(relation1.mid, 12345);
      expect(relation1.uname, '粉丝小明');
      expect(relation1.face, 'https://i2.hdslb.com/bfs/face/xxx.jpg');
      expect(relation1.vipLabel, '年度大会员');
      expect(relation1.isFollowing, isFalse);

      final jsonFollowing = {
        'mid': 67890,
        'uname': '关注的大佬',
        'face': '//i0.hdslb.com/bfs/face/yyy.jpg',
        'sign': '知名UP主',
        'attribute': 2,
      };

      final relation2 = RelationUser.fromJson(jsonFollowing, defaultFollowing: true);
      expect(relation2.mid, 67890);
      expect(relation2.uname, '关注的大佬');
      expect(relation2.face, 'https://i0.hdslb.com/bfs/face/yyy.jpg');
      expect(relation2.isFollowing, isTrue);
    });

    test('WatchLaterItem parses properly', () {
      final json = {
        'aid': 888888,
        'bvid': 'BV1zz411c7mF',
        'cid': 55555,
        'title': '稍后观看测试视频',
        'pic': 'http://i0.hdslb.com/bfs/archive/watchlater.jpg',
        'duration': 600,
        'add_at': 1700001000,
        'progress': 60,
        'owner': {
          'name': '影视UP主',
          'face': '//i1.hdslb.com/bfs/face/up.jpg',
          'mid': 99999,
        },
      };

      final item = WatchLaterItem.fromJson(json);
      expect(item.aid, 888888);
      expect(item.bvid, 'BV1zz411c7mF');
      expect(item.title, '稍后观看测试视频');
      expect(item.pic, 'https://i0.hdslb.com/bfs/archive/watchlater.jpg');
      expect(item.ownerName, '影视UP主');
      expect(item.ownerFace, 'https://i1.hdslb.com/bfs/face/up.jpg');
      expect(item.duration, 600);
      expect(item.progress, 60);
    });

    test('DynamicItem parses video and text dynamics properly', () {
      final dynamicJson = {
        'id_str': '9876543210',
        'type': 'DYNAMIC_TYPE_AV',
        'modules': {
          'module_author': {
            'mid': 123456,
            'name': '动漫UP主',
            'face': '//i0.hdslb.com/bfs/face/avatar.jpg',
            'pub_time': '2小时前',
            'pub_action': '投稿了视频',
          },
          'module_dynamic': {
            'desc': {'text': '本期视频带来新番吐槽！'},
            'major': {
              'type': 'MAJOR_TYPE_ARCHIVE',
              'archive': {
                'aid': 112233,
                'bvid': 'BV1ab411c7xx',
                'title': '新番大盘点',
                'cover': 'http://i1.hdslb.com/bfs/archive/cover.jpg',
                'duration_text': '15:20',
                'stat': {'play': '10万', 'danmaku': '2333'},
              },
            },
          },
          'module_stat': {
            'comment': {'count': 88},
            'forward': {'count': 22},
            'like': {'count': 666, 'status': true},
          },
        },
      };

      final item = DynamicItem.fromJson(dynamicJson);
      expect(item.id, '9876543210');
      expect(item.author.name, '动漫UP主');
      expect(item.author.face, 'https://i0.hdslb.com/bfs/face/avatar.jpg');
      expect(item.text, '本期视频带来新番吐槽！');
      expect(item.video, isNotNull);
      expect(item.video!.title, '新番大盘点');
      expect(item.video!.cover, 'https://i1.hdslb.com/bfs/archive/cover.jpg');
      expect(item.video!.bvid, 'BV1ab411c7xx');
      expect(item.stat.likeCount, 666);
      expect(item.stat.isLiked, isTrue);
    });

    test('UgcSeason parses video collections correctly', () {
      final seasonJson = {
        'id': 1001,
        'title': 'Flutter全栈合集',
        'cover': 'http://i0.hdslb.com/bfs/season/cover.jpg',
        'mid': 8888,
        'intro': '完整的Flutter教程',
        'ep_count': 2,
        'sections': [
          {
            'season_id': 1001,
            'id': 2001,
            'title': '第一季',
            'episodes': [
              {
                'id': 3001,
                'aid': 4001,
                'bvid': 'BV1ep111',
                'cid': 5001,
                'title': '第1集 入门',
                'arc': {
                  'pic': '//i1.hdslb.com/bfs/arc/ep1.jpg',
                  'duration': 320,
                },
                'page': {'page': 1},
              },
              {
                'id': 3002,
                'aid': 4002,
                'bvid': 'BV1ep222',
                'cid': 5002,
                'title': '第2集 进阶',
                'arc': {
                  'pic': 'http://i1.hdslb.com/bfs/arc/ep2.jpg',
                  'duration': 450,
                },
                'page': {'page': 1},
              },
            ],
          }
        ],
      };

      final season = UgcSeason.fromJson(seasonJson);
      expect(season.id, 1001);
      expect(season.title, 'Flutter全栈合集');
      expect(season.cover, 'https://i0.hdslb.com/bfs/season/cover.jpg');
      expect(season.epCount, 2);
      expect(season.sections.length, 1);
      expect(season.sections.first.episodes.length, 2);
      expect(season.sections.first.episodes.first.bvid, 'BV1ep111');
      expect(season.sections.first.episodes.first.cover, 'https://i1.hdslb.com/bfs/arc/ep1.jpg');
      expect(season.sections.first.episodes.last.duration, 450);
    });

    test('SearchUserItem and SearchArticleItem parse correctly', () {
      final userJson = {
        'mid': 55555,
        'uname': '<em class="keyword">技术</em>大佬',
        'upic': '//i0.hdslb.com/bfs/face/avatar.jpg',
        'usign': '每日分享干货',
        'level': 6,
        'fans': 100000,
        'videos': 120,
        'official_verify': {'type': 0, 'desc': '知名科技UP主'},
      };

      final user = SearchUserItem.fromJson(userJson);
      expect(user.mid, 55555);
      expect(user.uname, '技术大佬');
      expect(user.upic, 'https://i0.hdslb.com/bfs/face/avatar.jpg');
      expect(user.level, 6);
      expect(user.fans, 100000);
      expect(user.isOfficial, isTrue);

      final articleJson = {
        'id': 77777,
        'title': '<em class="keyword">Flutter</em> 实战图文分享',
        'desc': '这是一篇关于Flutter开发的深度好文',
        'image_urls': ['//i1.hdslb.com/bfs/article/pic1.jpg', 'http://i2.hdslb.com/bfs/article/pic2.jpg'],
        'uname': '博主小张',
        'mid': 66666,
        'view': 5000,
        'like': 300,
        'reply': 45,
        'pub_time': 1700000000,
      };

      final article = SearchArticleItem.fromJson(articleJson);
      expect(article.id, 77777);
      expect(article.title, 'Flutter 实战图文分享');
      expect(article.imageUrls.length, 2);
      expect(article.imageUrls.first, 'https://i1.hdslb.com/bfs/article/pic1.jpg');
      expect(article.imageUrls.last, 'https://i2.hdslb.com/bfs/article/pic2.jpg');
      expect(article.uname, '博主小张');
      expect(article.view, 5000);
      expect(article.like, 300);
    });

    test('VideoRelation parses attention, favorite, like, coin properly', () {
      final json1 = {
        'attention': true,
        'favorite': false,
        'season_fav': false,
        'like': true,
        'dislike': false,
        'coin': 2,
      };

      final rel1 = VideoRelation.fromJson(json1);
      expect(rel1.attention, isTrue);
      expect(rel1.favorite, isFalse);
      expect(rel1.like, isTrue);
      expect(rel1.dislike, isFalse);
      expect(rel1.coin, 2);

      final json2 = {
        'attention': 0,
        'favorite': 1,
        'like': 0,
        'coin': 0,
      };

      final rel2 = VideoRelation.fromJson(json2);
      expect(rel2.attention, isFalse);
      expect(rel2.favorite, isTrue);
      expect(rel2.like, isFalse);
      expect(rel2.coin, 0);

      final relNull = VideoRelation.fromJson(null);
      expect(relNull.attention, isFalse);
      expect(relNull.favorite, isFalse);
      expect(relNull.like, isFalse);
      expect(relNull.coin, 0);
    });

    test('ApiEndpoints includes correct reply and coin endpoints', () {
      expect(ApiEndpoints.replyAdd, contains('/x/v2/reply/add'));
      expect(ApiEndpoints.coinVideo, contains('/x/web-interface/coin/add'));
      expect(ApiEndpoints.toViewList, contains('/x/v2/history/toview'));
    });

    test('VideoDetail parses official view_points chapters and desc timestamps correctly', () {
      // 1. Official view_points test
      final jsonOfficial = {
        'aid': 12345,
        'bvid': 'BV1chapter1',
        'cid': 67890,
        'title': '官方章节测试',
        'pic': 'http://i0.hdslb.com/bfs/archive/test.jpg',
        'desc': '这是视频简介',
        'duration': 600,
        'view_points': [
          {'from': 0, 'to': 90, 'content': '01 序言与简介'},
          {'from': 90, 'to': 300, 'content': '02 实操与演示'},
          {'from': 300, 'to': 600, 'content': '03 总结与展望'},
        ],
      };

      final detail1 = VideoDetail.fromJson(jsonOfficial);
      expect(detail1.chapters.length, 3);
      expect(detail1.chapters[0].title, '01 序言与简介');
      expect(detail1.chapters[0].from, 0);
      expect(detail1.chapters[0].to, 90);
      expect(detail1.chapters[1].from, 90);
      expect(detail1.chapters[2].from, 300);

      // 2. Fallback description timestamps test
      final jsonDescTimestamps = {
        'aid': 54321,
        'bvid': 'BV1chapter2',
        'cid': 98765,
        'title': '简介时间戳测试',
        'pic': 'http://i0.hdslb.com/bfs/archive/test2.jpg',
        'desc': '时间线一览：\n00:00 前言\n01:30 核心功能拆解\n05:45 性能评测\n10:20 总结',
        'duration': 700,
      };

      final detail2 = VideoDetail.fromJson(jsonDescTimestamps);
      expect(detail2.chapters.length, 4);
      expect(detail2.chapters[0].from, 0);
      expect(detail2.chapters[0].title, '前言');
      expect(detail2.chapters[1].from, 90);
      expect(detail2.chapters[1].title, '核心功能拆解');
      expect(detail2.chapters[2].from, 345);
      expect(detail2.chapters[2].title, '性能评测');
      expect(detail2.chapters[3].from, 620);
      expect(detail2.chapters[3].title, '总结');
    });

    test('HistoryItem parses nested progress correctly', () {
      final jsonNestedProgress = {
        'title': '测试嵌套进度',
        'pic': 'http://i0.hdslb.com/bfs/archive/nested.jpg',
        'history': {
          'oid': 11111,
          'bvid': 'BV1nested1',
          'cid': 22222,
          'progress': 155,
        },
        'owner': {'name': 'UP主', 'mid': 123},
        'view_at': 1700000000,
        'duration': 300,
      };

      final item = HistoryItem.fromJson(jsonNestedProgress);
      expect(item.progress, 155);
      expect(item.bvid, 'BV1nested1');
    });

    test('VideoDetail parses ugc_season collections correctly', () {
      final jsonSeason = {
        'aid': 12345,
        'bvid': 'BV1season1',
        'cid': 67890,
        'title': '合集视频测试',
        'pic': 'http://i0.hdslb.com/bfs/archive/test.jpg',
        'ugc_season': {
          'id': 999,
          'title': 'Flutter 全栈开发实战合集',
          'cover': 'http://i0.hdslb.com/bfs/archive/season.jpg',
          'ep_count': 3,
          'sections': [
            {
              'season_id': 999,
              'id': 1,
              'title': '第一部分：基础篇',
              'episodes': [
                {
                  'id': 101,
                  'aid': 10001,
                  'cid': 20001,
                  'title': '1. 环境搭建与快速上手',
                  'bvid': 'BV1ep01',
                  'arc': {'duration': 180},
                },
                {
                  'id': 102,
                  'aid': 10002,
                  'cid': 20002,
                  'title': '2. 状态管理深入剖析',
                  'bvid': 'BV1ep02',
                  'arc': {'duration': 360},
                },
              ],
            },
            {
              'season_id': 999,
              'id': 2,
              'title': '第二部分：进阶篇',
              'episodes': [
                {
                  'id': 103,
                  'aid': 10003,
                  'cid': 20003,
                  'title': '3. 性能优化与实战演练',
                  'bvid': 'BV1ep03',
                  'arc': {'duration': 540},
                },
              ],
            },
          ],
        },
      };

      final detail = VideoDetail.fromJson(jsonSeason);
      expect(detail.ugcSeason, isNotNull);
      expect(detail.ugcSeason!.title, 'Flutter 全栈开发实战合集');
      expect(detail.ugcSeason!.epCount, 3);
      expect(detail.ugcSeason!.sections.length, 2);
      final allEps = detail.ugcSeason!.sections.expand((s) => s.episodes).toList();
      expect(allEps.length, 3);
      expect(allEps[0].title, '1. 环境搭建与快速上手');
      expect(allEps[0].bvid, 'BV1ep01');
      expect(allEps[0].duration, 180);
      expect(allEps[1].bvid, 'BV1ep02');
      expect(allEps[2].title, '3. 性能优化与实战演练');
    });
  });
}


