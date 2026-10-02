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
import '../app_toast.dart';
import 'components/player_danmaku_sheet.dart';
import 'components/player_floating_panels.dart';
import 'danmaku_overlay.dart';
import 'sleep_timer_bottom_sheet.dart';
import 'subtitle_overlay.dart';

export 'bili_player_value.dart';

class BiliVideoPlayer extends StatefulWidget {
  final PlayUrlInfo playUrlInfo;
  final String? localFilePath;
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
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? currentSubtitleTrack;
  final SubtitleData? subtitleData;
  final bool isSubtitleEnabled;
  final ValueChanged<SubtitleTrack?>? onSubtitleTrackChanged;
  final VoidCallback? onSubtitleTap;

  /// DASH 伴音轨初始化失败时回调（由页面回退到渐进式单流），
  /// 避免出现"有画面没声音"却静默播放的情况。
  final VoidCallback? onAudioTrackFailed;

  const BiliVideoPlayer({
    super.key,
    required this.playUrlInfo,
    this.localFilePath,
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
    this.subtitleTracks = const [],
    this.currentSubtitleTrack,
    this.subtitleData,
    this.isSubtitleEnabled = false,
    this.onSubtitleTrackChanged,
    this.onSubtitleTap,
    this.onAudioTrackFailed,
  });

  @override
  State<BiliVideoPlayer> createState() => BiliVideoPlayerState();
}

enum _PanGestureMode {
  none,
  horizontalSeek,
  verticalBrightness,
  verticalVolume,
}

class BiliVideoPlayerState extends State<BiliVideoPlayer> {
  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;

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

  /// 是否为 DASH 双流播放（视频轨 + 独立音轨）
  bool get hasSeparateAudio => _audioController != null;
  int _initToken = 0;
  late DanmakuController _danmakuController;
  bool _wakelockEnabled = false;
  bool _isExplicitlyPaused = false;

  VideoPlayerController? get controller => _controller;
  double get playbackSpeed => _playbackSpeed;

  bool _showControls = true;
  Timer? _hideTimer;
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
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

  // Pan Progress Seek & Vertical Pan Gestures (左右滑动快进快退 / 屏幕两侧滑动调亮度与音量)
  bool _isDraggingProgress = false;
  bool _isPanGestureIgnored = false;
  _PanGestureMode _panMode = _PanGestureMode.none;
  Offset _panStartPosition = Offset.zero;
  Duration _dragStartPosition = Duration.zero;
  Duration _targetSeekPosition = Duration.zero;
  double _accumulatedPanDx = 0.0;
  double _accumulatedPanDy = 0.0;
  Offset? _panDownLocalPosition;
  Offset? _panDownGlobalPosition;

  // Screen Brightness & Volume (左半边上下滑动调亮度，右半边上下滑动调音量)
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

  // Double-tap & HUD Overlay
  Offset _lastTapDownPosition = Offset.zero;
  bool _showHud = false;
  String _hudText = '';
  IconData? _hudIcon;
  Alignment _hudAlignment = Alignment.center;
  Timer? _hudTimer;
  double? _hudProgress;
  int _lastHudPercent = -1;

  // Isolated Slider Scrubbing
  final ValueNotifier<double?> _sliderDragPosition = ValueNotifier<double?>(
    null,
  );

  @override
  void initState() {
    super.initState();
    _danmakuController = DanmakuController();
    _danmakuController.setDanmakus(widget.danmakus);
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

  // 有意不监听 AppLifecycleState：拉下状态栏/通知栏（inactive）与切后台
  // （paused）均不自动暂停，保持播放（后台继续出声），由用户手动控制暂停。

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
        !isSameVideo) {
      _isExplicitlyPaused = false;
      final Duration? targetPos;
      if (isSameVideo &&
          (widget.playUrlInfo.currentQuality !=
                  oldWidget.playUrlInfo.currentQuality ||
              widget.playUrlInfo.separateAudioUrl !=
                  oldWidget.playUrlInfo.separateAudioUrl)) {
        // 切画质（含渐进式 ↔ DASH 双流切换）时保留当前进度
        targetPos = _controller?.value.position;
      } else {
        targetPos = widget.initialPosition;
      }
      _initPlayer(initialPosition: targetPos);
    }
  }

  /// 远程流地址落地：统一经本地代理（.mp4 + 正确 MIME + Referer/Cookie + 磁盘缓存）。
  /// [cacheKey] 用稳定键（bvid+cid+轨+画质），CDN 签名地址变化不影响缓存命中。
  Future<String> _resolveRemoteUrl(
    String url, {
    required bool isAudio,
    String? cacheKey,
  }) async {
    try {
      return await resolvePlayableUrl(
        url,
        isAudio: isAudio,
        cacheKey: cacheKey,
      );
    } catch (_) {
      return url;
    }
  }

  /// 播放流磁盘缓存的稳定键：优先 videoKey（bvid_cid）。
  String get _streamCacheBaseKey {
    final key = widget.videoKey;
    if (key != null && key.isNotEmpty) return key;
    return widget.playUrlInfo.primaryVideoUrl ?? widget.title;
  }

  /// 本地缓存音轨落地：`.m4s` 扩展名会被 iOS AVPlayer 拒绝，优先走本地文件服务，
  /// 失败时回退 `VideoPlayerController.file`。
  Future<VideoPlayerController> _buildAudioController(
    String audioUrl,
    VideoPlayerOptions options,
  ) async {
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
    int token,
  ) async {
    VideoPlayerController? audio;
    try {
      audio = await _buildAudioController(audioUrl, options);
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
    final url = widget.playUrlInfo.primaryVideoUrl;
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
      // 远程轨道统一经本地代理（MIME/Referer 修正 + 边播边磁盘缓存）
      final playableVideoUrl = await _resolveRemoteUrl(
        url!,
        isAudio: false,
        cacheKey: '$_streamCacheBaseKey|v${widget.playUrlInfo.currentQuality}',
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
    final separateAudioUrl = widget.playUrlInfo.separateAudioUrl;

    // 音轨与视频轨并行初始化：起播等待从「两者之和」降为「两者最大值」
    Future<VideoPlayerController?>? audioInitFuture;
    if (separateAudioUrl != null && separateAudioUrl.isNotEmpty) {
      audioInitFuture = _initAudioTrack(separateAudioUrl, playerOptions, token);
    }

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

      VideoPlayerController? audioController;
      bool audioFailed = false;
      if (audioInitFuture != null) {
        final audio = await audioInitFuture;
        if (!mounted || _initToken != token) return;
        if (audio == null) {
          audioFailed = true;
        } else {
          audioController = audio;
        }
      }

      if (initialPosition != null && initialPosition > Duration.zero) {
        await controller.seekTo(initialPosition);
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

      await controller.setPlaybackSpeed(_playbackSpeed);
      if (audioController != null) {
        try {
          await audioController.setPlaybackSpeed(_playbackSpeed);
        } catch (_) {}
      }

      if (!_isExplicitlyPaused) {
        await controller.play();
        if (audioController != null) {
          try {
            await audioController.play();
          } catch (_) {}
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
    } catch (_) {
      if (_initToken == token) {
        _pendingController = null;
        _pendingAudioController = null;
        try {
          await controller.dispose();
        } catch (_) {}
        if (mounted) {
          setState(() {
            _controller = null;
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
    if (video != null) {
      try {
        await op(video);
      } catch (_) {}
    }
    if (audio != null) {
      try {
        await op(audio);
      } catch (_) {}
    }
  }

  /// 成对 seek（并记录时间，避免漂移纠偏与用户拖动抢跑）
  Future<void> _seekBothPlayers(Duration target) async {
    _lastSeekAt = DateTime.now();
    await _applyToPlayers((c) => c.seekTo(target));
  }

  /// 以视频轨为时钟纠正伴音轨漂移（超过阈值且距上次纠偏超过间隔才执行）
  void _syncAudioWithVideo() {
    final video = _controller;
    final audio = _audioController;
    if (video == null || audio == null) return;
    if (!video.value.isInitialized || !audio.value.isInitialized) return;

    final now = DateTime.now();
    final recentSeek =
        _lastSeekAt != null &&
        now.difference(_lastSeekAt!) < const Duration(milliseconds: 300);

    if (!shouldCorrectDrift(
      videoPosition: video.value.position,
      audioPosition: audio.value.position,
      isSeeking: _isDraggingProgress || recentSeek,
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

  /// 播放状态恢复时把 Dart 侧期望倍速补发到平台（视频轨/伴音轨各自以
  /// value.playbackSpeed 为准）。同值重复下发不会触发监听回调。
  void _reassertPlaybackSpeeds() {
    final video = _controller;
    if (video != null && video.value.isInitialized && video.value.isPlaying) {
      unawaited(_setPlatformSpeed(video));
    }
    final audio = _audioController;
    if (audio != null && audio.value.isInitialized && audio.value.isPlaying) {
      unawaited(_setPlatformSpeed(audio));
    }
  }

  Future<void> _setPlatformSpeed(VideoPlayerController c) async {
    try {
      await c.setPlaybackSpeed(c.value.playbackSpeed);
    } catch (_) {}
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

    // DASH 双流：以视频轨为时钟纠正伴音轨漂移
    if (val.isPlaying) {
      _syncAudioWithVideo();
    }

    widget.onProgressUpdate?.call(val.position, val.duration);
  }

  /// 伴音轨状态监听：仅用于缓冲恢复时补发平台倍速（与视频轨同理）。
  void _onAudioPlayerUpdate() {
    final audio = _audioController;
    if (audio == null) return;
    if (audio.value.isPlaying && !_wasAudioPlaying) {
      _reassertPlaybackSpeeds();
    }
    _wasAudioPlaying = audio.value.isPlaying;
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
    if (_controller != null && !_controller!.value.isPlaying) {
      await _applyToPlayers((c) => c.play());
      _danmakuController.setPlaying(true);
      _startHideTimer();
      if (mounted) setState(() {});
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (_isFullScreen || isLandscape) {
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
      }
    });
    widget.onFullScreenChanged?.call(_isFullScreen);

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

  void _showDanmakuSettings() {
    PlayerDanmakuSheet.show(
      context,
      danmakuController: _danmakuController,
      accent: _getPlayerAccent(context),
    );
  }

  @override
  void dispose() {
    _initToken++;
    SleepTimerService().unregisterPauseCallback(_onSleepTimerPause);
    _hideTimer?.cancel();
    _lockIconTimer?.cancel();
    _hudTimer?.cancel();
    _sliderDragPosition.dispose();
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
    _danmakuController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
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

  void _showSeekHud({required bool isForward, required int seconds}) {
    _hudTimer?.cancel();
    setState(() {
      _showHud = true;
      _hudProgress = null;
      _hudIcon = isForward
          ? Icons.fast_forward_rounded
          : Icons.fast_rewind_rounded;
      _hudText = isForward ? '+$seconds 秒' : '-$seconds 秒';
      _hudAlignment = isForward
          ? const Alignment(0.65, 0.0)
          : const Alignment(-0.65, 0.0);
    });
    _hudTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showHud = false;
        });
      }
    });
  }

  void _showPlayPauseHud() {
    _hudTimer?.cancel();
    final isPlaying = _controller?.value.isPlaying ?? false;
    setState(() {
      _showHud = true;
      _hudProgress = null;
      _hudIcon = isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded;
      _hudText = isPlaying ? '播放' : '暂停';
      _hudAlignment = Alignment.center;
    });
    _hudTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        setState(() {
          _showHud = false;
        });
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

    if (_showHud && _lastHudPercent == percent && _hudProgress == brightness) {
      return;
    }
    _lastHudPercent = percent;

    _hudTimer?.cancel();
    setState(() {
      _showHud = true;
      _hudIcon = icon;
      _hudText = '$percent%';
      _hudProgress = brightness;
      _hudAlignment = const Alignment(-0.65, 0.0);
    });
  }

  void _showVolumeHud(double volume) {
    final percent = (volume * 100).round();
    final IconData icon = volume <= 0.001
        ? Icons.volume_off_rounded
        : (volume <= 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded);

    if (_showHud && _lastHudPercent == percent && _hudProgress == volume) {
      return;
    }
    _lastHudPercent = percent;

    _hudTimer?.cancel();
    setState(() {
      _showHud = true;
      _hudIcon = icon;
      _hudText = '$percent%';
      _hudProgress = volume;
      _hudAlignment = const Alignment(0.65, 0.0);
    });
  }

  void _dismissHudAfterDelay([
    Duration duration = const Duration(milliseconds: 750),
  ]) {
    _hudTimer?.cancel();
    _hudTimer = Timer(duration, () {
      if (mounted) {
        _lastHudPercent = -1;
        setState(() {
          _showHud = false;
          _hudProgress = null;
        });
      }
    });
  }

  Color _getPlayerAccent(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // On the video player's dark background, if primary is dark (e.g. Ink theme light mode #22242A),
    // fallback to clean white #EDEDF2 to guarantee high contrast and readability.
    if (primary.computeLuminance() < 0.35) {
      return AppTheme.textMainDark;
    }
    return primary;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isFull = _isFullScreen || isLandscape;
    final accent = _getPlayerAccent(context);

    final hasController =
        _controller != null && _controller!.value.isInitialized;

    Widget playerBody = Container(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) {
          _panDownLocalPosition = details.localPosition;
          _panDownGlobalPosition = details.globalPosition;
        },
        onTapDown: (details) {
          _lastTapDownPosition = details.localPosition;
        },
        onTap: () {
          if (_isScreenLocked) {
            _toggleLockIconVisibility();
            return;
          }
          _toggleControls();
        },
        onDoubleTapDown: (details) {
          _lastTapDownPosition = details.localPosition;
        },
        onDoubleTap: () {
          if (_isScreenLocked || !hasController) return;
          // 以播放器自身宽度划分区域：左右边缘为快进/快退命中区（默认各
          // 10%，宽度可在设置中调整），中间其余区域双击切换播放/暂停。
          final playerWidth =
              context.size?.width ?? MediaQuery.of(context).size.width;
          final x = _lastTapDownPosition.dx;
          final edgeRatio = PlayerSettingsService.doubleTapEdgeRatio;
          final seekSeconds = PlayerSettingsService.doubleTapSeekSeconds;
          if (x < playerWidth * edgeRatio) {
            _seekRelative(-seekSeconds);
            _showSeekHud(isForward: false, seconds: seekSeconds);
          } else if (x > playerWidth * (1 - edgeRatio)) {
            _seekRelative(seekSeconds);
            _showSeekHud(isForward: true, seconds: seekSeconds);
          } else {
            _togglePlayPause();
            _showPlayPauseHud();
          }
        },
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
        onPanStart: (details) {
          if (_isScreenLocked || _isLongPressSpeeding) {
            _isPanGestureIgnored = true;
            return;
          }

          // Top Edge & Status Bar Exclusion: Ignore touches starting in the top notification/status bar area
          final mediaQuery = MediaQuery.of(context);
          final topSafe = math.max(
            mediaQuery.viewPadding.top,
            mediaQuery.padding.top,
          );
          final topExclusion = math.max(topSafe + 40.0, 60.0);

          final downLocalY =
              _panDownLocalPosition?.dy ?? details.localPosition.dy;
          final downGlobalY =
              _panDownGlobalPosition?.dy ?? details.globalPosition.dy;

          if (downGlobalY < topSafe + 50.0 ||
              details.globalPosition.dy < topSafe + 50.0 ||
              downLocalY < topExclusion ||
              details.localPosition.dy < topExclusion) {
            _isPanGestureIgnored = true;
            return;
          }

          // Bottom Edge Exclusion: 全屏/横屏时播放器铺满整屏，底部边缘是
          // 系统上滑返回/回主屏的手势区。起手于此的滑动交给系统处理，
          // 不再判定为亮度/音量/进度手势，避免上滑返回时误触 HUD。
          if (isFull) {
            final bottomSafe = math.max(
              mediaQuery.viewPadding.bottom,
              mediaQuery.padding.bottom,
            );
            final playerHeight = context.size?.height ?? mediaQuery.size.height;
            final bottomExclusionY =
                playerHeight - math.max(bottomSafe + 40.0, 60.0);
            if (downLocalY > bottomExclusionY ||
                details.localPosition.dy > bottomExclusionY) {
              _isPanGestureIgnored = true;
              return;
            }
          }

          _isPanGestureIgnored = false;
          _isDraggingProgress = false;
          _panMode = _PanGestureMode.none;
          _panStartPosition = details.localPosition;
          _dragStartPosition = _controller?.value.position ?? Duration.zero;
          _targetSeekPosition = _dragStartPosition;
          _accumulatedPanDx = 0.0;
          _accumulatedPanDy = 0.0;
        },
        onPanUpdate: (details) {
          if (_isPanGestureIgnored || _isScreenLocked || _isLongPressSpeeding) {
            return;
          }

          _accumulatedPanDx += details.delta.dx;
          _accumulatedPanDy += details.delta.dy;

          final totalDuration = _controller?.value.duration ?? Duration.zero;
          final screenSize = MediaQuery.of(context).size;
          final screenWidth = screenSize.width;
          final playerHeight = context.size?.height ?? screenSize.height;

          // Gesture Arbitration (if not yet locked into a mode)
          if (_panMode == _PanGestureMode.none) {
            final absDx = _accumulatedPanDx.abs();
            final absDy = _accumulatedPanDy.abs();

            final mediaQuery = MediaQuery.of(context);
            final topSafe = math.max(
              mediaQuery.viewPadding.top,
              mediaQuery.padding.top,
            );
            final topExclusion = math.max(topSafe + 40.0, 60.0);

            // Horizontal Seek gesture (requires active controller with duration):
            if (hasController &&
                PlayerSettingsService.enableHorizontalPanSeek &&
                absDx >= 22.0 &&
                absDx > absDy * 1.5) {
              _panMode = _PanGestureMode.horizontalSeek;
              _isDraggingProgress = true;
              _hideTimer?.cancel();
              HapticFeedback.selectionClick();
            }
            // Vertical Pan (Brightness on Left half, Volume on Right half):
            else if (PlayerSettingsService.enableVerticalPanVolumeBrightness &&
                absDy >= 16.0 &&
                absDy > absDx * 1.2 &&
                _panStartPosition.dy >= topExclusion) {
              _hideTimer?.cancel();
              HapticFeedback.selectionClick();
              if (_panStartPosition.dx < screenWidth * 0.5) {
                _panMode = _PanGestureMode.verticalBrightness;
                _showBrightnessHud(_screenBrightness);
              } else {
                _panMode = _PanGestureMode.verticalVolume;
                _showVolumeHud(_currentVolume);
              }
            } else {
              return;
            }
          }

          switch (_panMode) {
            case _PanGestureMode.horizontalSeek:
              if (totalDuration.inMilliseconds <= 0) return;
              const double dragThreshold = 22.0;
              final effectiveDelta = _accumulatedPanDx > 0
                  ? (_accumulatedPanDx - dragThreshold)
                  : (_accumulatedPanDx + dragThreshold);
              final scaleDuration = totalDuration.inSeconds > 600
                  ? 90.0
                  : (totalDuration.inSeconds > 180 ? 45.0 : 20.0);
              final deltaSeconds =
                  (effectiveDelta / screenWidth) * scaleDuration;
              final targetMs =
                  (_dragStartPosition.inMilliseconds +
                          (deltaSeconds * 1000).toInt())
                      .clamp(0, totalDuration.inMilliseconds);
              setState(() {
                _targetSeekPosition = Duration(milliseconds: targetMs);
              });
              break;

            case _PanGestureMode.verticalBrightness:
              final double effectiveHeight = playerHeight > 100
                  ? playerHeight
                  : 300.0;
              final double delta = -details.delta.dy / (effectiveHeight * 0.75);
              _screenBrightness = (_screenBrightness + delta).clamp(0.0, 1.0);
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
              final double delta = -details.delta.dy / (effectiveHeight * 0.75);
              _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
              SystemMediaControlService.instance.setVolume(_currentVolume);
              _showVolumeHud(_currentVolume);
              break;

            case _PanGestureMode.none:
              break;
          }
        },
        onPanEnd: (details) {
          if (_panMode == _PanGestureMode.horizontalSeek) {
            _isDraggingProgress = false;
            if (hasController) {
              unawaited(_seekBothPlayers(_targetSeekPosition));
              _danmakuController.updatePosition(
                _targetSeekPosition.inMilliseconds / 1000.0,
              );
            }
            setState(() {});
            _startHideTimer();
          } else if (_panMode == _PanGestureMode.verticalBrightness ||
              _panMode == _PanGestureMode.verticalVolume) {
            if (_panMode == _PanGestureMode.verticalVolume) {
              _lastVolumePanEndTime = DateTime.now().millisecondsSinceEpoch;
              SystemMediaControlService.instance.setVolume(
                _currentVolume,
                immediate: true,
              );
            } else if (_panMode == _PanGestureMode.verticalBrightness) {
              SystemMediaControlService.instance.setBrightness(
                _screenBrightness,
                immediate: true,
              );
            }
            _dismissHudAfterDelay(const Duration(milliseconds: 800));
            _startHideTimer();
          }

          _accumulatedPanDx = 0.0;
          _accumulatedPanDy = 0.0;
          _panDownLocalPosition = null;
          _panDownGlobalPosition = null;
          _isPanGestureIgnored = false;
          _panMode = _PanGestureMode.none;
        },
        onPanCancel: () {
          if (_panMode == _PanGestureMode.horizontalSeek) {
            _isDraggingProgress = false;
            setState(() {});
            _startHideTimer();
          } else if (_panMode == _PanGestureMode.verticalBrightness ||
              _panMode == _PanGestureMode.verticalVolume) {
            if (_panMode == _PanGestureMode.verticalVolume) {
              _lastVolumePanEndTime = DateTime.now().millisecondsSinceEpoch;
              SystemMediaControlService.instance.setVolume(
                _currentVolume,
                immediate: true,
              );
            } else if (_panMode == _PanGestureMode.verticalBrightness) {
              SystemMediaControlService.instance.setBrightness(
                _screenBrightness,
                immediate: true,
              );
            }
            _dismissHudAfterDelay(const Duration(milliseconds: 600));
            _startHideTimer();
          }

          _accumulatedPanDx = 0.0;
          _accumulatedPanDy = 0.0;
          _panDownLocalPosition = null;
          _panDownGlobalPosition = null;
          _isPanGestureIgnored = false;
          _panMode = _PanGestureMode.none;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Layer
            if (hasController)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: RepaintBoundary(child: VideoPlayer(_controller!)),
                ),
              )
            else
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

            // Buffering indicator (locally listening to controller)
            if (hasController)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (context, val, _) {
                  if (!val.isBuffering) return const SizedBox.shrink();
                  return const Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Ultra-slim bottom progress line (when controls are hidden, locally listening to controller)
            if (!_showControls &&
                !_isScreenLocked &&
                hasController &&
                !_isDraggingProgress)
              Positioned(
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
              ),

            // Controls Overlay (when controls are visible and not locked)
            IgnorePointer(
              ignoring: !_showControls || _isScreenLocked,
              child: AnimatedOpacity(
                opacity: (_showControls && !_isScreenLocked) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildControls(context, hasController, isFull),
              ),
            ),

            // Horizontal Drag Seek HUD Overlay
            if (_isDraggingProgress && hasController)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: OverlayColors.bar,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 0.8),
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
                            _targetSeekPosition >= _dragStartPosition
                                ? Icons.fast_forward_rounded
                                : Icons.fast_rewind_rounded,
                            color: accent,
                            size: 26,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            _targetSeekPosition >= _dragStartPosition
                                ? '+${Formatters.formatDuration((_targetSeekPosition - _dragStartPosition).inSeconds)}'
                                : '-${Formatters.formatDuration((_dragStartPosition - _targetSeekPosition).inSeconds)}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        '${Formatters.formatDuration(_targetSeekPosition.inSeconds)} / ${Formatters.formatDuration(_controller!.value.duration.inSeconds)}',
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
                            value:
                                _controller!.value.duration.inMilliseconds > 0
                                ? (_targetSeekPosition.inMilliseconds /
                                          _controller!
                                              .value
                                              .duration
                                              .inMilliseconds)
                                      .clamp(0.0, 1.0)
                                : 0.0,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                            minHeight: 3.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Double Tap Seek / PlayPause / Brightness & Volume HUD Overlay
            if (_showHud)
              Align(
                alignment: _hudAlignment,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.75, end: 1.0),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20.0),
                        padding: EdgeInsets.symmetric(
                          horizontal: _hudProgress != null ? 16.0 : 12.0,
                          vertical: _hudProgress != null ? 12.0 : 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: OverlayColors.bar,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _hudProgress == null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_hudIcon != null) ...[
                                    Icon(_hudIcon, color: accent, size: 18),
                                    const SizedBox(width: 4.0),
                                  ],
                                  Text(
                                    _hudText,
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
                                  if (_hudIcon != null) ...[
                                    Icon(_hudIcon, color: accent, size: 28),
                                    const SizedBox(height: 8.0),
                                  ],
                                  SizedBox(
                                    width: 64,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _hudProgress!.clamp(0.0, 1.0),
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
                                    _hudText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),

            // Long Press 2.0X Speed HUD Overlay
            if (_isLongPressSpeeding)
              Positioned(
                top: isFull ? 24 : 12,
                left: 0,
                right: 0,
                child: Center(
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
                          '${PlayerSettingsService.longPressSpeedValue.toStringAsFixed(1)}X',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Screen Lock Button (in landscape / fullscreen mode)
            if (isFull)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: (_isScreenLocked ? _showLockIcon : _showControls)
                    ? 24
                    : -60,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleLock,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isScreenLocked
                              ? accent.withValues(alpha: 0.85)
                              : OverlayColors.circle,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isScreenLocked ? accent : Colors.white24,
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

            // Subtitle Overlay
            if (widget.isSubtitleEnabled &&
                widget.subtitleData != null &&
                hasController)
              Positioned(
                left: 20,
                right: 20,
                bottom: _showControls ? 80 : 24,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller!,
                  builder: (context, val, _) {
                    return SubtitleOverlay(
                      subtitleData: widget.subtitleData!,
                      currentPosition: val.position,
                    );
                  },
                ),
              ),

            // In-Player Floating Quality Selector Panel (直接在上方弹出半透明框)
            if (_showQualityPanel && !_isScreenLocked)
              Positioned(
                right: isFull ? 24 : 8,
                bottom: 40,
                child: _buildFloatingQualityPanel(isFull),
              ),

            // In-Player Floating Speed Selector Panel
            if (_showSpeedPanel && !_isScreenLocked)
              Positioned(
                right: isFull ? (widget.chapters.isNotEmpty ? 100 : 66) : 48,
                bottom: 40,
                child: _buildFloatingSpeedPanel(isFull),
              ),

            // In-Player Floating Chapter Selector Panel
            if (_showChapterPanel &&
                !_isScreenLocked &&
                widget.chapters.isNotEmpty)
              Positioned(
                right: isFull ? 24 : 8,
                bottom: 40,
                child: _buildFloatingChapterPanel(isFull),
              ),

            // In-Player Floating Subtitle Selector Panel
            if (_showSubtitlePanel &&
                !_isScreenLocked &&
                widget.subtitleTracks.isNotEmpty)
              Positioned(
                right: isFull ? (widget.chapters.isNotEmpty ? 140 : 106) : 76,
                bottom: 40,
                child: _buildFloatingSubtitlePanel(isFull),
              ),
          ],
        ),
      ),
    );

    if (isFull) {
      return playerBody;
    }

    final double effectiveRatio = isVerticalVideo
        ? _controller!.value.aspectRatio.clamp(0.72, 1.0)
        : (hasController && _controller!.value.aspectRatio > 0
              ? _controller!.value.aspectRatio.clamp(1.33, 1.85)
              : 16 / 9);

    return AspectRatio(aspectRatio: effectiveRatio, child: playerBody);
  }

  List<({int quality, String description, bool locked})>
  _getAvailableQualities() {
    // 只列视频真实提供的画质；此前无条件补"1080P 60帧"等档位，
    // 大会员点了必被降级并误报"需大会员"。
    return buildQualityPanelItems(
      widget.playUrlInfo,
      isLoggedIn: BiliHttpClient().isLoggedIn,
      labelOf: _getQualityLabel,
    );
  }

  Widget _buildFloatingQualityPanel(bool isFull) {
    return PlayerQualityPanel(
      qualityItems: _getAvailableQualities(),
      // 选中态用服务端实际授权的画质（DASH 下响应体 quality 字段不可信）
      currentQuality: widget.playUrlInfo.grantedQuality,
      accent: _getPlayerAccent(context),
      isFull: isFull,
      onSelectQuality: (quality) {
        setState(() => _showQualityPanel = false);
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
      },
    );
  }

  Widget _buildFloatingChapterPanel(bool isFull) {
    final currentSec = (_controller?.value.position.inSeconds ?? 0);
    return PlayerChapterPanel(
      chapters: widget.chapters,
      currentSec: currentSec,
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
          stops: [0.0, 0.25, 0.75, 1.0],
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
                    tooltip: '退出全屏',
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: () {
                      if (_isFullScreen || isFull) {
                        exitFullScreen();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (widget.localFilePath != null &&
                            widget.localFilePath!.isNotEmpty &&
                            !kIsWeb &&
                            File(widget.localFilePath!).existsSync()) ...[
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
                    onPressed: () => SleepTimerBottomSheet.show(context),
                  ),
                  if (isFull)
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
            if (hasController)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (context, val, _) {
                  if (val.isPlaying || !val.isInitialized) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    iconSize: 44,
                    tooltip: '播放/暂停',
                    icon: Icon(Icons.play_circle_fill_rounded, color: accent),
                    onPressed: _togglePlayPause,
                  );
                },
              )
            else
              const SizedBox.shrink(),

            // Ultra-Compact Single-Row Bottom Controls Bar
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Play / Pause Button
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

                  // 2 & 3. Compact Time Display & Slider (listening to position)
                  if (hasController)
                    Expanded(
                      child: ValueListenableBuilder<double?>(
                        valueListenable: _sliderDragPosition,
                        builder: (context, dragVal, _) {
                          return ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: _controller!,
                            builder: (context, val, _) {
                              final duration = val.duration;
                              final currentPos = dragVal != null
                                  ? Duration(milliseconds: dragVal.toInt())
                                  : val.position;
                              final maxMs = duration.inMilliseconds > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 1.0;
                              final curMs =
                                  (dragVal ??
                                          val.position.inMilliseconds
                                              .toDouble())
                                      .clamp(0.0, maxMs);

                              return Row(
                                children: [
                                  Text(
                                    '${Formatters.formatDuration(currentPos.inSeconds)} / ${Formatters.formatDuration(duration.inSeconds)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2.0,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 4.5,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 8.0,
                                            ),
                                        activeTrackColor: accent,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: accent,
                                      ),
                                      child: Slider(
                                        value: curMs,
                                        min: 0.0,
                                        max: maxMs,
                                        onChangeStart: (v) {
                                          _hideTimer?.cancel();
                                          _sliderDragPosition.value = v;
                                          HapticFeedback.selectionClick();
                                        },
                                        onChanged: (v) {
                                          _sliderDragPosition.value = v;
                                        },
                                        onChangeEnd: (v) {
                                          final ms = v.toInt();
                                          unawaited(
                                            _seekBothPlayers(
                                              Duration(milliseconds: ms),
                                            ),
                                          );
                                          _danmakuController.updatePosition(
                                            ms / 1000.0,
                                          );
                                          _sliderDragPosition.value = null;
                                          _startHideTimer();
                                          HapticFeedback.lightImpact();
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),

                  // 3.5 CC Subtitle Button
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

                  // 4. Danmaku Toggle Button
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

                  // 4.5 Chapters Button (In-player floating panel)
                  if (widget.chapters.isNotEmpty) ...[
                    InkWell(
                      onTap: _toggleChapterPanel,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
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
                    const SizedBox(width: 4),
                  ],

                  // 5. Speed Button (In-player floating panel)
                  InkWell(
                    onTap: _toggleSpeedPanel,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
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

                  const SizedBox(width: 4),

                  // 6. Quality Button (In-player floating panel)
                  InkWell(
                    onTap: _toggleQualityPanel,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Text(
                        _getQualityLabel(widget.playUrlInfo.currentQuality),
                        style: TextStyle(
                          color: _showQualityPanel ? accent : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // 7. Fullscreen Button
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
