import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/listen_video_provider.dart';
import '../../services/api/video_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/network_image_view.dart';
import 'video_detail_screen.dart';

class ListenPlaylistItem {
  final String bvid;
  final int cid;
  final String title;
  final String coverUrl;
  final String upName;
  final String? localFilePath;
  final Duration? duration;
  final int progress;

  const ListenPlaylistItem({
    required this.bvid,
    required this.cid,
    required this.title,
    required this.coverUrl,
    required this.upName,
    this.localFilePath,
    this.duration,
    this.progress = 0,
  });
}

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
  final List<ListenPlaylistItem>? playlist;
  final int initialPlaylistIndex;
  final void Function(ListenPlaylistItem item, int index)? onSwitchPlaylistItem;

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
    this.playlist,
    this.initialPlaylistIndex = 0,
    this.onSwitchPlaylistItem,
  });

  @override
  State<ListenVideoScreen> createState() => _ListenVideoScreenState();
}

class _ListenVideoScreenState extends State<ListenVideoScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  ListenVideoProvider? _listenProvider;
  List<ListenPlaylistItem>? _playlist;
  int _currentPlaylistIndex = 0;
  bool _isAutoAdvancing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = context.read<ListenVideoProvider>();
    if (_listenProvider != newProvider) {
      _listenProvider?.removeListener(_onListenProviderUpdate);
      _listenProvider = newProvider;
      _listenProvider?.addListener(_onListenProviderUpdate);
    }
  }

  void _onListenProviderUpdate() {
    if (!mounted || _listenProvider == null) return;
    final p = _listenProvider!;
    if (p.duration > Duration.zero && p.position >= p.duration && !p.isBuffering && !_isAutoAdvancing) {
      if (_playlist != null && _currentPlaylistIndex + 1 < _playlist!.length) {
        _isAutoAdvancing = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _playlist != null && _currentPlaylistIndex + 1 < _playlist!.length) {
            _switchPlaylistItem(_currentPlaylistIndex + 1);
            _isAutoAdvancing = false;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist != null ? List<ListenPlaylistItem>.from(widget.playlist!) : null;
    _currentPlaylistIndex = widget.initialPlaylistIndex;
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
    _listenProvider?.removeListener(_onListenProviderUpdate);
    // Whenever exiting the listen video screen, pause playback if still playing
    if (_listenProvider != null && _listenProvider!.isPlaying) {
      _listenProvider!.pause();
    }
    _rotationController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Future<void> _switchPlaylistItem(int newIndex) async {
    if (_playlist == null || newIndex < 0 || newIndex >= _playlist!.length) return;
    final item = _playlist![newIndex];
    final provider = context.read<ListenVideoProvider>();
    if (newIndex == _currentPlaylistIndex && provider.cid == item.cid && item.cid != 0) return;

    setState(() {
      _currentPlaylistIndex = newIndex;
    });

    int targetCid = item.cid;
    String? localPath = item.localFilePath;

    if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
      await provider.playAudio(
        bvid: item.bvid,
        cid: targetCid,
        title: item.title,
        coverUrl: item.coverUrl,
        upName: item.upName,
        audioUrl: localPath,
        totalDuration: item.duration,
        speed: provider.speed,
      );
    } else {
      if (targetCid == 0) {
        try {
          final detail = await VideoApiService().getVideoDetail(item.bvid);
          if (detail != null && detail.pages.isNotEmpty) {
            targetCid = detail.pages[0].cid;
          }
        } catch (_) {}
      }

      await provider.playAudio(
        bvid: item.bvid,
        cid: targetCid,
        title: item.title,
        coverUrl: item.coverUrl,
        upName: item.upName,
        totalDuration: item.duration,
        speed: provider.speed,
      );
    }

    widget.onSwitchPlaylistItem?.call(item, newIndex);
  }

  void _showSpeedDialog(BuildContext context, ListenVideoProvider provider) {
    final speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '播放速度',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12.0),
                ...speeds.map((s) {
                  final isSelected = (provider.speed - s).abs() < 0.01;
                  return ListTile(
                    title: Center(
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bedtime_outlined, size: 18, color: primary),
                    const SizedBox(width: 4.0),
                    const Text(
                      '定时关闭',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
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
                            ? FontWeight.w600
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
                        fontWeight: provider.isSleepEndOfTrack ? FontWeight.w600 : FontWeight.normal,
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
    final activeBvid = provider.bvid ?? widget.bvid;
    await provider.stopAndClear();
    if (!mounted) return;

    if (widget.onSwitchToVideo != null) {
      widget.onSwitchToVideo!(curPos);
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => VideoDetailScreen(
            bvid: activeBvid,
            initialPosition: curPos,
          ),
        ),
      );
    }
  }

  void _handleMinimize(ListenVideoProvider provider) {
    if (provider.isPlaying) {
      provider.pause();
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
        horizontal: isLandscape ? 16.0 : 12.0,
        vertical: isLandscape ? 4 : 8.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Minimize / Back button
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            tooltip: '返回 (暂停播放)',
            onPressed: () => _handleMinimize(provider),
          ),

          // "Switch to Video" pill button
          InkWell(
            onTap: () => _handleSwitchToVideo(provider),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_display_rounded, size: 16, color: primary),
                  const SizedBox(width: 4.0),
                  Text(
                    '转为视频播放',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: RotationTransition(
        turns: _rotationController,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // 深色背景下 black87 会与页面背景融没，提亮一档并加描边保持唱片轮廓
            color: isDark ? AppTheme.surfaceDark : Colors.black87,
            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.28),
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
    final hasPlaylist = _playlist != null && _playlist!.isNotEmpty;
    final canPrev = hasPlaylist ? _currentPlaylistIndex > 0 : true;
    final canNext = hasPlaylist ? _currentPlaylistIndex < _playlist!.length - 1 : true;

    final btnSize = isLandscape ? 28.0 : 32.0;
    final playBtnSize = isLandscape ? 52.0 : 64.0;
    final playIconSize = isLandscape ? 30.0 : 36.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8.0 : 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Playback Speed button
          InkWell(
            onTap: () => _showSpeedDialog(context, provider),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8.0 : 8.0,
                vertical: isLandscape ? 4 : 4.0,
              ),
              decoration: BoxDecoration(
                color: context.colors.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.speed}x',
                style: TextStyle(
                  fontSize: isLandscape ? 11.5 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Previous Track / -15s Button
          IconButton(
            iconSize: btnSize + 2,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              hasPlaylist ? Icons.skip_previous_rounded : Icons.replay_10_rounded,
              color: (hasPlaylist && !canPrev)
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : null,
            ),
            tooltip: hasPlaylist ? '上一首' : '后退 15 秒',
            onPressed: () {
              if (hasPlaylist) {
                if (provider.position.inSeconds > 3) {
                  provider.seekTo(Duration.zero);
                } else if (canPrev) {
                  _switchPlaylistItem(_currentPlaylistIndex - 1);
                } else {
                  provider.seekTo(Duration.zero);
                }
              } else {
                provider.seekRelative(-15);
              }
            },
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

          // Next Track / +15s Button
          IconButton(
            iconSize: btnSize + 2,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              hasPlaylist ? Icons.skip_next_rounded : Icons.forward_10_rounded,
              color: (hasPlaylist && !canNext)
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : null,
            ),
            tooltip: hasPlaylist ? '下一首' : '快进 15 秒',
            onPressed: () {
              if (hasPlaylist) {
                if (canNext) {
                  _switchPlaylistItem(_currentPlaylistIndex + 1);
                } else {
                  AppToast.show(context, '已经是最后一首了');
                }
              } else {
                provider.seekRelative(15);
              }
            },
          ),

          // Playlist button (if playlist exists) or Sleep Timer quick toggle
          if (hasPlaylist)
            IconButton(
              iconSize: isLandscape ? 24 : 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.queue_music_rounded),
              tooltip: '播放列表',
              onPressed: () => _showPlaylistBottomSheet(context, provider, primary, isDark),
            )
          else
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

  void _showPlaylistBottomSheet(
    BuildContext context,
    ListenVideoProvider provider,
    Color primary,
    bool isDark,
  ) {
    if (_playlist == null || _playlist!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: Row(
                  children: [
                    Icon(Icons.queue_music_rounded, size: 18, color: primary),
                    const SizedBox(width: 8.0),
                    Text(
                      '听视频播放列表 (共 ${_playlist!.length} 个)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: context.colors.divider,
              ),
              Flexible(
                child: ListView.separated(
                  // 长列表懒加载；短列表保持 shrinkWrap 以免弹窗被撑满
                  shrinkWrap: _playlist!.length <= 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  itemCount: _playlist!.length,
                  separatorBuilder: (c, _) => const SizedBox(height: 4.0),
                  itemBuilder: (c, idx) {
                    final item = _playlist![idx];
                    final isPlaying = idx == _currentPlaylistIndex;

                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchPlaylistItem(idx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? primary.withValues(alpha: 0.12)
                              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPlaying ? primary : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isPlaying)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.volume_up_rounded, color: primary, size: 16),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textHint,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (item.coverUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: NetworkImageView(
                                    url: item.coverUrl,
                                    width: 44,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 100,
                                    memCacheHeight: 64,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                                      color: isPlaying
                                          ? primary
                                          : (context.colors.textMain),
                                    ),
                                  ),
                                  if (item.upName.isNotEmpty)
                                    Text(
                                      item.upName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.colors.textHint,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (item.duration != null && item.duration! > Duration.zero)
                              Text(
                                Formatters.formatDuration(item.duration!.inSeconds),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.colors.textHint,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
                      padding: const EdgeInsets.only(right: 20.0, left: 8.0),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
                                  color: context.colors.textSub,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    currentUpName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.textSub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_playlist != null && _playlist!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _showPlaylistBottomSheet(context, provider, primary, isDark),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primary.withValues(alpha: 0.3), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.queue_music_rounded, size: 12, color: primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '播放列表 · ${_currentPlaylistIndex + 1}/${_playlist!.length}',
                                        style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (provider.isSleepTimerActive && provider.sleepTimerRemaining != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '🌙 将在 ${Formatters.formatDuration(provider.sleepTimerRemaining!.inSeconds)} 后停止播放',
                                    style: TextStyle(fontSize: 10, color: primary),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4.0),
                            _ListenProgressSection(
                              fallbackDuration: widget.totalDuration,
                              primary: primary,
                              isDark: isDark,
                              horizontalPadding: 12,
                            ),
                            const SizedBox(height: 4.0),
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
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  Text(
                    currentTitle,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: context.colors.textSub,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          currentUpName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_playlist != null && _playlist!.isNotEmpty) ...[
                    const SizedBox(height: 8.0),
                    InkWell(
                      onTap: () => _showPlaylistBottomSheet(context, provider, primary, isDark),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primary.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.queue_music_rounded, size: 13, color: primary),
                            const SizedBox(width: 4),
                            Text(
                              '播放列表 · ${_currentPlaylistIndex + 1}/${_playlist!.length}',
                              style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (provider.isSleepTimerActive && provider.sleepTimerRemaining != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🌙 将在 ${Formatters.formatDuration(provider.sleepTimerRemaining!.inSeconds)} 后停止播放',
                          style: TextStyle(fontSize: 11, color: primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20.0),

            _ListenProgressSection(
              fallbackDuration: widget.totalDuration,
              primary: primary,
              isDark: isDark,
              horizontalPadding: 24,
            ),

            const SizedBox(height: 16.0),

            _buildControlButtons(context, provider, primary, isDark, isLandscape: false),

            const Spacer(flex: 1),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Selector<ListenVideoProvider, ({
      String title,
      String coverUrl,
      String upName,
      bool isPlaying,
      bool isBuffering,
      double speed,
      bool isSleepTimerActive,
      Duration? sleepTimerRemaining,
      bool isSleepEndOfTrack,
    })>(
      selector: (_, p) => (
        title: p.title ?? widget.title,
        coverUrl: p.coverUrl ?? widget.coverUrl,
        upName: p.upName ?? widget.upName,
        isPlaying: p.isPlaying,
        isBuffering: p.isBuffering,
        speed: p.speed,
        isSleepTimerActive: p.isSleepTimerActive,
        sleepTimerRemaining: p.sleepTimerRemaining,
        isSleepEndOfTrack: p.isSleepEndOfTrack,
      ),
      builder: (context, data, _) {
        if (data.isPlaying) {
          if (!_rotationController.isAnimating) {
            _rotationController.repeat();
          }
        } else {
          if (_rotationController.isAnimating) {
            _rotationController.stop();
          }
        }

        final provider = context.read<ListenVideoProvider>();
        final currentTitle = data.title;
        final currentCover = data.coverUrl;
        final currentUpName = data.upName;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              if (provider.isPlaying) {
                provider.pause();
              }
            }
          },
          child: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Ambient blurred background with memory-efficient low-res cache
                if (currentCover.isNotEmpty)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: NetworkImageView(
                        url: currentCover,
                        fit: BoxFit.cover,
                        memCacheWidth: 100,
                        memCacheHeight: 100,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: Container(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.78),
                      ),
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
      },
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
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.formatDuration(pos.inSeconds),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textHint,
                      ),
                    ),
                    Text(
                      Formatters.formatDuration(dur.inSeconds),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textHint,
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
