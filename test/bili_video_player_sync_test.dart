// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/play_url_model.dart';
import 'package:mobili/models/subtitle_model.dart';
import 'package:mobili/services/player/bili_stream_proxy.dart';
import 'package:mobili/services/settings/player_settings_service.dart';
import 'package:mobili/widgets/player/bili_video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _FakePlayerState {
  final int id;
  final String? uri;
  final StreamController<VideoEvent> events = StreamController<VideoEvent>.broadcast();
  Duration position = Duration.zero;
  Duration duration = const Duration(minutes: 3);
  bool playing = false;
  int playCount = 0;
  int pauseCount = 0;
  int seekCount = 0;
  Duration? lastSeekTarget;
  bool disposed = false;
  bool initializedSent = false;

  _FakePlayerState(this.id, this.uri);
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextId = 1;
  final Map<int, _FakePlayerState> players = {};
  final List<int> createdIds = [];
  bool failVideoInit = false;

  _FakePlayerState? get videoPlayer =>
      players.values
          .where((p) => !p.disposed && (p.uri ?? '').contains('video_'))
          .lastOrNull;

  _FakePlayerState? get audioPlayer =>
      players.values
          .where((p) => !p.disposed && (p.uri ?? '').contains('audio_'))
          .lastOrNull;

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    return createWithOptions(VideoCreationOptions(
      dataSource: dataSource,
      viewType: VideoViewType.textureView,
    ));
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    final state = _FakePlayerState(id, options.dataSource.uri);
    players[id] = state;
    createdIds.add(id);
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final state = players[playerId]!;
    if (!state.initializedSent) {
      state.initializedSent = true;
      // 必须在 videoEventsFor 订阅建立后再派发初始化事件，否则 broadcast 流会丢失事件
      scheduleMicrotask(() {
        if (state.disposed) return;
        if (failVideoInit && (state.uri ?? '').contains('video_')) {
          state.events.addError(
            PlatformException(
              code: 'init_error',
              message: 'simulated video init error',
            ),
          );
          return;
        }
        state.events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: state.duration,
            size: const Size(1920, 1080),
            rotationCorrection: 0,
          ),
        );
      });
    }
    return state.events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {
    final p = players[playerId];
    if (p == null || p.disposed) return;
    p.playing = true;
    p.playCount++;
    p.events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    final p = players[playerId];
    if (p == null || p.disposed) return;
    p.playing = false;
    p.pauseCount++;
    p.events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    final p = players[playerId];
    if (p == null || p.disposed) return;
    p.seekCount++;
    p.lastSeekTarget = position;
    p.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return players[playerId]?.position ?? Duration.zero;
  }

  @override
  Future<void> dispose(int playerId) async {
    final p = players[playerId];
    if (p != null) {
      p.disposed = true;
      await p.events.close();
    }
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return SizedBox(key: ValueKey('fake_video_view_${options.playerId}'));
  }

  void emitVideoBuffering(_FakePlayerState p, bool buffering) {
    p.events.add(
      VideoEvent(
        eventType:
            buffering ? VideoEventType.bufferingStart : VideoEventType.bufferingEnd,
      ),
    );
    p.playing = !buffering;
    p.events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: !buffering,
      ),
    );
  }
}

PlayUrlInfo _dashPlayUrl({String suffix = '1'}) {
  return PlayUrlInfo(
    currentQuality: 80,
    format: 'dash',
    timelength: 180000,
    acceptQuality: const [80, 64],
    acceptDescription: const ['1080P 高清', '720P 高清'],
    durls: const [],
    supportFormats: const [],
    videoTracks: [
      DashVideoItem(
        id: 80,
        baseUrl: 'https://upos.bilibili.com/v_$suffix.m4s',
        mimeType: 'video/mp4',
        codecs: 'avc1.640032',
        width: 1920,
        height: 1080,
        bandwidth: 2000000,
        backupUrls: const [],
      ),
    ],
    audioTracks: [
      DashAudioItem(
        id: 30280,
        baseUrl: 'https://upos.bilibili.com/a_$suffix.m4s',
        mimeType: 'audio/mp4',
        codecs: 'mp4a.40.2',
        bandwidth: 192000,
        backupUrls: const [],
      ),
    ],
    videoCodecid: 7,
    requestedQuality: 80,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late _FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerPlatform originalPlatform;
  late Directory proxyTempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PlayerSettingsService.init();
    proxyTempDir = await Directory.systemTemp.createTemp('mobili_player_sync_test');
    BiliStreamProxy().debugSetCacheDirectory(proxyTempDir.path);
    await BiliStreamProxy().start();
    originalPlatform = VideoPlayerPlatform.instance;
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    VideoPlayerPlatform.instance = originalPlatform;
    BiliStreamProxy().dispose();
    if (proxyTempDir.existsSync()) {
      await proxyTempDir.delete(recursive: true);
    }
  });

  testWidgets('DASH 视频缓冲时立即暂停伴音，缓冲结束后对齐续播', (tester) async {
    final playerKey = GlobalKey<BiliVideoPlayerState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiliVideoPlayer(
            key: playerKey,
            videoKey: 'BV1SyncTest_1',
            playUrlInfo: _dashPlayUrl(),
          ),
        ),
      ),
    );

    // 等待异步代理注册和双流初始化完成
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final video = fakePlatform.videoPlayer!;
    final audio = fakePlatform.audioPlayer!;
    expect(video.playing, isTrue);
    expect(audio.playing, isTrue);

    // 先让双流各自同步到 10s，随后让伴音相对视频超前 180ms（小于稳态 250ms 纠偏阈值、大于恢复对齐 120ms 阈值）
    video.position = const Duration(seconds: 10);
    audio.position = const Duration(seconds: 10);
    await tester.pump(const Duration(milliseconds: 120));
    audio.position = const Duration(milliseconds: 10180);
    await tester.pump(const Duration(milliseconds: 120));

    final pausesBefore = audio.pauseCount;

    fakePlatform.emitVideoBuffering(video, true);
    await tester.pump(const Duration(milliseconds: 50));

    expect(audio.pauseCount, greaterThan(pausesBefore),
        reason: '视频进入缓冲态时必须暂停伴音，杜绝画面卡住但声音继续播放');
    expect(audio.playing, isFalse);

    // 视频结束缓冲恢复播放，伴音应先对齐到 10s 再恢复
    final playsBefore = audio.playCount;
    final seeksBefore = audio.seekCount;
    fakePlatform.emitVideoBuffering(video, false);
    await tester.pump(const Duration(milliseconds: 100));

    expect(audio.seekCount, greaterThan(seeksBefore));
    expect(audio.lastSeekTarget, equals(const Duration(seconds: 10)));
    expect(audio.playCount, greaterThan(playsBefore));
    expect(audio.playing, isTrue);

    // 销毁前清理页面避免悬挂定时器
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });

  testWidgets('视频静默卡帧（isPlaying 为真但进度停滞、伴音继续走）时触发暂停伴音与自愈踢活',
      (tester) async {
    final playerKey = GlobalKey<BiliVideoPlayerState>();
    var fakeNow = DateTime(2026, 11, 18, 12, 0, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiliVideoPlayer(
            key: playerKey,
            videoKey: 'BV1FreezeTest_1',
            playUrlInfo: _dashPlayUrl(),
            clock: () => fakeNow,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final video = fakePlatform.videoPlayer!;
    final audio = fakePlatform.audioPlayer!;

    // 先推进一段正常进度，确认进入稳定播放
    video.position = const Duration(seconds: 5);
    audio.position = const Duration(seconds: 5);
    fakeNow = fakeNow.add(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // 模拟画面静默卡在 5s，同时伴音在走（跑到 6.2s）
    final videoSeeksBefore = video.seekCount;
    final audioPausesBefore = audio.pauseCount;
    audio.position = const Duration(milliseconds: 6200);
    fakeNow = fakeNow.add(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    // 推进模拟时钟超过 kVideoSilentFreezeWithAudioTimeout (1.5s) 并触发看门狗周期
    for (int i = 0; i < 4; i++) {
      fakeNow = fakeNow.add(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(audio.pauseCount, greaterThan(audioPausesBefore),
        reason: '发现视频静默卡帧时应先暂停伴音');
    expect(video.seekCount, greaterThan(videoSeeksBefore),
        reason: '第 1 次卡帧应触发原地 seek 踢活视频解码器');

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });

  testWidgets('启用字幕与切换全屏时不抛 ParentData 异常且保留播放器视图节点', (tester) async {
    final playerKey = GlobalKey<BiliVideoPlayerState>();
    final subtitleData = SubtitleData(
      track: SubtitleTrack(
        id: 1,
        lan: 'zh-CN',
        lanDoc: '中文',
        subtitleUrl: 'https://example.com/sub.json',
      ),
      items: [
        SubtitleItem(from: 0.0, to: 10.0, content: '第一句字幕测试'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiliVideoPlayer(
            key: playerKey,
            videoKey: 'BV1SubTest_1',
            playUrlInfo: _dashPlayUrl(),
            isSubtitleEnabled: true,
            subtitleData: subtitleData,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final video = fakePlatform.videoPlayer!;
    video.position = const Duration(seconds: 2);
    await tester.pump(const Duration(milliseconds: 150));

    // 激活字幕应正常渲染且无 Flutter ParentDataWidget 异常
    expect(find.text('第一句字幕测试'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 切换全屏：VideoPlayer 视图节点应保持存在且未被重新创建新的 playerId
    final createdBefore = fakePlatform.createdIds.length;
    playerKey.currentState!.enterFullScreen();
    await tester.pump();
    expect(fakePlatform.createdIds.length, equals(createdBefore));
    expect(find.byKey(ValueKey('fake_video_view_${video.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });

  testWidgets('播放报错且重试耗尽后 DASH 自动回退或展示重试提示，不再死卡画面',
      (tester) async {
    bool dashFallbackCalled = false;
    final playerKey = GlobalKey<BiliVideoPlayerState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiliVideoPlayer(
            key: playerKey,
            videoKey: 'BV1ErrTest_1',
            playUrlInfo: _dashPlayUrl(),
            onDashPlaybackFailed: () {
              dashFallbackCalled = true;
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // 连续触发报错直至超出最大恢复次数（第 4 次触发 DASH 降级回调）
    for (int i = 0; i < 4; i++) {
      for (int hop = 0;
          hop < 10 && playerKey.currentState?.controller == null;
          hop++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      final v = fakePlatform.videoPlayer;
      if (v != null && !v.disposed) {
        v.events.addError(
          PlatformException(code: 'decode_stalled', message: 'decode stalled'),
        );
      }
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(dashFallbackCalled, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });
}
