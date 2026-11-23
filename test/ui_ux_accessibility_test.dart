import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/comment_model.dart';
import 'package:mobili/models/play_url_model.dart';
import 'package:mobili/models/search_model.dart';
import 'package:mobili/models/user_model.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/providers/home_provider.dart';
import 'package:mobili/providers/listen_video_provider.dart';
import 'package:mobili/providers/search_provider.dart';
import 'package:mobili/screens/dynamic/dynamic_screen.dart';
import 'package:mobili/screens/home/home_screen.dart';
import 'package:mobili/screens/search/search_screen.dart';
import 'package:mobili/screens/video/listen_video_screen.dart';
import 'package:mobili/services/player/system_media_control_service.dart';
import 'package:mobili/services/settings/player_settings_service.dart';
import 'package:mobili/theme/app_theme.dart';
import 'package:mobili/widgets/audio/mini_audio_player.dart';
import 'package:mobili/widgets/comment_item_widget.dart';
import 'package:mobili/widgets/player/bili_video_player.dart';
import 'package:mobili/widgets/skeleton_views.dart';
import 'package:mobili/widgets/video_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<VideoItem> _buildDummyVideos(String prefix, {int count = 16}) {
  return List.generate(
    count,
    (i) => VideoItem(
      aid: 1000 + i,
      bvid: 'BV1$prefix$i',
      cid: 2000 + i,
      title: '$prefix 测试视频 #$i',
      pic: '',
      desc: '',
      duration: 120,
      pubdate: 1700000000,
      ctime: 1700000000,
      owner: Owner(mid: 100 + i, name: 'UP主$i', face: ''),
      stat: Stat(view: 1000 + i, danmaku: 10),
    ),
  );
}

class _OfflineHomeProvider extends HomeProvider {
  List<VideoItem> _rcmd = const [];
  List<VideoItem> _pop = const [];
  List<VideoItem> _rank = const [];
  bool _loaded = false;

  @override
  List<VideoItem> get recommendVideos => _rcmd;

  @override
  List<VideoItem> get popularVideos => _pop;

  @override
  List<VideoItem> get rankingVideos => _rank;

  @override
  bool get rcmdLoaded => _loaded;

  @override
  bool get popularLoaded => _loaded;

  @override
  bool get rankingLoaded => _loaded;

  @override
  bool get rcmdHasMore => false;

  @override
  bool get popularHasMore => false;

  void populateAll() {
    _rcmd = _buildDummyVideos('rcmd');
    _pop = _buildDummyVideos('pop');
    _rank = _buildDummyVideos('rank');
    _loaded = true;
    notifyListeners();
  }

  @override
  Future<bool> loadRecommendFeed({bool isRefresh = false}) async => true;

  @override
  Future<bool> loadPopularVideos({bool isRefresh = false}) async => true;

  @override
  Future<bool> loadRankingVideos() async => true;
}

class _OfflineSearchProvider extends SearchProvider {
  String _cat = 'video';
  bool _hasSearched = false;
  List<VideoItem> _videos = const [];
  List<SearchUserItem> _users = const [];
  List<SearchArticleItem> _articles = const [];

  @override
  List<SearchHotItem> get hotSearches => const [];

  @override
  String get currentKeyword => '测试';

  @override
  String get currentCategory => _cat;

  @override
  bool get hasSearched => _hasSearched;

  @override
  bool get hasMore => false;

  @override
  List<VideoItem> get searchResults => _videos;

  @override
  List<SearchUserItem> get searchUsers => _users;

  @override
  List<SearchArticleItem> get searchArticles => _articles;

  void setSeededResults() {
    _hasSearched = true;
    _videos = _buildDummyVideos('srch', count: 6);
    _users = List.generate(
      4,
      (i) => SearchUserItem(
        mid: i + 1,
        uname: '用户$i',
        usign: '签名$i',
        fans: 100,
        videos: 5,
        upic: '',
        level: 4,
      ),
    );
    _articles = List.generate(
      4,
      (i) => SearchArticleItem(
        id: i + 1,
        mid: i + 10,
        title: '专栏文章$i',
        desc: '摘要$i',
        uname: '作者$i',
        view: 500,
        like: 20,
        reply: 2,
        imageUrls: const [],
        pubTime: 1700000000,
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> loadHotSearches() async {}

  @override
  Future<void> setCategory(String cat) async {
    _cat = cat;
    notifyListeners();
  }

  @override
  Future<bool> search(
    String keyword, {
    String? category,
    String? order,
    int? pn,
    bool forceRefresh = false,
  }) async => true;
}

class _TestListenVideoProvider extends ListenVideoProvider {
  @override
  bool get hasAudio => true;

  @override
  bool get isPlaying => true;

  @override
  int? get cid => 1001;

  @override
  String? get bvid => 'BV1uiux';

  @override
  String? get title => '无障碍测试音频';

  @override
  String? get coverUrl => '';

  @override
  String? get upName => '测试UP主';

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> stopAndClear() async {}
}

PlayUrlInfo _dummyPlayUrl() => PlayUrlInfo(
  currentQuality: 80,
  format: 'mp4',
  timelength: 60000,
  acceptQuality: [80],
  acceptDescription: ['1080P 高清'],
  durls: [
    PlayUrlDurl(
      order: 1,
      length: 60000,
      size: 1000,
      url: 'https://example.com/video.mp4',
      backupUrls: const [],
    ),
  ],
  supportFormats: const [],
  videoCodecid: 7,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI/UX Accessibility, Touch Targets & Text Scaling', () {
    testWidgets(
      'MiniAudioPlayer exposes accessible tooltips and >= 44x44 touch targets',
      (tester) async {
        final provider = _TestListenVideoProvider();
        await tester.pumpWidget(
          ChangeNotifierProvider<ListenVideoProvider>.value(
            value: provider,
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: const Scaffold(bottomNavigationBar: MiniAudioPlayer()),
            ),
          ),
        );
        await tester.pump();

        final playBtn = find.byTooltip('暂停');
        final closeBtn = find.byTooltip('关闭后台播放');
        expect(playBtn, findsOneWidget);
        expect(closeBtn, findsOneWidget);

        final playSize = tester.getSize(playBtn);
        final closeSize = tester.getSize(closeBtn);
        expect(playSize.width, greaterThanOrEqualTo(44.0));
        expect(playSize.height, greaterThanOrEqualTo(44.0));
        expect(closeSize.width, greaterThanOrEqualTo(44.0));
        expect(closeSize.height, greaterThanOrEqualTo(44.0));
      },
    );

    testWidgets(
      'ListenVideoScreen respects disableAnimations and keeps >= 44px transport targets',
      (tester) async {
        final provider = _TestListenVideoProvider();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(412, 915),
              disableAnimations: true,
            ),
            child: ChangeNotifierProvider<ListenVideoProvider>.value(
              value: provider,
              child: MaterialApp(
                theme: AppTheme.darkTheme(),
                home: const ListenVideoScreen(
                  bvid: 'BV1uiux',
                  cid: 1001,
                  title: '测试音频',
                  coverUrl: '',
                  upName: '测试UP',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final prevSize = tester.getSize(find.byTooltip('后退 15 秒'));
        final nextSize = tester.getSize(find.byTooltip('快进 15 秒'));
        expect(prevSize.width, greaterThanOrEqualTo(44.0));
        expect(prevSize.height, greaterThanOrEqualTo(44.0));
        expect(nextSize.width, greaterThanOrEqualTo(44.0));
        expect(nextSize.height, greaterThanOrEqualTo(44.0));
        expect(find.byTooltip('暂停'), findsOneWidget);

        // disableAnimations 下黑胶旋转 ticker 不再触发无限重绘，可正常 settle
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'CommentItemWidget and DynamicUpFilterStrip handle 1.4x text scaling without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final comment = CommentItem(
          rpid: 1,
          oid: 100,
          mid: 42,
          root: 0,
          parent: 0,
          count: 1,
          rcount: 1,
          like: 88,
          ctime: 1700000000,
          message: '这是一条测试评论内容，检查高文字缩放与窄屏兼容性。',
          member: CommentMember(
            mid: 42,
            uname: '一个名字非常非常长的测试用户昵称用于验证横向不溢出',
            avatar: '',
            level: 5,
          ),
          replies: [
            CommentItem(
              rpid: 2,
              oid: 100,
              mid: 43,
              root: 1,
              parent: 1,
              count: 0,
              rcount: 0,
              like: 0,
              ctime: 1700000100,
              message: '楼中楼回复内容',
              member: CommentMember(
                mid: 43,
                uname: '回复者',
                avatar: '',
                level: 4,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme(preset: AppThemePreset.biliPink),
              home: Scaffold(
                body: Column(
                  children: [
                    DynamicUpFilterStrip(
                      followings: [
                        RelationUser(
                          mid: 1,
                          uname: '测试博主A',
                          face: '',
                          sign: '',
                        ),
                      ],
                      selectedHostMid: null,
                      primaryColor: AppThemePreset.biliPink.lightPrimary,
                      onSelectAll: () {},
                      onSelectHost: (_) {},
                    ),
                    CommentItemWidget(comment: comment, onReplyTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byTooltip('点赞'), findsOneWidget);
        expect(find.byTooltip('回复'), findsOneWidget);
        expect(
          tester.getSize(find.byTooltip('点赞')).width,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          tester.getSize(find.byTooltip('回复')).width,
          greaterThanOrEqualTo(44.0),
        );
      },
    );

    testWidgets('VideoCard exposes accessible more menu tooltip and semantics', (
      tester,
    ) async {
      final video = VideoItem(
        aid: 10,
        bvid: 'BV1card',
        cid: 11,
        title: '高可读性浅色主题与触控测试视频标题两行截断测试',
        pic: '',
        desc: '',
        duration: 125,
        pubdate: 1700000000,
        ctime: 1700000000,
        owner: Owner(mid: 7, name: '测试UP主', face: ''),
        stat: Stat(view: 1024, danmaku: 12),
        rcmdReason: '已关注',
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.4),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: AppTheme.lightTheme(preset: AppThemePreset.biliPink),
            home: Scaffold(
              body: SizedBox(
                width: 190,
                height: 220,
                child: VideoCard(video: video, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('更多选项'), findsOneWidget);
    });
  });

  group('BiliVideoPlayer Desktop Keyboard Shortcuts', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PlayerSettingsService.init();
      await SystemMediaControlService.instance.setVolume(1.0);
    });

    testWidgets(
      'F toggles fullscreen, Up/Down adjusts volume, and Escape exits fullscreen',
      (tester) async {
        final playerKey = GlobalKey<BiliVideoPlayerState>();
        bool fullScreenCallbackValue = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 450,
                child: BiliVideoPlayer(
                  key: playerKey,
                  playUrlInfo: _dummyPlayUrl(),
                  clock: () => tester.binding.clock.now(),
                  onFullScreenChanged: (full) => fullScreenCallbackValue = full,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.pump();
        expect(playerKey.currentState!.isFullScreen, isTrue);
        expect(fullScreenCallbackValue, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(playerKey.currentState!.currentVolume, closeTo(0.9, 0.01));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(playerKey.currentState!.currentVolume, closeTo(1.0, 0.01));

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(playerKey.currentState!.isFullScreen, isFalse);
        expect(fullScreenCallbackValue, isFalse);

        // 等待内置自动隐藏与音量 HUD 定时器结束，避免残留 pending timer
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('Player shortcuts do not hijack keystrokes while typing in TextField', (
      tester,
    ) async {
      final playerKey = GlobalKey<BiliVideoPlayerState>();
      final textController = TextEditingController();
      addTearDown(textController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: textController),
                SizedBox(
                  width: 800,
                  height: 360,
                  child: BiliVideoPlayer(
                    key: playerKey,
                    playUrlInfo: _dummyPlayUrl(),
                    clock: () => tester.binding.clock.now(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(playerKey.currentState!.isFullScreen, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ScrollController Multi-Attach & PrimaryScrollController Safety', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
      testWidgets(
        'HomeScreen multi-tab KeepAlive and refresh-to-top never throw _positions.length == 1 ($platform)',
        (tester) async {
          final homeProvider = _OfflineHomeProvider();
          final searchProvider = _OfflineSearchProvider();
          final homeKey = GlobalKey<HomeScreenState>();

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<HomeProvider>.value(value: homeProvider),
                ChangeNotifierProvider<SearchProvider>.value(
                  value: searchProvider,
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme().copyWith(platform: platform),
                home: HomeScreen(key: homeKey),
              ),
            ),
          );
          await tester.pump();

          // 顶栏已移除刷新按钮，仅保留搜索与稍后观看入口
          expect(find.byTooltip('换一换'), findsNothing);
          expect(find.byIcon(Icons.refresh_rounded), findsNothing);
          expect(find.byTooltip('稍后观看'), findsOneWidget);

          // 1. 骨架加载态触发回顶/刷新，不因 VideoGridSkeleton 复用 PrimaryScrollController 崩溃
          unawaited(homeKey.currentState!.refreshAndScrollToTop());
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          // 2. 加载真实数据并切换 推荐 -> 热门 -> 排行榜，使 TabBarView 保活多个内层 ScrollPosition
          homeProvider.populateAll();
          await tester.pump();

          await tester.drag(find.byType(TabBarView), const Offset(0, -240));
          await tester.pump();

          await tester.tap(find.text('热门'));
          await tester.pumpAndSettle();

          await tester.drag(find.byType(TabBarView), const Offset(0, -240));
          await tester.pump();

          // 3. 多 tab 保活状态下重复触发回顶与刷新，不触发 ScrollController attached to multiple scroll views
          // 注意：animateTo / RefreshIndicator.show 需要测试泵帧驱动，不能直接同步 await
          unawaited(homeKey.currentState!.refreshAndScrollToTop());
          await tester.pump();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          unawaited(homeKey.currentState!.refreshAndScrollToTop());
          await tester.pump();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'CommentSkeleton inside CustomScrollView and SearchScreen TabBarView keep single ScrollPositions',
      (tester) async {
        late BuildContext capturedCtx;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme().copyWith(
              platform: TargetPlatform.android,
            ),
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  capturedCtx = ctx;
                  return const CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: CommentSkeleton(itemCount: 3),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          PrimaryScrollController.of(capturedCtx).positions.length,
          equals(1),
        );

        final searchProvider = _OfflineSearchProvider()..setSeededResults();
        await tester.pumpWidget(
          ChangeNotifierProvider<SearchProvider>.value(
            value: searchProvider,
            child: MaterialApp(
              theme: AppTheme.lightTheme().copyWith(
                platform: TargetPlatform.android,
              ),
              home: const SearchScreen(initialKeyword: '测试'),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('UP主'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('专栏'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
