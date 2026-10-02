import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/comment_model.dart';
import '../../models/danmaku_model.dart';
import '../../models/play_url_model.dart';
import '../../models/subtitle_model.dart';
import '../../models/user_model.dart';
import '../../models/video_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listen_video_provider.dart';
import '../../services/api/bili_http_client.dart';
import '../../services/api/comment_api_service.dart';
import '../../services/api/danmaku_service.dart';
import '../../services/api/subtitle_service.dart';
import '../../services/api/user_api_service.dart';
import '../../services/api/video_api_service.dart';
import '../../services/player/play_stream_planner.dart';
import '../../services/player/quality_panel_policy.dart';
import '../../services/player/video_prefetch_service.dart';
import '../../services/settings/player_settings_service.dart';
import '../../services/player/sleep_timer_service.dart';
import '../../services/storage/history_storage_service.dart';
import '../../services/storage/video_cache_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/comment_item_widget.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/player/bili_video_player.dart';
import '../../widgets/player/video_cache_bottom_sheet.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/video_card.dart';
import '../profile/login_dialog.dart';
import '../up/up_space_screen.dart';
import 'listen_video_screen.dart';
import 'widgets/video_action_bar.dart';
import 'widgets/video_coin_dialog.dart';
import 'widgets/video_favorite_folder_sheet.dart';
import 'widgets/video_season_sheet.dart';
import 'widgets/video_sub_replies_sheet.dart';
import 'widgets/video_watch_later_panel.dart';

part 'video_detail_tabs.dart';

class VideoDetailScreen extends StatefulWidget {
  final String bvid;
  final VideoItem? initialVideo;
  final Duration? initialPosition;
  final List<WatchLaterItem>? watchLaterList;
  final int initialWatchLaterIndex;

  const VideoDetailScreen({
    super.key,
    required this.bvid,
    this.initialVideo,
    this.initialPosition,
    this.watchLaterList,
    this.initialWatchLaterIndex = 0,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen>
    with TickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  late final AnimationController _tripleComboAnimController;
  final GlobalKey<_VideoInfoTabState> _infoTabKey =
      GlobalKey<_VideoInfoTabState>();
  // 评论数用于 Tab 标签展示，由评论子组件回报
  int _commentCountForLabel = 0;
  VideoDetail? _detail;
  PlayUrlInfo? _playUrlInfo;

  /// 播放流获取失败时的提示（-10403 权限/付费、-352 风控、网络异常等）
  String? _playUrlError;
  List<DanmakuItem> _danmakus = [];
  List<VideoItem> _relatedVideos = [];

  // Subtitles
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _currentSubtitleTrack;
  SubtitleData? _currentSubtitleData;
  bool _isSubtitleEnabled = false;

  // Watch Later Playlist state
  List<WatchLaterItem>? _watchLaterList;
  int _currentWatchLaterIndex = 0;
  bool _isAutoPlayingNext = false;
  Duration? _overrideInitialPosition;
  bool _hasSwitchedEpisodeOrPart = false;

  late String _currentBvid;
  int _selectedPageIndex = 0;
  String? _localVideoPath;
  bool _isLoading = true;
  bool _detailError = false;
  bool _isPlayerFullScreen = false;

  @override
  void initState() {
    super.initState();
    _currentBvid = widget.bvid;
    _watchLaterList = widget.watchLaterList != null
        ? List<WatchLaterItem>.from(widget.watchLaterList!)
        : null;
    _currentWatchLaterIndex = widget.initialWatchLaterIndex;
    _overrideInitialPosition = widget.initialPosition;
    _tabController = TabController(length: 2, vsync: this);
    _tripleComboAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1100),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _infoTabKey.currentState?._triggerTriple();
            _tripleComboAnimController.reset();
          }
        });
    if (ResponsiveUtil.isMobile) {
      if (PlayerSettingsService.autoRotateFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    }
    PlayerSettingsService.autoRotateListenable.addListener(
      _onAutoRotateSettingChanged,
    );
    _loadAll();
  }

  void _onAutoRotateSettingChanged() {
    if (!mounted || !ResponsiveUtil.isMobile) return;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isFull = _isPlayerFullScreen || isLandscape;
    if (!isFull) {
      if (PlayerSettingsService.autoRotateFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    } else {
      if (PlayerSettingsService.autoRotateFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  Future<void> _loadAll() async {
    // 作废在途的详情/流加载，防止快速切换视频时旧响应覆盖新状态
    _videoLoadToken++;
    _detailLoadToken++;
    final detailToken = _detailLoadToken;
    setState(() => _isLoading = true);

    // 0. Instant offline cache detection & zero-latency local playback
    final cacheService = VideoCacheService();
    final cachedTasks = cacheService.allTasks
        .where((t) => t.bvid == _currentBvid && t.isCompleted)
        .toList();

    if (cachedTasks.isNotEmpty) {
      final initialCid = widget.initialVideo?.cid ?? 0;
      final primaryTask = cachedTasks.firstWhere(
        (t) => initialCid > 0 && t.cid == initialCid,
        orElse: () => cachedTasks.first,
      );

      final localPages = cachedTasks
          .asMap()
          .entries
          .map(
            (e) => VideoPage(
              cid: e.value.cid,
              page: e.key + 1,
              from: 'local',
              part: e.value.pageTitle.isNotEmpty
                  ? e.value.pageTitle
                  : '第 ${e.key + 1} 集',
              duration: e.value.duration,
            ),
          )
          .toList();

      final pageIdx = localPages.indexWhere((p) => p.cid == primaryTask.cid);
      if (pageIdx >= 0) {
        _selectedPageIndex = pageIdx;
      }

      _detail = VideoDetail(
        videoItem: VideoItem(
          aid: primaryTask.aid,
          bvid: _currentBvid,
          cid: primaryTask.cid,
          title: primaryTask.title,
          pic: primaryTask.cover,
          desc: '',
          duration: primaryTask.duration,
          pubdate: 0,
          ctime: 0,
          owner: Owner(
            mid: 0,
            name: primaryTask.ownerName,
            face: primaryTask.ownerFace,
          ),
          stat: Stat(),
        ),
        pages: localPages,
      );

      // Start playing local video immediately
      await _loadPlayUrlAndDanmaku(primaryTask.cid);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } else if (widget.initialVideo != null && widget.initialVideo!.cid > 0) {
      // Fallback: If initial video has cid, try loading stream
      _loadPlayUrlAndDanmaku(widget.initialVideo!.cid);
    }

    // 1. Fetch Online Video Detail（命中预取缓存时可跳过网络等待）
    try {
      final detail = await VideoPrefetchService.instance.getDetail(
        _currentBvid,
      );
      if (detail != null && mounted && _detailLoadToken == detailToken) {
        setState(() {
          _detail = detail;
        });

        // 2. Relation / related / comments are self-managed by the tab child widgets

        // 3. If stream wasn't loaded from cache, load online stream
        if (_playUrlInfo == null) {
          final cid = detail.pages.isNotEmpty
              ? detail.pages[_selectedPageIndex].cid
              : detail.videoItem.cid;
          await _loadPlayUrlAndDanmaku(cid);
        }

        // 多 P 视频预取下一 P 的播放地址，切集时秒开
        if (detail.pages.length > _selectedPageIndex + 1) {
          unawaited(
            VideoPrefetchService.instance.getPlayStream(
              _currentBvid,
              detail.pages[_selectedPageIndex + 1].cid,
            ),
          );
        }

        // 4. Fetch Related Videos
        final relatedBvid = _currentBvid;
        VideoApiService().getRelatedVideos(relatedBvid).then((list) {
          if (mounted && relatedBvid == _currentBvid) {
            setState(() => _relatedVideos = list);
            // 预取前几个相关视频的详情与播放地址，点开时秒开
            VideoPrefetchService.instance.prefetchVideos(list);
          }
        });

        _detailError = false;
      } else {
        // 在线详情获取失败；若也没有本地/初始数据可展示，则标记错误态
        if (_detail == null && widget.initialVideo == null && mounted) {
          setState(() => _detailError = true);
        }
      }
    } catch (_) {
      if (_detail == null && widget.initialVideo == null && mounted) {
        setState(() => _detailError = true);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int _videoLoadToken = 0;

  /// 详情/相关视频加载代数：与 [_videoLoadToken] 分开，避免流加载与详情加载互相作废
  int _detailLoadToken = 0;

  Future<void> _loadPlayUrlAndDanmaku(int cid) async {
    final token = ++_videoLoadToken;
    final cacheService = VideoCacheService();
    final isCached = cacheService.isCached(_currentBvid, cid);
    final localVideo = cacheService.getLocalVideoPath(_currentBvid, cid);
    final localDanmaku = cacheService.getLocalDanmakuPath(cid);

    PlayUrlInfo? playUrl;
    String? playUrlError;
    if (isCached && localVideo != null) {
      final cachedItem = cacheService.getCacheItem(_currentBvid, cid);
      final q = cachedItem?.quality ?? 80;
      final dur = (cachedItem?.duration ?? 0) * 1000;
      final localAudio = cacheService.getLocalAudioPath(_currentBvid, cid);
      final hasLocalAudio =
          localAudio != null &&
          localAudio.isNotEmpty &&
          File(localAudio).existsSync();

      if (hasLocalAudio) {
        playUrl = PlayUrlInfo(
          currentQuality: q,
          format: 'dash',
          timelength: dur,
          acceptQuality: [q],
          acceptDescription: [cachedItem?.qualityDesc ?? '1080P 高清'],
          durls: const [],
          videoTracks: [
            DashVideoItem(
              id: q,
              baseUrl: Uri.file(localVideo).toString(),
              mimeType: 'video/mp4',
              codecs: 'avc1.640028',
              width: 1920,
              height: 1080,
              bandwidth: 1500000,
              backupUrls: const [],
            ),
          ],
          audioTracks: [
            DashAudioItem(
              id: 30280,
              baseUrl: Uri.file(localAudio).toString(),
              mimeType: 'audio/mp4',
              codecs: 'mp4a.40.2',
              bandwidth: 128000,
              backupUrls: const [],
            ),
          ],
          supportFormats: [
            SupportFormat(
              quality: q,
              format: 'dash',
              newDescription: cachedItem?.qualityDesc ?? '1080P 高清',
              displayDesc: cachedItem?.qualityDesc ?? '1080P 高清',
            ),
          ],
          videoCodecid: 7,
        );
      } else {
        playUrl = PlayUrlInfo(
          currentQuality: q,
          format: 'mp4',
          timelength: dur,
          acceptQuality: [q],
          acceptDescription: [cachedItem?.qualityDesc ?? '720P 高清'],
          durls: [
            PlayUrlDurl(
              order: 1,
              length: dur,
              size: cachedItem?.totalBytes ?? 0,
              url: Uri.file(localVideo).toString(),
              backupUrls: const [],
            ),
          ],
          supportFormats: [
            SupportFormat(
              quality: q,
              format: 'mp4',
              newDescription: cachedItem?.qualityDesc ?? '720P 高清',
              displayDesc: cachedItem?.qualityDesc ?? '720P 高清',
            ),
          ],
          videoCodecid: 7,
        );
      }
    } else {
      // 优先命中预取缓存（相关视频 / 下一 P 提前拿到的播放地址）
      final result = await VideoPrefetchService.instance.getPlayStream(
        _currentBvid,
        cid,
      );
      if (result != null) {
        playUrl = result.info;
      } else {
        final fetched = await VideoApiService().fetchPlayStream(
          bvid: _currentBvid,
          cid: cid,
          qn: PlayerSettingsService.defaultQuality,
        );
        playUrl = fetched.ok ? fetched.info : null;
        playUrlError = fetched.ok
            ? null
            : (fetched.message.isNotEmpty ? fetched.message : '播放地址获取失败');
      }
    }

    final danmakuListFuture = DanmakuService().getDanmakuList(
      cid,
      localFilePath: localDanmaku,
    );
    final subtitleTracksFuture = SubtitleService().getSubtitleTracks(
      bvid: _currentBvid,
      cid: cid,
    );

    final danmakuList = await danmakuListFuture;
    final subtitleTracks = await subtitleTracksFuture;

    final isSubEnabled = PlayerSettingsService.subtitleEnabled;
    SubtitleTrack? initialTrack;
    SubtitleData? initialData;
    if (subtitleTracks.isNotEmpty) {
      final preferredLan = PlayerSettingsService.preferredSubtitleLanguage;
      initialTrack = subtitleTracks.firstWhere(
        (t) => preferredLan.isNotEmpty && t.lan == preferredLan,
        orElse: () => subtitleTracks.first,
      );
      if (isSubEnabled) {
        initialData = await SubtitleService().getSubtitleData(initialTrack);
      }
    }

    if (mounted && _videoLoadToken == token) {
      final listenProvider = context.read<ListenVideoProvider>();
      if (listenProvider.isPlaying || listenProvider.controller != null) {
        await listenProvider.stopAndClear();
      }
      // stopAndClear 期间可能已切集/退出页面，落地前必须复查
      if (!mounted || _videoLoadToken != token) return;
      setState(() {
        _playUrlInfo = playUrl;
        _playUrlError = playUrlError;
        _danmakus = danmakuList;
        _localVideoPath = isCached ? localVideo : null;
        _subtitleTracks = subtitleTracks;
        _currentSubtitleTrack = initialTrack;
        _currentSubtitleData = initialData;
        _isSubtitleEnabled = isSubEnabled && initialTrack != null;
      });
    }
  }

  Future<void> _onSubtitleTrackChanged(SubtitleTrack? track) async {
    if (track == null) {
      setState(() {
        _isSubtitleEnabled = false;
        _currentSubtitleTrack = null;
        _currentSubtitleData = null;
      });
      unawaited(PlayerSettingsService.setSubtitleEnabled(false));
      AppToast.show(context, '已关闭字幕');
      return;
    }

    if (_currentSubtitleTrack?.id == track.id && _isSubtitleEnabled) {
      return;
    }

    final data = await SubtitleService().getSubtitleData(track);
    if (data != null && mounted) {
      setState(() {
        _currentSubtitleTrack = track;
        _currentSubtitleData = data;
        _isSubtitleEnabled = true;
      });
      unawaited(PlayerSettingsService.setSubtitleEnabled(true));
      if (track.lan.isNotEmpty) {
        unawaited(
          PlayerSettingsService.setPreferredSubtitleLanguage(track.lan),
        );
      }
      final name = track.lanDoc.isNotEmpty ? track.lanDoc : track.lan;
      AppToast.show(context, '已切换字幕: $name');
    }
  }

  void _showSubtitleSelector() {
    if (_subtitleTracks.isEmpty) {
      AppToast.show(context, '当前视频暂无可用字幕');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Material(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.closed_caption_rounded, size: 20),
                          const SizedBox(width: 8.0),
                          Text(
                            '字幕设置',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_isSubtitleEnabled)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSubtitleEnabled = false;
                                });
                                unawaited(
                                  PlayerSettingsService.setSubtitleEnabled(
                                    false,
                                  ),
                                );
                                Navigator.pop(sheetContext);
                                AppToast.show(this.context, '已关闭字幕');
                              },
                              child: const Text('关闭字幕'),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _subtitleTracks.length,
                        itemBuilder: (itemContext, index) {
                          final track = _subtitleTracks[index];
                          final isSelected =
                              _isSubtitleEnabled &&
                              _currentSubtitleTrack?.id == track.id;
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.hintColor,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  track.lanDoc.isNotEmpty
                                      ? track.lanDoc
                                      : track.lan,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                                if (track.isAi) ...[
                                  const SizedBox(width: 8.0),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'AI 生成',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              if (isSelected) return;
                              final data = await SubtitleService()
                                  .getSubtitleData(track);
                              if (data != null && mounted) {
                                setState(() {
                                  _currentSubtitleTrack = track;
                                  _currentSubtitleData = data;
                                  _isSubtitleEnabled = true;
                                });
                                unawaited(
                                  PlayerSettingsService.setSubtitleEnabled(
                                    true,
                                  ),
                                );
                                if (track.lan.isNotEmpty) {
                                  unawaited(
                                    PlayerSettingsService.setPreferredSubtitleLanguage(
                                      track.lan,
                                    ),
                                  );
                                }
                                AppToast.show(
                                  this.context,
                                  '已开启字幕: ${track.lanDoc}',
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _switchQuality(int qn) async {
    final token = ++_videoLoadToken;
    final isLogin = BiliHttpClient().isLoggedIn;

    if (qn >= 80 && !isLogin) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要登录'),
          content: Text('${_getQualityName(qn)}需登录哔哩哔哩账号，是否前往登录？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                showDialog(
                  context: context,
                  builder: (ctx) => const LoginDialog(),
                ).then((_) {
                  if (BiliHttpClient().isLoggedIn && mounted) {
                    _switchQuality(qn);
                  }
                });
              },
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      return;
    }

    final cid = _detail != null && _detail!.pages.isNotEmpty
        ? _detail!.pages[_selectedPageIndex].cid
        : (_detail?.videoItem.cid ?? 0);

    final result = await VideoApiService().fetchPlayStream(
      bvid: _currentBvid,
      cid: cid,
      qn: qn,
    );
    if (!mounted || _videoLoadToken != token) return;

    if (!result.ok || result.info == null) {
      AppToast.show(
        context,
        result.message.isNotEmpty ? result.message : '画质切换失败，请稍后重试',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final playUrl = result.info!;
    // DASH 下响应体的 quality 不可信，以实际授权的视频轨画质为准
    final granted = playUrl.grantedQuality > 0
        ? playUrl.grantedQuality
        : playUrl.currentQuality;
    // 记住用户的画质选择；被降级时记住实际能用的画质，避免下次继续请求拿不到的画质
    unawaited(
      PlayerSettingsService.setDefaultQuality(granted == qn ? qn : granted),
    );
    setState(() {
      _playUrlInfo = playUrl;
      _playUrlError = null;
    });
    if (granted == qn) {
      AppToast.show(context, '已切换至 ${_getQualityName(qn)}');
    } else {
      // 降级提示必须区分"视频没有该画质"与"账号权限不足"，
      // 不能对没有 60 帧轨的视频误报"需大会员"
      final message = qualityDowngradeMessage(
        requested: qn,
        granted: granted,
        isLogin: isLogin,
        videoOffersQuality: declaredQualities(playUrl).contains(qn),
        labelOf: _getQualityName,
      );
      if (message != null) {
        AppToast.show(context, message, icon: Icons.info_outline_rounded);
      }
    }
  }

  /// DASH 伴音轨初始化失败：保持进度回退到渐进式单流，避免"有画面没声音"
  Future<void> _fallbackToProgressiveStream() async {
    final token = ++_videoLoadToken;
    final cid = _detail != null && _detail!.pages.isNotEmpty
        ? _detail!.pages[_selectedPageIndex].cid
        : (_detail?.videoItem.cid ?? 0);
    if (cid <= 0) return;

    final position = _playerKey.currentState?.controller?.value.position;
    final result = await VideoApiService().requestPlayUrl(
      bvid: _currentBvid,
      cid: cid,
      qn: PlayerSettingsService.defaultQuality,
      fnval: kProgressiveFnval,
      kind: PlayStreamKind.progressive,
    );

    if (!mounted || _videoLoadToken != token) return;

    if (!result.ok || result.info == null) {
      AppToast.show(
        context,
        '伴音轨加载失败，且回退播放地址失败，请重试',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    setState(() {
      _playUrlInfo = result.info;
      _overrideInitialPosition = position;
      _playUrlError = null;
    });
    AppToast.show(
      context,
      '伴音轨加载失败，已切换至 ${_getQualityName(result.grantedQuality)} 单流播放',
      icon: Icons.info_outline_rounded,
    );
  }

  String _getQualityName(int q) {
    switch (q) {
      case 127:
        return '8K';
      case 120:
        return '4K';
      case 116:
        return '1080P 60帧';
      case 112:
        return '1080P 高码率';
      case 80:
        return '1080P 高清';
      case 74:
        return '720P 60帧';
      case 64:
        return '720P 高清';
      case 32:
        return '480P 清晰';
      case 16:
        return '360P 流畅';
      default:
        return '$q P';
    }
  }

  Future<void> _switchPart(int index) async {
    if (_detail == null ||
        index >= _detail!.pages.length ||
        index == _selectedPageIndex) {
      return;
    }
    _reportFinalProgress();
    setState(() {
      _hasSwitchedEpisodeOrPart = true;
      _selectedPageIndex = index;
      _playUrlInfo = null;
      _danmakus = [];
      _subtitleTracks = [];
      _currentSubtitleTrack = null;
      _currentSubtitleData = null;
      _isSubtitleEnabled = false;
      _overrideInitialPosition = null;
      _lastReportedPosition = Duration.zero;
      _lastReportTime = DateTime.fromMillisecondsSinceEpoch(0);
    });
    final cid = _detail!.pages[index].cid;
    await _loadPlayUrlAndDanmaku(cid);
  }

  Future<void> _switchEpisode(UgcEpisode ep) async {
    if (ep.bvid == _currentBvid) return;
    _reportFinalProgress();
    setState(() {
      _hasSwitchedEpisodeOrPart = true;
      _currentBvid = ep.bvid;
      _selectedPageIndex = 0;
      _isLoading = true;
      _playUrlInfo = null;
      _danmakus = [];
      _subtitleTracks = [];
      _currentSubtitleTrack = null;
      _currentSubtitleData = null;
      _isSubtitleEnabled = false;
      _relatedVideos = [];
      _overrideInitialPosition = null;
      _lastReportedPosition = Duration.zero;
      _lastReportTime = DateTime.fromMillisecondsSinceEpoch(0);
    });

    // 作废在途请求并记录本次切换的代数，防止快速连点时旧详情/旧流覆盖新状态
    _videoLoadToken++;
    _detailLoadToken++;
    final detailToken = _detailLoadToken;

    final detail = await VideoPrefetchService.instance.getDetail(_currentBvid);
    if (detail != null && mounted && _detailLoadToken == detailToken) {
      setState(() {
        _detail = detail;
      });

      final cid = detail.pages.isNotEmpty
          ? detail.pages[0].cid
          : (ep.cid != 0 ? ep.cid : detail.videoItem.cid);
      await _loadPlayUrlAndDanmaku(cid);

      final relatedBvid = _currentBvid;
      VideoApiService().getRelatedVideos(relatedBvid).then((list) {
        if (mounted && relatedBvid == _currentBvid) {
          setState(() => _relatedVideos = list);
          VideoPrefetchService.instance.prefetchVideos(list);
        }
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _switchWatchLaterItem(WatchLaterItem item, int index) async {
    if (item.bvid == _currentBvid && index == _currentWatchLaterIndex) return;
    _reportFinalProgress();
    final effectiveProgress = item.progress > 0
        ? item.progress
        : HistoryStorageService().getProgress(item.bvid);

    setState(() {
      _hasSwitchedEpisodeOrPart = true;
      _currentWatchLaterIndex = index;
      _currentBvid = item.bvid;
      _selectedPageIndex = 0;
      _isLoading = true;
      _playUrlInfo = null;
      _danmakus = [];
      _relatedVideos = [];
      _overrideInitialPosition = effectiveProgress > 0
          ? Duration(seconds: effectiveProgress)
          : Duration.zero;
    });

    _loadAll();
  }

  void _showUgcSeasonBottomSheet(UgcSeason season) {
    VideoSeasonSheet.show(
      context,
      season: season,
      currentBvid: _currentBvid,
      onSelectEpisode: (ep) => _switchEpisode(ep),
    );
  }

  void _navigateToUpSpace(int mid) async {
    final playerState = _playerKey.currentState;
    final isCurrentlyPlaying =
        playerState?.controller?.value.isPlaying ?? false;
    final currentPos = playerState?.controller?.value.position ?? Duration.zero;
    final currentSpeed = playerState?.playbackSpeed ?? 1.0;
    final video = _detail?.videoItem ?? widget.initialVideo;
    final totalDur = (_playUrlInfo != null && _playUrlInfo!.timelength > 0)
        ? Duration(milliseconds: _playUrlInfo!.timelength)
        : (video != null && video.duration > 0
              ? Duration(seconds: video.duration)
              : null);

    if (isCurrentlyPlaying && video != null && _playUrlInfo != null) {
      playerState?.pause();
      final listenProvider = context.read<ListenVideoProvider>();
      final cid = _detail != null && _detail!.pages.isNotEmpty
          ? _detail!.pages[_selectedPageIndex].cid
          : video.cid;
      // Start audio playback asynchronously in background without blocking route transition
      listenProvider.playAudio(
        bvid: _currentBvid,
        cid: cid,
        title: video.title,
        coverUrl: video.pic,
        upName: video.owner.name,
        audioUrl: _localVideoPath ?? _playUrlInfo?.primaryAudioUrl,
        startPosition: currentPos,
        totalDuration: totalDur,
        speed: currentSpeed,
      );
    }

    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => UpSpaceScreen(mid: mid)));

    if (mounted) {
      _infoTabKey.currentState?._loadRelation();

      // On return from UP space: check if ListenVideoProvider was playing this video
      final listenProvider = context.read<ListenVideoProvider>();
      if (listenProvider.hasAudio && listenProvider.bvid == _currentBvid) {
        final curAudioPos = listenProvider.position;
        final wasPlaying = listenProvider.isPlaying;
        await listenProvider.stopAndClear();
        if (mounted && playerState != null && playerState.controller != null) {
          await playerState.controller!.seekTo(curAudioPos);
          if (wasPlaying) {
            await playerState.play();
          }
        }
      }
    }
  }

  void _showCacheBottomSheet() {
    if (_detail == null) {
      AppToast.show(context, '视频数据加载中，请稍候');
      return;
    }
    VideoCacheBottomSheet.show(
      context,
      detail: _detail!,
      playUrlInfo: _playUrlInfo,
      initialPageIndex: _selectedPageIndex,
    );
  }

  Duration _lastReportedPosition = Duration.zero;
  DateTime _lastReportTime = DateTime.fromMillisecondsSinceEpoch(0);
  // 本地进度按「秒数变化」节流：回调每秒触发多次，避免每次都重建记录并触发持久化
  String _lastLocalSaveKey = '';

  final GlobalKey<BiliVideoPlayerState> _playerKey =
      GlobalKey<BiliVideoPlayerState>();

  void _onPlayerProgressUpdate(Duration position, Duration duration) {
    if (PlayerSettingsService.incognitoMode) return;

    final currentSec = position.inSeconds;
    final durSec = duration.inSeconds;
    final video = _detail?.videoItem ?? widget.initialVideo;
    final aid = video?.aid ?? 0;
    final cid =
        (_detail != null &&
            _detail!.pages.isNotEmpty &&
            _selectedPageIndex < _detail!.pages.length)
        ? _detail!.pages[_selectedPageIndex].cid
        : (video?.cid ?? 0);

    // Sleep Timer end of video check
    if (durSec > 0 && currentSec >= durSec) {
      if (SleepTimerService().notifyVideoFinished()) {
        return;
      }
    }

    // 1. Save to local persistent storage once per second of playback (immediate on video/P switch)
    if (currentSec > 0) {
      final saveKey = '$_currentBvid:$cid:$currentSec';
      if (saveKey != _lastLocalSaveKey) {
        _lastLocalSaveKey = saveKey;
        HistoryStorageService().saveProgress(
          bvid: _currentBvid,
          progress: currentSec,
          duration: durSec,
          aid: aid,
          cid: cid,
          title: video?.title,
          cover: video?.pic,
        );
      }
    }

    // 2. Periodic cloud report (every 5 seconds or 10s jump)
    final now = DateTime.now();
    if (now.difference(_lastReportTime).inSeconds >= 5 ||
        (position - _lastReportedPosition).inSeconds.abs() >= 10) {
      _lastReportTime = now;
      _lastReportedPosition = position;
      if (aid > 0 && cid > 0 && currentSec > 0) {
        UserApiService().reportHistory(
          aid: aid,
          cid: cid,
          progress: currentSec,
          bvid: _currentBvid,
          duration: durSec,
        );
      }
    }

    // 3. Auto-play next video in Watch Later playlist if reached end
    if (_watchLaterList != null &&
        durSec > 0 &&
        currentSec >= durSec &&
        !_isAutoPlayingNext &&
        _currentWatchLaterIndex + 1 < _watchLaterList!.length) {
      _isAutoPlayingNext = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted &&
            _watchLaterList != null &&
            _currentWatchLaterIndex + 1 < _watchLaterList!.length) {
          final nextIdx = _currentWatchLaterIndex + 1;
          final nextItem = _watchLaterList![nextIdx];
          AppToast.show(
            context,
            '正在自动播放下一条稍后看: ${nextItem.title}',
            icon: Icons.playlist_play_rounded,
          );
          _switchWatchLaterItem(nextItem, nextIdx);
          _isAutoPlayingNext = false;
        }
      });
    } else if (PlayerSettingsService.autoPlayNextEpisode &&
        _detail != null &&
        _detail!.pages.length > 1 &&
        _selectedPageIndex + 1 < _detail!.pages.length &&
        durSec > 0 &&
        currentSec >= durSec &&
        !_isAutoPlayingNext) {
      // 4. Auto-play next episode / part
      _isAutoPlayingNext = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted &&
            _detail != null &&
            _selectedPageIndex + 1 < _detail!.pages.length) {
          final nextIdx = _selectedPageIndex + 1;
          AppToast.show(
            context,
            '正在自动播放下一分P: ${_detail!.pages[nextIdx].part}',
            icon: Icons.playlist_play_rounded,
          );
          _switchPart(nextIdx);
          _isAutoPlayingNext = false;
        }
      });
    }
  }

  void _reportFinalProgress() {
    if (PlayerSettingsService.incognitoMode) return;
    final playerState = _playerKey.currentState;
    final pos =
        playerState?.controller?.value.position ?? _lastReportedPosition;
    final dur = playerState?.controller?.value.duration ?? Duration.zero;
    final currentSec = pos.inSeconds;
    if (currentSec <= 0) return;

    final video = _detail?.videoItem ?? widget.initialVideo;
    final aid = video?.aid ?? 0;
    final cid =
        (_detail != null &&
            _detail!.pages.isNotEmpty &&
            _selectedPageIndex < _detail!.pages.length)
        ? _detail!.pages[_selectedPageIndex].cid
        : (video?.cid ?? 0);

    HistoryStorageService().saveProgress(
      bvid: _currentBvid,
      progress: currentSec,
      duration: dur.inSeconds,
      aid: aid,
      cid: cid,
      title: video?.title,
      cover: video?.pic,
      immediate: true,
    );
    HistoryStorageService().flush();

    if (aid > 0 && cid > 0) {
      UserApiService().reportHistory(
        aid: aid,
        cid: cid,
        progress: currentSec,
        bvid: _currentBvid,
        duration: dur.inSeconds,
      );
    }
  }

  @override
  void didPopNext() {
    if (PlayerSettingsService.autoRotateFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void didPushNext() {
    // When a new route is pushed on top of this video detail, report progress and pause
    _reportFinalProgress();
    _playerKey.currentState?.pause();
  }

  @override
  void dispose() {
    _tripleComboAnimController.dispose();
    PlayerSettingsService.autoRotateListenable.removeListener(
      _onAutoRotateSettingChanged,
    );
    _reportFinalProgress();
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startListenMode() async {
    final video = _detail?.videoItem ?? widget.initialVideo;
    if (video == null) {
      AppToast.show(
        context,
        '正在获取视频信息，请稍候...',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final url = _localVideoPath ?? _playUrlInfo?.primaryAudioUrl;

    final pos =
        _playerKey.currentState?.controller?.value.position ?? Duration.zero;
    final speed = _playerKey.currentState?.playbackSpeed ?? 1.0;

    // Explicitly pause the video and danmaku
    await _playerKey.currentState?.pause();

    final wasFullScreen = _playerKey.currentState?.isFullScreen ?? false;
    if (wasFullScreen) {
      _playerKey.currentState?.exitFullScreen();
    }

    final totalDur = (_playUrlInfo != null && _playUrlInfo!.timelength > 0)
        ? Duration(milliseconds: _playUrlInfo!.timelength)
        : (video.duration > 0 ? Duration(seconds: video.duration) : null);

    List<ListenPlaylistItem>? listenPlaylist;
    int initialPlaylistIndex = 0;

    if (_watchLaterList != null && _watchLaterList!.isNotEmpty) {
      listenPlaylist = _watchLaterList!.map((item) {
        return ListenPlaylistItem(
          bvid: item.bvid,
          cid: item.cid,
          title: item.title,
          coverUrl: item.pic,
          upName: item.ownerName,
          duration: item.duration > 0 ? Duration(seconds: item.duration) : null,
          progress: item.progress,
        );
      }).toList();
      initialPlaylistIndex = _currentWatchLaterIndex;
    } else if (_detail?.ugcSeason != null &&
        _detail!.ugcSeason!.sections.isNotEmpty) {
      final episodes = _detail!.ugcSeason!.sections
          .expand((s) => s.episodes)
          .toList();
      if (episodes.length > 1) {
        listenPlaylist = episodes.map((ep) {
          return ListenPlaylistItem(
            bvid: ep.bvid,
            cid: ep.cid,
            title: ep.title,
            coverUrl: ep.cover.isNotEmpty ? ep.cover : video.pic,
            upName: video.owner.name,
            duration: ep.duration > 0 ? Duration(seconds: ep.duration) : null,
          );
        }).toList();
        final epIdx = episodes.indexWhere((ep) => ep.bvid == _currentBvid);
        initialPlaylistIndex = epIdx >= 0 ? epIdx : 0;
      }
    } else if (_detail != null && _detail!.pages.length > 1) {
      listenPlaylist = _detail!.pages.map((p) {
        return ListenPlaylistItem(
          bvid: _currentBvid,
          cid: p.cid,
          title: '${video.title} - ${p.part}',
          coverUrl: video.pic,
          upName: video.owner.name,
          duration: p.duration > 0 ? Duration(seconds: p.duration) : null,
        );
      }).toList();
      initialPlaylistIndex = _selectedPageIndex;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ListenVideoScreen(
          bvid: video.bvid,
          cid: video.cid,
          title: video.title,
          coverUrl: video.pic,
          upName: video.owner.name,
          playUrl: url,
          initialPosition: pos,
          totalDuration: totalDur,
          initialSpeed: speed,
          playlist: listenPlaylist,
          initialPlaylistIndex: initialPlaylistIndex,
          onSwitchPlaylistItem: (item, idx) {
            if (_watchLaterList != null &&
                idx >= 0 &&
                idx < _watchLaterList!.length) {
              _switchWatchLaterItem(_watchLaterList![idx], idx);
            } else if (_detail?.ugcSeason != null) {
              final episodes = _detail!.ugcSeason!.sections
                  .expand((s) => s.episodes)
                  .toList();
              if (idx >= 0 && idx < episodes.length) {
                _switchEpisode(episodes[idx]);
              }
            } else if (_detail != null &&
                idx >= 0 &&
                idx < _detail!.pages.length) {
              _switchPart(idx);
            }
          },
          onSwitchToVideo: (curPos) async {
            await _playerKey.currentState?.controller?.seekTo(curPos);
            await _playerKey.currentState?.play();
            if (mounted && wasFullScreen) {
              final isLandscapeNow =
                  MediaQuery.of(context).orientation == Orientation.landscape;
              if (isLandscapeNow) {
                _playerKey.currentState?.enterFullScreen();
              }
            }
          },
        ),
      ),
    );

    if (mounted) {
      final listenProvider = context.read<ListenVideoProvider>();
      if (listenProvider.hasAudio && listenProvider.bvid == _currentBvid) {
        final curAudioPos = listenProvider.position;
        if (curAudioPos > Duration.zero &&
            _playerKey.currentState?.controller != null) {
          await _playerKey.currentState?.controller?.seekTo(curAudioPos);
        }
      }
    }
  }

  Widget _buildPlayer(VideoItem? video, Color primaryColor) {
    if (_playUrlInfo != null) {
      final cid =
          (_detail != null &&
              _detail!.pages.isNotEmpty &&
              _selectedPageIndex < _detail!.pages.length)
          ? _detail!.pages[_selectedPageIndex].cid
          : (_detail?.videoItem.cid ?? 0);

      Duration? effectiveInitialPos = _overrideInitialPosition;
      if (effectiveInitialPos == null) {
        // Only use widget.initialPosition for the initial video before switching parts/episodes
        if (!_hasSwitchedEpisodeOrPart &&
            _currentBvid == widget.bvid &&
            _selectedPageIndex == 0) {
          effectiveInitialPos = widget.initialPosition;
        }
        if (effectiveInitialPos == null ||
            effectiveInitialPos == Duration.zero) {
          final savedSec = HistoryStorageService().getProgress(
            _currentBvid,
            cid: cid > 0 ? cid : null,
          );
          if (savedSec > 0) {
            effectiveInitialPos = Duration(seconds: savedSec);
          }
        }
      }

      final currentPartTitle =
          (_detail != null &&
              _detail!.pages.isNotEmpty &&
              _selectedPageIndex < _detail!.pages.length)
          ? _detail!.pages[_selectedPageIndex].part
          : '';
      final playerTitle =
          currentPartTitle.isNotEmpty && (_detail?.pages.length ?? 0) > 1
          ? '${video?.title ?? ''} · $currentPartTitle'
          : (video?.title ?? '');

      return BiliVideoPlayer(
        key: _playerKey,
        videoKey: '${_currentBvid}_$cid',
        playUrlInfo: _playUrlInfo!,
        localFilePath: _localVideoPath,
        danmakus: _danmakus,
        chapters: _detail?.chapters ?? const [],
        title: playerTitle,
        initialPosition: effectiveInitialPos,
        onQualityChanged: _switchQuality,
        onFullScreenChanged: (full) {
          setState(() => _isPlayerFullScreen = full);
        },
        onListenMode: _startListenMode,
        onProgressUpdate: _onPlayerProgressUpdate,
        onNextEpisode:
            (_detail != null && _selectedPageIndex + 1 < _detail!.pages.length)
            ? () => _switchPart(_selectedPageIndex + 1)
            : null,
        subtitleData: _currentSubtitleData,
        isSubtitleEnabled: _isSubtitleEnabled,
        subtitleTracks: _subtitleTracks,
        currentSubtitleTrack: _currentSubtitleTrack,
        onSubtitleTrackChanged: _onSubtitleTrackChanged,
        onSubtitleTap: _showSubtitleSelector,
        onAudioTrackFailed: _fallbackToProgressiveStream,
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null && video.pic.isNotEmpty)
              NetworkImageView(
                url: video.pic,
                fit: BoxFit.cover,
                memCacheWidth: 640,
                memCacheHeight: 360,
              ),
            Container(color: Colors.black45),
            if (_playUrlError != null)
              // 播放流获取失败（权限/付费/风控/网络）：给出可重试的明确提示
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white70,
                        size: 28,
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        _playUrlError!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      OutlinedButton.icon(
                        onPressed: () {
                          final cid =
                              _detail != null && _detail!.pages.isNotEmpty
                              ? _detail!.pages[_selectedPageIndex].cid
                              : (_detail?.videoItem.cid ?? 0);
                          if (cid > 0) {
                            setState(() {
                              _playUrlInfo = null;
                              _playUrlError = null;
                            });
                            _loadPlayUrlAndDanmaku(cid);
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('重试', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLandscape =
        ResponsiveUtil.isMobile &&
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isFullScreen = _isPlayerFullScreen || isMobileLandscape;
    final video = _detail?.videoItem ?? widget.initialVideo;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: !isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isFullScreen) {
          _playerKey.currentState?.exitFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: isFullScreen
            ? Colors.black
            : Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          top: !isFullScreen,
          bottom: false,
          left: !isFullScreen,
          right: !isFullScreen,
          child: Column(
            children: [
              // Top: Video Player (Full height in landscape/fullscreen, 16:9 in portrait)
              if (isFullScreen)
                Expanded(child: _buildPlayer(video, primaryColor))
              else
                _buildPlayer(video, primaryColor),

              // Tab Bar & Details (only when NOT fullscreen)
              if (!isFullScreen) ...[
                // Tab Bar: 简介 / 评论
                Container(
                  height: 40,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryColor,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: primaryColor,
                    unselectedLabelColor: context.colors.textSub,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 14),
                    dividerColor: Colors.transparent,
                    dividerHeight: 0,
                    tabs: [
                      const Tab(text: '简介'),
                      Tab(
                        text:
                            '评论 ${_commentCountForLabel > 0 ? Formatters.formatCount(_commentCountForLabel) : (_detail?.videoItem.stat.reply != null ? Formatters.formatCount(_detail!.videoItem.stat.reply) : "")}',
                      ),
                    ],
                  ),
                ),

                // Tab View Body
                Expanded(
                  child: _isLoading && _detail == null
                      ? const LoadingView(message: '正在加载视频详情...')
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _VideoInfoTab(key: _infoTabKey, state: this),
                            _VideoCommentsTab(
                              state: this,
                              onTotalCountChanged: (count) {
                                if (_commentCountForLabel != count) {
                                  setState(() => _commentCountForLabel = count);
                                }
                              },
                            ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showWatchLaterBottomSheet() {
    if (_watchLaterList == null || _watchLaterList!.isEmpty) return;
    VideoWatchLaterSheet.show(
      context,
      items: _watchLaterList!,
      currentIndex: _currentWatchLaterIndex,
      currentBvid: _currentBvid,
      onSelectItem: (item, idx) => _switchWatchLaterItem(item, idx),
    );
  }
}
