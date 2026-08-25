import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/search_model.dart';
import '../../providers/search_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
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
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            autofocus: widget.initialKeyword == null || widget.initialKeyword!.isEmpty,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              hintText: '搜索视频、UP主、图文...',
              hintStyle: TextStyle(
                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                fontSize: 12.5,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36, maxWidth: 36, maxHeight: 36),
              suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36, maxWidth: 36, maxHeight: 36),
              suffixIcon: _textController.text.isNotEmpty
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _textController.clear();
                        searchProvider.clearSuggestions();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            ),
            onChanged: (val) {
              setState(() {});
              searchProvider.fetchSuggestions(val);
            },
            onSubmitted: _doSearch,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _doSearch(_textController.text),
            child: Text('搜索', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(searchProvider, isDark),
    );
  }

  Widget _buildBody(SearchProvider sp, bool isDark) {
    // 1. If typing and suggestions available
    if (_textController.text.isNotEmpty && sp.suggestions.isNotEmpty && _focusNode.hasFocus) {
      return ListView.separated(
        itemCount: sp.suggestions.length,
        separatorBuilder: (ctx, _) => Divider(
          height: 1,
          thickness: 0.5,
          indent: 38,
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),
        itemBuilder: (ctx, idx) {
          final item = sp.suggestions[idx];
          return ListTile(
            leading: Icon(
              Icons.search_rounded,
              size: 16,
              color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
            ),
            title: Text(
              item.value,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => sp.clearHistory(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sp.history.map((h) {
                return GestureDetector(
                  onTap: () => _doSearch(h),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Trending / Hot Search
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFF6699)),
              const SizedBox(width: 4),
              const Text(
                '热搜榜',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sp.hotSearches.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sp.hotSearches.length,
              itemBuilder: (ctx, idx) {
                final item = sp.hotSearches[idx];
                final rank = idx + 1;
                Color rankColor = isDark ? AppTheme.textHintDark : AppTheme.textHintLight;
                if (rank == 1) rankColor = const Color(0xFFFF3366);
                if (rank == 2) rankColor = const Color(0xFFFF6C00);
                if (rank == 3) rankColor = const Color(0xFFFFB027);

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  leading: SizedBox(
                    width: 20,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
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
                        const SizedBox(width: 6),
                        NetworkImageView(
                          url: item.icon,
                          width: 14,
                          height: 14,
                        ),
                      ],
                    ],
                  ),
                  onTap: () => _doSearch(item.keyword),
                );
              },
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Row(
            children: [
              _buildCategoryChip('视频', 'video', sp, isDark),
              const SizedBox(width: 8),
              _buildCategoryChip('UP主', 'bili_user', sp, isDark),
              const SizedBox(width: 8),
              _buildCategoryChip('图文', 'article', sp, isDark),
            ],
          ),
        ),

        // Sort Bar (only for video)
        if (sp.currentCategory == 'video')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _buildSortChip('综合排序', 'totalrank', sp, isDark),
                const SizedBox(width: 6),
                _buildSortChip('最多点击', 'click', sp, isDark),
                const SizedBox(width: 6),
                _buildSortChip('最新发布', 'pubdate', sp, isDark),
                const SizedBox(width: 6),
                _buildSortChip('最多弹幕', 'danmaku', sp, isDark),
              ],
            ),
          ),

        Divider(
          height: 1,
          thickness: 0.5,
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),

        // Main Content Area
        Expanded(
          child: sp.isLoading
              ? const LoadingView(message: '正在搜索中...')
              : _buildCategoryContent(sp, isDark),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, String catKey, SearchProvider sp, bool isDark) {
    final isSelected = sp.currentCategory == catKey;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return GestureDetector(
      onTap: () => sp.setCategory(catKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? onPrimary
                : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String orderKey, SearchProvider sp, bool isDark) {
    final isSelected = sp.currentOrder == orderKey;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => sp.changeOrder(orderKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? primaryColor
                : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContent(SearchProvider sp, bool isDark) {
    if (sp.currentCategory == 'video') {
      if (sp.searchResults.isEmpty) {
        return const EmptyView(message: '未找到相关视频');
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            sp.loadMore();
          }
          return false;
        },
        child: GridView.builder(
          cacheExtent: 600.0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.96,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: sp.searchResults.length + (sp.isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, idx) {
            if (idx == sp.searchResults.length) {
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                ),
              );
            }
            return RepaintBoundary(
              child: VideoCard(video: sp.searchResults[idx]),
            );
          },
        ),
      );
    } else if (sp.currentCategory == 'user' || sp.currentCategory == 'bili_user') {
      if (sp.searchUsers.isEmpty) {
        return const EmptyView(message: '未找到相关UP主');
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            sp.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          cacheExtent: 600.0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: sp.searchUsers.length + (sp.isLoadingMore ? 1 : 0),
          separatorBuilder: (ctx, _) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 62,
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),
          itemBuilder: (ctx, idx) {
            if (idx == sp.searchUsers.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                ),
              );
            }
            return RepaintBoundary(
              child: _buildUserTile(sp.searchUsers[idx], isDark),
            );
          },
        ),
      );
    } else {
      // Article
      if (sp.searchArticles.isEmpty) {
        return const EmptyView(message: '未找到相关图文');
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            sp.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          cacheExtent: 600.0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: sp.searchArticles.length + (sp.isLoadingMore ? 1 : 0),
          separatorBuilder: (ctx, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, idx) {
            if (idx == sp.searchArticles.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                ),
              );
            }
            return RepaintBoundary(
              child: _buildArticleTile(sp.searchArticles[idx], isDark),
            );
          },
        ),
      );
    }
  }

  Widget _buildUserTile(SearchUserItem user, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => UpSpaceScreen(mid: user.mid),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            UserAvatar(url: user.upic, size: 46),
            const SizedBox(width: 12),
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Lv${user.level}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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
                      fontSize: 11.5,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
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
                        color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleTile(SearchArticleItem article, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.35),
          ),
          if (article.desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              article.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                height: 1.4,
              ),
            ),
          ],
          if (article.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
                  fontSize: 10.5,
                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
