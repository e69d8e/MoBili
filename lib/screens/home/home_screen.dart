import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../models/video_model.dart';
import '../../providers/home_provider.dart';
import '../../providers/search_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_routes.dart';
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
  final GlobalKey<NestedScrollViewState> _nestedKey =
      GlobalKey<NestedScrollViewState>();
  final ScrollController _outerScrollController = ScrollController();

  // 上一次稳定停留的分区，用于识别「重复点击当前 Tab」
  int _selectedTabIndex = 0;

  // 顶部搜索胶囊热词轮播
  int _hotHintIndex = 0;
  Timer? _hotHintTimer;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sp = context.read<SearchProvider>();
      if (sp.hotSearches.isEmpty) {
        sp.loadHotSearches().then((_) {
          if (mounted) _ensureHotHintTimer();
        });
      } else {
        _ensureHotHintTimer();
      }
    });
  }

  void _ensureHotHintTimer() {
    if (_hotHintTimer != null) return;
    final hotCount = context.read<SearchProvider>().hotSearches.length;
    if (hotCount <= 1) return;
    _hotHintTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final list = context.read<SearchProvider>().hotSearches;
      if (list.isEmpty) return;
      setState(() {
        _hotHintIndex = (_hotHintIndex + 1) % list.length;
      });
    });
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
    _hotHintTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  bool get _isNestedAtTop {
    final outerAtTop =
        !_outerScrollController.hasClients ||
        _outerScrollController.positions.every((pos) => pos.pixels <= 1);
    final inner = _nestedKey.currentState?.innerController;
    final innerAtTop =
        inner == null ||
        !inner.hasClients ||
        inner.positions.every((pos) => pos.pixels <= 1);
    return outerAtTop && innerAtTop;
  }

  Future<void> _scrollAllToTop() async {
    final inner = _nestedKey.currentState?.innerController;
    if (inner != null && inner.hasClients) {
      // NestedScrollView + TabBarView（KeepAlive）会使 innerController 同时挂载多个滚动视图，
      // 逐一取用已滚出顶部的首个 position 调用 animateTo，内部 Coordinator 会联动所有关联位置。
      for (final pos in inner.positions.toList()) {
        if (pos.pixels > 0) {
          await pos.animateTo(
            0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
          break;
        }
      }
    }
    if (!mounted) return;
    if (_outerScrollController.hasClients) {
      for (final pos in _outerScrollController.positions.toList()) {
        if (pos.pixels > 0) {
          await pos.animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
          break;
        }
      }
    }
  }

  /// 底部导航重复点击：官方客户端行为是「先回顶，已在顶部时再点才刷新」。
  Future<void> refreshAndScrollToTop() async {
    final atTop = _isNestedAtTop;
    await _scrollAllToTop();
    if (!atTop) return;
    final curIndex = _tabController.index;
    if (curIndex == 0) {
      await _rcmdKey.currentState?.triggerRefresh();
    } else if (curIndex == 1) {
      await _popularKey.currentState?.triggerRefresh();
    } else if (curIndex == 2) {
      await _rankingKey.currentState?.triggerRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final hotSearches = context.select<SearchProvider, List<String>>(
      (sp) => sp.hotSearches.map((e) => e.keyword).toList(growable: false),
    );
    final hintText = hotSearches.isNotEmpty
        ? '热搜: ${hotSearches[_hotHintIndex % hotSearches.length]}'
        : '搜索视频、UP主、图文...';

    return Scaffold(
      body: NestedScrollView(
        key: _nestedKey,
        controller: _outerScrollController,
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final tabHeight = math.max(42.0, 40.0 * textScale);
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                floating: true,
                snap: true,
                pinned: true,
                forceElevated: innerBoxIsScrolled,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                titleSpacing: AppSpacing.lg,
                title: Row(
                  children: [
                    Text(
                      '墨哩',
                      style: TextStyle(
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // 极简搜索胶囊：轮播热搜提示
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: '搜索：$hintText',
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              AppRoutes.page(const SearchScreen()),
                            );
                          },
                          borderRadius: AppRadius.of(AppRadius.pill),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 38),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.fill,
                                borderRadius: AppRadius.of(AppRadius.pill),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 16,
                                    color: context.colors.textHint,
                                  ),
                                  const SizedBox(width: 6.0),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 240),
                                      layoutBuilder: (currentChild, previousChildren) =>
                                          Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          ...previousChildren,
                                          ?currentChild,
                                        ],
                                      ),
                                      child: Text(
                                        hintText,
                                        key: ValueKey(hintText),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: AppTypography.body2,
                                          color: context.colors.textHint,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.watch_later_outlined, size: 21),
                      tooltip: '稍后观看',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      color: context.colors.textSub,
                      onPressed: () {
                        Navigator.of(context).push(
                          AppRoutes.page(const WatchLaterScreen()),
                        );
                      },
                    ),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(tabHeight + 2),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: context.colors.divider.withValues(alpha: 0.6),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: 248.0 * textScale.clamp(1.0, 1.4),
                      height: tabHeight,
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
                          fontSize: AppTypography.body1,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.normal,
                        ),
                        dividerColor: Colors.transparent,
                        dividerHeight: 0,
                        onTap: (idx) {
                          final hp = context.read<HomeProvider>();
                          final isReTap = _selectedTabIndex == idx;
                          hp.setTab(idx);
                          if (isReTap) _scrollAllToTop();
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
            ),
          ];
        },
        body: ScrollConfiguration(
          // NestedScrollView 的 innerController 会被 TabBarView 多个保活 Tab 共享，
          // 禁用自动桌面端 Scrollbar 以避免其内部访问单个 position 时触发 _positions.length == 1 断言。
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: TabBarView(
            controller: _tabController,
            children: [
              _RecommendFeedTab(key: _rcmdKey),
              _PopularVideosTab(key: _popularKey),
              _RankingVideosTab(key: _rankingKey),
            ],
          ),
        ),
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
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hp = context.read<HomeProvider>();
      if (hp.recommendVideos.isEmpty && !hp.rcmdLoading) {
        hp.loadRecommendFeed();
      }
    });
  }

  Future<void> triggerRefresh() async {
    if (_refreshKey.currentState != null) {
      await _refreshKey.currentState!.show();
    } else if (mounted) {
      await _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    final homeProvider = context.read<HomeProvider>();
    final ok = await homeProvider.loadRecommendFeed(isRefresh: true);
    if (!mounted) return;
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

    if ((isLoading && videos.isEmpty) || (!loaded && error == null)) {
      return const _SliverSkeletonWrapper();
    }

    if (videos.isEmpty) {
      return _FirstPageStateSliver(
        error: error,
        refreshKey: _refreshKey,
        onRefresh: _handleRefresh,
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
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
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hp = context.read<HomeProvider>();
      if (hp.popularVideos.isEmpty && !hp.popularLoading) {
        hp.loadPopularVideos();
      }
    });
  }

  Future<void> triggerRefresh() async {
    if (_refreshKey.currentState != null) {
      await _refreshKey.currentState!.show();
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

    if ((isLoading && videos.isEmpty) || (!loaded && error == null)) {
      return const _SliverSkeletonWrapper();
    }

    if (videos.isEmpty) {
      return _FirstPageStateSliver(
        error: error,
        refreshKey: _refreshKey,
        onRefresh: _handleRefresh,
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
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
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hp = context.read<HomeProvider>();
      if (hp.rankingVideos.isEmpty && !hp.rankingLoading) {
        hp.loadRankingVideos();
      }
    });
  }

  Future<void> triggerRefresh() async {
    if (_refreshKey.currentState != null) {
      await _refreshKey.currentState!.show();
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

    if ((isLoading && videos.isEmpty) || (!loaded && error == null)) {
      return const _SliverSkeletonWrapper();
    }

    if (videos.isEmpty) {
      return _FirstPageStateSliver(
        error: error,
        refreshKey: _refreshKey,
        onRefresh: _handleRefresh,
      );
    }

    return _CommonVideoGrid(
      refreshKey: _refreshKey,
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
// 通用空/错态与骨架容器（兼容 NestedScrollView OverlapInjector）
// ==========================================
class _SliverSkeletonWrapper extends StatelessWidget {
  const _SliverSkeletonWrapper();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        const SliverFillRemaining(
          child: ResponsiveMaxConstraint(
            child: VideoGridSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _FirstPageStateSliver extends StatelessWidget {
  final String? error;
  final GlobalKey<RefreshIndicatorState> refreshKey;
  final Future<void> Function() onRefresh;

  const _FirstPageStateSliver({
    required this.error,
    required this.refreshKey,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final child = error != null
        ? ErrorView(message: error!, onRetry: () => onRefresh())
        : EmptyView(message: '暂时没有内容，下拉刷新试试', onRetry: () => onRefresh());
    return RefreshIndicator(
      key: refreshKey,
      color: Theme.of(context).colorScheme.primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: child,
          ),
        ],
      ),
    );
  }
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
    final showFooter = isLoadingMore || !hasMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth
                .clamp(0.0, ResponsiveUtil.maxContentWidth);
            final horizontalInset =
                ((constraints.maxWidth - maxWidth) / 2).clamp(0.0, double.infinity);
            final crossAxisCount =
                ResponsiveGridConfig.calculateCrossAxisCountForWidth(maxWidth);
            final mainAxisExtent =
                ResponsiveGridConfig.calculateMainAxisExtent(
              context,
              availableWidth: maxWidth,
              crossAxisCount: crossAxisCount,
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
              slivers: [
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    12.0 + horizontalInset,
                    8.0,
                    12.0 + horizontalInset,
                    8.0,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: mainAxisExtent,
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
            );
          },
        ),
      ),
    );
  }
}
