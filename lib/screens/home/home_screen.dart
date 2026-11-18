import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../models/video_model.dart';
import '../../providers/home_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/state_views.dart';
import '../../widgets/video_card.dart';
import '../profile/watch_later_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 上一次稳定停留的分区，用于识别「重复点击当前 Tab」
  int _selectedTabIndex = 0;

  final GlobalKey<_RecommendFeedTabState> _rcmdKey =
      GlobalKey<_RecommendFeedTabState>();
  final GlobalKey<_PopularVideosTabState> _popularKey =
      GlobalKey<_PopularVideosTabState>();
  final GlobalKey<_RankingVideosTabState> _rankingKey =
      GlobalKey<_RankingVideosTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final hp = context.read<HomeProvider>();
      hp.setTab(_tabController.index);
      _selectedTabIndex = _tabController.index;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 底部导航重复点击：官方客户端行为是「先回顶，已在顶部时再点才刷新」。
  Future<void> refreshAndScrollToTop() async {
    final curIndex = _tabController.index;
    if (curIndex == 0) {
      final tab = _rcmdKey.currentState;
      if (tab != null) await tab.onReTap(refresh: tab.isAtTop);
    } else if (curIndex == 1) {
      final tab = _popularKey.currentState;
      if (tab != null) await tab.onReTap(refresh: tab.isAtTop);
    } else if (curIndex == 2) {
      final tab = _rankingKey.currentState;
      if (tab != null) await tab.onReTap(refresh: tab.isAtTop);
    }
  }

  /// 顶栏「换一换」：显式刷新当前分区并回到顶部
  void refreshCurrentTab() {
    final index = _tabController.index;
    if (index == 0) {
      _rcmdKey.currentState?.onReTap(refresh: true);
    } else if (index == 1) {
      _popularKey.currentState?.onReTap(refresh: true);
    } else if (index == 2) {
      _rankingKey.currentState?.onReTap(refresh: true);
    }
  }

  /// 顶部 Tab 重复点击当前分区时回顶（不强制联网刷新）
  void _scrollTabToTop(int index) {
    if (index == 0) {
      _rcmdKey.currentState?.scrollToTop();
    } else if (index == 1) {
      _popularKey.currentState?.scrollToTop();
    } else if (index == 2) {
      _rankingKey.currentState?.scrollToTop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            // MoBili Logo / Wordmark
            Text(
              '墨哩',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.colors.textMain,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8.0),
            // Minimalist Search Bar Pill
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const SearchScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: context.colors.fill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: context.colors.textHint,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        '搜索视频、UP主、图文...',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 换一换：显式刷新当前分区（对齐官方客户端的显式刷新入口）
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: '换一换',
              padding: const EdgeInsets.all(4.0),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              color: context.colors.textSub,
              onPressed: refreshCurrentTab,
            ),
            // Watch Later entry icon
            IconButton(
              icon: const Icon(Icons.watch_later_outlined, size: 21),
              tooltip: '稍后观看',
              padding: const EdgeInsets.all(4.0),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              color: context.colors.textSub,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const WatchLaterScreen()),
                );
              },
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Center(
            child: SizedBox(
              width: 240,
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: primaryColor,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: primaryColor,
                unselectedLabelColor: context.colors.textSub,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                dividerColor: Colors.transparent,
                dividerHeight: 0,
                onTap: (idx) {
                  final hp = context.read<HomeProvider>();
                  final isReTap = _selectedTabIndex == idx;
                  hp.setTab(idx);
                  if (isReTap) _scrollTabToTop(idx);
                },
                tabs: const [
                  Tab(text: '推荐'),
                  Tab(text: '热门'),
                  Tab(text: '排行榜'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecommendFeedTab(key: _rcmdKey),
          _PopularVideosTab(key: _popularKey),
          _RankingVideosTab(key: _rankingKey),
        ],
      ),
    );
  }
}

// ==========================================
// 1. 推荐页面 Tab
// ==========================================
class _RecommendFeedTab extends StatefulWidget {
  const _RecommendFeedTab({super.key});

  @override
  State<_RecommendFeedTab> createState() => _RecommendFeedTabState();
}

class _RecommendFeedTabState extends State<_RecommendFeedTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hp = context.read<HomeProvider>();
      if (hp.recommendVideos.isEmpty && !hp.rcmdLoading) {
        hp.loadRecommendFeed();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get isAtTop =>
      !_scrollController.hasClients || _scrollController.offset <= 1;

  Future<void> scrollToTop() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// 重复点击当前分区：先回顶；已在顶部时才刷新
  Future<void> onReTap({required bool refresh}) async {
    await scrollToTop();
    if (!refresh) return;
    if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else if (mounted) {
      await _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    final homeProvider = context.read<HomeProvider>();
    final ok = await homeProvider.loadRecommendFeed(isRefresh: true);
    if (!mounted) return;
    // 成功时静默，避免打扰；失败才给出明确提示
    if (!ok) AppToast.show(context, '刷新失败，请检查网络');
  }

  Future<void> _loadMore() async {
    final ok = await context.read<HomeProvider>().loadMoreRecommend();
    if (!ok && mounted) {
      AppToast.show(context, '加载失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLoading = context.select<HomeProvider, bool>((p) => p.rcmdLoading);
    final isLoadingMore = context.select<HomeProvider, bool>(
      (p) => p.rcmdLoadingMore,
    );
    final hasMore = context.select<HomeProvider, bool>((p) => p.rcmdHasMore);
    final loaded = context.select<HomeProvider, bool>((p) => p.rcmdLoaded);
    final error = context.select<HomeProvider, String?>((p) => p.rcmdError);
    final videos = context.select<HomeProvider, List<VideoItem>>(
      (p) => p.recommendVideos,
    );

    if (isLoading && videos.isEmpty) {
      return const VideoGridSkeleton();
    }

    if (videos.isEmpty) {
      return _buildFirstPageState(
        error: error,
        loaded: loaded,
        refreshKey: _refreshKey,
        onRefresh: _handleRefresh,
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
      scrollController: _scrollController,
      videos: videos,
      isLoadingMore: isLoadingMore,
      hasMore: hasMore,
      onRefresh: _handleRefresh,
      onLoadMore: _loadMore,
      onNotInterested: (video) => _hideVideo(context, video),
      heroTagPrefix: 'home_rcmd',
    );
  }
}

// ==========================================
// 2. 热门页面 Tab
// ==========================================
class _PopularVideosTab extends StatefulWidget {
  const _PopularVideosTab({super.key});

  @override
  State<_PopularVideosTab> createState() => _PopularVideosTabState();
}

class _PopularVideosTabState extends State<_PopularVideosTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hp = context.read<HomeProvider>();
      if (hp.popularVideos.isEmpty && !hp.popularLoading) {
        hp.loadPopularVideos();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get isAtTop =>
      !_scrollController.hasClients || _scrollController.offset <= 1;

  Future<void> scrollToTop() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// 重复点击当前分区：先回顶；已在顶部时才刷新
  Future<void> onReTap({required bool refresh}) async {
    await scrollToTop();
    if (!refresh) return;
    if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else if (mounted) {
      await _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    final homeProvider = context.read<HomeProvider>();
    final ok = await homeProvider.loadPopularVideos(isRefresh: true);
    if (!mounted) return;
    if (!ok) AppToast.show(context, '刷新失败，请检查网络');
  }

  Future<void> _loadMore() async {
    final ok = await context.read<HomeProvider>().loadMorePopular();
    if (!ok && mounted) {
      AppToast.show(context, '加载失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLoading = context.select<HomeProvider, bool>(
      (p) => p.popularLoading,
    );
    final isLoadingMore = context.select<HomeProvider, bool>(
      (p) => p.popularLoadingMore,
    );
    final hasMore = context.select<HomeProvider, bool>((p) => p.popularHasMore);
    final loaded = context.select<HomeProvider, bool>((p) => p.popularLoaded);
    final error = context.select<HomeProvider, String?>((p) => p.popularError);
    final videos = context.select<HomeProvider, List<VideoItem>>(
      (p) => p.popularVideos,
    );

    if (isLoading && videos.isEmpty) {
      return const VideoGridSkeleton();
    }

    if (videos.isEmpty) {
      return _buildFirstPageState(
        error: error,
        loaded: loaded,
        refreshKey: _refreshKey,
        onRefresh: _handleRefresh,
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
      scrollController: _scrollController,
      videos: videos,
      isLoadingMore: isLoadingMore,
      hasMore: hasMore,
      onRefresh: _handleRefresh,
      onLoadMore: _loadMore,
      onNotInterested: (video) => _hideVideo(context, video),
      heroTagPrefix: 'home_popular',
    );
  }
}

// ==========================================
// 3. 排行榜页面 Tab
// ==========================================
class _RankingVideosTab extends StatefulWidget {
  const _RankingVideosTab({super.key});

  @override
  State<_RankingVideosTab> createState() => _RankingVideosTabState();
}

class _RankingVideosTabState extends State<_RankingVideosTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hp = context.read<HomeProvider>();
      if (hp.rankingVideos.isEmpty && !hp.rankingLoading) {
        hp.loadRankingVideos();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get isAtTop =>
      !_scrollController.hasClients || _scrollController.offset <= 1;

  Future<void> scrollToTop() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// 重复点击当前分区：先回顶；已在顶部时才刷新
  Future<void> onReTap({required bool refresh}) async {
    await scrollToTop();
    if (!refresh) return;
    if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else if (mounted) {
      await _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    final homeProvider = context.read<HomeProvider>();
    final ok = await homeProvider.loadRankingVideos();
    if (!mounted) return;
    if (!ok) AppToast.show(context, '刷新失败，请检查网络');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLoading = context.select<HomeProvider, bool>(
      (p) => p.rankingLoading,
    );
    final loaded = context.select<HomeProvider, bool>((p) => p.rankingLoaded);
    final error = context.select<HomeProvider, String?>((p) => p.rankingError);
    final videos = context.select<HomeProvider, List<VideoItem>>(
      (p) => p.rankingVideos,
    );

    if (isLoading && videos.isEmpty) {
      return const VideoGridSkeleton();
    }

    if (videos.isEmpty) {
      return _buildFirstPageState(
        error: error,
        loaded: loaded,
        refreshKey: _refreshKey,
        onRefresh: _handleRefresh,
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
      scrollController: _scrollController,
      videos: videos,
      isLoadingMore: false,
      onRefresh: _handleRefresh,
      onLoadMore: null,
      onNotInterested: (video) => _hideVideo(context, video),
      heroTagPrefix: 'home_rank',
    );
  }
}

// ==========================================
// 通用空/错态与「不感兴趣」
// ==========================================

/// 首屏占位需要区分三种情况：加载失败要可重试、成功但确实没有内容要说明、
/// 请求尚未发出时保持骨架占位（避免首帧闪出「加载失败」）。
Widget _buildFirstPageState({
  required String? error,
  required bool loaded,
  required GlobalKey<RefreshIndicatorState> refreshKey,
  required Future<void> Function() onRefresh,
}) {
  if (!loaded && error == null) return const VideoGridSkeleton();

  // 空态/错态同样支持下拉刷新，避免只能依赖按钮重试
  final child = error != null
      ? ErrorView(message: error, onRetry: () => onRefresh())
      : EmptyView(message: '暂时没有内容，下拉刷新试试', onRetry: () => onRefresh());
  return LayoutBuilder(
    builder: (context, constraints) {
      // 让内容至少铺满可视高度，居中提示才不会贴在顶部
      final content = constraints.maxHeight.isFinite
          ? SizedBox(height: constraints.maxHeight, child: child)
          : child;
      return RefreshIndicator(
        key: refreshKey,
        color: Theme.of(context).colorScheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: content,
        ),
      );
    },
  );
}

void _hideVideo(BuildContext context, VideoItem video) {
  context.read<HomeProvider>().hideVideo(video.bvid);
  AppToast.show(context, '将减少此类内容推荐', icon: Icons.visibility_off_outlined);
}

// ==========================================
// 通用视频网格展示组件
// ==========================================
class _CommonVideoGrid extends StatelessWidget {
  final Key? refreshKey;
  final ScrollController scrollController;
  final List<VideoItem> videos;
  final bool isLoadingMore;
  final bool hasMore;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoadMore;
  final void Function(VideoItem video)? onNotInterested;

  /// 共享元素 tag 前缀：推荐/热门/排行榜各自独立，避免 TabBarView 预构建
  /// 相邻页时同 bvid 的卡片产生重复 Hero tag
  final String heroTagPrefix;

  const _CommonVideoGrid({
    this.refreshKey,
    required this.scrollController,
    required this.videos,
    required this.isLoadingMore,
    this.hasMore = true,
    required this.onRefresh,
    this.onLoadMore,
    this.onNotInterested,
    required this.heroTagPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveGridConfig.calculateCrossAxisCount(
      context,
    );
    final childAspectRatio = ResponsiveGridConfig.calculateChildAspectRatio(
      context,
    );
    final showFooter = isLoadingMore || !hasMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        // 守卫：翻页在途 / 已到底 / 短列表无滚动区时不再触发，
        // 避免一次滚动发出多条通知导致重复翻页
        if (onLoadMore == null || isLoadingMore || !hasMore) return false;
        if (scrollInfo.metrics.maxScrollExtent <= 0) return false;
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 300) {
          onLoadMore!();
        }
        return false;
      },
      child: RefreshIndicator(
        key: refreshKey,
        color: Theme.of(context).colorScheme.primary,
        onRefresh: onRefresh,
        child: CustomScrollView(
          controller: scrollController,
          // 短列表也能下拉刷新，否则 RefreshIndicator 在某些平台不响应
          physics: const AlwaysScrollableScrollPhysics(),
          scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: videos.length,
                itemBuilder: (ctx, idx) {
                  final video = videos[idx];
                  return RepaintBoundary(
                    child: VideoCard(
                      video: video,
                      showMoreMenu: onNotInterested != null,
                      onNotInterested: onNotInterested == null
                          ? null
                          : () => onNotInterested!(video),
                      heroTag: '${heroTagPrefix}_${video.bvid}_$idx',
                    ),
                  );
                },
              ),
            ),
            // 底部提示独占整行，避免「没有更多了」被挤进单个网格单元
            if (showFooter)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: isLoadingMore
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : Text(
                            '没有更多了',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textHint,
                            ),
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
