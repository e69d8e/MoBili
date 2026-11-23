// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/dynamic_model.dart';
import 'package:mobili/models/play_url_model.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/providers/auth_provider.dart';
import 'package:mobili/providers/listen_video_provider.dart';
import 'package:mobili/providers/search_provider.dart';
import 'package:mobili/screens/search/search_screen.dart';
import 'package:mobili/screens/video/listen_video_screen.dart';
import 'package:mobili/screens/video/video_detail_screen.dart';
import 'package:mobili/services/player/bili_stream_proxy.dart';
import 'package:mobili/services/settings/player_settings_service.dart';
import 'package:mobili/services/player/system_media_control_service.dart';
import 'package:mobili/theme/app_theme.dart';
import 'package:mobili/utils/responsive_util.dart';
import 'package:mobili/widgets/dynamic_card.dart';
import 'package:mobili/widgets/network_image_view.dart';
import 'package:mobili/widgets/player/bili_video_player.dart';
import 'package:mobili/widgets/player/components/player_progress_bar.dart';
import 'package:mobili/widgets/video_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _FakePlayerState {
  final int id;
  final StreamController<VideoEvent> events =
      StreamController<VideoEvent>.broadcast();
  Duration position = const Duration(seconds: 20);
  Duration duration = const Duration(minutes: 2);
  bool playing = false;
  bool initializedSent = false;

  _FakePlayerState(this.id);
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextId = 1;
  final Map<int, _FakePlayerState> players = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    return createWithOptions(
      VideoCreationOptions(
        dataSource: dataSource,
        viewType: VideoViewType.textureView,
      ),
    );
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    players[id] = _FakePlayerState(id);
    return id;
  }

  @override
  Future<void> dispose(int textureId) async {
    final state = players.remove(textureId);
    await state?.events.close();
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {
    final p = players[textureId];
    if (p == null) return;
    p.playing = true;
    p.events.add(VideoEvent(eventType: VideoEventType.isPlayingStateUpdate, isPlaying: true));
  }

  @override
  Future<void> pause(int textureId) async {
    final p = players[textureId];
    if (p == null) return;
    p.playing = false;
    p.events.add(VideoEvent(eventType: VideoEventType.isPlayingStateUpdate, isPlaying: false));
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    players[textureId]?.position = position;
  }

  @override
  Future<Duration> getPosition(int textureId) async =>
      players[textureId]?.position ?? Duration.zero;

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    final state = players[textureId];
    if (state == null) return const Stream.empty();
    if (!state.initializedSent) {
      state.initializedSent = true;
      scheduleMicrotask(() {
        if (!state.events.isClosed) {
          state.events.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: state.duration,
              size: const Size(1280, 720),
            ),
          );
        }
      });
    }
    return state.events.stream;
  }

  @override
  Widget buildView(int textureId) => const SizedBox.shrink();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();
}

class _FakeListenVideoProvider extends ListenVideoProvider {
  bool pauseCalled = false;
  bool _fakePlaying = true;
  final int _fakeCid;
  final String _fakeBvid;

  _FakeListenVideoProvider({int cid = 12345, String bvid = 'BV1test'})
    : _fakeCid = cid,
      _fakeBvid = bvid;

  @override
  bool get hasAudio => true;

  @override
  bool get isPlaying => _fakePlaying;

  @override
  int? get cid => _fakeCid;

  @override
  String? get bvid => _fakeBvid;

  @override
  String? get title => '后台测试音频';

  @override
  String? get coverUrl => '';

  @override
  String? get upName => '测试UP';

  @override
  Future<void> pause() async {
    pauseCalled = true;
    _fakePlaying = false;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    _fakePlaying = true;
    notifyListeners();
  }

  @override
  Future<void> stopAndClear() async {
    _fakePlaying = false;
    notifyListeners();
  }
}

class _OfflineSearchProvider extends SearchProvider {
  String _kw = '';
  String _cat = 'video';
  String _ord = 'totalrank';
  bool _searched = false;
  final List<String> _hist = ['初始历史'];

  @override
  String get currentKeyword => _kw;

  @override
  String get currentCategory => _cat;

  @override
  String get currentOrder => _ord;

  @override
  bool get hasSearched => _searched;

  @override
  bool get isLoading => false;

  @override
  List<String> get history => _hist;

  @override
  Future<void> init() async {}

  @override
  Future<void> loadHotSearches() async {}

  @override
  Future<void> removeHistoryItem(String kw) async {
    _hist.remove(kw);
    notifyListeners();
  }

  @override
  Future<void> setCategory(String cat) async {
    _cat = cat == 'bili_user' ? 'user' : cat;
    notifyListeners();
  }

  @override
  Future<void> changeOrder(String order) async {
    _ord = order;
    notifyListeners();
  }

  @override
  Future<bool> search(String keyword, {String? order, String? category}) async {
    _kw = keyword.trim();
    if (order != null) _ord = order;
    if (category != null) {
      _cat = category == 'bili_user' ? 'user' : category;
    }
    _searched = true;
    if (!_hist.contains(_kw)) _hist.insert(0, _kw);
    notifyListeners();
    return true;
  }

  @override
  void resetSearch() {
    _kw = '';
    _searched = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyPlayUrl = PlayUrlInfo(
    currentQuality: 80,
    format: 'mp4',
    timelength: 120000,
    acceptQuality: [80],
    acceptDescription: ['1080P 高清'],
    durls: [
      PlayUrlDurl(
        order: 1,
        length: 120000,
        size: 1000,
        url: 'https://example.com/video.mp4',
        backupUrls: const [],
      ),
    ],
    supportFormats: const [],
    videoCodecid: 7,
  );

  VideoItem buildSampleVideo({String? rcmdReason}) {
    return VideoItem(
      aid: 1001,
      bvid: 'BV1xx411c7mD',
      cid: 2002,
      title: '这是一个用于验证两行标题与推荐角标在1.4倍大字体下也不会溢出的超长视频标题示例',
      pic: '',
      desc: '这是测试简介内容',
      duration: 185,
      pubdate: 1700000000,
      ctime: 1700000000,
      owner: Owner(mid: 99, name: '测试UP主名称很长时自动省略', face: ''),
      stat: Stat(view: 123456, danmaku: 789, reply: 42, like: 5000),
      rcmdReason: rcmdReason,
    );
  }

  late _FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerPlatform originalPlatform;
  late Directory proxyTempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PlayerSettingsService.init();
    SystemMediaControlService.instance.clearSessionBrightness();
    proxyTempDir = await Directory.systemTemp.createTemp('mobili_ux_test');
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

  group('Player Gesture & Desktop Guard Tests', () {
    testWidgets(
      'Single tap toggles controls with zero delay and desktop landscape stays non-fullscreen',
      (tester) async {
        final playerKey = GlobalKey<BiliVideoPlayerState>();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 450,
                child: BiliVideoPlayer(
                  key: playerKey,
                  playUrlInfo: dummyPlayUrl,
                  clock: () => tester.binding.clock.now(),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        expect(playerKey.currentState, isNotNull);
        // Desktop landscape never forces fullscreen automatically
        expect(playerKey.currentState!.isFullScreen, isFalse);
        // Controls initially visible
        expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

        // Single tap immediately toggles controls off (no 250ms delay wait)
        await tester.tapAt(const Offset(400, 225));
        await tester.pump();
        expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);

        // Advance past double-tap window then tap again to immediately bring controls back
        await tester.pump(const Duration(milliseconds: 280));
        await tester.tapAt(const Offset(400, 225));
        await tester.pump();
        expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

        // Drain controls hide timer before disposal
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'Double tap right edge seeks forward and double tap center triggers play/pause HUD',
      (tester) async {
        final playerKey = GlobalKey<BiliVideoPlayerState>();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 225,
                child: BiliVideoPlayer(
                  key: playerKey,
                  playUrlInfo: dummyPlayUrl,
                  clock: () => tester.binding.clock.now(),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        expect(playerKey.currentState!.controller?.value.isInitialized, isTrue);

        // Double tap on right zone (x = 385 out of 400, > 90% boundary)
        await tester.tapAt(const Offset(385, 112));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(const Offset(385, 112));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

        // Let HUD + ripple timers clear
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.byIcon(Icons.fast_forward_rounded), findsNothing);

        // Double tap on center triggers play/pause HUD cleanly
        await tester.tapAt(const Offset(200, 112));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(const Offset(200, 112));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('暂停'), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('VideoCard & Responsive Extent Tests', () {
    testWidgets(
      'VideoCard renders without overflow at 1.4x textScale and shows quick action sheet on more_vert tap',
      (tester) async {
        final video = buildSampleVideo(rcmdReason: '百万播放');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 640,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(360, 640),
                      textScaler: TextScaler.linear(1.4),
                    ),
                    child: Builder(
                      builder: (ctx) {
                        final extent =
                            ResponsiveGridConfig.calculateMainAxisExtent(
                              ctx,
                              availableWidth: 360,
                              crossAxisCount: 2,
                            );
                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: extent,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: 2,
                          itemBuilder: (_, idx) => VideoCard(
                            video: video,
                            showMoreMenu: true,
                            onNotInterested: () {},
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('百万播放'), findsWidgets);

        await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
        await tester.pumpAndSettle();

        expect(find.text('添加至稍后观看'), findsOneWidget);
        expect(find.textContaining('的空间'), findsOneWidget);
        expect(find.text('分享 / 复制链接'), findsOneWidget);
        expect(find.text('不感兴趣'), findsOneWidget);
      },
    );
  });

  group('SearchProvider & SearchScreen Contract Tests', () {
    test('SearchProvider normalizes bili_user to user and removes history items', () async {
      final realSp = SearchProvider();
      await realSp.setCategory('bili_user');
      expect(realSp.currentCategory, equals('user'));

      await realSp.addHistory('测试关键字');
      expect(realSp.history, contains('测试关键字'));
      await realSp.removeHistoryItem('测试关键字');
      expect(realSp.history, isNot(contains('测试关键字')));
    });

    testWidgets(
      'SearchScreen exposes swipeable tabs (视频/UP主/专栏) and stowed/danmaku order chips',
      (tester) async {
        final sp = _OfflineSearchProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<SearchProvider>.value(
            value: sp,
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: const SearchScreen(initialKeyword: 'Flutter'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('视频'), findsOneWidget);
        expect(find.text('UP主'), findsOneWidget);
        expect(find.text('专栏'), findsOneWidget);
        expect(find.text('最多弹幕'), findsOneWidget);
        expect(find.text('最多收藏'), findsOneWidget);

        await tester.tap(find.text('最多收藏'));
        await tester.pump();
        expect(sp.currentOrder, equals('stow'));

        await tester.tap(find.text('最多弹幕'));
        await tester.pump();
        expect(sp.currentOrder, equals('dm'));

        await tester.tap(find.text('UP主'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(sp.currentCategory, equals('user'));
      },
    );
  });

  group('DynamicCard Hero & Long Image Tests', () {
    test('resolveEffectiveUrl omits _1c center-crop suffix when disableServerCrop is true', () {
      const rawUrl = 'https://i0.hdslb.com/bfs/new_dyn/long_image.jpg';
      final cropped = NetworkImageView.resolveEffectiveUrl(
        rawUrl,
        cacheWidth: 400,
        cacheHeight: 400,
        disableServerCrop: false,
      );
      final uncropped = NetworkImageView.resolveEffectiveUrl(
        rawUrl,
        cacheWidth: 400,
        cacheHeight: 400,
        disableServerCrop: true,
      );

      expect(cropped, contains('_1c.webp'));
      expect(uncropped, isNot(contains('_1c.webp')));
    });

    testWidgets(
      'DynamicCard wires Hero tags for pictures and embedded video with disableServerCrop',
      (tester) async {
        final dynItem = DynamicItem(
          id: 'dyn123',
          type: 'DYNAMIC_TYPE_DRAW',
          author: DynamicAuthor(
            mid: 42,
            name: '动态测试作者',
            face: '',
            pubTime: '刚刚',
            pubAction: '投稿了动态',
          ),
          text: '一条长图+视频测试动态',
          pictures: const [
            DynamicPicture(
              url: 'https://i0.hdslb.com/bfs/new_dyn/long_pic.jpg',
              width: 600,
              height: 3000,
            ),
          ],
          video: DynamicVideo(
            aid: 777,
            bvid: 'BV1dy777',
            title: '动态内嵌视频',
            cover: 'https://i0.hdslb.com/bfs/archive/vid.jpg',
            desc: '',
            durationText: '01:23',
            playCount: '1万',
            danmakuCount: '50',
          ),
          stat: DynamicStat(commentCount: 5, likeCount: 12),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DynamicCard(item: dynItem),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byWidgetPredicate((w) => w is Hero && w.tag == 'dyn_dyn123_0'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is Hero && w.tag == 'dyn_vid_dyn123_BV1dy777',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is NetworkImageView &&
                w.url.contains('long_pic') &&
                w.disableServerCrop == true,
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('ListenVideoScreen Minimize & VideoDetailScreen Instant Render Tests', () {
    testWidgets(
      'Minimizing ListenVideoScreen pops route while keeping background playback active',
      (tester) async {
        final fakeProvider = _FakeListenVideoProvider(
          cid: 999,
          bvid: 'BV1listen',
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<ListenVideoProvider>.value(
            value: fakeProvider,
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => const ListenVideoScreen(
                              bvid: 'BV1listen',
                              cid: 999,
                              title: '后台测试音频',
                              coverUrl: '',
                              upName: '测试UP',
                            ),
                          ),
                        );
                      },
                      child: const Text('打开听视频'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('打开听视频'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('后台测试音频'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('打开听视频'), findsOneWidget);
        expect(fakeProvider.pauseCalled, isFalse);
        expect(fakeProvider.isPlaying, isTrue);
      },
    );

    testWidgets(
      'ListenVideoScreen Play/Pause button and BiliVideoPlayer accent keep high contrast in dark themes',
      (tester) async {
        final fakeProvider = _FakeListenVideoProvider(
          cid: 888,
          bvid: 'BV1dark',
        );

        for (final preset in [
          AppThemePreset.ink,
          AppThemePreset.biliPink,
          AppThemePreset.wisteria,
        ]) {
          final darkTheme = AppTheme.darkTheme(preset: preset);
          await tester.pumpWidget(
            ChangeNotifierProvider<ListenVideoProvider>.value(
              value: fakeProvider,
              child: MaterialApp(
                key: ValueKey('listen_${preset.key}'),
                theme: darkTheme,
                home: const ListenVideoScreen(
                  bvid: 'BV1dark',
                  cid: 888,
                  title: '暗色主题音频测试',
                  coverUrl: '',
                  upName: '测试UP',
                ),
              ),
            ),
          );
          await tester.pump();

          final pauseIcon = tester.widget<Icon>(find.byIcon(Icons.pause_rounded));
          expect(pauseIcon.color, darkTheme.colorScheme.onPrimary);
          expect(pauseIcon.color, isNot(Colors.white));
        }

        // BiliVideoPlayer 在 biliPink 与 wisteria 暗色模式下应保留主题色而非被误回退为白色
        for (final preset in [AppThemePreset.biliPink, AppThemePreset.wisteria]) {
          final darkTheme = AppTheme.darkTheme(preset: preset);
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('player_${preset.key}'),
              theme: darkTheme,
              home: Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 450,
                  child: BiliVideoPlayer(
                    key: ValueKey('bvp_${preset.key}'),
                    playUrlInfo: dummyPlayUrl,
                    clock: () => tester.binding.clock.now(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 200));

          final progressBar = tester.widget<PlayerProgressBar>(
            find.byType(PlayerProgressBar),
          );
          expect(
            progressBar.accent,
            preset.darkPrimary,
            reason: '${preset.key} dark mode accent should not fall back to white',
          );
          await tester.pump(const Duration(seconds: 5));
        }

        // 浅色水墨主色 #22242A 过暗，在播放器深底上仍应回退为高对比浅色
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('player_ink_light'),
            theme: AppTheme.lightTheme(preset: AppThemePreset.ink),
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 450,
                child: BiliVideoPlayer(
                  key: const ValueKey('bvp_ink_light'),
                  playUrlInfo: dummyPlayUrl,
                  clock: () => tester.binding.clock.now(),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        final inkLightProgressBar = tester.widget<PlayerProgressBar>(
          find.byType(PlayerProgressBar),
        );
        expect(inkLightProgressBar.accent, AppTheme.textMainDark);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'VideoDetailScreen renders initialVideo metadata immediately without full-screen spinner',
      (tester) async {
        final sample = VideoItem(
          aid: 555,
          bvid: 'BV1instant',
          cid: 0,
          title: '即时渲染标题',
          pic: '',
          desc: '无需全屏等待',
          duration: 120,
          pubdate: 1700000000,
          ctime: 1700000000,
          owner: Owner(mid: 12, name: '即时UP主', face: ''),
          stat: Stat(view: 1000, danmaku: 10, reply: 8, like: 50),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider<ListenVideoProvider>.value(
                value: _FakeListenVideoProvider(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: VideoDetailScreen(
                bvid: 'BV1instant',
                initialVideo: sample,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('正在加载视频详情...'), findsNothing);
        expect(find.text('即时渲染标题'), findsOneWidget);
        expect(find.text('即时UP主'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
