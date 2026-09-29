import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/user_model.dart';
import '../../models/video_model.dart';
import '../../services/api/user_api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/audio/mini_audio_player.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/video_card.dart';

class UpSpaceScreen extends StatefulWidget {
  final int mid;

  const UpSpaceScreen({super.key, required this.mid});

  @override
  State<UpSpaceScreen> createState() => _UpSpaceScreenState();
}

class _UpSpaceScreenState extends State<UpSpaceScreen> {
  UpSpaceInfo? _spaceInfo;
  List<VideoItem> _videos = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    final results = await Future.wait([
      UserApiService().getUpSpaceInfo(widget.mid),
      UserApiService().getUpSpaceVideos(widget.mid, pn: 1),
    ]);
    final info = results[0] as UpSpaceInfo?;
    final videos = results[1] as List<VideoItem>;

    if (mounted) {
      setState(() {
        _spaceInfo = info;
        _isFollowing = info?.isFollowing ?? false;
        _videos = videos;
        _page = 1;
        // 空页视为到底
        _hasMore = videos.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final more =
        await UserApiService().getUpSpaceVideos(widget.mid, pn: _page + 1);

    if (mounted) {
      setState(() {
        // 空页视为到底，页码不再前进
        if (more.isNotEmpty) {
          _videos.addAll(more);
          _page++;
        }
        _hasMore = more.isNotEmpty;
        _isLoadingMore = false;
      });
    }
  }

  void _toggleFollow() async {
    setState(() => _isFollowing = !_isFollowing);
    final ok = await UserApiService().modifyRelation(
      widget.mid,
      act: _isFollowing ? 1 : 2,
    );
    if (!ok && mounted) {
      setState(() => _isFollowing = !_isFollowing);
      AppToast.show(context, '操作失败，请先登录', icon: Icons.info_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      bottomNavigationBar: const MiniAudioPlayer(),
      body: _isLoading
          ? const VideoGridSkeleton()
          : _spaceInfo == null
          ? ErrorView(onRetry: _loadData)
          : NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
                  _loadMore();
                }
                return false;
              },
              child: RefreshIndicator(
                color: primaryColor,
                onRefresh: () => _loadData(isRefresh: true),
                child: CustomScrollView(
                scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
                slivers: [
                  // App Bar without banner image
                  SliverAppBar(
                    pinned: true,
                    title: Text(
                      _spaceInfo!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    centerTitle: false,
                  ),

                  // UP Info Header Card
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          width: 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserAvatar(
                                url: _spaceInfo!.face,
                                size: 56,
                                level: _spaceInfo!.level,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _spaceInfo!.name,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${Formatters.formatCount(_spaceInfo!.fans)} 粉丝',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppTheme.textHintDark
                                                : AppTheme.textHintLight,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${Formatters.formatCount(_spaceInfo!.attention)} 关注',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppTheme.textHintDark
                                                : AppTheme.textHintLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _toggleFollow,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? (isDark
                                            ? AppTheme.surfaceDark
                                            : AppTheme.surfaceLight)
                                      : primaryColor,
                                  foregroundColor: _isFollowing
                                      ? (isDark
                                            ? AppTheme.textSubDark
                                            : AppTheme.textSubLight)
                                      : Theme.of(context).colorScheme.onPrimary,
                                  elevation: 0,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: Icon(
                                  _isFollowing ? Icons.check : Icons.add,
                                  size: 15,
                                ),
                                label: Text(
                                  _isFollowing ? '已关注' : '关注',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_spaceInfo!.sign.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _spaceInfo!.sign,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? AppTheme.textSubDark
                                    : AppTheme.textSubLight,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        '投稿视频 (${_videos.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Video Grid
                  if (_videos.isEmpty)
                    const SliverFillRemaining(
                      child: EmptyView(message: '该UP主暂无投稿视频'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              ResponsiveGridConfig.calculateCrossAxisCount(
                                context,
                              ),
                          childAspectRatio:
                              ResponsiveGridConfig.calculateChildAspectRatio(
                                context,
                              ),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, idx) => RepaintBoundary(
                            child: VideoCard(video: _videos[idx]),
                          ),
                          childCount: _videos.length,
                        ),
                      ),
                    ),

                  if (_isLoadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ),
            ),
    );
  }
}
