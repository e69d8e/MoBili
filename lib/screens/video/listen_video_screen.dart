import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/listen_video_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/network_image_view.dart';
import 'video_detail_screen.dart';

class ListenVideoScreen extends StatefulWidget {
  final String bvid;
  final int cid;
  final String title;
  final String coverUrl;
  final String upName;
  final String? playUrl;
  final Duration? initialPosition;
  final Duration? totalDuration;
  final double initialSpeed;
  final void Function(Duration currentPosition)? onSwitchToVideo;

  const ListenVideoScreen({
    super.key,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.coverUrl,
    required this.upName,
    this.playUrl,
    this.initialPosition,
    this.totalDuration,
    this.initialSpeed = 1.0,
    this.onSwitchToVideo,
  });

  @override
  State<ListenVideoScreen> createState() => _ListenVideoScreenState();
}

class _ListenVideoScreenState extends State<ListenVideoScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    // Restore normal edge-to-edge system UI and allow all device orientations
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ListenVideoProvider>();
      if (widget.onSwitchToVideo != null || provider.cid != widget.cid || !provider.hasAudio) {
        provider.playAudio(
          bvid: widget.bvid,
          cid: widget.cid,
          title: widget.title,
          coverUrl: widget.coverUrl,
          upName: widget.upName,
          audioUrl: widget.playUrl,
          startPosition: widget.initialPosition,
          totalDuration: widget.totalDuration,
          speed: widget.initialSpeed,
        );
      } else if (!provider.isPlaying) {
        provider.play();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _showSpeedDialog(BuildContext context, ListenVideoProvider provider) {
    final speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '播放速度',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...speeds.map((s) {
                  final isSelected = (provider.speed - s).abs() < 0.01;
                  return ListTile(
                    title: Center(
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? primary : null,
                        ),
                      ),
                    ),
                    onTap: () {
                      provider.setSpeed(s);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context, ListenVideoProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bedtime_outlined, size: 18, color: primary),
                    const SizedBox(width: 6),
                    const Text(
                      '定时关闭',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Center(
                    child: Text(
                      '不开启',
                      style: TextStyle(
                        fontSize: 14,
                        color: !provider.isSleepTimerActive && !provider.isSleepEndOfTrack
                            ? primary
                            : null,
                        fontWeight: !provider.isSleepTimerActive && !provider.isSleepEndOfTrack
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  onTap: () {
                    provider.cancelSleepTimer();
                    Navigator.pop(ctx);
                  },
                ),
                _buildSleepOption(ctx, provider, '15 分钟后', const Duration(minutes: 15), primary),
                _buildSleepOption(ctx, provider, '30 分钟后', const Duration(minutes: 30), primary),
                _buildSleepOption(ctx, provider, '45 分钟后', const Duration(minutes: 45), primary),
                _buildSleepOption(ctx, provider, '60 分钟后', const Duration(minutes: 60), primary),
                ListTile(
                  title: Center(
                    child: Text(
                      '播完当前视频',
                      style: TextStyle(
                        fontSize: 14,
                        color: provider.isSleepEndOfTrack ? primary : null,
                        fontWeight: provider.isSleepEndOfTrack ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  onTap: () {
                    provider.setSleepTimer(null, endOfTrack: true);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSleepOption(
    BuildContext context,
    ListenVideoProvider provider,
    String label,
    Duration duration,
    Color primary,
  ) {
    return ListTile(
      title: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      onTap: () {
        provider.setSleepTimer(duration);
        Navigator.pop(context);
      },
    );
  }

  void _handleSwitchToVideo(ListenVideoProvider provider) async {
    final curPos = provider.position;
    await provider.stopAndClear();
    if (!mounted) return;

    if (widget.onSwitchToVideo != null) {
      widget.onSwitchToVideo!(curPos);
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => VideoDetailScreen(
            bvid: widget.bvid,
            initialPosition: curPos,
          ),
        ),
      );
    }
  }

  void _handleMinimize(ListenVideoProvider provider) async {
    if (widget.onSwitchToVideo != null) {
      // Returning to VideoDetailScreen: pause audio playback
      await provider.pause();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildTopBar(
    BuildContext context,
    ListenVideoProvider provider,
    Color primary, {
    bool isLandscape = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 16 : 12,
        vertical: isLandscape ? 4 : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Minimize / Back button
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            tooltip: widget.onSwitchToVideo != null ? '返回视频' : '收起',
            onPressed: () => _handleMinimize(provider),
          ),

          // "Switch to Video" pill button
          InkWell(
            onTap: () => _handleSwitchToVideo(provider),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ondemand_video_rounded, size: 14, color: primary),
                  const SizedBox(width: 4),
                  Text(
                    '切回视频',
                    style: TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sleep timer status / button
          IconButton(
            icon: Icon(
              provider.isSleepTimerActive || provider.isSleepEndOfTrack
                  ? Icons.bedtime_rounded
                  : Icons.bedtime_outlined,
              size: 22,
              color: provider.isSleepTimerActive || provider.isSleepEndOfTrack
                  ? primary
                  : null,
            ),
            tooltip: '定时关闭',
            onPressed: () => _showSleepTimerDialog(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildVinylArtwork(String coverUrl, double size) {
    final innerPadding = size * 0.13;
    return RepaintBoundary(
      child: RotationTransition(
        turns: _rotationController,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black87,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: size * 0.1,
                spreadRadius: 2,
                offset: Offset(0, size * 0.04),
              ),
            ],
          ),
          padding: EdgeInsets.all(innerPadding),
          child: ClipOval(
            child: NetworkImageView(
              url: coverUrl,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              memCacheHeight: 400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(
    BuildContext context,
    ListenVideoProvider provider,
    Color primary,
    bool isDark, {
    bool isLandscape = false,
  }) {
    final btnSize = isLandscape ? 28.0 : 32.0;
    final playBtnSize = isLandscape ? 52.0 : 64.0;
    final playIconSize = isLandscape ? 30.0 : 36.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Playback Speed button
          InkWell(
            onTap: () => _showSpeedDialog(context, provider),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8 : 10,
                vertical: isLandscape ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${provider.speed}x',
                style: TextStyle(
                  fontSize: isLandscape ? 11.5 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // -15s Seek button
          IconButton(
            iconSize: btnSize,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.replay_10_rounded),
            tooltip: '后退 15 秒',
            onPressed: () => provider.seekRelative(-15),
          ),

          // Main Play / Pause Button
          Container(
            width: playBtnSize,
            height: playBtnSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              iconSize: playIconSize,
              icon: provider.isBuffering
                  ? SizedBox(
                      width: isLandscape ? 20 : 24,
                      height: isLandscape ? 20 : 24,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
              onPressed: provider.togglePlayPause,
            ),
          ),

          // +15s Seek button
          IconButton(
            iconSize: btnSize,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.forward_10_rounded),
            tooltip: '快进 15 秒',
            onPressed: () => provider.seekRelative(15),
          ),

          // Sleep Timer quick toggle
          IconButton(
            iconSize: isLandscape ? 22 : 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              provider.isSleepTimerActive || provider.isSleepEndOfTrack
                  ? Icons.alarm_on_rounded
                  : Icons.alarm_rounded,
              color: provider.isSleepTimerActive || provider.isSleepEndOfTrack
                  ? primary
                  : null,
            ),
            tooltip: '定时设置',
            onPressed: () => _showSleepTimerDialog(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    ListenVideoProvider provider,
    String currentTitle,
    String currentCover,
    String currentUpName,
    Color primary,
    bool isDark,
  ) {
    return Column(
      children: [
        _buildTopBar(context, provider, primary, isLandscape: true),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final vinylSize = (constraints.maxHeight * 0.78).clamp(90.0, 220.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Vinyl Record
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: _buildVinylArtwork(currentCover, vinylSize),
                    ),
                  ),

                  // Right: Info & Controls
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20, left: 8),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentTitle,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    currentUpName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (provider.isSleepTimerActive && provider.sleepTimerRemaining != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '🌙 将在 ${Formatters.formatDuration(provider.sleepTimerRemaining!.inSeconds)} 后停止播放',
                                    style: TextStyle(fontSize: 10, color: primary),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            _ListenProgressSection(
                              fallbackDuration: widget.totalDuration,
                              primary: primary,
                              isDark: isDark,
                              horizontalPadding: 12,
                            ),
                            const SizedBox(height: 6),
                            _buildControlButtons(context, provider, primary, isDark, isLandscape: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    ListenVideoProvider provider,
    String currentTitle,
    String currentCover,
    String currentUpName,
    Color primary,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final vinylSize = (availableHeight * 0.35).clamp(160.0, 260.0);

        return Column(
          children: [
            _buildTopBar(context, provider, primary, isLandscape: false),

            const Spacer(flex: 1),

            Center(
              child: _buildVinylArtwork(currentCover, vinylSize),
            ),

            const Spacer(flex: 1),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    currentTitle,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          currentUpName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (provider.isSleepTimerActive && provider.sleepTimerRemaining != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🌙 将在 ${Formatters.formatDuration(provider.sleepTimerRemaining!.inSeconds)} 后停止播放',
                          style: TextStyle(fontSize: 10.5, color: primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _ListenProgressSection(
              fallbackDuration: widget.totalDuration,
              primary: primary,
              isDark: isDark,
              horizontalPadding: 24,
            ),

            const SizedBox(height: 16),

            _buildControlButtons(context, provider, primary, isDark, isLandscape: false),

            const Spacer(flex: 1),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListenVideoProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (provider.isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }

    final currentTitle = provider.title ?? widget.title;
    final currentCover = provider.coverUrl ?? widget.coverUrl;
    final currentUpName = provider.upName ?? widget.upName;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop && widget.onSwitchToVideo != null) {
          // If returning to VideoDetailScreen via system back, pause audio playback
          await provider.pause();
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Ambient blurred background with memory-efficient low-res cache
            if (currentCover.isNotEmpty)
              Positioned.fill(
                child: NetworkImageView(
                  url: currentCover,
                  fit: BoxFit.cover,
                  memCacheWidth: 100,
                  memCacheHeight: 100,
                ),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.78),
                ),
              ),
            ),

            // 2. Main Content (Landscape vs Portrait adaptive layout)
            SafeArea(
              child: isLandscape
                  ? _buildLandscapeLayout(context, provider, currentTitle, currentCover, currentUpName, primary, isDark)
                  : _buildPortraitLayout(context, provider, currentTitle, currentCover, currentUpName, primary, isDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListenProgressSection extends StatefulWidget {
  final Duration? fallbackDuration;
  final Color primary;
  final bool isDark;
  final double horizontalPadding;

  const _ListenProgressSection({
    this.fallbackDuration,
    required this.primary,
    required this.isDark,
    this.horizontalPadding = 24.0,
  });

  @override
  State<_ListenProgressSection> createState() => _ListenProgressSectionState();
}

class _ListenProgressSectionState extends State<_ListenProgressSection> {
  bool _isSeeking = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Selector<ListenVideoProvider, ({Duration position, Duration duration})>(
      selector: (_, p) => (
        position: p.position,
        duration: p.duration > Duration.zero
            ? p.duration
            : (widget.fallbackDuration ?? Duration.zero),
      ),
      builder: (context, data, _) {
        final dur = data.duration;
        final pos = _isSeeking
            ? Duration(milliseconds: _dragValue.toInt())
            : (data.position > dur && dur > Duration.zero ? dur : data.position);

        final durMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final currentSliderVal = (_isSeeking ? _dragValue : pos.inMilliseconds.toDouble()).clamp(0.0, durMs);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: widget.primary,
                  inactiveTrackColor: widget.isDark ? Colors.white12 : Colors.black12,
                  thumbColor: widget.primary,
                ),
                child: Slider(
                  value: currentSliderVal,
                  min: 0.0,
                  max: durMs,
                  onChangeStart: (val) {
                    setState(() {
                      _isSeeking = true;
                      _dragValue = val;
                    });
                  },
                  onChanged: (val) {
                    setState(() {
                      _dragValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    setState(() {
                      _isSeeking = false;
                    });
                    context.read<ListenVideoProvider>().seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.formatDuration(pos.inSeconds),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                      ),
                    ),
                    Text(
                      Formatters.formatDuration(dur.inSeconds),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
