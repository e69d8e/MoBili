import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../models/video_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/state_views.dart';
import '../../widgets/video_card.dart';
import '../video/video_detail_screen.dart';
import 'login_dialog.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  static const int _pageSize = 20;

  List<FavFolder> _folders = [];
  FavFolder? _selectedFolder;
  List<VideoItem> _folderVideos = [];
  bool _isLoading = true;
  bool _isVideoLoading = false;
  String? _error;
  int _videoPn = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final mid = context.read<AuthProvider>().userInfo.mid;
    if (mid > 0) {
      try {
        final folders = await UserApiService().getUserFavFolders(mid);
        if (!mounted) return;
        setState(() {
          _folders = folders;
          _isLoading = false;
        });
        if (folders.isNotEmpty) {
          await _selectFolder(folders.first);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = '收藏夹加载失败，请检查网络或重新登录';
          _folders = [];
        });
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFolder(FavFolder folder, {bool isRefresh = false}) async {
    setState(() {
      if (!isRefresh) _selectedFolder = folder;
      _isVideoLoading = !isRefresh;
      _error = null;
      if (!isRefresh) {
        _folderVideos = [];
        _videoPn = 1;
        _hasMore = true;
      }
    });

    try {
      final videos = await UserApiService().getFavFolderVideos(
        _selectedFolder!.id,
        pn: 1,
        ps: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _folderVideos = videos;
        _videoPn = 1;
        _isVideoLoading = false;
        _hasMore = videos.length >= _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVideoLoading = false;
        _error = '视频加载失败，请检查网络后重试';
        _folderVideos = [];
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _selectedFolder == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _videoPn + 1;
      final videos = await UserApiService().getFavFolderVideos(
        _selectedFolder!.id,
        pn: nextPage,
        ps: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _videoPn = nextPage;
        _folderVideos.addAll(videos);
        _hasMore = videos.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _handleRefresh() async {
    if (_selectedFolder == null) {
      await _loadFolders();
      return;
    }
    try {
      final videos = await UserApiService().getFavFolderVideos(
        _selectedFolder!.id,
        pn: 1,
        ps: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _folderVideos = videos;
        _videoPn = 1;
        _hasMore = videos.length >= _pageSize;
        _error = null;
      });
    } catch (_) {}
  }

  void _playAll() {
    if (_folderVideos.isEmpty) return;
    final playlist = _folderVideos.map((v) {
      return WatchLaterItem(
        aid: v.aid,
        bvid: v.bvid,
        cid: v.cid,
        title: v.title,
        pic: v.pic,
        ownerName: v.owner.name,
        ownerFace: v.owner.face,
        ownerMid: v.owner.mid,
        duration: v.duration,
        pubdate: v.pubdate,
        addAt: 0,
        progress: 0,
      );
    }).toList();
    final first = _folderVideos.first;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => VideoDetailScreen(
          bvid: first.bvid,
          initialVideo: first,
          watchLaterList: playlist,
          initialWatchLaterIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = context.watch<AuthProvider>().isLogin;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          if (_folderVideos.isNotEmpty)
            TextButton.icon(
              onPressed: _playAll,
              icon: const Icon(Icons.playlist_play_rounded, size: 20),
              label: const Text('全部播放'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ResponsiveMaxConstraint(
        child: !isLogin
            ? EmptyView(
                message: '登录后即可查看收藏夹与收藏视频',
                icon: Icons.star_border_rounded,
                retryText: '立即登录',
                onRetry: () {
                  showDialog(
                    context: context,
                    builder: (_) => const LoginDialog(),
                  ).then((_) => _loadFolders());
                },
              )
            : _isLoading
            ? const LoadingView(message: '正在加载收藏夹...')
            : _error != null && _folders.isEmpty
            ? ErrorView(message: _error!, onRetry: _loadFolders)
            : _folders.isEmpty
            ? EmptyView(
                message: '暂无收藏夹',
                icon: Icons.star_border_rounded,
                retryText: '刷新重试',
                onRetry: _loadFolders,
              )
            : Column(
                children: [
                  // Folders Selector Bar
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      itemCount: _folders.length,
                      separatorBuilder: (ctx, _) => const SizedBox(width: 8.0),
                      itemBuilder: (ctx, idx) {
                        final folder = _folders[idx];
                        final isSelected = _selectedFolder?.id == folder.id;
                        return ChoiceChip(
                          label: Text('${folder.title} (${folder.mediaCount})'),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? onPrimary
                                : context.colors.textSub,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          backgroundColor: context.colors.fill,
                          side: BorderSide.none,
                          onSelected: (_) => _selectFolder(folder),
                        );
                      },
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: context.colors.divider,
                  ),
                  // Videos Grid
                  Expanded(
                    child: _isVideoLoading
                        ? const VideoGridSkeleton(padding: EdgeInsets.all(12.0))
                        : _error != null && _folderVideos.isEmpty
                        ? ErrorView(
                            message: _error!,
                            onRetry: () => _selectFolder(_selectedFolder!),
                          )
                        : RefreshIndicator(
                            color: primaryColor,
                            onRefresh: _handleRefresh,
                            child: _folderVideos.isEmpty
                                ? ListView(
                                    // AlwaysScrollable 让空列表也能下拉刷新
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: const [
                                      SizedBox(height: 120),
                                      EmptyView(message: '该收藏夹暂无视频'),
                                    ],
                                  )
                                : NotificationListener<ScrollNotification>(
                                    onNotification: (scrollInfo) {
                                      if (scrollInfo.metrics.maxScrollExtent >
                                              0 &&
                                          scrollInfo.metrics.pixels >=
                                              scrollInfo
                                                      .metrics
                                                      .maxScrollExtent -
                                                  300) {
                                        _loadMore();
                                      }
                                      return false;
                                    },
                                    child: CustomScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      scrollCacheExtent:
                                          ScrollCacheExtent.pixels(500.0),
                                      slivers: [
                                        SliverLayoutBuilder(
                                          builder: (ctx, sliverConstraints) {
                                            final w = sliverConstraints
                                                .crossAxisExtent;
                                            final cols = ResponsiveGridConfig
                                                .calculateCrossAxisCountForWidth(
                                                  w,
                                                );
                                            final extent = ResponsiveGridConfig
                                                .calculateMainAxisExtent(
                                                  ctx,
                                                  availableWidth: w,
                                                  crossAxisCount: cols,
                                                );
                                            return SliverPadding(
                                              padding: const EdgeInsets.all(
                                                12.0,
                                              ),
                                              sliver: SliverGrid.builder(
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: cols,
                                                      mainAxisExtent: extent,
                                                      crossAxisSpacing: 10,
                                                      mainAxisSpacing: 10,
                                                    ),
                                                itemCount:
                                                    _folderVideos.length,
                                                itemBuilder: (itemCtx, idx) {
                                                  return RepaintBoundary(
                                                    child: VideoCard(
                                                      video:
                                                          _folderVideos[idx],
                                                      showViewCount: false,
                                                      heroTag:
                                                          'fav_${_folderVideos[idx].bvid}_$idx',
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        if (_isLoadingMore || !_hasMore)
                                          SliverToBoxAdapter(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    12.0,
                                                    4.0,
                                                    12.0,
                                                    24.0,
                                                  ),
                                              child: Center(
                                                child: _isLoadingMore
                                                    ? SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  primaryColor,
                                                            ),
                                                      )
                                                    : Text(
                                                        '没有更多了',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: context
                                                              .colors
                                                              .textHint,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
