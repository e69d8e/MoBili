import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/video_model.dart';
import '../../providers/home_provider.dart';
import '../../theme/app_theme.dart';
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
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> refreshAndScrollToTop() async {
    final curIndex = _tabController.index;
    if (curIndex == 0) {
      await _rcmdKey.currentState?.refreshAndScrollToTop();
    } else if (curIndex == 1) {
      await _popularKey.currentState?.refreshAndScrollToTop();
    } else if (curIndex == 2) {
      await _rankingKey.currentState?.refreshAndScrollToTop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textMainLight,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 10),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.surfaceDark
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: isDark
                            ? AppTheme.textHintDark
                            : AppTheme.textHintLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '搜索视频、UP主、图文...',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? AppTheme.textHintDark
                              : AppTheme.textHintLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Watch Later entry icon
            IconButton(
              icon: const Icon(Icons.watch_later_outlined, size: 21),
              tooltip: '稍后观看',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
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
                unselectedLabelColor: isDark
                    ? AppTheme.textSubDark
                    : AppTheme.textSubLight,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                dividerColor: Colors.transparent,
                dividerHeight: 0,
                onTap: (idx) {
                  context.read<HomeProvider>().setTab(idx);
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

  Future<void> refreshAndScrollToTop() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else {
      if (!mounted) return;
      final hp = context.read<HomeProvider>();
      await hp.loadRecommendFeed(isRefresh: true);
      if (mounted) AppToast.show(context, '已刷新');
    }
  }

  Future<void> _handleRefresh() async {
    final homeProvider = context.read<HomeProvider>();
    await homeProvider.loadRecommendFeed(isRefresh: true);
    if (mounted) {
      AppToast.show(context, '已刷新');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLoading = context.select<HomeProvider, bool>((p) => p.rcmdLoading);
    final isLoadingMore = context.select<HomeProvider, bool>(
      (p) => p.rcmdLoadingMore,
    );
    final videos = context.select<HomeProvider, List<VideoItem>>(
      (p) => p.recommendVideos,
    );

    if (isLoading && videos.isEmpty) {
      return const VideoGridSkeleton();
    }

    if (videos.isEmpty) {
      return ErrorView(
        onRetry: () =>
            context.read<HomeProvider>().loadRecommendFeed(isRefresh: true),
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
      scrollController: _scrollController,
      videos: videos,
      isLoadingMore: isLoadingMore,
      onRefresh: _handleRefresh,
      onLoadMore: () => context.read<HomeProvider>().loadMoreRecommend(),
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

  Future<void> refreshAndScrollToTop() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else {
      await _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    final homeProvider = context.read<HomeProvider>();
    await homeProvider.loadPopularVideos(isRefresh: true);
    if (mounted) {
      AppToast.show(context, '已刷新');
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
    final videos = context.select<HomeProvider, List<VideoItem>>(
      (p) => p.popularVideos,
    );

    if (isLoading && videos.isEmpty) {
      return const VideoGridSkeleton();
    }

    if (videos.isEmpty) {
      return ErrorView(
        onRetry: () =>
            context.read<HomeProvider>().loadPopularVideos(isRefresh: true),
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
      scrollController: _scrollController,
      videos: videos,
      isLoadingMore: isLoadingMore,
      onRefresh: _handleRefresh,
      onLoadMore: () => context.read<HomeProvider>().loadMorePopular(),
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

  Future<void> refreshAndScrollToTop() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else {
      await _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    final homeProvider = context.read<HomeProvider>();
    await homeProvider.loadRankingVideos();
    if (mounted) {
      AppToast.show(context, '已刷新');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLoading = context.select<HomeProvider, bool>(
      (p) => p.rankingLoading,
    );
    final videos = context.select<HomeProvider, List<VideoItem>>(
      (p) => p.rankingVideos,
    );

    if (isLoading && videos.isEmpty) {
      return const VideoGridSkeleton();
    }

    if (videos.isEmpty) {
      return ErrorView(
        onRetry: () => context.read<HomeProvider>().loadRankingVideos(),
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
      scrollController: _scrollController,
      videos: videos,
      isLoadingMore: false,
      onRefresh: _handleRefresh,
      onLoadMore: null,
    );
  }
}

// ==========================================
// 通用视频网格展示组件
// ==========================================
class _CommonVideoGrid extends StatelessWidget {
  final Key? refreshKey;
  final ScrollController scrollController;
  final List<VideoItem> videos;
  final bool isLoadingMore;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoadMore;

  const _CommonVideoGrid({
    this.refreshKey,
    required this.scrollController,
    required this.videos,
    required this.isLoadingMore,
    required this.onRefresh,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveGridConfig.calculateCrossAxisCount(
      context,
    );
    final childAspectRatio = ResponsiveGridConfig.calculateChildAspectRatio(
      context,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (onLoadMore != null &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 300) {
          onLoadMore!();
        }
        return false;
      },
      child: RefreshIndicator(
        key: refreshKey,
        color: Theme.of(context).colorScheme.primary,
        onRefresh: onRefresh,
        child: GridView.builder(
          controller: scrollController,
          cacheExtent: 600.0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: videos.length + (isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, idx) {
            if (idx == videos.length) {
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            }
            return RepaintBoundary(child: VideoCard(video: videos[idx]));
          },
        ),
      ),
    );
  }
}
