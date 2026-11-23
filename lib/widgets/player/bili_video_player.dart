import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/overlay_colors.dart';
import '../../theme/app_theme.dart';

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/danmaku_model.dart';
import '../../models/play_url_model.dart';
import '../../models/subtitle_model.dart';
import '../../models/video_model.dart';
import '../../services/api/bili_http_client.dart';
import '../../services/player/play_stream_planner.dart';
import '../../services/player/quality_panel_policy.dart';
import '../../services/settings/player_settings_service.dart';
import '../../services/player/system_media_control_service.dart';
import '../../services/player/sleep_timer_service.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive_util.dart';
import '../app_toast.dart';
import '../network_image_view.dart';
import 'components/player_danmaku_sheet.dart';
import 'components/player_floating_panels.dart';
import 'components/player_progress_bar.dart';
import 'danmaku_overlay.dart';
import 'sleep_timer_bottom_sheet.dart';
import 'subtitle_overlay.dart';

export 'bili_player_value.dart';

class BiliVideoPlayer extends StatefulWidget {
  final PlayUrlInfo playUrlInfo;
  final String? localFilePath;
  final String? coverUrl;
  final List<DanmakuItem> danmakus;
  final List<VideoChapter> chapters;
  final String title;
  final String? videoKey;
  final Duration? initialPosition;
  final Function(int quality)? onQualityChanged;
  final Function(bool isFullScreen)? onFullScreenChanged;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onListenMode;
  final void Function(Duration position, Duration duration)? onProgressUpdate;
  final Widget? autoNextOverlay;
  final ValueListenable<double>? portraitCollapseListenable;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? currentSubtitleTrack;
  final SubtitleData? subtitleData;
  final bool isSubtitleEnabled;
  final ValueChanged<SubtitleTrack?>? onSubtitleTrackChanged;
  final VoidCallback? onSubtitleTap;

  /// DASH 伴音轨初始化失败时回调（由页面回退到渐进式单流），
  /// 避免出现"有画面没声音"却静默播放的情况。
  final VoidCallback? onAudioTrackFailed;

  /// 播放卡死/报错需要刷新最新播放地址时回调（返回新地址后就地恢复进度）。
  final Future<PlayUrlInfo?> Function(int quality)? onRefreshPlayStream;

  /// DASH 双流多次恢复仍异常时回调（由页面降级到渐进式单流）。
  final VoidCallback? onDashPlaybackFailed;

  /// 仅供测试注入可控时钟，生产环境默认使用 `DateTime.now`。
  @visibleForTesting
  final DateTime Function()? clock;

  const BiliVideoPlayer({
    super.key,
    required this.playUrlInfo,
    this.localFilePath,
    this.coverUrl,
    this.danmakus = const [],
    this.chapters = const [],
    this.title = '',
    this.videoKey,
    this.initialPosition,
    this.onQualityChanged,
    this.onFullScreenChanged,
    this.onNextEpisode,
    this.onListenMode,
    this.onProgressUpdate,
    this.autoNextOverlay,
    this.portraitCollapseListenable,
    this.subtitleTracks = const [],
    this.currentSubtitleTrack,
    this.subtitleData,
    this.isSubtitleEnabled = false,
    this.onSubtitleTrackChanged,
    this.onSubtitleTap,
    this.onAudioTrackFailed,
    this.onRefreshPlayStream,
    this.onDashPlaybackFailed,
    this.clock,
  });

  @override
  State<BiliVideoPlayer> createState() => BiliVideoPlayerState();
}

enum _PanGestureMode {
  none,
  horizontalSeek,
  verticalBrightness,
  verticalVolume,
  verticalFullscreen,
}

enum _TapZone { left, center, right }

class _PlayerHudData {
  final IconData? icon;
  final String text;
  final Alignment alignment;
  final double? progress;

  const _PlayerHudData({
    this.icon,
    required this.text,
    required this.alignment,
    this.progress,
  });
}

class _DoubleTapRippleData {
  final bool isForward;
  final int totalSeconds;
  final int token;

  const _DoubleTapRippleData({
    required this.isForward,
    required this.totalSeconds,
    required this.token,
  });
}

class BiliVideoPlayerState extends State<BiliVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;
  late PlayUrlInfo _activePlayUrlInfo;

  /// 固定播放器视图主体 Key，切换全屏/竖屏时保持 VideoPlayer(Texture) 与弹幕树不被卸载重建，
  /// 避免 Android SurfaceProducer 在重建纹理时丢帧卡住。
  final GlobalKey _playerBodyKey = GlobalKey();

  /// B 站 CDN 要求 Referer/UA，直连时由播放器携带
  static const Map<String, String> _biliHeaders = {
    'Referer': 'https://www.bilibili.com',
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  /// DASH 双流：独立音轨控制器（渐进式单流时为 null，音轨已内嵌在视频流中）
  VideoPlayerController? _audioController;
  VideoPlayerController? _pendingAudioController;
  DateTime? _lastAudioSyncAt;
  DateTime? _lastSeekAt;
  bool _isSeekingNow = false;
  bool _isSyncPausedAudio = false;
  bool _isSyncPausedVideo = false;
  bool _isResumingAudio = false;

  /// 是否为 DASH 双流播放（视频轨 + 独立音轨）
  bool get hasSeparateAudio => _audioController != null;
  int _initToken = 0;
  late DanmakuController _danmakuController;
  bool _wakelockEnabled = false;
  bool _isExplicitlyPaused = false;

  // 卡顿检测与自愈状态
  static const int _maxRecoveryAttempts = 3;
  Duration _lastKnownPosition = Duration.zero;
  Duration _lastWatchdogVideoPos = Duration.zero;
  DateTime _lastWatchdogProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRecoveryAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchdogTimer;
  bool _isRecovering = false;
  int _recoveryAttempts = 0;
  bool _hasTriedProgressiveFallback = false;
  String? _playbackErrorMessage;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  VideoPlayerController? get controller => _controller;
  Duration get currentPosition => _controller?.value.position ?? _lastKnownPosition;
  double get playbackSpeed => _playbackSpeed;

  bool _showControls = true;
  Timer? _hideTimer;
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'bili_video_player');
  DeviceOrientation _currentLandscapeOrientation =
      DeviceOrientation.landscapeLeft;

  // Screen Lock (横屏锁屏)
  bool _isScreenLocked = false;
  bool _showLockIcon = true;
  Timer? _lockIconTimer;

  // Long Press 2.0X Speed (长按二倍速)
  bool _isLongPressSpeeding = false;
  double get _effectivePlaybackSpeed => _isLongPressSpeeding
      ? PlayerSettingsService.longPressSpeedValue
      : _playbackSpeed;
  double _speedBeforeLongPress = 1.0;

  // 播放状态边沿跟踪：缓冲结束的自动续播不经过 play()，而 video_player 的
  // setPlaybackSpeed 在非播放态（含缓冲中）会跳过平台调用，倍速的设置/恢复
  // 若恰好落在缓冲窗口就会停留在平台侧旧值，需在恢复播放时补发（见
  // _reassertPlaybackSpeeds）。
  bool _wasVideoPlaying = false;
  bool _wasAudioPlaying = false;

  // Pan Progress Seek & Vertical Pan Gestures (左右滑动快进快退 / 两侧亮度音量 / 居中全屏滑入)
  bool _isDraggingProgress = false;
  bool _isPanGestureIgnored = false;
  bool _hasPinchedInGesture = false;
  BoxFit _videoFit = BoxFit.contain;
  _PanGestureMode _panMode = _PanGestureMode.none;
  Offset _panStartPosition = Offset.zero;
  Duration _dragStartPosition = Duration.zero;
  Duration _targetSeekPosition = Duration.zero;
  double _accumulatedPanDx = 0.0;
  double _accumulatedPanDy = 0.0;
  Offset? _panDownLocalPosition;
  Offset? _panDownGlobalPosition;

  // Screen Brightness & Volume (左30%亮度，中40%全屏，右30%音量)
  double _screenBrightness = 1.0; // 0.0 ~ 1.0 (1.0 = normal full brightness)
  double _currentVolume = 1.0; // 0.0 ~ 1.0
  double get screenBrightness => _screenBrightness;
  double get currentVolume => _currentVolume;

  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    await SystemMediaControlService.instance.setVolume(
      _currentVolume,
      immediate: true,
    );
    if (_controller != null) {
      await _controller!.setVolume(1.0);
    }
    if (mounted) setState(() {});
  }

  void setScreenBrightness(double brightness) {
    _screenBrightness = brightness.clamp(0.0, 1.0);
    SystemMediaControlService.instance.rememberBrightness(_screenBrightness);
    SystemMediaControlService.instance.setBrightness(
      _screenBrightness,
      immediate: true,
    );
    if (mounted) setState(() {});
  }

  // In-Player Floating Panels
  bool _showQualityPanel = false;
  bool _showSpeedPanel = false;
  bool _showChapterPanel = false;
  bool _showSubtitlePanel = false;

  // 零延迟单击 + 双连击累加状态
  DateTime? _lastTapUpAt;
  _TapZone? _lastTapZone;
  bool _controlsBeforeFirstTap = true;
  int _doubleTapStreak = 0;
  int _doubleTapRippleSeq = 0;
  Timer? _doubleTapRippleTimer;

  // 局部状态 ValueNotifier：拖拽快进与亮度/音量 HUD 不触发整棵播放器树重建
  Timer? _hudTimer;
  int _lastHudPercent = -1;
  final ValueNotifier<_PlayerHudData?> _hudNotifier =
      ValueNotifier<_PlayerHudData?>(null);
  final ValueNotifier<Duration?> _dragSeekTarget =
      ValueNotifier<Duration?>(null);
  final ValueNotifier<bool> _dragSeekCancelled = ValueNotifier<bool>(false);
  final ValueNotifier<_DoubleTapRippleData?> _doubleTapRippleNotifier =
      ValueNotifier<_DoubleTapRippleData?>(null);

  // Isolated Slider Scrubbing
  final ValueNotifier<double?> _sliderDragPosition = ValueNotifier<double?>(
    null,
  );

  /// 本地文件是否真实存在（「已离线」徽标用）。existsSync 是磁盘系统调用，
  /// 不能放在 build 里随控制栏反复执行，仅在 init / localFilePath 变化时重算。
  bool _isLocalFileAvailable = false;

  bool _computeLocalFileAvailable() {
    final p = widget.localFilePath;
    return p != null && p.isNotEmpty && !kIsWeb && File(p).existsSync();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastWatchdogProgressAt = _now();
    _activePlayUrlInfo = widget.playUrlInfo;
    _lastKnownPosition = widget.initialPosition ?? Duration.zero;
    _danmakuController = DanmakuController();
    _danmakuController.setDanmakus(widget.danmakus);
    _isLocalFileAvailable = _computeLocalFileAvailable();
    SleepTimerService().registerPauseCallback(_onSleepTimerPause);
    _initSystemBrightnessAndVolume();
    _initPlayer(initialPosition: widget.initialPosition);
  }

  Future<void> _initSystemBrightnessAndVolume() async {
    SystemMediaControlService.instance.updateShowSystemUI(false);

    final rememberedBrightness =
        SystemMediaControlService.instance.sessionBrightness;
    if (rememberedBrightness != null) {
      if (mounted) {
        setState(() {
          _screenBrightness = rememberedBrightness;
        });
      }
      await SystemMediaControlService.instance.setBrightness(
        rememberedBrightness,
        immediate: true,
      );
    } else {
      final sysBrightness = await SystemMediaControlService.instance
          .getBrightness();
      if (sysBrightness != null && mounted) {
        setState(() {
          _screenBrightness = sysBrightness;
        });
      }
    }

    final sysVolume = await SystemMediaControlService.instance.getVolume();
    if (sysVolume != null && mounted) {
      setState(() {
        _currentVolume = sysVolume;
      });
    }
    // 异步初始化期间页面可能已退出（dispose 已 removeVolumeListener），不再回注回调
    if (!mounted) return;
    SystemMediaControlService.instance.addVolumeListener(
      _onSystemVolumeChanged,
    );
  }

  // 有意不在 inactive/paused 时自动暂停（保留后台继续出声的能力），
  // 仅在回到前台（resumed）时检查音画同步、重置卡顿计时并恢复期望倍速。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state != AppLifecycleState.resumed) return;
    _lastWatchdogProgressAt = _now();
    _lastWatchdogVideoPos = currentPosition;
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_isExplicitlyPaused) {
      _reconcileDualStreamPlayback();
      _reassertPlaybackSpeeds();
      _syncAudioWithVideo(alignThreshold: kDashAudioResumeAlignThreshold);
      _startWatchdog();
    }
  }

  int _lastVolumePanEndTime = 0;

  void _onSystemVolumeChanged(double volume) {
    if (!mounted) return;
    // Suppress system broadcast echo while dragging or shortly after gesture ends
    if (_panMode == _PanGestureMode.verticalVolume) return;
    if (DateTime.now().millisecondsSinceEpoch - _lastVolumePanEndTime < 400) {
      return;
    }

    final clamped = volume.clamp(0.0, 1.0);
    // Only show HUD if volume actually changed, preventing HUD popup on player entrance
    final hasRealDifference = (_currentVolume - clamped).abs() > 0.005;

    setState(() {
      _currentVolume = clamped;
    });

    if (hasRealDifference) {
      _showVolumeHud(_currentVolume);
      _dismissHudAfterDelay(const Duration(milliseconds: 1000));
    }
  }

  void _onSleepTimerPause() {
    if (mounted) {
      pause();
    }
  }

  Future<void> seekTo(Duration target) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _seekBothPlayers(target);
      _danmakuController.updatePosition(target.inMilliseconds / 1000.0);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    if (_controller != null) {
      await _applyToPlayers((c) => c.setPlaybackSpeed(speed));
    }
    _danmakuController.setPlaybackSpeed(speed);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant BiliVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.danmakus != oldWidget.danmakus) {
      _danmakuController.setDanmakus(widget.danmakus);
    }
    if (widget.localFilePath != oldWidget.localFilePath) {
      _isLocalFileAvailable = _computeLocalFileAvailable();
    }

    final isSameVideo = (widget.videoKey != null && oldWidget.videoKey != null)
        ? widget.videoKey == oldWidget.videoKey
        : widget.title == oldWidget.title;

    if (widget.localFilePath != oldWidget.localFilePath ||
        widget.playUrlInfo.primaryVideoUrl !=
            oldWidget.playUrlInfo.primaryVideoUrl ||
        widget.playUrlInfo.separateAudioUrl !=
            oldWidget.playUrlInfo.separateAudioUrl ||
        widget.playUrlInfo.currentQuality !=
            oldWidget.playUrlInfo.currentQuality ||
        widget.playUrlInfo.grantedQuality !=
            oldWidget.playUrlInfo.grantedQuality ||
        !isSameVideo) {
      _activePlayUrlInfo = widget.playUrlInfo;
      _isExplicitlyPaused = false;
      _recoveryAttempts = 0;
      if (!isSameVideo) {
        _hasTriedProgressiveFallback = false;
        _lastKnownPosition = widget.initialPosition ?? Duration.zero;
      }
      final Duration? targetPos;
      if (isSameVideo && currentPosition > Duration.zero) {
        // 同视频切画质、刷新流或单流回退时尽量延续当前播放位置
        targetPos = currentPosition;
      } else {
        targetPos = widget.initialPosition;
      }
      _initPlayer(initialPosition: targetPos);
    } else if (widget.playUrlInfo != oldWidget.playUrlInfo) {
      _activePlayUrlInfo = widget.playUrlInfo;
    }
  }

  /// 远程流地址落地：统一经本地代理（.mp4 + 正确 MIME + Referer/Cookie + 磁盘缓存）。
  /// [cacheKey] 用稳定键（bvid+cid+轨+画质），CDN 签名地址变化不影响缓存命中。
  Future<String> _resolveRemoteUrl(
    String url, {
    required bool isAudio,
    String? cacheKey,
    List<String> backupUrls = const [],
  }) async {
    try {
      return await resolvePlayableUrl(
        url,
        isAudio: isAudio,
        cacheKey: cacheKey,
        backupUrls: backupUrls,
      );
    } catch (_) {
      return url;
    }
  }

  /// 播放流磁盘缓存的稳定键：优先 videoKey（bvid_cid）。
  String get _streamCacheBaseKey {
    final key = widget.videoKey;
    if (key != null && key.isNotEmpty) return key;
    return _activePlayUrlInfo.primaryVideoUrl ?? widget.title;
  }

  /// 本地缓存音轨落地：`.m4s` 扩展名会被 iOS AVPlayer 拒绝，优先走本地文件服务，
  /// 失败时回退 `VideoPlayerController.file`。
  Future<VideoPlayerController> _buildAudioController(
    String audioUrl,
    VideoPlayerOptions options, {
    List<String> backupUrls = const [],
  }) async {
    final isLocal =
        !audioUrl.startsWith('http://') && !audioUrl.startsWith('https://');
    if (!kIsWeb && isLocal) {
      final path = audioUrl.startsWith('file:')
          ? (Uri.tryParse(audioUrl)?.toFilePath() ?? audioUrl)
          : audioUrl;
      final proxied = await resolveLocalDashUrl(path, isAudio: true);
      if (proxied.startsWith('http://127.0.0.1:')) {
        return VideoPlayerController.networkUrl(
          Uri.parse(proxied),
          videoPlayerOptions: options,
        );
      }
      return VideoPlayerController.file(
        File(path),
        videoPlayerOptions: options,
      );
    }

    final playable = await _resolveRemoteUrl(
      audioUrl,
      isAudio: true,
      cacheKey: '$_streamCacheBaseKey|a',
      backupUrls: backupUrls,
    );
    return VideoPlayerController.networkUrl(
      Uri.parse(playable),
      videoPlayerOptions: options,
      httpHeaders: kIsWeb ? const {} : _biliHeaders,
    );
  }

  /// 初始化独立伴音轨（与视频轨并行执行，缩短起播等待）。
  ///
  /// 返回 null 表示失败（调用方按音轨失败回退处理）；初始化期间被更新的
  /// 初始化作废或页面退出时，自行 dispose 后返回 null。
  Future<VideoPlayerController?> _initAudioTrack(
    String audioUrl,
    VideoPlayerOptions options,
    int token, {
    List<String> backupUrls = const [],
  }) async {
    VideoPlayerController? audio;
    try {
      audio = await _buildAudioController(
        audioUrl,
        options,
        backupUrls: backupUrls,
      );
      if (!mounted || _initToken != token) {
        try {
          await audio.dispose();
        } catch (_) {}
        return null;
      }
      _pendingAudioController = audio;
      await audio.initialize();
      await audio.setVolume(1.0);
      if (!mounted || _initToken != token || _pendingAudioController != audio) {
        _pendingAudioController = null;
        try {
          await audio.pause();
          await audio.dispose();
        } catch (_) {}
        return null;
      }
      _pendingAudioController = null;
      return audio;
    } catch (_) {
      if (_pendingAudioController == audio) {
        _pendingAudioController = null;
      }
      try {
        await audio?.dispose();
      } catch (_) {}
      return null;
    }
  }

  Future<void> _initPlayer({Duration? initialPosition}) async {
    final int token = ++_initToken;

    _stopWatchdog();
    _isSyncPausedAudio = false;
    _isSyncPausedVideo = false;
    _isResumingAudio = false;
    _isSeekingNow = false;
    _playbackErrorMessage = null;

    final oldController = _controller;
    _controller = null;
    final oldPending = _pendingController;
    _pendingController = null;
    final oldAudioController = _audioController;
    _audioController = null;
    final oldPendingAudio = _pendingAudioController;
    _pendingAudioController = null;

    if (mounted) setState(() {});

    // Immediately stop and dispose any previously active or pending controller
    if (oldController != null) {
      oldController.removeListener(_onPlayerUpdate);
      try {
        await oldController.pause();
        await oldController.dispose();
      } catch (_) {}
    }
    if (oldPending != null) {
      try {
        await oldPending.pause();
        await oldPending.dispose();
      } catch (_) {}
    }
    if (oldAudioController != null) {
      oldAudioController.removeListener(_onPlayerUpdate);
      oldAudioController.removeListener(_onAudioPlayerUpdate);
      try {
        await oldAudioController.pause();
        await oldAudioController.dispose();
      } catch (_) {}
    }
    if (oldPendingAudio != null) {
      try {
        await oldPendingAudio.pause();
        await oldPendingAudio.dispose();
      } catch (_) {}
    }

    if (!mounted || _initToken != token) return;

    final localPath = widget.localFilePath;
    final videoCandidates = _activePlayUrlInfo.primaryVideoCandidateUrls;
    final url = videoCandidates.isNotEmpty
        ? videoCandidates.first
        : _activePlayUrlInfo.primaryVideoUrl;
    final hasLocalFile =
        localPath != null &&
        localPath.isNotEmpty &&
        !kIsWeb &&
        File(localPath).existsSync();

    if (!hasLocalFile && (url == null || url.isEmpty)) return;

    final VideoPlayerController controller;
    // mixWithOthers: true 保持与听书/其他后台音频共存；系统音频焦点策略不在播放器层强制切换
    final playerOptions = VideoPlayerOptions(mixWithOthers: true);
    if (hasLocalFile) {
      controller = VideoPlayerController.file(
        File(localPath),
        videoPlayerOptions: playerOptions,
      );
    } else {
      // 远程轨道统一经本地代理（MIME/Referer 修正 + 边播边磁盘缓存 + 备链故障切换）
      final playableVideoUrl = await _resolveRemoteUrl(
        url!,
        isAudio: false,
        cacheKey: '$_streamCacheBaseKey|v${_activePlayUrlInfo.currentQuality}',
        backupUrls: videoCandidates.length > 1
            ? videoCandidates.sublist(1)
            : const [],
      );
      if (!mounted || _initToken != token) return;
      controller = VideoPlayerController.networkUrl(
        Uri.parse(playableVideoUrl),
        videoPlayerOptions: playerOptions,
        httpHeaders: kIsWeb ? const {} : _biliHeaders,
      );
    }
    _pendingController = controller;

    // DASH 双流：独立音轨（渐进式单流时为 null）
    final audioCandidates = _activePlayUrlInfo.separateAudioCandidateUrls;
    final separateAudioUrl = audioCandidates.isNotEmpty
        ? audioCandidates.first
        : _activePlayUrlInfo.separateAudioUrl;

    // 音轨与视频轨并行初始化：起播等待从「两者之和」降为「两者最大值」
    Future<VideoPlayerController?>? audioInitFuture;
    if (separateAudioUrl != null && separateAudioUrl.isNotEmpty) {
      audioInitFuture = _initAudioTrack(
        separateAudioUrl,
        playerOptions,
        token,
        backupUrls: audioCandidates.length > 1
            ? audioCandidates.sublist(1)
            : const [],
      );
    }

    // 提升到 try 外：视频轨任一步失败时，在此统一释放已就绪的音轨，
    // 否则并行初始化产出的音轨控制器无人持有，平台播放器句柄泄漏
    VideoPlayerController? audioController;
    bool audioFailed = false;
    try {
      await controller.initialize();
      await controller.setVolume(1.0);

      // Guard: Check if the user navigated away or switched to a different video while initializing
      if (!mounted || _initToken != token || _pendingController != controller) {
        try {
          await controller.pause();
          await controller.dispose();
        } catch (_) {}
        return;
      }

      if (audioInitFuture != null) {
        final audio = await audioInitFuture;
        if (!mounted || _initToken != token) {
          // 音轨已就绪但本次初始化已被作废：产出物未被任何字段接管，就地释放
          if (audio != null) {
            try {
              await audio.pause();
              await audio.dispose();
            } catch (_) {}
          }
          return;
        }
        if (audio == null) {
          audioFailed = true;
        } else {
          audioController = audio;
        }
      }

      if (initialPosition != null && initialPosition > Duration.zero) {
        await controller.seekTo(initialPosition);
        _lastKnownPosition = controller.value.position;
        if (widget.initialPosition != null &&
            widget.initialPosition == initialPosition &&
            mounted) {
          AppToast.show(
            context,
            '已定位至上次播放位置 ${Formatters.formatDuration(initialPosition.inSeconds)}',
            icon: Icons.history_rounded,
          );
        }
      }

      // 音轨对齐到视频轨位置后再同时起播，随后由漂移纠偏维持同步
      if (audioController != null) {
        final targetPos = controller.value.position;
        if (targetPos > Duration.zero) {
          try {
            await audioController.seekTo(targetPos);
          } catch (_) {}
        }
      }

      await controller.setPlaybackSpeed(_effectivePlaybackSpeed);
      if (audioController != null) {
        try {
          await audioController.setPlaybackSpeed(_effectivePlaybackSpeed);
        } catch (_) {}
      }

      if (!_isExplicitlyPaused) {
        await controller.play();
        if (audioController != null) {
          if (!controller.value.isBuffering) {
            try {
              await audioController.play();
            } catch (_) {}
          } else {
            _isSyncPausedAudio = true;
          }
        }
      } else {
        await controller.pause();
        if (audioController != null) {
          try {
            await audioController.pause();
          } catch (_) {}
        }
      }

      // Second Guard: Check again after async play call
      if (!mounted || _initToken != token) {
        try {
          await controller.pause();
          await controller.dispose();
        } catch (_) {}
        if (audioController != null) {
          try {
            await audioController.pause();
            await audioController.dispose();
          } catch (_) {}
        }
        return;
      }

      _pendingController = null;
      _controller = controller;
      controller.addListener(_onPlayerUpdate);
      _wasVideoPlaying = false;
      if (audioController != null) {
        _audioController = audioController;
        audioController.addListener(_onAudioPlayerUpdate);
        _wasAudioPlaying = false;
        _lastAudioSyncAt = null;
      }

      _lastWatchdogVideoPos = controller.value.position;
      _lastWatchdogProgressAt = _now();
      if (controller.value.position > Duration.zero) {
        _lastKnownPosition = controller.value.position;
      }
      if (!_isExplicitlyPaused) {
        _startWatchdog();
        _reconcileDualStreamPlayback();
      }

      _danmakuController.syncPlayerState(
        positionSeconds: initialPosition != null
            ? (initialPosition.inMilliseconds / 1000.0)
            : 0.0,
        isPlaying: !_isExplicitlyPaused,
        playbackSpeed: _effectivePlaybackSpeed,
      );

      if (mounted) {
        setState(() {});
        if (!_isExplicitlyPaused) {
          _startHideTimer();
        }
      }

      // 音轨失败时通知页面回退到渐进式单流（避免静默无声音播放）
      if (audioFailed) {
        final callback = widget.onAudioTrackFailed;
        if (callback != null) {
          scheduleMicrotask(() {
            if (mounted && _initToken == token) callback();
          });
        }
      }
    } catch (e) {
      // 视频轨失败时音轨可能已就绪或仍在途：等它落地并释放，
      // 已成功转交给 _audioController 的除外（所有权不在此处）
      if (audioInitFuture != null) {
        try {
          final audio = await audioInitFuture;
          if (audio != null && audio != _audioController) {
            try {
              await audio.pause();
              await audio.dispose();
            } catch (_) {}
          }
        } catch (_) {}
      }
      if (_initToken == token) {
        _pendingController = null;
        _pendingAudioController = null;
        try {
          await controller.dispose();
        } catch (_) {}

        // 无原生播放器插件环境（headless widget 测试）不进入错误重试态
        final isMissingPlugin =
            e is MissingPluginException || e is UnimplementedError;
        if (!isMissingPlugin &&
            !hasLocalFile &&
            _recoveryAttempts < 1 &&
            widget.onRefreshPlayStream != null &&
            mounted) {
          _recoveryAttempts++;
          try {
            final refreshed = await widget.onRefreshPlayStream!(
              _activePlayUrlInfo.currentQuality,
            );
            if (!mounted || _initToken != token) return;
            if (refreshed != null) {
              _activePlayUrlInfo = refreshed;
              await _initPlayer(initialPosition: initialPosition);
              return;
            }
          } catch (_) {}
        }

        if (mounted && _initToken == token) {
          setState(() {
            _controller = null;
            if (!isMissingPlugin) {
              _playbackErrorMessage = '视频加载失败，点击重试';
            }
          });
        }
      }
    }
  }

  /// 对视频轨与伴音轨同时执行同一操作（DASH 双流必须成对下发）
  Future<void> _applyToPlayers(
    Future<void> Function(VideoPlayerController controller) op,
  ) async {
    final video = _controller;
    final audio = _audioController;
    final futures = <Future<void>>[];
    if (video != null) {
      futures.add(op(video).catchError((_) {}));
    }
    if (audio != null) {
      futures.add(op(audio).catchError((_) {}));
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// 成对并行 seek（并记录时间，避免漂移纠偏与用户拖动抢跑）
  Future<void> _seekBothPlayers(Duration target) async {
    _isSeekingNow = true;
    _lastSeekAt = _now();
    _lastKnownPosition = target;
    _lastWatchdogVideoPos = target;
    _lastWatchdogProgressAt = _now();
    try {
      await _applyToPlayers((c) => c.seekTo(target));
    } finally {
      _lastSeekAt = _now();
      _isSeekingNow = false;
    }
    if (mounted) {
      _reconcileDualStreamPlayback();
    }
  }

  /// 以视频轨为时钟纠正伴音轨漂移（超过阈值且距上次纠偏超过间隔才执行）
  void _syncAudioWithVideo({
    Duration alignThreshold = kDashAudioDriftThreshold,
  }) {
    final video = _controller;
    final audio = _audioController;
    if (video == null || audio == null) return;
    if (!video.value.isInitialized || !audio.value.isInitialized) return;
    if (_isSyncPausedAudio || _isSyncPausedVideo || _isResumingAudio) return;

    final now = _now();
    final recentSeek =
        _lastSeekAt != null &&
        now.difference(_lastSeekAt!) < const Duration(milliseconds: 300);
    final isSeeking =
        _isSeekingNow ||
        _isDraggingProgress ||
        _sliderDragPosition.value != null ||
        recentSeek;

    final drift = (video.value.position - audio.value.position).abs();
    if (alignThreshold < kDashAudioDriftThreshold) {
      if (isSeeking || drift < alignThreshold) return;
      if (_lastAudioSyncAt != null &&
          now.difference(_lastAudioSyncAt!) < const Duration(milliseconds: 400)) {
        return;
      }
    } else if (!shouldCorrectDrift(
      videoPosition: video.value.position,
      audioPosition: audio.value.position,
      isSeeking: isSeeking,
      lastSyncAt: _lastAudioSyncAt,
      now: now,
    )) {
      return;
    }

    _lastAudioSyncAt = now;
    final target = video.value.position;
    unawaited(() async {
      try {
        await audio.seekTo(target);
      } catch (_) {}
    }());
  }

  /// 播放状态恢复时把 Dart 侧期望倍速补发到平台（视频轨/伴音轨统一使用
  /// [_effectivePlaybackSpeed]）。同值重复下发不会触发监听回调。
  void _reassertPlaybackSpeeds() {
    final targetSpeed = _effectivePlaybackSpeed;
    final video = _controller;
    if (video != null && video.value.isInitialized && video.value.isPlaying) {
      unawaited(_setPlatformSpeed(video, targetSpeed));
    }
    final audio = _audioController;
    if (audio != null && audio.value.isInitialized && audio.value.isPlaying) {
      unawaited(_setPlatformSpeed(audio, targetSpeed));
    }
  }

  Future<void> _setPlatformSpeed(VideoPlayerController c, double speed) async {
    try {
      await c.setPlaybackSpeed(speed);
    } catch (_) {}
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _lastWatchdogProgressAt = _now();
    _watchdogTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _onWatchdogTick();
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void _onWatchdogTick() {
    if (!mounted) return;
    final video = _controller;
    if (video == null || !video.value.isInitialized) return;

    final val = video.value;
    final now = _now();

    if (val.hasError) {
      if (!_isRecovering && !_isExplicitlyPaused) {
        unawaited(
          _attemptPlaybackRecovery(
            reason: 'watchdogVideoError: ${val.errorDescription ?? 'unknown'}',
            forceReinit: true,
          ),
        );
      }
      return;
    }

    final audio = _audioController;
    if (audio != null && audio.value.hasError) {
      if (!_isRecovering && !_isExplicitlyPaused) {
        unawaited(_handleMidPlaybackAudioError());
      }
      return;
    }

    final isSeeking =
        _isSeekingNow ||
        _isDraggingProgress ||
        _sliderDragPosition.value != null;
    if (isSeeking || _isExplicitlyPaused || _isRecovering || val.isCompleted) {
      _lastWatchdogProgressAt = now;
      _lastWatchdogVideoPos = val.position;
      return;
    }

    if (val.position != _lastWatchdogVideoPos) {
      _lastWatchdogVideoPos = val.position;
      _lastWatchdogProgressAt = now;
      _lastKnownPosition = val.position;
      if (_recoveryAttempts > 0 &&
          now.difference(_lastRecoveryAt) > const Duration(seconds: 10)) {
        _recoveryAttempts = 0;
      }
      _reconcileDualStreamPlayback();
      return;
    }

    _reconcileDualStreamPlayback();

    final stallKind = evaluateVideoStall(
      isInitialized: val.isInitialized,
      isPlaying: val.isPlaying,
      isBuffering: val.isBuffering,
      isCompleted: val.isCompleted,
      hasError: val.hasError,
      isExplicitlyPaused: _isExplicitlyPaused,
      isSyncPausedVideo: _isSyncPausedVideo,
      isSeeking: isSeeking,
      isRecovering: _isRecovering,
      videoPosition: val.position,
      videoDuration: val.duration,
      stalledFor: now.difference(_lastWatchdogProgressAt),
      audioPlaying: audio?.value.isPlaying ?? false,
      audioPosition: audio?.value.position,
    );

    if (stallKind != VideoStallKind.none) {
      unawaited(
        _attemptPlaybackRecovery(
          reason: stallKind.name,
          forceReinit: stallKind == VideoStallKind.bufferTimeout,
        ),
      );
    }
  }

  Future<void> _handleMidPlaybackAudioError() async {
    if (!mounted || _isRecovering || _isExplicitlyPaused) return;
    final video = _controller;
    if (video != null && video.value.isPlaying) {
      _isSyncPausedVideo = true;
      await _pauseQuietly(video);
    }
    await _attemptPlaybackRecovery(
      reason: 'audioError: ${_audioController?.value.errorDescription ?? ''}',
      forceReinit: true,
    );
  }

  Future<void> _attemptPlaybackRecovery({
    required String reason,
    bool forceReinit = false,
  }) async {
    if (!mounted || _isRecovering || _isExplicitlyPaused) return;
    _isRecovering = true;
    final token = _initToken;
    final resumePos = currentPosition;
    final isDash = _audioController != null;

    // 恢复期间立即暂停伴音轨，彻底避免"画面卡住、声音还在播"
    final audio = _audioController;
    if (audio != null && audio.value.isPlaying) {
      _isSyncPausedAudio = true;
      await _pauseQuietly(audio);
    }

    _recoveryAttempts++;
    debugPrint(
      'BiliVideoPlayer: recovery #$_recoveryAttempts ($reason) at $resumePos',
    );

    if (_recoveryAttempts > _maxRecoveryAttempts) {
      if (isDash &&
          !_hasTriedProgressiveFallback &&
          widget.onDashPlaybackFailed != null) {
        _hasTriedProgressiveFallback = true;
        _isRecovering = false;
        widget.onDashPlaybackFailed!.call();
        return;
      }
      _isRecovering = false;
      _stopWatchdog();
      if (mounted && _initToken == token) {
        setState(() {
          _playbackErrorMessage = '视频播放卡顿或流异常，请点击重试';
        });
      }
      return;
    }

    if (mounted) setState(() {});

    try {
      final video = _controller;
      // 第 1 次非报错卡帧：先做原地 seek 踢活（刷新硬解输出与 Texture 帧）
      if (!forceReinit &&
          _recoveryAttempts == 1 &&
          video != null &&
          video.value.isInitialized &&
          !video.value.hasError) {
        _lastSeekAt = _now();
        await video.pause();
        await video.seekTo(resumePos);
        await video.setPlaybackSpeed(_effectivePlaybackSpeed);
        await video.play();
        if (audio != null &&
            audio.value.isInitialized &&
            !audio.value.hasError) {
          await audio.seekTo(resumePos);
          await audio.setPlaybackSpeed(_effectivePlaybackSpeed);
        }
        _lastWatchdogVideoPos = resumePos;
        _lastWatchdogProgressAt = _now();
        _lastRecoveryAt = _now();
        _isRecovering = false;
        _reconcileDualStreamPlayback();
        if (mounted) setState(() {});
        return;
      }

      // 第 2 次及以后（或缓冲挂死/底层报错）：先尝试刷新最新 CDN 播放地址再重建控制器
      if (!_isLocalFileAvailable && widget.onRefreshPlayStream != null) {
        final refreshed = await widget.onRefreshPlayStream!(
          _activePlayUrlInfo.currentQuality,
        );
        if (!mounted || _initToken != token) {
          _isRecovering = false;
          return;
        }
        if (refreshed != null) {
          _activePlayUrlInfo = refreshed;
        }
      }

      _lastRecoveryAt = _now();
      _isRecovering = false;
      await _initPlayer(initialPosition: resumePos);
    } catch (_) {
      _isRecovering = false;
      if (mounted && _initToken == token) {
        setState(() {
          _playbackErrorMessage = '视频恢复播放失败，请点击重试';
        });
      }
    }
  }

  Future<void> _retryPlayback() async {
    _recoveryAttempts = 0;
    _hasTriedProgressiveFallback = false;
    _playbackErrorMessage = null;
    _isExplicitlyPaused = false;
    final resumePos = currentPosition;
    if (mounted) setState(() {});

    if (!_isLocalFileAvailable && widget.onRefreshPlayStream != null) {
      try {
        final refreshed = await widget.onRefreshPlayStream!(
          _activePlayUrlInfo.currentQuality,
        );
        if (!mounted) return;
        if (refreshed != null) {
          _activePlayUrlInfo = refreshed;
        }
      } catch (_) {}
    }

    await _initPlayer(initialPosition: resumePos);
  }

  void _reconcileDualStreamPlayback() {
    final video = _controller;
    final audio = _audioController;
    if (video == null || audio == null) return;

    final decision = evaluateDualStreamSync(
      isExplicitlyPaused: _isExplicitlyPaused,
      isRecovering: _isRecovering,
      videoInitialized: video.value.isInitialized,
      videoPlaying: video.value.isPlaying,
      videoBuffering: video.value.isBuffering,
      videoCompleted: video.value.isCompleted,
      videoHasError: video.value.hasError,
      audioInitialized: audio.value.isInitialized,
      audioPlaying: audio.value.isPlaying,
      audioBuffering: audio.value.isBuffering,
      audioCompleted: audio.value.isCompleted,
      audioHasError: audio.value.hasError,
      isSyncPausedAudio: _isSyncPausedAudio,
      isSyncPausedVideo: _isSyncPausedVideo,
    );

    _isSyncPausedAudio = decision.nextSyncPausedAudio;
    _isSyncPausedVideo = decision.nextSyncPausedVideo;

    if (decision.pauseAudio) {
      unawaited(_pauseQuietly(audio));
    }
    if (decision.pauseVideo) {
      unawaited(_pauseQuietly(video));
    }
    if (decision.resumeVideo && decision.resumeAudio) {
      unawaited(() async {
        await _resumeVideoQuietly(video);
        await _resumeAudioAligned(video, audio);
      }());
    } else if (decision.resumeVideo) {
      unawaited(_resumeVideoQuietly(video));
    } else if (decision.resumeAudio) {
      unawaited(_resumeAudioAligned(video, audio));
    }
  }

  Future<void> _pauseQuietly(VideoPlayerController c) async {
    try {
      await c.pause();
    } catch (_) {}
  }

  Future<void> _resumeVideoQuietly(VideoPlayerController video) async {
    try {
      if (!mounted || video != _controller || _isExplicitlyPaused) return;
      await video.setPlaybackSpeed(_effectivePlaybackSpeed);
      await video.play();
      _lastWatchdogProgressAt = _now();
    } catch (_) {}
  }

  Future<void> _resumeAudioAligned(
    VideoPlayerController video,
    VideoPlayerController audio,
  ) async {
    if (_isResumingAudio) return;
    _isResumingAudio = true;
    try {
      if (!mounted ||
          video != _controller ||
          audio != _audioController ||
          _isExplicitlyPaused ||
          _isRecovering ||
          video.value.isBuffering ||
          !video.value.isPlaying) {
        return;
      }
      final videoPos = video.value.position;
      final audioPos = audio.value.position;
      final drift = (videoPos - audioPos).abs();
      if (drift >= kDashAudioResumeAlignThreshold &&
          !_isSeekingNow &&
          !_isDraggingProgress &&
          _sliderDragPosition.value == null) {
        _lastAudioSyncAt = _now();
        await audio.seekTo(videoPos);
      }
      if (!mounted ||
          video != _controller ||
          audio != _audioController ||
          _isExplicitlyPaused ||
          _isRecovering ||
          video.value.isBuffering ||
          !video.value.isPlaying) {
        return;
      }
      await audio.setPlaybackSpeed(_effectivePlaybackSpeed);
      await audio.play();
    } catch (_) {
    } finally {
      _isResumingAudio = false;
    }
  }

  void _enableWakelock() {
    if (!_wakelockEnabled) {
      _wakelockEnabled = true;
      try {
        WakelockPlus.enable();
      } catch (_) {}
    }
  }

  void _disableWakelock() {
    if (_wakelockEnabled) {
      _wakelockEnabled = false;
      try {
        WakelockPlus.disable();
      } catch (_) {}
    }
  }

  void _onPlayerUpdate() {
    if (!mounted || _controller == null) return;

    final val = _controller!.value;
    if (val.isInitialized && val.position > Duration.zero) {
      _lastKnownPosition = val.position;
    }
    if (val.position != _lastWatchdogVideoPos) {
      _lastWatchdogVideoPos = val.position;
      _lastWatchdogProgressAt = _now();
    }

    if (val.hasError) {
      _disableWakelock();
      _danmakuController.setPlaying(false);
      if (!_isRecovering && !_isExplicitlyPaused) {
        unawaited(
          _attemptPlaybackRecovery(
            reason: 'videoError: ${val.errorDescription ?? 'unknown'}',
            forceReinit: true,
          ),
        );
      }
      return;
    }

    if (val.isPlaying && !_wasVideoPlaying) {
      _reassertPlaybackSpeeds();
    }
    _wasVideoPlaying = val.isPlaying;
    if (val.isPlaying) {
      _enableWakelock();
    } else {
      _disableWakelock();
    }

    final posSec = val.position.inMilliseconds / 1000.0;
    _danmakuController.syncPlayerState(
      positionSeconds: posSec,
      isPlaying: val.isPlaying,
      playbackSpeed: _effectivePlaybackSpeed,
    );

    // DASH 双流：缓冲态协同 + 视频轨为时钟纠正伴音轨漂移
    _reconcileDualStreamPlayback();
    if (val.isPlaying && !val.isBuffering && !_isSyncPausedVideo) {
      _syncAudioWithVideo();
    }

    widget.onProgressUpdate?.call(val.position, val.duration);
  }

  /// 伴音轨状态监听：缓冲恢复时补发平台倍速并联动视频轨同步状态。
  void _onAudioPlayerUpdate() {
    if (!mounted) return;
    final audio = _audioController;
    if (audio == null) return;
    if (audio.value.hasError) {
      if (!_isRecovering && !_isExplicitlyPaused) {
        unawaited(_handleMidPlaybackAudioError());
      }
      return;
    }
    if (audio.value.isPlaying && !_wasAudioPlaying) {
      _reassertPlaybackSpeeds();
    }
    _wasAudioPlaying = audio.value.isPlaying;
    _reconcileDualStreamPlayback();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          _controller != null &&
          _controller!.value.isPlaying &&
          !_showQualityPanel &&
          !_showSpeedPanel &&
          !_showChapterPanel &&
          !_showSubtitlePanel &&
          !_isDraggingProgress) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_showQualityPanel ||
        _showSpeedPanel ||
        _showChapterPanel ||
        _showSubtitlePanel) {
      setState(() {
        _showQualityPanel = false;
        _showSpeedPanel = false;
        _showChapterPanel = false;
        _showSubtitlePanel = false;
      });
      return;
    }
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  Future<void> pause() async {
    _isExplicitlyPaused = true;
    _isSyncPausedAudio = false;
    _isSyncPausedVideo = false;
    _stopWatchdog();
    await _applyToPlayers((c) => c.pause());
    if (_pendingController != null) {
      try {
        await _pendingController!.pause();
      } catch (_) {}
    }
    if (_pendingAudioController != null) {
      try {
        await _pendingAudioController!.pause();
      } catch (_) {}
    }
    _danmakuController.setPlaying(false);
    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }
  }

  Future<void> play() async {
    _isExplicitlyPaused = false;
    _isSyncPausedAudio = false;
    _isSyncPausedVideo = false;
    _playbackErrorMessage = null;
    final video = _controller;
    if (video == null) return;

    if (video.value.hasError) {
      await _retryPlayback();
      return;
    }

    if (video.value.isCompleted) {
      await _seekBothPlayers(Duration.zero);
    }

    if (!video.value.isPlaying ||
        (_audioController != null && !_audioController!.value.isPlaying)) {
      await video.setPlaybackSpeed(_effectivePlaybackSpeed);
      await video.play();
      final audio = _audioController;
      if (audio != null && audio.value.isInitialized) {
        if (!video.value.isBuffering) {
          await _resumeAudioAligned(video, audio);
        } else {
          _isSyncPausedAudio = true;
        }
      }
      _lastWatchdogVideoPos = video.value.position;
      _lastWatchdogProgressAt = _now();
      _startWatchdog();
      _danmakuController.setPlaying(true);
      _startHideTimer();
      if (mounted) setState(() {});
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    final video = _controller!;
    if (video.value.isPlaying ||
        (!_isExplicitlyPaused &&
            (video.value.isBuffering || _isSyncPausedVideo))) {
      pause();
      _hideTimer?.cancel();
    } else {
      play();
    }
  }

  void _toggleLock() {
    setState(() {
      _isScreenLocked = !_isScreenLocked;
      if (_isScreenLocked) {
        _showControls = false;
        _showQualityPanel = false;
        _showSpeedPanel = false;
        _showChapterPanel = false;
        _showLockIcon = true;
        _startLockIconTimer();
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        if (isLandscape) {
          SystemChrome.setPreferredOrientations([_currentLandscapeOrientation]);
        } else {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        }
      } else {
        _showControls = true;
        _showLockIcon = true;
        _startHideTimer();
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        if (isLandscape || _isFullScreen) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          if (PlayerSettingsService.autoRotateFullScreen) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
          }
        }
      }
    });
    HapticFeedback.lightImpact();
  }

  void _startLockIconTimer() {
    _lockIconTimer?.cancel();
    _lockIconTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isScreenLocked) {
        setState(() {
          _showLockIcon = false;
        });
      }
    });
  }

  void _toggleLockIconVisibility() {
    setState(() {
      _showLockIcon = !_showLockIcon;
    });
    if (_showLockIcon) {
      _startLockIconTimer();
    } else {
      _lockIconTimer?.cancel();
    }
  }

  bool get isVerticalVideo =>
      _controller != null &&
      _controller!.value.isInitialized &&
      _controller!.value.aspectRatio < 0.95;

  void _toggleFullScreen() {
    final isMobileLandscape =
        ResponsiveUtil.isMobile &&
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (_isFullScreen || isMobileLandscape) {
      exitFullScreen();
    } else {
      enterFullScreen();
    }
  }

  bool get isFullScreen => _isFullScreen;

  void toggleFullScreen() {
    _toggleFullScreen();
  }

  void enterFullScreen() {
    _setFullScreen(true);
  }

  void exitFullScreen() {
    _setFullScreen(false);
  }

  void _setFullScreen(bool full, {bool? forceLandscape}) {
    if (_isFullScreen == full && forceLandscape == null) return;
    setState(() {
      _isFullScreen = full;
      if (!_isFullScreen) {
        _isScreenLocked = false;
        _showChapterPanel = false;
        _showQualityPanel = false;
        _showSpeedPanel = false;
        _showSubtitlePanel = false;
      }
    });
    widget.onFullScreenChanged?.call(_isFullScreen);

    if (!ResponsiveUtil.isMobile) {
      return;
    }

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (isVerticalVideo && !(forceLandscape ?? false)) {
        // Vertical video enters portrait immersive fullscreen
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        // Horizontal video or forced landscape enters landscape fullscreen
        _currentLandscapeOrientation = DeviceOrientation.landscapeLeft;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      // Re-enable sensor auto-rotation for the video detail page after restoring portrait if enabled
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isFullScreen) {
          if (PlayerSettingsService.autoRotateFullScreen) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
          }
        }
      });
    }
  }

  void _toggleFullscreenOrientation() {
    if (!ResponsiveUtil.isMobile) return;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isVerticalVideo) {
      if (isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } else {
      // Horizontal video: Flip 180° between landscapeLeft and landscapeRight
      if (_currentLandscapeOrientation == DeviceOrientation.landscapeLeft) {
        _currentLandscapeOrientation = DeviceOrientation.landscapeRight;
      } else {
        _currentLandscapeOrientation = DeviceOrientation.landscapeLeft;
      }
      SystemChrome.setPreferredOrientations([_currentLandscapeOrientation]);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted &&
            (_isFullScreen ||
                MediaQuery.of(context).orientation == Orientation.landscape)) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      });
    }
    HapticFeedback.lightImpact();
  }

  void _setVideoFit(BoxFit fit) {
    if (_videoFit == fit) return;
    setState(() => _videoFit = fit);
    HapticFeedback.selectionClick();
    _showTextHud(
      icon: fit == BoxFit.cover
          ? Icons.fit_screen_rounded
          : Icons.aspect_ratio_rounded,
      text: fit == BoxFit.cover ? '铺满画面' : '适应画面',
    );
  }

  void _toggleQualityPanel() {
    setState(() {
      _showQualityPanel = !_showQualityPanel;
      _showSpeedPanel = false;
      _showChapterPanel = false;
      _showSubtitlePanel = false;
    });
    _startHideTimer();
  }

  void _toggleSpeedPanel() {
    setState(() {
      _showSpeedPanel = !_showSpeedPanel;
      _showQualityPanel = false;
      _showChapterPanel = false;
      _showSubtitlePanel = false;
    });
    _startHideTimer();
  }

  void _toggleChapterPanel() {
    setState(() {
      _showChapterPanel = !_showChapterPanel;
      _showQualityPanel = false;
      _showSpeedPanel = false;
      _showSubtitlePanel = false;
    });
    _startHideTimer();
  }

  void _toggleSubtitlePanel() {
    setState(() {
      _showSubtitlePanel = !_showSubtitlePanel;
      _showQualityPanel = false;
      _showSpeedPanel = false;
      _showChapterPanel = false;
    });
    _startHideTimer();
  }

  Future<void> _showDanmakuSettings() async {
    _hideTimer?.cancel();
    await PlayerDanmakuSheet.show(
      context,
      danmakuController: _danmakuController,
      accent: _getPlayerAccent(context),
    );
    if (mounted) _startHideTimer();
  }

  Future<void> _openSleepTimerSheet() async {
    _hideTimer?.cancel();
    await SleepTimerBottomSheet.show(context);
    if (mounted) _startHideTimer();
  }

  @override
  void dispose() {
    _initToken++;
    WidgetsBinding.instance.removeObserver(this);
    _stopWatchdog();
    SleepTimerService().unregisterPauseCallback(_onSleepTimerPause);
    _hideTimer?.cancel();
    _lockIconTimer?.cancel();
    _hudTimer?.cancel();
    _doubleTapRippleTimer?.cancel();
    _sliderDragPosition.dispose();
    _hudNotifier.dispose();
    _dragSeekTarget.dispose();
    _dragSeekCancelled.dispose();
    _doubleTapRippleNotifier.dispose();
    _disableWakelock();
    SystemMediaControlService.instance.removeVolumeListener();
    SystemMediaControlService.instance.resetBrightness();
    SystemMediaControlService.instance.updateShowSystemUI(true);
    if (_controller != null) {
      _controller!.removeListener(_onPlayerUpdate);
      try {
        _controller!.pause();
        _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
    if (_pendingController != null) {
      try {
        _pendingController!.pause();
        _pendingController!.dispose();
      } catch (_) {}
      _pendingController = null;
    }
    if (_audioController != null) {
      _audioController!.removeListener(_onPlayerUpdate);
      _audioController!.removeListener(_onAudioPlayerUpdate);
      try {
        _audioController!.pause();
        _audioController!.dispose();
      } catch (_) {}
      _audioController = null;
    }
    if (_pendingAudioController != null) {
      try {
        _pendingAudioController!.pause();
        _pendingAudioController!.dispose();
      } catch (_) {}
      _pendingAudioController = null;
    }
    _playerFocusNode.dispose();
    _danmakuController.dispose();
    // 方向与系统栏状态由外层 VideoDetailScreen / CachedVideoPlayerScreen 统一退出恢复，
    // 防止切集或同页刷新流时把全屏播放踢回竖屏。
    super.dispose();
  }

  /// 桌面端与 Web 端键盘快捷键映射：聚焦播放器时支持播放控制、快进退、音量、全屏与面板退出。
  Map<ShortcutActivator, VoidCallback> _buildKeyboardShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.space): _handleSpaceKey,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          _handleSeekByKey(-5),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          _handleSeekByKey(5),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          _adjustVolumeByKey(0.1),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          _adjustVolumeByKey(-0.1),
      const SingleActivator(LogicalKeyboardKey.keyF): () {
        if (!_isScreenLocked) _toggleFullScreen();
      },
      const SingleActivator(LogicalKeyboardKey.escape): _handleEscapeKey,
    };
  }

  void _handleSpaceKey() {
    if (_isScreenLocked || _controller == null) return;
    _togglePlayPause();
    final isNowPlaying =
        _controller!.value.isPlaying && !_isExplicitlyPaused;
    _showPlayPauseHud(isPlaying: isNowPlaying);
  }

  void _handleSeekByKey(int deltaSeconds) {
    if (_isScreenLocked) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    _seekRelative(deltaSeconds);
    _showTextHud(
      icon: deltaSeconds > 0
          ? Icons.fast_forward_rounded
          : Icons.fast_rewind_rounded,
      text: deltaSeconds > 0 ? '+${deltaSeconds}s' : '${deltaSeconds}s',
    );
  }

  void _adjustVolumeByKey(double delta) {
    if (_isScreenLocked) return;
    final next = (_currentVolume + delta).clamp(0.0, 1.0);
    unawaited(setVolume(next));
    _showVolumeHud(next);
    _dismissHudAfterDelay(const Duration(milliseconds: 900));
  }

  void _handleEscapeKey() {
    if (_showQualityPanel ||
        _showSpeedPanel ||
        _showChapterPanel ||
        _showSubtitlePanel) {
      setState(() {
        _showQualityPanel = false;
        _showSpeedPanel = false;
        _showChapterPanel = false;
        _showSubtitlePanel = false;
      });
      return;
    }
    if (_isFullScreen) {
      exitFullScreen();
    }
  }

  void _seekRelative(int deltaSeconds) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final current = _controller!.value.position;
    final total = _controller!.value.duration;
    if (total.inMilliseconds <= 0) return;
    final targetMs = (current.inMilliseconds + deltaSeconds * 1000).clamp(
      0,
      total.inMilliseconds,
    );
    final target = Duration(milliseconds: targetMs);
    unawaited(_seekBothPlayers(target));
    _danmakuController.updatePosition(targetMs / 1000.0);
    HapticFeedback.lightImpact();
  }

  void _showDoubleTapRipple({required bool isForward, required int totalSeconds}) {
    _doubleTapRippleTimer?.cancel();
    _doubleTapRippleNotifier.value = _DoubleTapRippleData(
      isForward: isForward,
      totalSeconds: totalSeconds,
      token: ++_doubleTapRippleSeq,
    );
    _doubleTapRippleTimer = Timer(const Duration(milliseconds: 680), () {
      if (mounted) {
        _doubleTapRippleNotifier.value = null;
      }
    });
  }

  void _showTextHud({required IconData icon, required String text}) {
    _hudTimer?.cancel();
    _hudNotifier.value = _PlayerHudData(
      icon: icon,
      text: text,
      alignment: Alignment.center,
    );
    _hudTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        _hudNotifier.value = null;
      }
    });
  }

  void _showPlayPauseHud({required bool isPlaying}) {
    _hudTimer?.cancel();
    _hudNotifier.value = _PlayerHudData(
      icon: isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
      text: isPlaying ? '播放' : '暂停',
      alignment: Alignment.center,
    );
    _hudTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        _hudNotifier.value = null;
      }
    });
  }

  void _showBrightnessHud(double brightness) {
    final percent = (brightness * 100).round();
    final IconData icon = brightness >= 0.7
        ? Icons.brightness_high_rounded
        : (brightness >= 0.3
              ? Icons.brightness_medium_rounded
              : Icons.brightness_low_rounded);

    if (_hudNotifier.value != null &&
        _lastHudPercent == percent &&
        _hudNotifier.value!.progress == brightness) {
      return;
    }
    _lastHudPercent = percent;

    _hudTimer?.cancel();
    _hudNotifier.value = _PlayerHudData(
      icon: icon,
      text: '$percent%',
      progress: brightness,
      alignment: const Alignment(-0.65, 0.0),
    );
  }

  void _showVolumeHud(double volume) {
    final percent = (volume * 100).round();
    final IconData icon = volume <= 0.001
        ? Icons.volume_off_rounded
        : (volume <= 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded);

    if (_hudNotifier.value != null &&
        _lastHudPercent == percent &&
        _hudNotifier.value!.progress == volume) {
      return;
    }
    _lastHudPercent = percent;

    _hudTimer?.cancel();
    _hudNotifier.value = _PlayerHudData(
      icon: icon,
      text: '$percent%',
      progress: volume,
      alignment: const Alignment(0.65, 0.0),
    );
  }

  void _dismissHudAfterDelay([
    Duration duration = const Duration(milliseconds: 750),
  ]) {
    _hudTimer?.cancel();
    _hudTimer = Timer(duration, () {
      if (mounted) {
        _lastHudPercent = -1;
        _hudNotifier.value = null;
      }
    });
  }

  Color _getPlayerAccent(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // 播放器叠加层永远压在暗底视频画面上，仅当主色过暗（如浅色模式水墨 #22242A，
    // 亮度 < 0.179）时回退为浅白，避免暗色模式下的粉/紫等主题色也被误切回白色。
    if (primary.computeLuminance() <= 0.179) {
      return AppTheme.textMainDark;
    }
    return primary;
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isScreenLocked) {
      _toggleLockIconVisibility();
      return;
    }
    final hasController =
        _controller != null && _controller!.value.isInitialized;
    final now = _now();
    final playerWidth =
        context.size?.width ?? MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;
    final edgeRatio = PlayerSettingsService.doubleTapEdgeRatio;
    final zone = x < playerWidth * edgeRatio
        ? _TapZone.left
        : (x > playerWidth * (1 - edgeRatio) ? _TapZone.right : _TapZone.center);

    final isDoubleTap =
        hasController &&
        _lastTapUpAt != null &&
        _lastTapZone == zone &&
        now.difference(_lastTapUpAt!) <= const Duration(milliseconds: 240);

    if (isDoubleTap) {
      _lastTapUpAt = now;
      // 还原首击触发的控制栏显隐跳变，实现 0ms 单击响应与双击无缝仲裁
      if (_showControls != _controlsBeforeFirstTap) {
        setState(() => _showControls = _controlsBeforeFirstTap);
        if (_showControls) {
          _startHideTimer();
        } else {
          _hideTimer?.cancel();
        }
      }
      final seekSeconds = PlayerSettingsService.doubleTapSeekSeconds;
      if (zone == _TapZone.left) {
        _doubleTapStreak = _doubleTapStreak < 0 ? _doubleTapStreak - 1 : -1;
        _seekRelative(-seekSeconds);
        _showDoubleTapRipple(
          isForward: false,
          totalSeconds: _doubleTapStreak.abs() * seekSeconds,
        );
      } else if (zone == _TapZone.right) {
        _doubleTapStreak = _doubleTapStreak > 0 ? _doubleTapStreak + 1 : 1;
        _seekRelative(seekSeconds);
        _showDoubleTapRipple(
          isForward: true,
          totalSeconds: _doubleTapStreak * seekSeconds,
        );
      } else {
        _doubleTapStreak = 0;
        final video = _controller!;
        final currentlyPlaying =
            video.value.isPlaying ||
            (!_isExplicitlyPaused &&
                (video.value.isBuffering || _isSyncPausedVideo));
        final willPlay = !currentlyPlaying;
        _togglePlayPause();
        _showPlayPauseHud(isPlaying: willPlay);
      }
      return;
    }

    _lastTapUpAt = now;
    _lastTapZone = zone;
    _doubleTapStreak = 0;
    _controlsBeforeFirstTap = _showControls;
    _toggleControls();
  }

  void _resetScaleGestureState() {
    _accumulatedPanDx = 0.0;
    _accumulatedPanDy = 0.0;
    _panDownLocalPosition = null;
    _panDownGlobalPosition = null;
    _isPanGestureIgnored = false;
    _hasPinchedInGesture = false;
    _panMode = _PanGestureMode.none;
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLandscape =
        ResponsiveUtil.isMobile &&
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isFull = _isFullScreen || isMobileLandscape;
    final accent = _getPlayerAccent(context);

    final hasController =
        _controller != null && _controller!.value.isInitialized;

    Widget playerBody = Container(
      key: _playerBodyKey,
      decoration: const BoxDecoration(color: Colors.black),
      clipBehavior: Clip.hardEdge,
      child: Listener(
        onPointerDown: (event) {
          _panDownLocalPosition = event.localPosition;
          _panDownGlobalPosition = event.position;
          if ((ResponsiveUtil.isDesktop || kIsWeb || _isFullScreen) &&
              !_playerFocusNode.hasFocus) {
            _playerFocusNode.requestFocus();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTapUp,
          onLongPressStart: (details) {
            if (_isScreenLocked ||
                !hasController ||
                !PlayerSettingsService.enableLongPressSpeed) {
              return;
            }
            final speedValue = PlayerSettingsService.longPressSpeedValue;
            _speedBeforeLongPress = _playbackSpeed;
            _isLongPressSpeeding = true;
            unawaited(_applyToPlayers((c) => c.setPlaybackSpeed(speedValue)));
            _danmakuController.setPlaybackSpeed(speedValue);
            HapticFeedback.selectionClick();
            setState(() {});
          },
          onLongPressEnd: (details) {
            if (!_isLongPressSpeeding) return;
            _isLongPressSpeeding = false;
            unawaited(
              _applyToPlayers((c) => c.setPlaybackSpeed(_speedBeforeLongPress)),
            );
            _danmakuController.setPlaybackSpeed(_speedBeforeLongPress);
            setState(() {});
          },
          onLongPressCancel: () {
            if (!_isLongPressSpeeding) return;
            _isLongPressSpeeding = false;
            unawaited(
              _applyToPlayers((c) => c.setPlaybackSpeed(_speedBeforeLongPress)),
            );
            _danmakuController.setPlaybackSpeed(_speedBeforeLongPress);
            setState(() {});
          },
          onScaleStart: (details) {
            _hasPinchedInGesture = false;
            if (_isScreenLocked ||
                _isLongPressSpeeding ||
                details.pointerCount >= 2) {
              _isPanGestureIgnored = true;
              _panMode = _PanGestureMode.none;
              return;
            }

            final mediaQuery = MediaQuery.of(context);
            final topSafe = math.max(
              mediaQuery.viewPadding.top,
              mediaQuery.padding.top,
            );
            final downLocal = _panDownLocalPosition ?? details.localFocalPoint;
            final downGlobal = _panDownGlobalPosition ?? details.focalPoint;

            // 顶部排除区：仅按全局坐标检查状态栏，并固定局部顶栏下拉热区 48dp，
            // 修复竖屏 SafeArea 下局部坐标重复叠加 topSafe 造成顶部 40% 死区的问题。
            final double localTopExclusion =
                (isFull && topSafe > 0) ? (topSafe + 40.0) : 48.0;
            if (downGlobal.dy < topSafe + 24.0 ||
                downLocal.dy < localTopExclusion) {
              _isPanGestureIgnored = true;
              return;
            }

            // 非全屏左侧边缘留白 24dp：让渡给系统/Cupertino 左边缘侧滑返回手势
            if (!isFull && downLocal.dx < 24.0) {
              _isPanGestureIgnored = true;
              return;
            }

            // 底部排除区：全屏护航系统上滑手势，小窗护航底部进度条拖动手势
            final bottomSafe = math.max(
              mediaQuery.viewPadding.bottom,
              mediaQuery.padding.bottom,
            );
            final playerHeight = context.size?.height ?? mediaQuery.size.height;
            final bottomThreshold = isFull
                ? math.max(bottomSafe + 40.0, 60.0)
                : (playerHeight > 260.0 ? 60.0 : 44.0);
            if (downLocal.dy > playerHeight - bottomThreshold) {
              _isPanGestureIgnored = true;
              return;
            }

            _isPanGestureIgnored = false;
            _isDraggingProgress = false;
            _dragSeekCancelled.value = false;
            _panMode = _PanGestureMode.none;
            _panStartPosition = downLocal;
            _dragStartPosition = _controller?.value.position ?? Duration.zero;
            _targetSeekPosition = _dragStartPosition;
            _accumulatedPanDx = 0.0;
            _accumulatedPanDy = 0.0;
          },
          onScaleUpdate: (details) {
            if (_isScreenLocked || _isLongPressSpeeding) return;

            // 双指捏合缩放：铺满画面 / 适应画面切换
            if (details.pointerCount >= 2) {
              if (!_hasPinchedInGesture && hasController) {
                if (details.scale > 1.18 && _videoFit != BoxFit.cover) {
                  _hasPinchedInGesture = true;
                  _setVideoFit(BoxFit.cover);
                } else if (details.scale < 0.85 && _videoFit != BoxFit.contain) {
                  _hasPinchedInGesture = true;
                  _setVideoFit(BoxFit.contain);
                }
              }
              return;
            }

            if (_isPanGestureIgnored) return;

            final delta = details.focalPointDelta;
            _accumulatedPanDx += delta.dx;
            _accumulatedPanDy += delta.dy;

            final totalDuration = _controller?.value.duration ?? Duration.zero;
            final mediaQuery = MediaQuery.of(context);
            final playerWidth = context.size?.width ?? mediaQuery.size.width;
            final playerHeight =
                context.size?.height ?? mediaQuery.size.height;

            // 手势仲裁
            if (_panMode == _PanGestureMode.none) {
              final absDx = _accumulatedPanDx.abs();
              final absDy = _accumulatedPanDy.abs();

              if (hasController &&
                  PlayerSettingsService.enableHorizontalPanSeek &&
                  absDx >= 20.0 &&
                  absDx > absDy * 1.5) {
                _panMode = _PanGestureMode.horizontalSeek;
                _isDraggingProgress = true;
                _dragSeekCancelled.value = false;
                _hideTimer?.cancel();
                HapticFeedback.selectionClick();
              } else if (absDy >= 16.0 && absDy > absDx * 1.2) {
                _hideTimer?.cancel();
                if (_panStartPosition.dx < playerWidth * 0.30) {
                  if (!PlayerSettingsService.enableVerticalPanVolumeBrightness) {
                    return;
                  }
                  _panMode = _PanGestureMode.verticalBrightness;
                  HapticFeedback.selectionClick();
                  _showBrightnessHud(_screenBrightness);
                } else if (_panStartPosition.dx > playerWidth * 0.70) {
                  if (!PlayerSettingsService.enableVerticalPanVolumeBrightness) {
                    return;
                  }
                  _panMode = _PanGestureMode.verticalVolume;
                  HapticFeedback.selectionClick();
                  _showVolumeHud(_currentVolume);
                } else {
                  // 中间 40% 区域：上滑进全屏 / 下滑退全屏
                  _panMode = _PanGestureMode.verticalFullscreen;
                }
              } else {
                return;
              }
            }

            switch (_panMode) {
              case _PanGestureMode.horizontalSeek:
                if (totalDuration.inMilliseconds <= 0) return;
                final cancelled = _accumulatedPanDy.abs() > 64.0;
                if (_dragSeekCancelled.value != cancelled) {
                  _dragSeekCancelled.value = cancelled;
                  HapticFeedback.selectionClick();
                }
                if (cancelled) return;
                const double dragThreshold = 20.0;
                final effectiveDelta = _accumulatedPanDx > 0
                    ? (_accumulatedPanDx - dragThreshold)
                    : (_accumulatedPanDx + dragThreshold);
                final scaleDuration = totalDuration.inSeconds > 600
                    ? 90.0
                    : (totalDuration.inSeconds > 180 ? 45.0 : 20.0);
                final deltaSeconds =
                    (effectiveDelta / math.max(playerWidth, 240.0)) *
                    scaleDuration;
                final targetMs =
                    (_dragStartPosition.inMilliseconds +
                            (deltaSeconds * 1000).toInt())
                        .clamp(0, totalDuration.inMilliseconds);
                final target = Duration(milliseconds: targetMs);
                _targetSeekPosition = target;
                _dragSeekTarget.value = target;
                _sliderDragPosition.value = targetMs.toDouble();
                break;

              case _PanGestureMode.verticalBrightness:
                final double effectiveHeight = playerHeight > 100
                    ? playerHeight
                    : 300.0;
                final double step = -delta.dy / (effectiveHeight * 0.75);
                _screenBrightness = (_screenBrightness + step).clamp(0.0, 1.0);
                SystemMediaControlService.instance.rememberBrightness(
                  _screenBrightness,
                );
                SystemMediaControlService.instance.setBrightness(
                  _screenBrightness,
                );
                _showBrightnessHud(_screenBrightness);
                break;

              case _PanGestureMode.verticalVolume:
                final double effectiveHeight = playerHeight > 100
                    ? playerHeight
                    : 300.0;
                final double step = -delta.dy / (effectiveHeight * 0.75);
                _currentVolume = (_currentVolume + step).clamp(0.0, 1.0);
                SystemMediaControlService.instance.setVolume(_currentVolume);
                _showVolumeHud(_currentVolume);
                break;

              case _PanGestureMode.verticalFullscreen:
                if (!isFull && _accumulatedPanDy < -18) {
                  _hudNotifier.value = _PlayerHudData(
                    icon: Icons.fullscreen_rounded,
                    text: _accumulatedPanDy < -40 ? '松手进入全屏' : '继续上滑全屏',
                    alignment: Alignment.center,
                  );
                } else if (isFull && _accumulatedPanDy > 18) {
                  _hudNotifier.value = _PlayerHudData(
                    icon: Icons.fullscreen_exit_rounded,
                    text: _accumulatedPanDy > 40 ? '松手退出全屏' : '继续下滑退出',
                    alignment: Alignment.center,
                  );
                }
                break;

              case _PanGestureMode.none:
                break;
            }
          },
          onScaleEnd: (details) {
            if (_panMode == _PanGestureMode.horizontalSeek) {
              final cancelled = _dragSeekCancelled.value;
              _isDraggingProgress = false;
              _dragSeekTarget.value = null;
              _dragSeekCancelled.value = false;
              _sliderDragPosition.value = null;
              if (!cancelled && hasController) {
                unawaited(_seekBothPlayers(_targetSeekPosition));
                _danmakuController.updatePosition(
                  _targetSeekPosition.inMilliseconds / 1000.0,
                );
              }
              _startHideTimer();
            } else if (_panMode == _PanGestureMode.verticalBrightness ||
                _panMode == _PanGestureMode.verticalVolume) {
              if (_panMode == _PanGestureMode.verticalVolume) {
                _lastVolumePanEndTime = DateTime.now().millisecondsSinceEpoch;
                SystemMediaControlService.instance.setVolume(
                  _currentVolume,
                  immediate: true,
                );
              } else {
                SystemMediaControlService.instance.setBrightness(
                  _screenBrightness,
                  immediate: true,
                );
              }
              _dismissHudAfterDelay(const Duration(milliseconds: 800));
              _startHideTimer();
            } else if (_panMode == _PanGestureMode.verticalFullscreen) {
              _hudNotifier.value = null;
              if (!isFull && _accumulatedPanDy < -40) {
                enterFullScreen();
              } else if (isFull && _accumulatedPanDy > 40) {
                exitFullScreen();
              }
            }

            _resetScaleGestureState();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 过渡封面底图：初始化或切画质期间平滑衬底，消除纯黑闪屏
              if (!hasController &&
                  widget.coverUrl != null &&
                  widget.coverUrl!.isNotEmpty) ...[
                NetworkImageView(
                  url: widget.coverUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
                  memCacheHeight: 300,
                ),
                Container(color: Colors.black38),
              ],

              // 视频画面层
              if (hasController)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _videoFit == BoxFit.cover
                      ? ClipRect(
                          key: const ValueKey('fit_cover'),
                          child: SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.size.width > 0
                                    ? _controller!.value.size.width
                                    : 16,
                                height: _controller!.value.size.height > 0
                                    ? _controller!.value.size.height
                                    : 9,
                                child: RepaintBoundary(
                                  child: VideoPlayer(_controller!),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          key: const ValueKey('fit_contain'),
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: RepaintBoundary(
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        ),
                )
              else if (_playbackErrorMessage == null)
                Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),

              // Danmaku Overlay Layer
              DanmakuOverlay(controller: _danmakuController),

              // Buffering / Recovery indicator (locally listening to controller)
              if (hasController && _playbackErrorMessage == null)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller!,
                  builder: (context, val, _) {
                    if (!val.isBuffering && !_isRecovering) {
                      return const SizedBox.shrink();
                    }
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: OverlayColors.bubble,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white70,
                                ),
                              ),
                            ),
                            if (_isRecovering) ...[
                              const SizedBox(height: 6),
                              const Text(
                                '正在恢复播放...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Playback Error / Stall Retry Overlay
              if (_playbackErrorMessage != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: OverlayColors.bar,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _playbackErrorMessage!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _retryPlayback,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('重试', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 隐藏控制条时的底部极细进度线（仅在控制条隐藏且未拖拽时生效）
              if (!_showControls && !_isScreenLocked && hasController)
                ValueListenableBuilder<Duration?>(
                  valueListenable: _dragSeekTarget,
                  builder: (context, dragTarget, _) {
                    if (dragTarget != null) return const SizedBox.shrink();
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 2,
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _controller!,
                        builder: (context, val, _) {
                          final dur = val.duration.inMilliseconds;
                          if (dur <= 0) return const SizedBox.shrink();
                          final pos = val.position.inMilliseconds;
                          return LinearProgressIndicator(
                            value: (pos / dur).clamp(0.0, 1.0),
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          );
                        },
                      ),
                    );
                  },
                ),

              // 控制层：隐藏完成后彻底卸载内部高频率监听，消除播放期空转重建
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                reverseDuration: Duration.zero,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: (_showControls && !_isScreenLocked)
                    ? KeyedSubtree(
                        key: const ValueKey('controls_visible'),
                        child: _buildControls(context, hasController, isFull),
                      )
                    : const SizedBox.shrink(key: ValueKey('controls_hidden')),
              ),

              // 双击边缘快进/快退波纹动效
              ValueListenableBuilder<_DoubleTapRippleData?>(
                valueListenable: _doubleTapRippleNotifier,
                builder: (context, ripple, _) {
                  if (ripple == null) return const SizedBox.shrink();
                  return Align(
                    alignment: ripple.isForward
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(ripple.token),
                      tween: Tween(begin: 0.72, end: 1.0),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 112,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: ripple.isForward
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                radius: 1.1,
                                colors: [
                                  Colors.white.withValues(alpha: 0.24),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  ripple.isForward
                                      ? Icons.fast_forward_rounded
                                      : Icons.fast_rewind_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ripple.isForward
                                      ? '+${ripple.totalSeconds}秒'
                                      : '-${ripple.totalSeconds}秒',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              // 水平拖拽进度局部浮窗（ValueListenableBuilder 隔离重建）
              if (hasController)
                ValueListenableBuilder<Duration?>(
                  valueListenable: _dragSeekTarget,
                  builder: (context, targetPos, _) {
                    if (targetPos == null) return const SizedBox.shrink();
                    return ValueListenableBuilder<bool>(
                      valueListenable: _dragSeekCancelled,
                      builder: (context, cancelled, _) {
                        final total = _controller!.value.duration;
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 12.0,
                            ),
                            decoration: BoxDecoration(
                              color: OverlayColors.bar,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cancelled
                                    ? Colors.redAccent.withValues(alpha: 0.7)
                                    : Colors.white24,
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      cancelled
                                          ? Icons.close_rounded
                                          : (targetPos >= _dragStartPosition
                                                ? Icons.fast_forward_rounded
                                                : Icons.fast_rewind_rounded),
                                      color: cancelled
                                          ? Colors.redAccent
                                          : accent,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      cancelled
                                          ? '松手取消跳转'
                                          : (targetPos >= _dragStartPosition
                                                ? '+${Formatters.formatDuration((targetPos - _dragStartPosition).inSeconds)}'
                                                : '-${Formatters.formatDuration((_dragStartPosition - targetPos).inSeconds)}'),
                                      style: TextStyle(
                                        color: cancelled
                                            ? Colors.redAccent
                                            : accent,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6.0),
                                Text(
                                  '${Formatters.formatDuration(targetPos.inSeconds)} / ${Formatters.formatDuration(total.inSeconds)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                SizedBox(
                                  width: 140,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: total.inMilliseconds > 0
                                          ? (targetPos.inMilliseconds /
                                                    total.inMilliseconds)
                                                .clamp(0.0, 1.0)
                                          : 0.0,
                                      backgroundColor: Colors.white24,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        cancelled ? Colors.redAccent : accent,
                                      ),
                                      minHeight: 3.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              // 亮度 / 音量 / 播放暂停 / 全屏手势局部 HUD（零整树重建 + 平滑淡出）
              ValueListenableBuilder<_PlayerHudData?>(
                valueListenable: _hudNotifier,
                builder: (context, hud, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    reverseDuration: Duration.zero,
                    child: hud == null
                        ? const SizedBox.shrink(key: ValueKey('hud_none'))
                        : Align(
                            key: ValueKey('${hud.alignment}_${hud.progress != null}'),
                            alignment: hud.alignment,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: hud.progress != null ? 16.0 : 12.0,
                                vertical: hud.progress != null ? 12.0 : 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: OverlayColors.bar,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: hud.progress == null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hud.icon != null) ...[
                                          Icon(
                                            hud.icon,
                                            color: accent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4.0),
                                        ],
                                        Text(
                                          hud.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hud.icon != null) ...[
                                          Icon(
                                            hud.icon,
                                            color: accent,
                                            size: 28,
                                          ),
                                          const SizedBox(height: 8.0),
                                        ],
                                        SizedBox(
                                          width: 64,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: hud.progress!.clamp(
                                                0.0,
                                                1.0,
                                              ),
                                              backgroundColor: Colors.white24,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    accent,
                                                  ),
                                              minHeight: 4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          hud.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                  );
                },
              ),

              // 长按倍速胶囊（SafeArea 避开刘海/灵动岛）
              Positioned(
                top: isFull ? 16 : 10,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: isFull,
                  bottom: false,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: !_isLongPressSpeeding
                        ? const SizedBox.shrink()
                        : Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                color: OverlayColors.bubble,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fast_forward_rounded,
                                    color: accent,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    '${PlayerSettingsService.longPressSpeedValue.toStringAsFixed(1)}X 快进中',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // 横屏锁屏按钮（移动端全屏专属，置于 SafeArea 内避开挖孔）
              if (isFull && ResponsiveUtil.isMobile)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: (_isScreenLocked ? _showLockIcon : _showControls)
                      ? 16
                      : -68,
                  top: 0,
                  bottom: 0,
                  child: SafeArea(
                    right: false,
                    top: false,
                    bottom: false,
                    child: Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleLock,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isScreenLocked
                                  ? accent.withValues(alpha: 0.85)
                                  : OverlayColors.circle,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _isScreenLocked ? accent : Colors.white24,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isScreenLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              color: _isScreenLocked
                                  ? Colors.white
                                  : Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Subtitle Overlay
              if (widget.isSubtitleEnabled &&
                  widget.subtitleData != null &&
                  hasController)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller!,
                  builder: (context, val, _) {
                    return SubtitleOverlay(
                      subtitleData: widget.subtitleData!,
                      currentPosition: val.position,
                      isFullScreen: isFull,
                      bottomOffset: _showControls ? 80.0 : 24.0,
                    );
                  },
                ),

              // 浮窗/抽屉控制面板（全屏贴合右侧抽屉滑出，竖屏居中偏右平滑浮现）
              _buildActiveFloatingPanel(isFull),

              // 自动连播下一集倒计时浮窗（由详情页传入，全屏/竖屏通用）
              if (widget.autoNextOverlay != null) widget.autoNextOverlay!,
            ],
          ),
        ),
      ),
    );

    final Widget result;
    if (isFull) {
      result = playerBody;
    } else if (isVerticalVideo && widget.portraitCollapseListenable != null) {
      final baseRatio = _controller!.value.aspectRatio.clamp(0.72, 1.0);
      result = ValueListenableBuilder<double>(
        valueListenable: widget.portraitCollapseListenable!,
        builder: (context, collapse, child) {
          final t = collapse.clamp(0.0, 1.0);
          final ratio = baseRatio + ((16 / 9) - baseRatio) * t;
          return AspectRatio(aspectRatio: ratio, child: child);
        },
        child: playerBody,
      );
    } else {
      final double effectiveRatio = isVerticalVideo
          ? _controller!.value.aspectRatio.clamp(0.72, 1.0)
          : (hasController && _controller!.value.aspectRatio > 0
                ? _controller!.value.aspectRatio.clamp(1.33, 1.85)
                : 16 / 9);
      result = AspectRatio(aspectRatio: effectiveRatio, child: playerBody);
    }

    return CallbackShortcuts(
      bindings: _buildKeyboardShortcuts(),
      child: Focus(
        focusNode: _playerFocusNode,
        autofocus: ResponsiveUtil.isDesktop || kIsWeb,
        child: result,
      ),
    );
  }

  Widget _buildActiveFloatingPanel(bool isFull) {
    Widget? panel;
    String keyName = 'none';
    if (!_isScreenLocked) {
      if (_showQualityPanel) {
        keyName = 'quality';
        panel = _buildFloatingQualityPanel(isFull);
      } else if (_showSpeedPanel) {
        keyName = 'speed';
        panel = _buildFloatingSpeedPanel(isFull);
      } else if (_showChapterPanel && widget.chapters.isNotEmpty) {
        keyName = 'chapter';
        panel = _buildFloatingChapterPanel(isFull);
      } else if (_showSubtitlePanel && widget.subtitleTracks.isNotEmpty) {
        keyName = 'subtitle';
        panel = _buildFloatingSubtitlePanel(isFull);
      }
    }

    if (isFull) {
      return Positioned(
        top: 12,
        bottom: 52,
        right: 12,
        child: SafeArea(
          left: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            reverseDuration: Duration.zero,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.18, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: panel == null
                ? const SizedBox.shrink(key: ValueKey('drawer_empty'))
                : KeyedSubtree(key: ValueKey('drawer_$keyName'), child: panel),
          ),
        ),
      );
    }

    return Positioned(
      right: 10,
      bottom: 48,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        reverseDuration: Duration.zero,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            alignment: Alignment.bottomRight,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: panel == null
            ? const SizedBox.shrink(key: ValueKey('pop_empty'))
            : KeyedSubtree(key: ValueKey('pop_$keyName'), child: panel),
      ),
    );
  }

  List<({int quality, String description, bool locked})>
  _getAvailableQualities() {
    // 只列视频真实提供的画质；此前无条件补"1080P 60帧"等档位，
    // 大会员点了必被降级并误报"需大会员"。
    return buildQualityPanelItems(
      _activePlayUrlInfo,
      isLoggedIn: BiliHttpClient().isLoggedIn,
      labelOf: _getQualityLabel,
    );
  }

  Widget _buildFloatingQualityPanel(bool isFull) {
    return PlayerQualityPanel(
      qualityItems: _getAvailableQualities(),
      // 选中态用服务端实际授权的画质（DASH 下响应体 quality 字段不可信）
      currentQuality: _activePlayUrlInfo.grantedQuality,
      accent: _getPlayerAccent(context),
      isFull: isFull,
      onSelectQuality: (quality) {
        setState(() => _showQualityPanel = false);
        _startHideTimer();
        widget.onQualityChanged?.call(quality);
      },
    );
  }

  Widget _buildFloatingSpeedPanel(bool isFull) {
    return PlayerSpeedPanel(
      currentSpeed: _playbackSpeed,
      accent: _getPlayerAccent(context),
      isFull: isFull,
      onSelectSpeed: (s) {
        setState(() {
          _playbackSpeed = s;
          _showSpeedPanel = false;
        });
        unawaited(_applyToPlayers((c) => c.setPlaybackSpeed(s)));
        _danmakuController.setPlaybackSpeed(s);
        _startHideTimer();
      },
    );
  }

  Widget _buildFloatingChapterPanel(bool isFull) {
    final currentSec = (_controller?.value.position.inSeconds ?? 0);
    return PlayerChapterPanel(
      chapters: widget.chapters,
      currentSec: currentSec,
      positionListenable: _controller,
      accent: _getPlayerAccent(context),
      isFull: isFull,
      onSelectChapter: (ch) {
        setState(() => _showChapterPanel = false);
        unawaited(_seekBothPlayers(Duration(seconds: ch.from)));
        _danmakuController.updatePosition(ch.from.toDouble());
        _startHideTimer();
      },
    );
  }

  Widget _buildFloatingSubtitlePanel(bool isFull) {
    return PlayerSubtitlePanel(
      subtitleTracks: widget.subtitleTracks,
      currentSubtitleTrack: widget.currentSubtitleTrack,
      isSubtitleEnabled: widget.isSubtitleEnabled,
      accent: _getPlayerAccent(context),
      isFull: isFull,
      onSelectTrack: (track) {
        setState(() => _showSubtitlePanel = false);
        _startHideTimer();
        widget.onSubtitleTrackChanged?.call(track);
      },
    );
  }

  Widget _buildControls(BuildContext context, bool hasController, bool isFull) {
    final accent = _getPlayerAccent(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [0.0, 0.25, 0.72, 1.0],
        ),
      ),
      child: SafeArea(
        top: isFull,
        bottom: isFull,
        left: isFull,
        right: isFull,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar (Back button, Title, Settings)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isFull ? '退出全屏' : '返回',
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: () {
                      if (isFull) {
                        exitFullScreen();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (_isLocalFileAvailable) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 1.5,
                            ),
                            margin: const EdgeInsets.only(right: 4.0),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '已离线',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onListenMode != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.headphones_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      tooltip: '听视频 (熄屏播放)',
                      onPressed: widget.onListenMode,
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: ListenableBuilder(
                      listenable: SleepTimerService(),
                      builder: (context, _) {
                        final active = SleepTimerService().isActive;
                        return Icon(
                          active
                              ? Icons.bedtime_rounded
                              : Icons.bedtime_outlined,
                          color: active ? accent : Colors.white,
                          size: 17,
                        );
                      },
                    ),
                    tooltip: '睡眠定时',
                    onPressed: _openSleepTimerSheet,
                  ),
                  if (isFull)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _videoFit == BoxFit.cover
                            ? Icons.aspect_ratio_rounded
                            : Icons.fit_screen_rounded,
                        color: _videoFit == BoxFit.cover ? accent : Colors.white,
                        size: 17,
                      ),
                      tooltip: _videoFit == BoxFit.cover ? '适应画面' : '铺满屏幕',
                      onPressed: () => _setVideoFit(
                        _videoFit == BoxFit.cover
                            ? BoxFit.contain
                            : BoxFit.cover,
                      ),
                    ),
                  if (isFull && ResponsiveUtil.isMobile)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.screen_rotation_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      tooltip: '翻转/旋转屏幕',
                      onPressed: _toggleFullscreenOrientation,
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '弹幕设置',
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: _showDanmakuSettings,
                  ),
                ],
              ),
            ),

            // Center Play/Pause Quick Toggle (listens to controller)
            if (hasController && _playbackErrorMessage == null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (context, val, _) {
                  if (val.isPlaying ||
                      val.isBuffering ||
                      _isRecovering ||
                      !val.isInitialized) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    iconSize: 46,
                    tooltip: '播放/暂停',
                    icon: Icon(Icons.play_circle_fill_rounded, color: accent),
                    onPressed: _togglePlayPause,
                  );
                },
              )
            else
              const SizedBox.shrink(),

            // 底部控制栏（播放/下一集 + 时间 + 自定义气泡进度条 + 字幕/弹幕/章节/倍速/清晰度/全屏）
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasController)
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller!,
                      builder: (context, val, _) {
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          tooltip: val.isPlaying ? '暂停' : '播放',
                          icon: Icon(
                            val.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: _togglePlayPause,
                        );
                      },
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tooltip: '播放',
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _togglePlayPause,
                    ),

                  if (widget.onNextEpisode != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tooltip: '下一集',
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        _startHideTimer();
                        widget.onNextEpisode?.call();
                      },
                    ),

                  if (hasController)
                    Expanded(
                      child: Row(
                        children: [
                          ValueListenableBuilder<double?>(
                            valueListenable: _sliderDragPosition,
                            builder: (context, dragVal, _) {
                              return ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: _controller!,
                                builder: (context, val, _) {
                                  final currentPos = dragVal != null
                                      ? Duration(milliseconds: dragVal.toInt())
                                      : val.position;
                                  return Text(
                                    '${Formatters.formatDuration(currentPos.inSeconds)} / ${Formatters.formatDuration(val.duration.inSeconds)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: PlayerProgressBar(
                              controller: _controller!,
                              dragPositionMs: _sliderDragPosition,
                              chapters: widget.chapters,
                              accent: accent,
                              onSeekStart: (v) {
                                _hideTimer?.cancel();
                                _isDraggingProgress = true;
                                _sliderDragPosition.value = v;
                              },
                              onSeekUpdate: (v) {
                                _sliderDragPosition.value = v;
                              },
                              onSeekEnd: (v) {
                                final ms = v.toInt();
                                _isDraggingProgress = false;
                                unawaited(
                                  _seekBothPlayers(Duration(milliseconds: ms)),
                                );
                                _danmakuController.updatePosition(ms / 1000.0);
                                _sliderDragPosition.value = null;
                                _startHideTimer();
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),

                  if (widget.subtitleTracks.isNotEmpty ||
                      widget.onSubtitleTap != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      icon: Icon(
                        widget.isSubtitleEnabled
                            ? Icons.closed_caption_rounded
                            : Icons.closed_caption_outlined,
                        color: _showSubtitlePanel
                            ? accent
                            : (widget.isSubtitleEnabled
                                  ? accent
                                  : Colors.white60),
                        size: 20,
                      ),
                      tooltip: '字幕',
                      onPressed: () {
                        if (widget.subtitleTracks.isNotEmpty) {
                          _toggleSubtitlePanel();
                        } else {
                          widget.onSubtitleTap?.call();
                        }
                      },
                    ),

                  ListenableBuilder(
                    listenable: _danmakuController,
                    builder: (ctx, _) {
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        tooltip: _danmakuController.enabled ? '关闭弹幕' : '开启弹幕',
                        icon: Icon(
                          _danmakuController.enabled
                              ? Icons.subtitles_rounded
                              : Icons.subtitles_off_outlined,
                          color: _danmakuController.enabled
                              ? accent
                              : Colors.white60,
                          size: 16,
                        ),
                        onPressed: _danmakuController.toggle,
                      );
                    },
                  ),

                  if (widget.chapters.isNotEmpty) ...[
                    InkWell(
                      onTap: _toggleChapterPanel,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        child: Text(
                          '章节',
                          style: TextStyle(
                            color: _showChapterPanel ? accent : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],

                  InkWell(
                    onTap: _toggleSpeedPanel,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: TextStyle(
                          color: _showSpeedPanel ? accent : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 2),

                  InkWell(
                    onTap: _toggleQualityPanel,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      child: Text(
                        _getQualityLabel(
                          _activePlayUrlInfo.grantedQuality > 0
                              ? _activePlayUrlInfo.grantedQuality
                              : _activePlayUrlInfo.currentQuality,
                        ),
                        style: TextStyle(
                          color: _showQualityPanel ? accent : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    tooltip: isFull ? '退出全屏' : '进入全屏',
                    icon: Icon(
                      isFull
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    onPressed: _toggleFullScreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getQualityLabel(int q) {
    switch (q) {
      case 127:
        return '8K';
      case 120:
        return '4K';
      case 116:
        return '1080P 60';
      case 112:
        return '1080P 高码';
      case 80:
        return '1080P';
      case 74:
        return '720P 60';
      case 64:
        return '720P';
      case 32:
        return '480P';
      case 16:
        return '360P';
      default:
        return '$q P';
    }
  }
}
