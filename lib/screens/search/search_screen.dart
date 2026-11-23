import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/dynamic_model.dart';
import '../../models/search_model.dart';
import '../../providers/search_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_routes.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/video_card.dart';
import '../dynamic/dynamic_detail_screen.dart';
import '../up/up_space_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialKeyword;
  const SearchScreen({super.key, this.initialKeyword});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _textController;
  late final TabController _categoryTabController;
  final FocusNode _focusNode = FocusNode();
  bool _historyExpanded = false;

  static const List<({String key, String label})> _categories = [
    (key: 'video', label: '视频'),
    (key: 'user', label: 'UP主'),
    (key: 'article', label: '专栏'),
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialKeyword ?? '');
    _categoryTabController = TabController(length: _categories.length, vsync: this);
    _categoryTabController.addListener(_onCategoryTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sp = context.read<SearchProvider>();
      sp.init();
      if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
        sp.search(widget.initialKeyword!, order: 'totalrank', category: 'video');
      } else {
        // 全新进入搜索页时清理上一次残留结果，回到历史与热搜首页
        sp.resetSearch();
        _focusNode.requestFocus();
      }
    });
  }

  void _onCategoryTabChanged() {
    if (_categoryTabController.indexIsChanging) return;
    final catKey = _categories[_categoryTabController.index].key;
    final sp = context.read<SearchProvider>();
    if (sp.currentCategory != catKey) {
      sp.setCategory(catKey);
    }
  }

  @override
  void dispose() {
    _categoryTabController.removeListener(_onCategoryTabChanged);
    _categoryTabController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _doSearch(String keyword) {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    HapticFeedback.lightImpact();
    _textController.text = clean;
    _textController.selection = TextSelection.collapsed(offset: clean.length);
    _focusNode.unfocus();
    final catKey = _categories[_categoryTabController.index].key;
    context.read<SearchProvider>().search(
      clean,
      order: 'totalrank',
      category: catKey,
    );
  }

  void _openArticle(SearchArticleItem article) {
    if (article.id <= 0) return;
    final dynamicId = 'cv${article.id}';
    final initialItem = DynamicItem(
      id: dynamicId,
      type: 'DYNAMIC_TYPE_ARTICLE',
      title: article.title,
      author: DynamicAuthor(
        mid: article.mid,
        name: article.uname,
        face: '',
        pubTime: article.pubTime > 0
            ? Formatters.formatTime(article.pubTime)
            : '',
        pubAction: '投稿了专栏',
        pubTs: article.pubTime,
      ),
      text: article.desc,
      pictures: article.imageUrls
          .where((u) => u.isNotEmpty)
          .map(DynamicPicture.fromUrl)
          .toList(),
      stat: DynamicStat(
        commentCount: article.reply,
        likeCount: article.like,
      ),
      commentId: article.id,
      commentType: 12,
    );
    Navigator.of(context).push(
      AppRoutes.page(
        DynamicDetailScreen(
          dynamicId: dynamicId,
          initialItem: initialItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Container(
            margin: const EdgeInsets.only(right: 4.0),
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            decoration: BoxDecoration(
              color: context.colors.fill,
              borderRadius: AppRadius.of(AppRadius.pill),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus:
                  widget.initialKeyword == null || widget.initialKeyword!.isEmpty,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: AppTypography.body),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                hintText: '搜索视频、UP主、专栏...',
                hintStyle: TextStyle(
                  color: context.colors.textHint,
                  fontSize: AppTypography.body2,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: context.colors.textHint,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                  maxWidth: 36,
                  maxHeight: 36,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: '清空搜索词',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _textController.clear();
                        searchProvider.resetSearch();
                        _focusNode.requestFocus();
                      },
                    );
                  },
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                searchProvider.fetchSuggestions(val);
              },
              onSubmitted: _doSearch,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _doSearch(_textController.text),
            child: Text(
              '搜索',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: AppTypography.body,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
        ],
      ),
      body: ResponsiveMaxConstraint(child: _buildBody(searchProvider)),
    );
  }

  Widget _buildBody(SearchProvider sp) {
    // 1. 输入联想词
    if (_textController.text.isNotEmpty &&
        sp.suggestions.isNotEmpty &&
        _focusNode.hasFocus) {
      final query = _textController.text.trim();
      final primaryColor = Theme.of(context).colorScheme.primary;
      return ListView.separated(
        primary: false,
        itemCount: sp.suggestions.length,
        separatorBuilder: (ctx, _) => Divider(
          height: 1,
          thickness: 0.5,
          indent: 38,
          color: context.colors.divider,
        ),
        itemBuilder: (ctx, idx) {
          final item = sp.suggestions[idx];
          return ListTile(
            leading: Icon(
              Icons.search_rounded,
              size: 16,
              color: context.colors.textHint,
            ),
            title: _buildHighlightedSuggestion(item.value, query, primaryColor),
            trailing: IconButton(
              icon: Icon(
                Icons.north_west_rounded,
                size: 16,
                color: context.colors.textHint,
              ),
              tooltip: '填入搜索框',
              onPressed: () {
                _textController.text = item.value;
                _textController.selection = TextSelection.collapsed(
                  offset: item.value.length,
                );
                sp.fetchSuggestions(item.value);
              },
            ),
            dense: true,
            onTap: () => _doSearch(item.value),
          );
        },
      );
    }

    // 2. 搜索结果 TabBarView
    if (sp.hasSearched) {
      return _buildSearchResults(sp);
    }

    // 3. 默认：历史搜索 + 热搜榜
    return _buildHistoryAndHot(sp);
  }

  Widget _buildHighlightedSuggestion(
    String text,
    String query,
    Color primaryColor,
  ) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: AppTypography.body,
          color: context.colors.textMain,
        ),
      );
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIdx = lowerText.indexOf(lowerQuery);
    if (matchIdx < 0) {
      return Text(
        text,
        style: TextStyle(
          fontSize: AppTypography.body,
          color: context.colors.textMain,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: AppTypography.body,
          color: context.colors.textMain,
        ),
        children: [
          if (matchIdx > 0) TextSpan(text: text.substring(0, matchIdx)),
          TextSpan(
            text: text.substring(matchIdx, matchIdx + query.length),
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (matchIdx + query.length < text.length)
            TextSpan(text: text.substring(matchIdx + query.length)),
        ],
      ),
    );
  }

  Widget _buildHistoryAndHot(SearchProvider sp) {
    final visibleHistory = _historyExpanded || sp.history.length <= 8
        ? sp.history
        : sp.history.take(8).toList();

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索历史
          if (sp.history.isNotEmpty) ...[
            Row(
              children: [
                const Text(
                  '搜索历史',
                  style: TextStyle(
                    fontSize: AppTypography.body2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (sp.history.length > 8)
                  TextButton(
                    onPressed: () =>
                        setState(() => _historyExpanded = !_historyExpanded),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _historyExpanded ? '收起' : '展开全部',
                      style: TextStyle(
                        fontSize: AppTypography.footnote,
                        color: context.colors.textSub,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  tooltip: '清空搜索历史',
                  color: context.colors.textHint,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => sp.clearHistory(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleHistory.map((h) {
                return Material(
                  color: context.colors.fill,
                  borderRadius: AppRadius.of(AppRadius.pill),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _doSearch(h),
                    onLongPress: () {
                      HapticFeedback.selectionClick();
                      sp.removeHistoryItem(h);
                      AppToast.show(context, '已移除历史记录');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 5.0,
                      ),
                      child: Text(
                        h,
                        style: TextStyle(
                          fontSize: AppTypography.footnote,
                          color: context.colors.textSub,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // 热搜榜
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: context.colors.rankFirst,
              ),
              const SizedBox(width: 4),
              const Text(
                '热搜榜',
                style: TextStyle(
                  fontSize: AppTypography.body2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (sp.hotSearches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: UserListSkeleton(itemCount: 5, shrinkWrap: true),
            )
          else
            Column(
              children: sp.hotSearches.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final rank = idx + 1;
                Color rankColor = context.colors.textHint;
                Color? rankBadgeBg;
                if (rank == 1) {
                  rankColor = context.colors.rankFirst;
                  rankBadgeBg = rankColor.withValues(alpha: 0.15);
                } else if (rank == 2) {
                  rankColor = context.colors.rankSecond;
                  rankBadgeBg = rankColor.withValues(alpha: 0.15);
                } else if (rank == 3) {
                  rankColor = context.colors.rankThird;
                  rankBadgeBg = rankColor.withValues(alpha: 0.15);
                }

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rankBadgeBg ?? Colors.transparent,
                      borderRadius: AppRadius.of(AppRadius.sm),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: AppTypography.body2,
                        fontWeight: FontWeight.w600,
                        color: rankColor,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.keyword,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: AppTypography.body2),
                        ),
                      ),
                      if (item.icon.isNotEmpty) ...[
                        const SizedBox(width: 4.0),
                        NetworkImageView(url: item.icon, width: 14, height: 14),
                      ],
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _doSearch(item.keyword);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(SearchProvider sp) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final targetIdx = _categories.indexWhere((c) => c.key == sp.currentCategory);
    if (targetIdx >= 0 &&
        targetIdx != _categoryTabController.index &&
        !_categoryTabController.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryTabController.index != targetIdx) {
          _categoryTabController.animateTo(targetIdx);
        }
      });
    }

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final categoryTabHeight = math.max(40.0, 38.0 * textScale);

    return Column(
      children: [
        // 分类 TabBar：支持点击切换与下方左右滑动同步
        Container(
          height: categoryTabHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: TabBar(
            controller: _categoryTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: primaryColor,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: primaryColor,
            unselectedLabelColor: context.colors.textSub,
            labelStyle: const TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.normal,
            ),
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            onTap: (idx) {
              final catKey = _categories[idx].key;
              if (sp.currentCategory != catKey) {
                sp.setCategory(catKey);
              }
            },
            tabs: _categories.map((c) => Tab(text: c.label)).toList(),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: context.colors.divider),

        Expanded(
          child: TabBarView(
            controller: _categoryTabController,
            children: [
              _buildVideoResultsTab(sp),
              _buildUserResultsTab(sp),
              _buildArticleResultsTab(sp),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoResultsTab(SearchProvider sp) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final sortBarHeight = math.max(38.0, 34.0 * textScale);

    return Column(
      children: [
        // 横向可滚动排序胶囊，兼容大字体不溢出
        SizedBox(
          height: sortBarHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            children: [
              _buildSortChip('综合排序', 'totalrank', sp),
              const SizedBox(width: 6.0),
              _buildSortChip('最多播放', 'click', sp),
              const SizedBox(width: 6.0),
              _buildSortChip('最新发布', 'pubdate', sp),
              const SizedBox(width: 6.0),
              _buildSortChip('最多弹幕', 'dm', sp),
              const SizedBox(width: 6.0),
              _buildSortChip('最多收藏', 'stow', sp),
            ],
          ),
        ),
        Expanded(child: _buildVideoResultsBody(sp)),
      ],
    );
  }

  Widget _buildVideoResultsBody(SearchProvider sp) {
    if (sp.isLoading && sp.searchResults.isEmpty) {
      return const VideoGridSkeleton(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      );
    }
    if (sp.searchResults.isEmpty) {
      if (sp.errorMessage != null) {
        return ErrorView(
          message: sp.errorMessage!,
          onRetry: () => sp.search(sp.currentKeyword, category: 'video'),
        );
      }
      return const EmptyView(message: '未找到相关视频');
    }

    final showFooter = sp.isLoadingMore || !sp.hasMore;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => _refreshSearch(sp, 'video'),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (sp.isLoadingMore || !sp.hasMore) return false;
          if (scrollInfo.metrics.maxScrollExtent <= 0) return false;
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 240) {
            _loadMoreSearch(sp);
          }
          return false;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                ResponsiveGridConfig.calculateCrossAxisCountForWidth(
                  constraints.maxWidth,
                );
            final mainAxisExtent =
                ResponsiveGridConfig.calculateMainAxisExtent(
                  context,
                  availableWidth: constraints.maxWidth,
                  crossAxisCount: crossAxisCount,
                );
            return CustomScrollView(
              primary: false,
              scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: mainAxisExtent,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: sp.searchResults.length,
                    itemBuilder: (ctx, idx) {
                      final video = sp.searchResults[idx];
                      return RepaintBoundary(
                        child: VideoCard(
                          video: video,
                          heroTag: 'search_${video.bvid}_$idx',
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
                        child: sp.isLoadingMore
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
                                  fontSize: AppTypography.footnote,
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

  Widget _buildUserResultsTab(SearchProvider sp) {
    if (sp.isLoading && sp.searchUsers.isEmpty) {
      return const UserListSkeleton();
    }
    if (sp.searchUsers.isEmpty) {
      if (sp.errorMessage != null) {
        return ErrorView(
          message: sp.errorMessage!,
          onRetry: () => sp.search(sp.currentKeyword, category: 'user'),
        );
      }
      return const EmptyView(message: '未找到相关UP主');
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => _refreshSearch(sp, 'user'),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (sp.isLoadingMore || !sp.hasMore) return false;
          if (scrollInfo.metrics.maxScrollExtent <= 0) return false;
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 200) {
            _loadMoreSearch(sp);
          }
          return false;
        },
        child: ListView.separated(
          primary: false,
          scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          itemCount:
              sp.searchUsers.length + ((sp.isLoadingMore || !sp.hasMore) ? 1 : 0),
          separatorBuilder: (ctx, _) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 62,
            color: context.colors.divider,
          ),
          itemBuilder: (ctx, idx) {
            if (idx == sp.searchUsers.length) {
              return _buildListFooter(sp.isLoadingMore);
            }
            return RepaintBoundary(child: _buildUserTile(sp.searchUsers[idx]));
          },
        ),
      ),
    );
  }

  Widget _buildArticleResultsTab(SearchProvider sp) {
    if (sp.isLoading && sp.searchArticles.isEmpty) {
      return const DynamicCardSkeleton(itemCount: 4);
    }
    if (sp.searchArticles.isEmpty) {
      if (sp.errorMessage != null) {
        return ErrorView(
          message: sp.errorMessage!,
          onRetry: () => sp.search(sp.currentKeyword, category: 'article'),
        );
      }
      return const EmptyView(message: '未找到相关专栏');
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => _refreshSearch(sp, 'article'),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (sp.isLoadingMore || !sp.hasMore) return false;
          if (scrollInfo.metrics.maxScrollExtent <= 0) return false;
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 200) {
            _loadMoreSearch(sp);
          }
          return false;
        },
        child: ListView.separated(
          primary: false,
          scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          itemCount: sp.searchArticles.length +
              ((sp.isLoadingMore || !sp.hasMore) ? 1 : 0),
          separatorBuilder: (ctx, _) => const SizedBox(height: 10.0),
          itemBuilder: (ctx, idx) {
            if (idx == sp.searchArticles.length) {
              return _buildListFooter(sp.isLoadingMore);
            }
            return RepaintBoundary(
              child: _buildArticleTile(sp.searchArticles[idx]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListFooter(bool isLoadingMore) {
    if (isLoadingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          '没有更多了',
          style: TextStyle(
            fontSize: AppTypography.footnote,
            color: context.colors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(
    String label,
    String orderKey,
    SearchProvider sp,
  ) {
    final isSelected = sp.currentOrder == orderKey;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.14)
          : context.colors.fill,
      borderRadius: AppRadius.of(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => sp.changeOrder(orderKey),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.caption,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? primaryColor : context.colors.textSub,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshSearch(SearchProvider sp, String category) async {
    final ok = await sp.search(sp.currentKeyword, category: category);
    if (!mounted) return;
    if (!ok) {
      AppToast.show(context, sp.errorMessage ?? '刷新失败，请检查网络');
    }
  }

  Future<void> _loadMoreSearch(SearchProvider sp) async {
    final ok = await sp.loadMore();
    if (!ok && mounted) {
      AppToast.show(context, '加载失败，请重试');
    }
  }

  Widget _buildUserTile(SearchUserItem user) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          AppRoutes.page(UpSpaceScreen(mid: user.mid)),
        );
      },
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
        child: Row(
          children: [
            UserAvatar(url: user.upic, size: 46),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.uname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: AppRadius.of(AppRadius.xs),
                        ),
                        child: Text(
                          'Lv${user.level}',
                          style: TextStyle(
                            fontSize: AppTypography.tiny,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '粉丝: ${Formatters.formatCount(user.fans)} · 视频: ${user.videos}',
                    style: TextStyle(
                      fontSize: AppTypography.footnote,
                      color: context.colors.textHint,
                    ),
                  ),
                  if (user.usign.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.usign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: context.colors.textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleTile(SearchArticleItem article) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openArticle(article),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (article.desc.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    article.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.footnote,
                      color: context.colors.textSub,
                      height: 1.4,
                    ),
                  ),
                ],
                if (article.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8.0),
                  ClipRRect(
                    borderRadius: AppRadius.of(AppRadius.sm),
                    child: SizedBox(
                      height: 100,
                      child: Row(
                        children: article.imageUrls.take(3).map((img) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.0,
                              ),
                              child: NetworkImageView(
                                url: img,
                                fit: BoxFit.cover,
                                memCacheWidth: 320,
                                memCacheHeight: 200,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Semantics(
                      button: article.mid > 0,
                      label: '查看 ${article.uname} 主页',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: AppRadius.of(AppRadius.xs),
                          onTap: article.mid > 0
                              ? () {
                                  Navigator.of(context).push(
                                    AppRoutes.page(UpSpaceScreen(mid: article.mid)),
                                  );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              article.uname,
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '阅读 ${Formatters.formatCount(article.view)} · 点赞 ${Formatters.formatCount(article.like)}',
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: context.colors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
