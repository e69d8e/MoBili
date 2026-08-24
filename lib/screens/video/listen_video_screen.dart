import 'dart:ui';
import 'package:flutter/material.dart';
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
  bool _isSeeking = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ListenVideoProvider>();
      if (provider.cid != widget.cid || !provider.hasAudio) {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListenVideoProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

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

    final dur = provider.duration > Duration.zero
        ? provider.duration
        : (widget.totalDuration != null && widget.totalDuration! > Duration.zero
            ? widget.totalDuration!
            : Duration.zero);
    final pos = _isSeeking
        ? Duration(milliseconds: _dragValue.toInt())
        : (provider.position > dur && dur > Duration.zero ? dur : provider.position);

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
            // 1. Ambient blurred background
            if (currentCover.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  currentCover,
                  fit: BoxFit.cover,
                  headers: const {'Referer': 'https://www.bilibili.com'},
                  errorBuilder: (ctx, error, stackTrace) => const SizedBox.shrink(),
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

            // 2. Main Content
            SafeArea(
              child: Column(
                children: [
                  // Top Action Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                ),

                const Spacer(flex: 1),

                // Center Vinyl / Breathing Artwork
                Center(
                  child: RepaintBoundary(
                    child: RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black87,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 4,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(32),
                        child: ClipOval(
                          child: NetworkImageView(
                            url: currentCover,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            memCacheHeight: 400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Video Title & UP info
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
                          Text(
                            currentUpName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
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

                const SizedBox(height: 24),

                // Progress Bar & Durations
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: primary,
                          inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                          thumbColor: primary,
                        ),
                        child: Slider(
                          value: (_isSeeking ? _dragValue : pos.inMilliseconds.toDouble()).clamp(
                                0.0,
                                dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0,
                              ),
                          min: 0.0,
                          max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0,
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
                            provider.seek(Duration(milliseconds: val.toInt()));
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
                                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                              ),
                            ),
                            Text(
                              Formatters.formatDuration(dur.inSeconds),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Playback Control Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Playback Speed button
                      InkWell(
                        onTap: () => _showSpeedDialog(context, provider),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${provider.speed}x',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // -15s Seek button
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.replay_10_rounded),
                        tooltip: '后退 15 秒',
                        onPressed: () => provider.seekRelative(-15),
                      ),

                      // Main Play / Pause Button
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary,
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: 36,
                          icon: provider.isBuffering
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
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
                        iconSize: 32,
                        icon: const Icon(Icons.forward_10_rounded),
                        tooltip: '快进 15 秒',
                        onPressed: () => provider.seekRelative(15),
                      ),

                      // Sleep Timer quick toggle
                      IconButton(
                        icon: Icon(
                          provider.isSleepTimerActive || provider.isSleepEndOfTrack
                              ? Icons.alarm_on_rounded
                              : Icons.alarm_rounded,
                          size: 24,
                          color: provider.isSleepTimerActive || provider.isSleepEndOfTrack
                              ? primary
                              : null,
                        ),
                        tooltip: '定时设置',
                        onPressed: () => _showSleepTimerDialog(context, provider),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
