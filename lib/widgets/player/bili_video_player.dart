import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/danmaku_model.dart';
import '../../models/play_url_model.dart';
import '../../models/video_model.dart';
import '../../services/player_settings_service.dart';
import '../../utils/formatters.dart';
import '../app_toast.dart';
import 'danmaku_overlay.dart';

class BiliVideoPlayer extends StatefulWidget {
  final PlayUrlInfo playUrlInfo;
  final String? localFilePath;
  final List<DanmakuItem> danmakus;
  final List<VideoChapter> chapters;
  final String title;
  final Duration? initialPosition;
  final Function(int quality)? onQualityChanged;
  final Function(bool isFullScreen)? onFullScreenChanged;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onListenMode;
  final void Function(Duration position, Duration duration)? onProgressUpdate;

  const BiliVideoPlayer({
    super.key,
    required this.playUrlInfo,
    this.localFilePath,
    this.danmakus = const [],
    this.chapters = const [],
    this.title = '',
    this.initialPosition,
    this.onQualityChanged,
    this.onFullScreenChanged,
    this.onNextEpisode,
    this.onListenMode,
    this.onProgressUpdate,
  });

  @override
  State<BiliVideoPlayer> createState() => BiliVideoPlayerState();
}

class BiliVideoPlayerState extends State<BiliVideoPlayer> {
  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;
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
  DeviceOrientation _currentLandscapeOrientation = DeviceOrientation.landscapeLeft;

  // Screen Lock (横屏锁屏)
  bool _isScreenLocked = false;
  bool _showLockIcon = true;
  Timer? _lockIconTimer;

  // Long Press 2.0X Speed (长按二倍速)
  bool _isLongPressSpeeding = false;
  double get _effectivePlaybackSpeed => _isLongPressSpeeding ? 2.0 : _playbackSpeed;
  double _speedBeforeLongPress = 1.0;

  // Pan Progress Seek (左右滑动快进快退)
  bool _isDraggingProgress = false;
  bool _isPanGestureIgnored = false;
  Duration _dragStartPosition = Duration.zero;
  Duration _targetSeekPosition = Duration.zero;
  double _accumulatedPanDx = 0.0;
  double _accumulatedPanDy = 0.0;

  // In-Player Floating Panels
  bool _showQualityPanel = false;
  bool _showSpeedPanel = false;
  bool _showChapterPanel = false;

  // Double-tap & HUD Overlay
  Offset _lastTapDownPosition = Offset.zero;
  bool _showHud = false;
  String _hudText = '';
  IconData? _hudIcon;
  Alignment _hudAlignment = Alignment.center;
  Timer? _hudTimer;

  // Isolated Slider Scrubbing
  final ValueNotifier<double?> _sliderDragPosition = ValueNotifier<double?>(null);

  @override
  void initState() {
    super.initState();
    _danmakuController = DanmakuController();
    _danmakuController.setDanmakus(widget.danmakus);
    _initPlayer(initialPosition: widget.initialPosition);
  }

  @override
  void didUpdateWidget(covariant BiliVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.danmakus != oldWidget.danmakus) {
      _danmakuController.setDanmakus(widget.danmakus);
    }
    if (widget.localFilePath != oldWidget.localFilePath ||
        widget.playUrlInfo.primaryVideoUrl != oldWidget.playUrlInfo.primaryVideoUrl ||
        widget.playUrlInfo.currentQuality != oldWidget.playUrlInfo.currentQuality) {
      _isExplicitlyPaused = false;
      final oldPos = _controller?.value.position;
      _initPlayer(initialPosition: oldPos);
    }
  }

  Future<void> _initPlayer({Duration? initialPosition}) async {
    final int token = ++_initToken;

    final oldController = _controller;
    _controller = null;
    final oldPending = _pendingController;
    _pendingController = null;

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

    if (!mounted || _initToken != token) return;

    final localPath = widget.localFilePath;
    final url = widget.playUrlInfo.primaryVideoUrl;
    final hasLocalFile = localPath != null &&
        localPath.isNotEmpty &&
        !kIsWeb &&
        File(localPath).existsSync();

    if (!hasLocalFile && (url == null || url.isEmpty)) return;

    final VideoPlayerController controller;
    if (hasLocalFile) {
      controller = VideoPlayerController.file(File(localPath));
    } else {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(url!),
        httpHeaders: kIsWeb
            ? const {}
            : const {
                'Referer': 'https://www.bilibili.com',
                'User-Agent':
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
      );
    }
    _pendingController = controller;

    try {
      await controller.initialize();

      // Guard: Check if the user navigated away or switched to a different video while initializing
      if (!mounted || _initToken != token || _pendingController != controller) {
        try {
          await controller.pause();
          await controller.dispose();
        } catch (_) {}
        return;
      }

      if (initialPosition != null && initialPosition > Duration.zero) {
        await controller.seekTo(initialPosition);
        if (widget.initialPosition != null && widget.initialPosition == initialPosition && mounted) {
          AppToast.show(
            context,
            '已定位至上次播放位置 ${Formatters.formatDuration(initialPosition.inSeconds)}',
            icon: Icons.history_rounded,
          );
        }
      }
      await controller.setPlaybackSpeed(_playbackSpeed);
      if (!_isExplicitlyPaused) {
        await controller.play();
      } else {
        await controller.pause();
      }

      // Second Guard: Check again after async play call
      if (!mounted || _initToken != token) {
        try {
          await controller.pause();
          await controller.dispose();
        } catch (_) {}
        return;
      }

      _pendingController = null;
      _controller = controller;
      controller.addListener(_onPlayerUpdate);

      _danmakuController.syncPlayerState(
        positionSeconds: initialPosition != null ? (initialPosition.inMilliseconds / 1000.0) : 0.0,
        isPlaying: !_isExplicitlyPaused,
        playbackSpeed: _effectivePlaybackSpeed,
      );

      if (mounted) {
        setState(() {});
        if (!_isExplicitlyPaused) {
          _startHideTimer();
        }
      }
    } catch (_) {
      if (_initToken == token) {
        _pendingController = null;
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

    widget.onProgressUpdate?.call(val.position, val.duration);
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
          !_isDraggingProgress) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_showQualityPanel || _showSpeedPanel || _showChapterPanel) {
      setState(() {
        _showQualityPanel = false;
        _showSpeedPanel = false;
        _showChapterPanel = false;
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
    if (_controller != null) {
      try {
        await _controller!.pause();
      } catch (_) {}
    }
    if (_pendingController != null) {
      try {
        await _pendingController!.pause();
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
      await _controller!.play();
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
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        if (isLandscape) {
          SystemChrome.setPreferredOrientations([_currentLandscapeOrientation]);
        } else {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        }
      } else {
        _showControls = true;
        _showLockIcon = true;
        _startHideTimer();
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
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
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
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
        if (mounted && (_isFullScreen || MediaQuery.of(context).orientation == Orientation.landscape)) {
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
    });
    _startHideTimer();
  }

  void _toggleSpeedPanel() {
    setState(() {
      _showSpeedPanel = !_showSpeedPanel;
      _showQualityPanel = false;
      _showChapterPanel = false;
    });
    _startHideTimer();
  }

  void _toggleChapterPanel() {
    setState(() {
      _showChapterPanel = !_showChapterPanel;
      _showQualityPanel = false;
      _showSpeedPanel = false;
    });
    _startHideTimer();
  }

  void _showDanmakuSettings() {
    final accent = _getPlayerAccent(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        '弹幕设置',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Opacity
                    Row(
                      children: [
                        const Text('不透明度', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: _danmakuController.opacity,
                            min: 0.2,
                            max: 1.0,
                            activeColor: accent,
                            inactiveColor: Colors.white24,
                            thumbColor: accent,
                            onChanged: (val) {
                              setSheetState(() {});
                              _danmakuController.setOpacity(val);
                            },
                          ),
                        ),
                        Text(
                          '${(_danmakuController.opacity * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    // Font Size
                    Row(
                      children: [
                        const Text('字体大小', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: _danmakuController.fontSizeScale,
                            min: 0.6,
                            max: 1.6,
                            activeColor: accent,
                            inactiveColor: Colors.white24,
                            thumbColor: accent,
                            onChanged: (val) {
                              setSheetState(() {});
                              _danmakuController.setFontSizeScale(val);
                            },
                          ),
                        ),
                        Text(
                          '${(_danmakuController.fontSizeScale * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    // Area ratio
                    Row(
                      children: [
                        const Text('显示区域', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 14),
                        ...[0.25, 0.5, 0.75, 1.0].map((ratio) {
                          final selected = (_danmakuController.areaRatio - ratio).abs() < 0.05;
                          final label = '${(ratio * 100).toInt()}%';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {});
                                _danmakuController.setAreaRatio(ratio);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? accent.withValues(alpha: 0.22)
                                      : const Color(0xFF262630),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? accent
                                        : Colors.white.withValues(alpha: 0.15),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: selected ? accent : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _initToken++;
    _hideTimer?.cancel();
    _lockIconTimer?.cancel();
    _hudTimer?.cancel();
    _sliderDragPosition.dispose();
    _disableWakelock();
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
    _danmakuController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _seekRelative(int deltaSeconds) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final current = _controller!.value.position;
    final total = _controller!.value.duration;
    if (total.inMilliseconds <= 0) return;
    final targetMs = (current.inMilliseconds + deltaSeconds * 1000).clamp(0, total.inMilliseconds);
    final target = Duration(milliseconds: targetMs);
    _controller!.seekTo(target);
    _danmakuController.updatePosition(targetMs / 1000.0);
    HapticFeedback.lightImpact();
  }

  void _showSeekHud({required bool isForward, required int seconds}) {
    _hudTimer?.cancel();
    setState(() {
      _showHud = true;
      _hudIcon = isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded;
      _hudText = isForward ? '+$seconds 秒' : '-$seconds 秒';
      _hudAlignment = isForward ? const Alignment(0.65, 0.0) : const Alignment(-0.65, 0.0);
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

  Color _getPlayerAccent(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // On the video player's dark background, if primary is dark (e.g. Ink theme light mode #22242A),
    // fallback to clean white #EDEDF2 to guarantee high contrast and readability.
    if (primary.computeLuminance() < 0.35) {
      return const Color(0xFFEDEDF2);
    }
    return primary;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isFull = _isFullScreen || isLandscape;
    final accent = _getPlayerAccent(context);

    final hasController = _controller != null && _controller!.value.isInitialized;

    Widget playerBody = Container(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
          final screenWidth = MediaQuery.of(context).size.width;
          final x = _lastTapDownPosition.dx;
          if (x < screenWidth * 0.35) {
            _seekRelative(-10);
            _showSeekHud(isForward: false, seconds: 10);
          } else if (x > screenWidth * 0.65) {
            _seekRelative(10);
            _showSeekHud(isForward: true, seconds: 10);
          } else {
            _togglePlayPause();
            _showPlayPauseHud();
          }
        },
        onLongPressStart: (details) {
          if (_isScreenLocked || !hasController) return;
          _speedBeforeLongPress = _playbackSpeed;
          _isLongPressSpeeding = true;
          _controller?.setPlaybackSpeed(2.0);
          _danmakuController.setPlaybackSpeed(2.0);
          HapticFeedback.selectionClick();
          setState(() {});
        },
        onLongPressEnd: (details) {
          if (!_isLongPressSpeeding) return;
          _isLongPressSpeeding = false;
          _controller?.setPlaybackSpeed(_speedBeforeLongPress);
          _danmakuController.setPlaybackSpeed(_speedBeforeLongPress);
          setState(() {});
        },
        onLongPressCancel: () {
          if (!_isLongPressSpeeding) return;
          _isLongPressSpeeding = false;
          _controller?.setPlaybackSpeed(_speedBeforeLongPress);
          _danmakuController.setPlaybackSpeed(_speedBeforeLongPress);
          setState(() {});
        },
        onPanStart: (details) {
          if (_isScreenLocked || !hasController || _isLongPressSpeeding) {
            _isPanGestureIgnored = true;
            return;
          }

          // Top Edge Exclusion: Ignore touches starting in the top notification/status bar area
          final topPadding = MediaQuery.of(context).padding.top;
          if (details.localPosition.dy < topPadding + 28.0) {
            _isPanGestureIgnored = true;
            return;
          }

          _isPanGestureIgnored = false;
          _isDraggingProgress = false;
          _dragStartPosition = _controller!.value.position;
          _targetSeekPosition = _dragStartPosition;
          _accumulatedPanDx = 0.0;
          _accumulatedPanDy = 0.0;
        },
        onPanUpdate: (details) {
          if (_isPanGestureIgnored || _isScreenLocked || !hasController || _isLongPressSpeeding) return;

          _accumulatedPanDx += details.delta.dx;
          _accumulatedPanDy += details.delta.dy;

          // Vertical Dominance Lockout: If swiping down/up (e.g. status bar / page scroll), reject immediately
          if (!_isDraggingProgress) {
            if (_accumulatedPanDy.abs() > _accumulatedPanDx.abs() && _accumulatedPanDy.abs() > 10.0) {
              _isPanGestureIgnored = true;
              return;
            }

            // Stricter horizontal threshold:
            // 1. Must move horizontally by at least 26.0 pixels
            // 2. Horizontal movement must clearly dominate vertical movement (> 1.8x)
            const double horizontalThreshold = 26.0;
            if (_accumulatedPanDx.abs() >= horizontalThreshold &&
                _accumulatedPanDx.abs() > _accumulatedPanDy.abs() * 1.8) {
              _isDraggingProgress = true;
              _hideTimer?.cancel();
              HapticFeedback.selectionClick();
            } else {
              return;
            }
          }

          final totalDuration = _controller!.value.duration;
          if (totalDuration.inMilliseconds <= 0) return;

          final screenWidth = MediaQuery.of(context).size.width;
          const double dragThreshold = 26.0;
          // Offset deadzone so scrubbing starts smoothly from zero
          final effectiveDelta = _accumulatedPanDx > 0
              ? (_accumulatedPanDx - dragThreshold)
              : (_accumulatedPanDx + dragThreshold);

          // Scaled scrubbing: full-screen swipe ~90s for long videos, ~45s for medium, ~20s for short
          final scaleDuration = totalDuration.inSeconds > 600
              ? 90.0
              : (totalDuration.inSeconds > 180 ? 45.0 : 20.0);
          final deltaSeconds = (effectiveDelta / screenWidth) * scaleDuration;

          final targetMs = (_dragStartPosition.inMilliseconds + (deltaSeconds * 1000).toInt())
              .clamp(0, totalDuration.inMilliseconds);
          setState(() {
            _targetSeekPosition = Duration(milliseconds: targetMs);
          });
        },
        onPanEnd: (details) {
          if (!_isDraggingProgress) {
            _accumulatedPanDx = 0.0;
            _accumulatedPanDy = 0.0;
            _isPanGestureIgnored = false;
            return;
          }
          _isDraggingProgress = false;
          _accumulatedPanDx = 0.0;
          _accumulatedPanDy = 0.0;
          _isPanGestureIgnored = false;
          if (hasController) {
            _controller!.seekTo(_targetSeekPosition);
            _danmakuController.updatePosition(_targetSeekPosition.inMilliseconds / 1000.0);
          }
          setState(() {});
          _startHideTimer();
        },
        onPanCancel: () {
          _accumulatedPanDx = 0.0;
          _accumulatedPanDy = 0.0;
          _isPanGestureIgnored = false;
          if (_isDraggingProgress) {
            setState(() {
              _isDraggingProgress = false;
            });
            _startHideTimer();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Layer
            if (hasController)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                  );
                },
              ),

            // Ultra-slim bottom progress line (when controls are hidden, locally listening to controller)
            if (!_showControls && !_isScreenLocked && hasController && !_isDraggingProgress)
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
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xE614141C),
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
                          const SizedBox(width: 8),
                          Text(
                            _targetSeekPosition >= _dragStartPosition
                                ? '+${Formatters.formatDuration((_targetSeekPosition - _dragStartPosition).inSeconds)}'
                                : '-${Formatters.formatDuration((_dragStartPosition - _targetSeekPosition).inSeconds)}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${Formatters.formatDuration(_targetSeekPosition.inSeconds)} / ${Formatters.formatDuration(_controller!.value.duration.inSeconds)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _controller!.value.duration.inMilliseconds > 0
                                ? (_targetSeekPosition.inMilliseconds / _controller!.value.duration.inMilliseconds).clamp(0.0, 1.0)
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

            // Double Tap Seek / PlayPause HUD Overlay
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
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xE614141C),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hudIcon != null) ...[
                              Icon(_hudIcon, color: accent, size: 18),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _hudText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xD9101016),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.8),
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
                        Icon(Icons.fast_forward_rounded, color: accent, size: 15),
                        const SizedBox(width: 5),
                        const Text(
                          '2.0X',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                left: (_isScreenLocked ? _showLockIcon : _showControls) ? 24 : -60,
                top: 0,
                bottom: 0,
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
                              : const Color(0x99101016),
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
                          _isScreenLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: _isScreenLocked ? Colors.white : Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
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
            if (_showChapterPanel && !_isScreenLocked && widget.chapters.isNotEmpty)
              Positioned(
                right: isFull ? 24 : 8,
                bottom: 40,
                child: _buildFloatingChapterPanel(isFull),
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

    return AspectRatio(
      aspectRatio: effectiveRatio,
      child: playerBody,
    );
  }

  List<({int quality, String description})> _getAvailableQualities() {
    final List<({int quality, String description})> list = [];
    final seen = <int>{};

    // 1. First add from support_formats
    for (final sf in widget.playUrlInfo.supportFormats) {
      if (sf.quality > 0 && !seen.contains(sf.quality)) {
        seen.add(sf.quality);
        final desc = sf.newDescription.isNotEmpty
            ? sf.newDescription
            : (sf.displayDesc.isNotEmpty ? sf.displayDesc : _getQualityLabel(sf.quality));
        list.add((quality: sf.quality, description: desc));
      }
    }

    // 2. Merge with acceptQuality & acceptDescription
    for (int i = 0; i < widget.playUrlInfo.acceptQuality.length; i++) {
      final q = widget.playUrlInfo.acceptQuality[i];
      if (q > 0 && !seen.contains(q)) {
        seen.add(q);
        final desc = i < widget.playUrlInfo.acceptDescription.length
            ? widget.playUrlInfo.acceptDescription[i]
            : _getQualityLabel(q);
        list.add((quality: q, description: desc));
      }
    }

    // 3. Fallback: Always ensure standard quality tiers (1080P 60, 1080P, 720P, 480P, 360P) are selectable
    const standardTiers = [
      (quality: 116, description: '1080P 60帧'),
      (quality: 80, description: '1080P 高清'),
      (quality: 64, description: '720P 准高清'),
      (quality: 32, description: '480P 标清'),
      (quality: 16, description: '360P 流畅'),
    ];
    for (final tier in standardTiers) {
      if (!seen.contains(tier.quality)) {
        seen.add(tier.quality);
        list.add(tier);
      }
    }

    // Sort descending (4K -> 1080P60 -> 1080P -> 720P -> 480P -> 360P)
    list.sort((a, b) => b.quality.compareTo(a.quality));
    return list;
  }

  Widget _buildFloatingQualityPanel(bool isFull) {
    final qualityItems = _getAvailableQualities();
    final accent = _getPlayerAccent(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        constraints: BoxConstraints(maxHeight: isFull ? 240 : 120),
        decoration: BoxDecoration(
          color: const Color(0xF0181820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: qualityItems.map((item) {
              final isSelected = widget.playUrlInfo.currentQuality == item.quality;

              return InkWell(
                onTap: () {
                  setState(() => _showQualityPanel = false);
                  widget.onQualityChanged?.call(item.quality);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.55) : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      item.description,
                      style: TextStyle(
                        color: isSelected ? accent : Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSpeedPanel(bool isFull) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final accent = _getPlayerAccent(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        constraints: BoxConstraints(maxHeight: isFull ? 240 : 120),
        decoration: BoxDecoration(
          color: const Color(0xF0181820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: speeds.map((s) {
              final isSelected = _playbackSpeed == s;
              return InkWell(
                onTap: () {
                  setState(() {
                    _playbackSpeed = s;
                    _showSpeedPanel = false;
                  });
                  _controller?.setPlaybackSpeed(s);
                  _danmakuController.setPlaybackSpeed(s);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.55) : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${s}x',
                      style: TextStyle(
                        color: isSelected ? accent : Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingChapterPanel(bool isFull) {
    final accent = _getPlayerAccent(context);
    final currentSec = (_controller?.value.position.inSeconds ?? 0);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        constraints: BoxConstraints(
          maxHeight: isFull ? 240 : 130,
          maxWidth: isFull ? 220 : 170,
        ),
        decoration: BoxDecoration(
          color: const Color(0xF0181820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.bookmark_outline_rounded, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    '视频章节',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 6, thickness: 0.5, color: Colors.white12),
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.chapters.map((ch) {
                    final isCurrent = currentSec >= ch.from && (ch.to > ch.from ? currentSec < ch.to : true);
                    final timeStr = Formatters.formatDuration(ch.from);

                    return InkWell(
                      onTap: () {
                        setState(() => _showChapterPanel = false);
                        _controller?.seekTo(Duration(seconds: ch.from));
                        _danmakuController.updatePosition(ch.from.toDouble());
                        _startHideTimer();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        decoration: BoxDecoration(
                          color: isCurrent ? accent.withValues(alpha: 0.22) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCurrent ? accent.withValues(alpha: 0.55) : Colors.transparent,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: isCurrent ? accent : Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ch.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? accent : Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    bool hasController,
    bool isFull,
  ) {
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '已离线',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onListenMode != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.headphones_rounded, color: Colors.white, size: 17),
                      tooltip: '听视频 (熄屏播放)',
                      onPressed: widget.onListenMode,
                    ),
                  if (isFull)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 17),
                      tooltip: '翻转/旋转屏幕',
                      onPressed: _toggleFullscreenOrientation,
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
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
                  if (val.isPlaying || !val.isInitialized) return const SizedBox.shrink();
                  return IconButton(
                    iconSize: 44,
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
              padding: const EdgeInsets.symmetric(horizontal: 6),
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
                          icon: Icon(
                            val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                              final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
                              final curMs = (dragVal ?? val.position.inMilliseconds.toDouble()).clamp(0.0, maxMs);

                              return Row(
                                children: [
                                  Text(
                                    '${Formatters.formatDuration(currentPos.inSeconds)} / ${Formatters.formatDuration(duration.inSeconds)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2.0,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
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
                                          _controller?.seekTo(Duration(milliseconds: ms));
                                          _danmakuController.updatePosition(ms / 1000.0);
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

                  // 4. Danmaku Toggle Button
                  ListenableBuilder(
                    listenable: _danmakuController,
                    builder: (ctx, _) {
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        icon: Icon(
                          _danmakuController.enabled ? Icons.subtitles_rounded : Icons.subtitles_off_outlined,
                          color: _danmakuController.enabled ? accent : Colors.white60,
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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
                    icon: Icon(
                      isFull ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
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
