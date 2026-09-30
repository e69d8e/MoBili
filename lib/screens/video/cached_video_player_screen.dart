import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/danmaku_model.dart';
import '../../models/play_url_model.dart';
import '../../models/video_cache_model.dart';
import '../../models/video_model.dart';
import '../../providers/listen_video_provider.dart';
import '../../services/api/danmaku_service.dart';
import '../../services/player_settings_service.dart';
import '../../services/storage/history_storage_service.dart';
import '../../services/storage/video_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/player/bili_video_player.dart';
import '../../widgets/user_avatar.dart';
import 'listen_video_screen.dart';
import 'video_detail_screen.dart';

class CachedVideoPlayerScreen extends StatefulWidget {
  final VideoCacheItem item;

  const CachedVideoPlayerScreen({
    super.key,
    required this.item,
  });

  @override
  State<CachedVideoPlayerScreen> createState() => _CachedVideoPlayerScreenState();
}

class _CachedVideoPlayerScreenState extends State<CachedVideoPlayerScreen> {
  final GlobalKey<BiliVideoPlayerState> _playerKey = GlobalKey<BiliVideoPlayerState>();
  final VideoCacheService _cacheService = VideoCacheService();

  late VideoCacheItem _currentItem;
  List<VideoCacheItem> _cachedEpisodes = [];
  PlayUrlInfo? _playUrlInfo;
  List<DanmakuItem> _danmakus = [];
  bool _isPlayerFullScreen = false;

  // 最近一次播放位置：dispose 时子组件已卸载，GlobalKey 取不到播放器，
  // 退出保存进度只能靠这里兜底（同 video_detail_screen 的做法）
  Duration _lastPlayerPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _refreshCachedEpisodes();
    _loadCurrentEpisode();

    PlayerSettingsService.autoRotateListenable.addListener(_onAutoRotateSettingChanged);
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

  void _onAutoRotateSettingChanged() {
    if (!mounted) return;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isFull = _isPlayerFullScreen || isLandscape;
    if (!isFull) {
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
  void dispose() {
    PlayerSettingsService.autoRotateListenable.removeListener(_onAutoRotateSettingChanged);
    _reportProgress();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _refreshCachedEpisodes() {
    _cachedEpisodes = _cacheService.allTasks
        .where((t) => t.bvid == _currentItem.bvid && t.isCompleted)
        .toList()
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
  }

  Future<void> _loadCurrentEpisode() async {
    final localPath = _currentItem.localVideoPath;
    if (localPath.isEmpty || !File(localPath).existsSync()) {
      if (mounted) {
        AppToast.show(context, '本地视频文件不存在或已被删除');
      }
      return;
    }

    final durMs = _currentItem.duration * 1000;
    final q = _currentItem.quality;
    final qDesc = _currentItem.qualityDesc.isNotEmpty ? _currentItem.qualityDesc : '${q}P';
    final localAudio = _currentItem.localAudioPath;
    final hasLocalAudio = localAudio.isNotEmpty && File(localAudio).existsSync();

    final PlayUrlInfo playInfo;
    if (hasLocalAudio) {
      playInfo = PlayUrlInfo(
        currentQuality: q,
        format: 'dash',
        timelength: durMs,
        acceptQuality: [q],
        acceptDescription: [qDesc],
        durls: const [],
        videoTracks: [
          DashVideoItem(
            id: q,
            baseUrl: Uri.file(localPath).toString(),
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
            newDescription: qDesc,
            displayDesc: qDesc,
          ),
        ],
        videoCodecid: 7,
      );
    } else {
      playInfo = PlayUrlInfo(
        currentQuality: q,
        format: 'mp4',
        timelength: durMs,
        acceptQuality: [q],
        acceptDescription: [qDesc],
        durls: [
          PlayUrlDurl(
            order: 1,
            length: durMs,
            size: _currentItem.totalBytes,
            url: Uri.file(localPath).toString(),
            backupUrls: const [],
          ),
        ],
        supportFormats: [
          SupportFormat(
            quality: q,
            format: 'mp4',
            newDescription: qDesc,
            displayDesc: qDesc,
          ),
        ],
        videoCodecid: 7,
      );
    }

    // Load local danmakus
    final danmakuList = await DanmakuService().getDanmakuList(
      _currentItem.cid,
      localFilePath: _currentItem.localDanmakuPath,
    );

    if (mounted) {
      setState(() {
        _playUrlInfo = playInfo;
        _danmakus = danmakuList;
      });
    }
  }

  void _switchEpisode(VideoCacheItem ep) {
    if (ep.taskId == _currentItem.taskId) return;
    _reportProgress();
    _lastPlayerPosition = Duration.zero;
    setState(() {
      _currentItem = ep;
      _playUrlInfo = null;
      _danmakus = [];
    });
    _loadCurrentEpisode();
  }

  void _reportProgress() {
    final pos =
        _playerKey.currentState?.controller?.value.position ??
        _lastPlayerPosition;
    if (pos > Duration.zero) {
      HistoryStorageService().saveProgress(
        bvid: _currentItem.bvid,
        progress: pos.inSeconds,
        duration: _currentItem.duration,
        aid: _currentItem.aid,
        cid: _currentItem.cid,
        title: _currentItem.title,
        cover: _currentItem.cover,
        immediate: true,
      );
    }
  }

  void _startListenMode() async {
    final localPath = _currentItem.localVideoPath;
    if (localPath.isEmpty || !File(localPath).existsSync()) {
      AppToast.show(context, '本地文件不可用');
      return;
    }

    final pos = _playerKey.currentState?.controller?.value.position ?? Duration.zero;
    final speed = _playerKey.currentState?.playbackSpeed ?? 1.0;

    await _playerKey.currentState?.pause();

    if (!mounted) return;

    final playlist = _cachedEpisodes.map((e) {
      final epTitle = e.pageTitle.isNotEmpty && e.pageCount > 1
          ? '${e.title} · ${e.pageTitle}'
          : e.title;
      return ListenPlaylistItem(
        bvid: e.bvid,
        cid: e.cid,
        title: epTitle,
        coverUrl: e.cover,
        upName: e.ownerName,
        localFilePath: e.localVideoPath,
        duration: e.duration > 0 ? Duration(seconds: e.duration) : null,
        progress: HistoryStorageService().getProgress(e.bvid),
      );
    }).toList();

    final curIdx = _cachedEpisodes.indexWhere((e) => e.taskId == _currentItem.taskId);
    final initialIdx = curIdx >= 0 ? curIdx : 0;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ListenVideoScreen(
          bvid: _currentItem.bvid,
          cid: _currentItem.cid,
          title: _currentItem.pageTitle.isNotEmpty && _currentItem.pageCount > 1
              ? '${_currentItem.title} · ${_currentItem.pageTitle}'
              : _currentItem.title,
          coverUrl: _currentItem.cover,
          upName: _currentItem.ownerName,
          playUrl: localPath,
          initialPosition: pos,
          totalDuration: _currentItem.duration > 0
              ? Duration(seconds: _currentItem.duration)
              : null,
          initialSpeed: speed,
          playlist: playlist,
          initialPlaylistIndex: initialIdx,
          onSwitchPlaylistItem: (item, idx) {
            if (idx >= 0 && idx < _cachedEpisodes.length) {
              _switchEpisode(_cachedEpisodes[idx]);
            }
          },
          onSwitchToVideo: (curPos) async {
            await _playerKey.currentState?.controller?.seekTo(curPos);
            await _playerKey.currentState?.play();
          },
        ),
      ),
    );

    if (mounted) {
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
      final listenProvider = context.read<ListenVideoProvider>();
      if (listenProvider.hasAudio && listenProvider.bvid == _currentItem.bvid) {
        final curAudioPos = listenProvider.position;
        if (curAudioPos > Duration.zero && _playerKey.currentState?.controller != null) {
          await _playerKey.currentState?.controller?.seekTo(curAudioPos);
        }
      }
    }
  }

  void _openOnlineDetail() async {
    await _playerKey.currentState?.pause();

    if (!mounted) return;

    final videoItem = VideoItem(
      aid: _currentItem.aid,
      bvid: _currentItem.bvid,
      cid: _currentItem.cid,
      title: _currentItem.title,
      pic: _currentItem.cover,
      desc: '',
      duration: _currentItem.duration,
      pubdate: 0,
      ctime: 0,
      owner: Owner(mid: 0, name: _currentItem.ownerName, face: _currentItem.ownerFace),
      stat: Stat(),
    );

    final pos = _playerKey.currentState?.controller?.value.position;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => VideoDetailScreen(
          bvid: _currentItem.bvid,
          initialVideo: videoItem,
          initialPosition: pos,
        ),
      ),
    );
  }

  Future<void> _deleteCurrentCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除此集缓存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('确定要删除「${_currentItem.pageTitle.isNotEmpty ? _currentItem.pageTitle : _currentItem.title}」的离线缓存吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final taskIdToDelete = _currentItem.taskId;
      await _cacheService.deleteTask(taskIdToDelete);

      _refreshCachedEpisodes();
      if (_cachedEpisodes.isEmpty) {
        if (mounted) {
          AppToast.show(context, '已删除缓存');
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          AppToast.show(context, '已删除此集缓存，已为您切换下一集');
          _switchEpisode(_cachedEpisodes.first);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isFullScreen = _isPlayerFullScreen || isLandscape;

    final savedProgress = HistoryStorageService().getProgress(_currentItem.bvid);
    final initialPos = savedProgress > 0 ? Duration(seconds: savedProgress) : null;

    final dateStr = _currentItem.completedAt > 0
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_currentItem.completedAt))
        : DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_currentItem.createdAt));

    return PopScope(
      canPop: !isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isFullScreen) {
          _playerKey.currentState?.exitFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: isFullScreen ? Colors.black : theme.scaffoldBackgroundColor,
        body: SafeArea(
          top: !isFullScreen,
          bottom: false,
          left: !isFullScreen,
          right: !isFullScreen,
          child: Column(
            children: [
              // Video Player Container (Expanded in fullscreen, 16:9 in portrait)
              if (isFullScreen)
                Expanded(
                  child: _buildPlayer(initialPos),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildPlayer(initialPos),
                ),

              if (!isFullScreen)
                Expanded(
                  child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: Column(
                          children: [
                    // Video Title
                    Text(
                      _currentItem.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Metadata Card (UP, Quality, Size, Date)
                    Material(
                      color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            UserAvatar(
                              url: _currentItem.ownerFace,
                              size: 38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentItem.ownerName.isNotEmpty
                                        ? _currentItem.ownerName
                                        : '哔哩哔哩 UP主',
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '缓存于 $dateStr · ${VideoCacheService.formatBytes(_currentItem.totalBytes)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.offline_pin_rounded, size: 13, color: Colors.green),
                                  const SizedBox(width: 3),
                                  Text(
                                    _currentItem.qualityDesc.isNotEmpty ? _currentItem.qualityDesc : '本地',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Action Buttons Row (Listen, Online Detail, Delete)
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            icon: Icons.headphones_rounded,
                            label: '听视频',
                            isDark: isDark,
                            primaryColor: primaryColor,
                            onTap: _startListenMode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            icon: Icons.public_rounded,
                            label: '联网看详情',
                            isDark: isDark,
                            primaryColor: primaryColor,
                            onTap: _openOnlineDetail,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            icon: Icons.delete_outline_rounded,
                            label: '删除此集',
                            isDark: isDark,
                            primaryColor: Colors.redAccent,
                            isDestructive: true,
                            onTap: _deleteCurrentCache,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                        ],
                      ),
                    ),
                    ),
                    // Episodes Section (if multi-part or season) — Sliver 懒加载，避免一次性构建全部剧集
                    if (_cachedEpisodes.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '已缓存剧集 (共 ${_cachedEpisodes.length} 集)',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                                ),
                              ),
                              Text(
                                '点击直接切集',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        sliver: SliverList.separated(
                          itemCount: _cachedEpisodes.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                          final ep = _cachedEpisodes[i];
                          final isPlaying = ep.taskId == _currentItem.taskId;

                          return Material(
                            color: isPlaying
                                ? primaryColor.withValues(alpha: 0.12)
                                : (isDark ? AppTheme.cardDark : AppTheme.cardLight),
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: isPlaying ? null : () => _switchEpisode(ep),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isPlaying
                                        ? primaryColor
                                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                    width: isPlaying ? 1.2 : 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    if (isPlaying) ...[
                                      Icon(Icons.play_circle_fill_rounded, color: primaryColor, size: 18),
                                      const SizedBox(width: 8),
                                    ] else ...[
                                      Container(
                                        width: 22,
                                        height: 22,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          '${ep.pageIndex + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ep.pageTitle.isNotEmpty ? ep.pageTitle : '第 ${ep.pageIndex + 1} 集',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                              color: isPlaying
                                                  ? (isDark ? AppTheme.textMainDark : primaryColor)
                                                  : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${Formatters.formatDuration(ep.duration)} · ${VideoCacheService.formatBytes(ep.totalBytes)} · ${ep.qualityDesc}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isPlaying)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '播放中',
                                          style: TextStyle(
                                            color: onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primaryColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isDestructive ? Colors.redAccent : primaryColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDestructive
                      ? Colors.redAccent
                      : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(Duration? initialPos) {
    if (_playUrlInfo != null) {
      return BiliVideoPlayer(
        key: _playerKey,
        videoKey: '${_currentItem.bvid}_${_currentItem.cid}',
        playUrlInfo: _playUrlInfo!,
        localFilePath: _currentItem.localVideoPath,
        danmakus: _danmakus,
        title: _currentItem.pageTitle.isNotEmpty && _currentItem.pageCount > 1
            ? '${_currentItem.title} · ${_currentItem.pageTitle}'
            : _currentItem.title,
        initialPosition: initialPos,
        // 切集时 _playUrlInfo 先置空，旧播放器卸载前的回调不再写入，
        // 避免旧分P的进度残留到新分P
        onProgressUpdate: (pos, _) {
          if (_playUrlInfo != null) _lastPlayerPosition = pos;
        },
        onFullScreenChanged: (full) {
          setState(() => _isPlayerFullScreen = full);
        },
        onListenMode: _startListenMode,
      );
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
