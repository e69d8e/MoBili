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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: _isLoading
          ? const LoadingView(message: '正在加载收藏夹...')
          : _error != null && _folders.isEmpty
          ? ErrorView(message: _error!, onRetry: _loadFolders)
          : _folders.isEmpty
          ? const EmptyView(
              message: '暂无收藏夹或未登录',
              icon: Icons.star_border_rounded,
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
                      final primaryColor = Theme.of(context)
                          .colorScheme
                          .primary;
                      final onPrimary = Theme.of(context).colorScheme.onPrimary;
                      return ChoiceChip(
                        label: Text('${folder.title} (${folder.mediaCount})'),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? onPrimary
                              : (isDark ? Colors.white70 : Colors.black87),
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
                      ? ErrorView(message: _error!, onRetry: () => _selectFolder(_selectedFolder!))
                      : RefreshIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          onRefresh: _handleRefresh,
                          child: _folderVideos.isEmpty
                              ? ListView(
                                  // AlwaysScrollable 让空列表也能下拉刷新
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 120),
                                    EmptyView(message: '该收藏夹暂无视频'),
                                  ],
                                )
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (scrollInfo) {
                                    if (scrollInfo.metrics.pixels >=
                                        scrollInfo.metrics.maxScrollExtent - 300) {
                                      _loadMore();
                                    }
                                    return false;
                                  },
                                  child: GridView.builder(
                                    scrollCacheExtent: ScrollCacheExtent.pixels(500.0),
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(12.0),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
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
                                    itemCount: _folderVideos.length +
                                        ((_isLoadingMore || !_hasMore) ? 1 : 0),
                                    itemBuilder: (ctx, idx) {
                                      if (idx == _folderVideos.length) {
                                        if (_isLoadingMore) {
                                          return Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          );
                                        }
                                        return Center(
                                          child: Text(
                                            '没有更多了',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.colors.textHint,
                                            ),
                                          ),
                                        );
                                      }
                                      return RepaintBoundary(
                                        child: VideoCard(
                                          video: _folderVideos[idx],
                                          showViewCount: false,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                ),
              ],
            ),
    );
  }
}
