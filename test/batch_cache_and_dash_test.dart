import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/danmaku_model.dart';
import 'package:mobili/models/play_url_model.dart';
import 'package:mobili/models/video_cache_model.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/providers/auth_provider.dart';
import 'package:mobili/services/api/bili_http_client.dart';
import 'package:mobili/services/api/danmaku_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/utils/app_constants.dart';
import 'package:mobili/widgets/player/bili_video_player.dart';
import 'package:mobili/widgets/player/video_cache_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConstants Tests', () {
    test('Version display reflects dynamic version constant', () {
      expect(AppConstants.appVersion, equals('v1.0.5'));
      expect(AppConstants.appBuildNumber, equals(6));
      expect(AppConstants.versionDisplay, equals('v1.0.5 (Build 6)'));
    });
  });

  group('PlayUrlInfo DASH Tests', () {
    test('isDash is true when videoTracks and audioTracks are present', () {
      final info = PlayUrlInfo(
        currentQuality: 116,
        format: 'dash',
        timelength: 60000,
        acceptQuality: [116, 80, 64],
        acceptDescription: ['1080P 60帧', '1080P 高清', '720P 高清'],
        durls: [],
        supportFormats: [],
        videoTracks: [
          DashVideoItem(
            id: 116,
            baseUrl: 'https://upos.bilibili.com/video_1080p60.m4s',
            mimeType: 'video/mp4',
            codecs: 'avc1.640032',
            width: 1920,
            height: 1080,
            bandwidth: 3000000,
            backupUrls: [],
          ),
          DashVideoItem(
            id: 80,
            baseUrl: 'https://upos.bilibili.com/video_1080p.m4s',
            mimeType: 'video/mp4',
            codecs: 'avc1.640032',
            width: 1920,
            height: 1080,
            bandwidth: 1500000,
            backupUrls: [],
          ),
        ],
        audioTracks: [
          DashAudioItem(
            id: 30280,
            baseUrl: 'https://upos.bilibili.com/audio_320k.m4s',
            mimeType: 'audio/mp4',
            codecs: 'mp4a.40.2',
            bandwidth: 320000,
            backupUrls: [],
          ),
        ],
        videoCodecid: 7,
      );

      expect(info.isDash, isTrue);
      expect(info.primaryVideoUrl, equals('https://upos.bilibili.com/video_1080p60.m4s'));
      expect(info.getVideoUrlForQuality(80), equals('https://upos.bilibili.com/video_1080p.m4s'));
      expect(info.primaryAudioUrl, equals('https://upos.bilibili.com/audio_320k.m4s'));
    });

    test('isDash is false for legacy single-stream mp4 durl', () {
      final info = PlayUrlInfo(
        currentQuality: 80,
        format: 'mp4',
        timelength: 60000,
        acceptQuality: [80],
        acceptDescription: ['1080P 高清'],
        durls: [
          PlayUrlDurl(
            order: 1,
            length: 60000,
            size: 50000000,
            url: 'https://upos.bilibili.com/single_stream.mp4',
            backupUrls: [],
          ),
        ],
        supportFormats: [],
        videoTracks: [],
        audioTracks: [],
        videoCodecid: 7,
      );

      expect(info.isDash, isFalse);
      expect(info.primaryVideoUrl, equals('https://upos.bilibili.com/single_stream.mp4'));
      expect(info.primaryAudioUrl, equals('https://upos.bilibili.com/single_stream.mp4'));
    });

    test('getVideoUrlForQuality prioritizes AVC (avc1) track over AV1 (av01) and HEVC (hvc1)', () {
      final info = PlayUrlInfo(
        currentQuality: 80,
        format: 'dash',
        timelength: 60000,
        acceptQuality: [80],
        acceptDescription: ['1080P 高清'],
        durls: [],
        supportFormats: [],
        videoTracks: [
          DashVideoItem(
            id: 80,
            baseUrl: 'https://upos.bilibili.com/video_1080p_av1.m4s',
            mimeType: 'video/mp4',
            codecs: 'av01.0.08M.08.0.110.01.01.01.0',
            width: 1920,
            height: 1080,
            bandwidth: 1200000,
            backupUrls: [],
          ),
          DashVideoItem(
            id: 80,
            baseUrl: 'https://upos.bilibili.com/video_1080p_hevc.m4s',
            mimeType: 'video/mp4',
            codecs: 'hvc1.1.6.L120.90',
            width: 1920,
            height: 1080,
            bandwidth: 1400000,
            backupUrls: [],
          ),
          DashVideoItem(
            id: 80,
            baseUrl: 'https://upos.bilibili.com/video_1080p_avc.m4s',
            mimeType: 'video/mp4',
            codecs: 'avc1.640032',
            width: 1920,
            height: 1080,
            bandwidth: 1800000,
            backupUrls: [],
          ),
        ],
        audioTracks: [],
        videoCodecid: 7,
      );

      expect(info.getVideoUrlForQuality(80), equals('https://upos.bilibili.com/video_1080p_avc.m4s'));
      expect(info.primaryVideoUrl, equals('https://upos.bilibili.com/video_1080p_avc.m4s'));
    });

    test('isDash is false for progressive MP4 stream (fnval=0) and primaryVideoUrl returns durl', () {
      final info = PlayUrlInfo(
        currentQuality: 64,
        format: 'mp4',
        timelength: 60000,
        acceptQuality: [64, 16],
        acceptDescription: ['720P 高清', '360P 流畅'],
        durls: [
          PlayUrlDurl(
            order: 1,
            length: 60000,
            size: 15000000,
            url: 'https://upos.bilibili.com/video_720p.mp4',
            backupUrls: [],
          ),
        ],
        supportFormats: [],
        videoTracks: [],
        audioTracks: [],
        videoCodecid: 7,
      );

      expect(info.isDash, isFalse);
      expect(info.primaryVideoUrl, equals('https://upos.bilibili.com/video_720p.mp4'));
      expect(info.primaryAudioUrl, equals('https://upos.bilibili.com/video_720p.mp4'));
    });
  });

  group('VideoCacheModel Audio-Only Tests', () {
    test('Serialization and deserialization with isAudioOnly flag', () {
      final task = VideoCacheItem(
        taskId: 'test_audio_task',
        bvid: 'BV1AudioOnly',
        cid: 10001,
        title: '测试纯音频播客',
        cover: 'https://pic.bilibili.com/cover.jpg',
        pageTitle: 'P1',
        pageIndex: 0,
        quality: 0,
        qualityDesc: '纯音频',
        duration: 3600,
        createdAt: 1600000000,
        isAudioOnly: true,
      );

      final json = task.toJson();
      expect(json['isAudioOnly'], isTrue);

      final fromJsonTask = VideoCacheItem.fromJson(json);
      expect(fromJsonTask.isAudioOnly, isTrue);
      expect(fromJsonTask.qualityDesc, equals('纯音频'));

      final videoTask = task.copyWith(isAudioOnly: false, qualityDesc: '1080P 高清');
      expect(videoTask.isAudioOnly, isFalse);
      expect(videoTask.qualityDesc, equals('1080P 高清'));
    });

    test('VideoCacheItem correctly stores and serializes localAudioPath and audioUrl for DASH cache', () {
      final task = VideoCacheItem(
        taskId: 'BV1DashTest_12345',
        bvid: 'BV1DashTest',
        cid: 12345,
        title: 'DASH 1080P Video',
        quality: 80,
        qualityDesc: '1080P 高清',
        videoUrl: 'https://upos.bilibili.com/video.m4s',
        audioUrl: 'https://upos.bilibili.com/audio.m4s',
        localVideoPath: '/storage/video_BV1DashTest_12345.m4s',
        localAudioPath: '/storage/audio_BV1DashTest_12345.m4s',
        createdAt: 1600000000,
        status: VideoCacheStatus.completed,
      );

      final json = task.toJson();
      expect(json['localAudioPath'], equals('/storage/audio_BV1DashTest_12345.m4s'));
      expect(json['audioUrl'], equals('https://upos.bilibili.com/audio.m4s'));

      final restored = VideoCacheItem.fromJson(json);
      expect(restored.localAudioPath, equals('/storage/audio_BV1DashTest_12345.m4s'));
      expect(restored.audioUrl, equals('https://upos.bilibili.com/audio.m4s'));
      expect(restored.quality, equals(80));
      expect(restored.isCompleted, isTrue);
    });

    test('BiliPlayerValue immutable copyWith and defaults', () {
      const initial = BiliPlayerValue();
      expect(initial.isInitialized, isFalse);
      expect(initial.isPlaying, isFalse);
      expect(initial.isBuffering, isFalse);
      expect(initial.position, equals(Duration.zero));
      expect(initial.duration, equals(Duration.zero));
      expect(initial.aspectRatio, equals(16 / 9));

      final updated = initial.copyWith(
        isInitialized: true,
        isPlaying: true,
        position: const Duration(seconds: 45),
        duration: const Duration(minutes: 5),
        aspectRatio: 1.77,
      );
      expect(updated.isInitialized, isTrue);
      expect(updated.isPlaying, isTrue);
      expect(updated.position.inSeconds, equals(45));
      expect(updated.duration.inMinutes, equals(5));
      expect(updated.aspectRatio, closeTo(1.77, 0.01));
    });
  });

  group('Danmaku Deduplication Tests', () {
    test('Deduplicates by dmid and falls back to timePoint + text', () {
      final danmaku1 = DanmakuItem(
        timePoint: 10.5,
        mode: DanmakuMode.scroll,
        fontSize: 16,
        color: const Color(0xFFFFFFFF),
        timestamp: 1600000000,
        senderHash: 'abc',
        dmid: '9988776655',
        text: '前方高能！！！',
      );

      // Duplicate with same dmid
      final danmaku2 = DanmakuItem(
        timePoint: 10.5,
        mode: DanmakuMode.scroll,
        fontSize: 16,
        color: const Color(0xFFFFFFFF),
        timestamp: 1600000000,
        senderHash: 'abc',
        dmid: '9988776655',
        text: '前方高能！！！',
      );

      // Duplicate without dmid but same timePoint and text
      final danmaku3 = DanmakuItem(
        timePoint: 20.0,
        mode: DanmakuMode.scroll,
        fontSize: 16,
        color: const Color(0xFFFFFFFF),
        timestamp: 1600000000,
        senderHash: 'def',
        dmid: '',
        text: '2333333',
      );

      final danmaku4 = DanmakuItem(
        timePoint: 20.0,
        mode: DanmakuMode.scroll,
        fontSize: 16,
        color: const Color(0xFFFFFFFF),
        timestamp: 1600000001,
        senderHash: 'ghi',
        dmid: '',
        text: '2333333',
      );

      final uniqueDanmaku = DanmakuItem(
        timePoint: 35.0,
        mode: DanmakuMode.scroll,
        fontSize: 16,
        color: const Color(0xFFFFFFFF),
        timestamp: 1600000000,
        senderHash: 'xyz',
        dmid: '11223344',
        text: '完结撒花！',
      );

      final rawList = [danmaku1, danmaku2, danmaku3, danmaku4, uniqueDanmaku];
      final deduped = DanmakuService.deduplicateDanmakus(rawList);

      expect(deduped.length, equals(3));
      expect(deduped.map((d) => d.text).toList(), containsAll(['前方高能！！！', '2333333', '完结撒花！']));
    });
  });

  group('Cookie Expiration in AuthProvider Tests', () {
    test('isCookieExpired flag is exposed and accessible', () {
      final auth = AuthProvider();
      expect(auth.isCookieExpired, isFalse);
    });
  });

  group('Video Cache Quality & Login Permission Tests', () {
    test('VideoCacheItem copyWith retains downgraded quality and label correctly', () {
      final task = VideoCacheItem(
        taskId: 'test_task_1',
        bvid: 'BV1QualityCheck',
        cid: 10002,
        title: '测试画质降级处理',
        cover: 'https://pic.bilibili.com/cover.jpg',
        pageTitle: 'P1',
        pageIndex: 0,
        quality: 80,
        qualityDesc: '1080P 高清',
        duration: 120,
        createdAt: 1600000000,
      );

      // Verify initial quality
      expect(task.quality, equals(80));
      expect(task.qualityDesc, equals('1080P 高清'));

      // Simulate service-level automatic quality fallback when server only provides 720P
      final downgradedTask = task.copyWith(
        quality: 64,
        qualityDesc: '720P 高清 (权限自动适配)',
        status: VideoCacheStatus.completed,
      );

      expect(downgradedTask.quality, equals(64));
      expect(downgradedTask.qualityDesc, equals('720P 高清 (权限自动适配)'));
      expect(downgradedTask.status, equals(VideoCacheStatus.completed));
    });

    testWidgets('VideoCacheBottomSheet displays login status and prevents selecting 1080P when not logged in', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await BiliHttpClient().clearUserCookies();

      final videoItem = VideoItem(
        bvid: 'BV1TestQualityUI',
        aid: 12345,
        cid: 10001,
        title: '测试画质底部面板',
        desc: '测试描述',
        pic: 'https://pic.bilibili.com/cover.jpg',
        owner: Owner(mid: 1, name: 'UP主', face: ''),
        stat: Stat(view: 1000, danmaku: 50, reply: 10, favorite: 5, coin: 2, share: 1, like: 100),
        duration: 120,
        pubdate: 1600000000,
        ctime: 1600000000,
      );

      final detail = VideoDetail(
        videoItem: videoItem,
        pages: [
          VideoPage(cid: 10001, page: 1, from: 'vupload', part: 'P1 第一集', duration: 120),
        ],
      );

      final playUrlInfo = PlayUrlInfo(
        currentQuality: 80,
        format: 'mp4',
        timelength: 120000,
        acceptQuality: [80, 64, 32],
        acceptDescription: ['1080P 高清', '720P 高清', '480P 清晰'],
        durls: [],
        supportFormats: [
          SupportFormat(quality: 80, format: 'mp4', newDescription: '1080P 高清', displayDesc: '1080P'),
          SupportFormat(quality: 64, format: 'mp4', newDescription: '720P 高清', displayDesc: '720P'),
          SupportFormat(quality: 32, format: 'mp4', newDescription: '480P 清晰', displayDesc: '480P'),
        ],
        videoTracks: [],
        audioTracks: [],
        videoCodecid: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoCacheBottomSheet(
              detail: detail,
              playUrlInfo: playUrlInfo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect '未登录 (最高720P)' badge
      expect(find.text('未登录 (最高720P)'), findsOneWidget);
      // Expect '需登录' label on 1080P chip
      expect(find.text('1080P 高清'), findsOneWidget);
      expect(find.text('需登录'), findsOneWidget);

      // Tap on 1080P chip should trigger toast
      await tester.tap(find.text('1080P 高清'));
      await tester.pump();
      expect(find.textContaining('需登录哔哩哔哩账号'), findsOneWidget);

      // Settle toast timer (1300ms + animation)
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
    });

    testWidgets('VideoCacheBottomSheet displays logged-in status when logged in', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await BiliHttpClient().saveCookies({'SESSDATA': 'mock_sess_token'});

      final videoItem = VideoItem(
        bvid: 'BV1TestQualityUI2',
        aid: 12346,
        cid: 10002,
        title: '测试已登录面板',
        desc: '测试描述',
        pic: 'https://pic.bilibili.com/cover.jpg',
        owner: Owner(mid: 1, name: 'UP主', face: ''),
        stat: Stat(view: 1000, danmaku: 50, reply: 10, favorite: 5, coin: 2, share: 1, like: 100),
        duration: 120,
        pubdate: 1600000000,
        ctime: 1600000000,
      );

      final detail = VideoDetail(
        videoItem: videoItem,
        pages: [
          VideoPage(cid: 10002, page: 1, from: 'vupload', part: 'P1 第一集', duration: 120),
        ],
      );

      final playUrlInfo = PlayUrlInfo(
        currentQuality: 80,
        format: 'mp4',
        timelength: 120000,
        acceptQuality: [80, 64],
        acceptDescription: ['1080P 高清', '720P 高清'],
        durls: [],
        supportFormats: [
          SupportFormat(quality: 80, format: 'mp4', newDescription: '1080P 高清', displayDesc: '1080P'),
          SupportFormat(quality: 64, format: 'mp4', newDescription: '720P 高清', displayDesc: '720P'),
        ],
        videoTracks: [],
        audioTracks: [],
        videoCodecid: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoCacheBottomSheet(
              detail: detail,
              playUrlInfo: playUrlInfo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect '已登录 (支持1080P)' badge
      expect(find.text('已登录 (支持1080P)'), findsOneWidget);
      expect(find.text('需登录'), findsNothing);

      // Reset cookies after test
      await BiliHttpClient().clearUserCookies();
    });
  });
}
