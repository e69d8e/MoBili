import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/search_model.dart';
import '../../providers/search_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/video_card.dart';
import '../up/up_space_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialKeyword;
  const SearchScreen({super.key, this.initialKeyword});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialKeyword ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SearchProvider>();
      sp.init();
      if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
        sp.search(widget.initialKeyword!, order: 'totalrank');
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _doSearch(String keyword) {
    if (keyword.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    _textController.text = keyword.trim();
    _focusNode.unfocus();
    context.read<SearchProvider>().search(keyword.trim(), order: 'totalrank');
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 4.0),
          decoration: BoxDecoration(
            color: context.colors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            autofocus:
                widget.initialKeyword == null || widget.initialKeyword!.isEmpty,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              hintText: '搜索视频、UP主、图文...',
              hintStyle: TextStyle(
                color: context.colors.textHint,
                fontSize: 13,
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
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _textController.clear();
                      searchProvider.clearSuggestions();
                    },
                  );
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 0,
              ),
            ),
            onChanged: (val) {
              searchProvider.fetchSuggestions(val);
            },
            onSubmitted: _doSearch,
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
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
        ],
      ),
      body: _buildBody(searchProvider, isDark),
    );
  }

  Widget _buildBody(SearchProvider sp, bool isDark) {
    // 1. If typing and suggestions available
    if (_textController.text.isNotEmpty &&
        sp.suggestions.isNotEmpty &&
        _focusNode.hasFocus) {
      return ListView.separated(
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
            title: Text(
              item.value,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textMain,
              ),
            ),
            dense: true,
            onTap: () => _doSearch(item.value),
          );
        },
      );
    }

    // 2. If searched, show results
    if (sp.hasSearched) {
      return _buildSearchResults(sp, isDark);
    }

    // 3. Default: History & Hot Searches
    return _buildHistoryAndHot(sp, isDark);
  }

  Widget _buildHistoryAndHot(SearchProvider sp, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // History
          if (sp.history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '搜索历史',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: context.colors.textHint,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => sp.clearHistory(),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sp.history.map((h) {
                return GestureDetector(
                  onTap: () => _doSearch(h),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.fill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSub,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20.0),
          ],

          // Trending / Hot Search
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: AppTheme.biliPink,
              ),
              const SizedBox(width: 4),
              const Text(
                '热搜榜',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          if (sp.hotSearches.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
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
                  // 深色下换亮色变体，避免低对比
                  rankColor = isDark ? const Color(0xFFE57373) : const Color(0xFFC0483E); // 朱砂
                  rankBadgeBg = rankColor.withValues(alpha: isDark ? 0.18 : 0.12);
                } else if (rank == 2) {
                  rankColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFE67E22); // 琥珀
                  rankBadgeBg = rankColor.withValues(alpha: isDark ? 0.18 : 0.12);
                } else if (rank == 3) {
                  rankColor = isDark ? const Color(0xFF64B5F6) : const Color(0xFF2A6F97); // 霁蓝
                  rankBadgeBg = rankColor.withValues(alpha: isDark ? 0.18 : 0.12);
                }

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  leading: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rankBadgeBg ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 13,
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
                          style: const TextStyle(fontSize: 13),
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

  Widget _buildSearchResults(SearchProvider sp, bool isDark) {
    return Column(
      children: [
        // Category Pills (Video / UP / Article)
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            children: [
              _buildCategoryChip('视频', 'video', sp, isDark),
              const SizedBox(width: 8.0),
              _buildCategoryChip('UP主', 'bili_user', sp, isDark),
              const SizedBox(width: 8.0),
              _buildCategoryChip('图文', 'article', sp, isDark),
            ],
          ),
        ),

        // Sort Bar (only for video)
        if (sp.currentCategory == 'video')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
            child: Row(
              children: [
                _buildSortChip('综合排序', 'totalrank', sp, isDark),
                const SizedBox(width: 4.0),
                _buildSortChip('最多点击', 'click', sp, isDark),
                const SizedBox(width: 4.0),
                _buildSortChip('最新发布', 'pubdate', sp, isDark),
                const SizedBox(width: 4.0),
                _buildSortChip('最多弹幕', 'danmaku', sp, isDark),
              ],
            ),
          ),

        Divider(
          height: 1,
          thickness: 0.5,
          color: context.colors.divider,
        ),

        // Main Content Area（加载/错误态由各分类内容自行处理）
        Expanded(child: _buildCategoryContent(sp, isDark)),
      ],
    );
  }

  Widget _buildCategoryChip(
    String label,
    String catKey,
    SearchProvider sp,
    bool isDark,
  ) {
    final isSelected = sp.currentCategory == catKey;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return GestureDetector(
      onTap: () => sp.setCategory(catKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (context.colors.fill),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? onPrimary
                : (context.colors.textSub),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(
    String label,
    String orderKey,
    SearchProvider sp,
    bool isDark,
  ) {
    final isSelected = sp.currentOrder == orderKey;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => sp.changeOrder(orderKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : (context.colors.fill),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? primaryColor
                : (context.colors.textSub),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContent(SearchProvider sp, bool isDark) {
    if (sp.currentCategory == 'video') {
      if (sp.isLoading && sp.searchResults.isEmpty) {
        return const VideoGridSkeleton(
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        );
      }
      if (sp.searchResults.isEmpty) {
        if (sp.errorMessage != null) {
          return ErrorView(
            message: sp.errorMessage!,
            onRetry: () => sp.search(sp.currentKeyword),
          );
        }
        return const EmptyView(message: '未找到相关视频');
      }
      final crossAxisCount = ResponsiveGridConfig.calculateCrossAxisCount(
        context,
      );
      final childAspectRatio = ResponsiveGridConfig.calculateChildAspectRatio(
        context,
      );
      final showFooter = sp.isLoadingMore || !sp.hasMore;

      return RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: () => _refreshSearch(sp),
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              _loadMoreSearch(sp);
            }
            return false;
          },
          child: GridView.builder(
            scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: sp.searchResults.length + (showFooter ? 1 : 0),
            itemBuilder: (ctx, idx) {
              if (idx == sp.searchResults.length) {
                if (sp.isLoadingMore) {
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
                child: VideoCard(video: sp.searchResults[idx]),
              );
            },
          ),
        ),
      );
    } else if (sp.currentCategory == 'user' ||
        sp.currentCategory == 'bili_user') {
      if (sp.isLoading && sp.searchUsers.isEmpty) {
        return const LoadingView(message: '正在搜索UP主...');
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
        onRefresh: () => _refreshSearch(sp),
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              _loadMoreSearch(sp);
            }
            return false;
          },
          child: ListView.separated(
            scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            itemCount: sp.searchUsers.length +
                ((sp.isLoadingMore || !sp.hasMore) ? 1 : 0),
            separatorBuilder: (ctx, _) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 62,
              color: context.colors.divider,
            ),
            itemBuilder: (ctx, idx) {
              if (idx == sp.searchUsers.length) {
                if (sp.isLoadingMore) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
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
                        fontSize: 12,
                        color: context.colors.textHint,
                      ),
                    ),
                  ),
                );
              }
              return RepaintBoundary(
                child: _buildUserTile(sp.searchUsers[idx], isDark),
              );
            },
          ),
        ),
      );
    } else {
      // Article
      if (sp.isLoading && sp.searchArticles.isEmpty) {
        return const LoadingView(message: '正在搜索图文...');
      }
      if (sp.searchArticles.isEmpty) {
        if (sp.errorMessage != null) {
          return ErrorView(
            message: sp.errorMessage!,
            onRetry: () => sp.search(sp.currentKeyword, category: 'article'),
          );
        }
        return const EmptyView(message: '未找到相关图文');
      }
      return RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: () => _refreshSearch(sp),
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              _loadMoreSearch(sp);
            }
            return false;
          },
          child: ListView.separated(
            scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            itemCount: sp.searchArticles.length +
                ((sp.isLoadingMore || !sp.hasMore) ? 1 : 0),
            separatorBuilder: (ctx, _) => const SizedBox(height: 8.0),
            itemBuilder: (ctx, idx) {
              if (idx == sp.searchArticles.length) {
                if (sp.isLoadingMore) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
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
                        fontSize: 12,
                        color: context.colors.textHint,
                      ),
                    ),
                  ),
                );
              }
              return RepaintBoundary(
                child: _buildArticleTile(sp.searchArticles[idx], isDark),
              );
            },
          ),
        ),
      );
    }
  }

  /// 重新搜索当前关键词（下拉刷新）。失败时提示，不打断列表
  Future<void> _refreshSearch(SearchProvider sp) async {
    final ok = await sp.search(sp.currentKeyword);
    if (!mounted) return;
    if (!ok) {
      AppToast.show(context, sp.errorMessage ?? '刷新失败，请检查网络');
    }
  }

  /// 滚动加载更多，失败时提示
  Future<void> _loadMoreSearch(SearchProvider sp) async {
    final ok = await sp.loadMore();
    if (!ok && mounted) {
      AppToast.show(context, '加载失败，请重试');
    }
  }

  Widget _buildUserTile(SearchUserItem user, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => UpSpaceScreen(mid: user.mid)),
        );
      },
      borderRadius: BorderRadius.circular(12),
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
                            fontSize: 14,
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Lv${user.level}',
                          style: TextStyle(
                            fontSize: 10,
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
                      fontSize: 12,
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
                        fontSize: 11,
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

  Widget _buildArticleTile(SearchArticleItem article, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            article.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
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
                fontSize: 12,
                color: context.colors.textSub,
                height: 1.4,
              ),
            ),
          ],
          if (article.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 100,
                child: Row(
                  children: article.imageUrls.take(3).map((img) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
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
          // Meta Row
          Row(
            children: [
              GestureDetector(
                onTap: article.mid > 0
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => UpSpaceScreen(mid: article.mid),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  article.uname,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '阅读 ${Formatters.formatCount(article.view)} · 点赞 ${Formatters.formatCount(article.like)}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
