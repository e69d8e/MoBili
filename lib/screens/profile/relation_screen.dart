import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/user_model.dart';
import '../../services/api/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../up/up_space_screen.dart';

class RelationScreen extends StatefulWidget {
  final int mid;
  final int initialIndex;

  const RelationScreen({
    super.key,
    required this.mid,
    this.initialIndex = 0,
  });

  @override
  State<RelationScreen> createState() => _RelationScreenState();
}

class _RelationScreenState extends State<RelationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          width: 180,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorColor: primaryColor,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: primaryColor,
            unselectedLabelColor: context.colors.textSub,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            tabs: const [
              Tab(text: '关注'),
              Tab(text: '粉丝'),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RelationListTab(mid: widget.mid, isFollowings: true),
          _RelationListTab(mid: widget.mid, isFollowings: false),
        ],
      ),
    );
  }
}

class _RelationListTab extends StatefulWidget {
  final int mid;
  final bool isFollowings;

  const _RelationListTab({
    required this.mid,
    required this.isFollowings,
  });

  @override
  State<_RelationListTab> createState() => _RelationListTabState();
}

class _RelationListTabState extends State<_RelationListTab> with AutomaticKeepAliveClientMixin {
  final List<RelationUser> _users = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    setState(() {
      if (_users.isEmpty || refresh) _isLoading = true;
    });

    List<RelationUser> result;
    if (widget.isFollowings) {
      result = await UserApiService().getUserFollowings(vmid: widget.mid, pn: _page);
    } else {
      result = await UserApiService().getUserFollowers(vmid: widget.mid, pn: _page);
    }

    if (mounted) {
      setState(() {
        if (refresh || _page == 1) {
          _users.clear();
          _users.addAll(result);
        } else {
          _users.addAll(result);
        }
        _hasMore = result.isNotEmpty;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore || _searchQuery.isNotEmpty) return;
    setState(() => _isLoadingMore = true);

    _page++;
    List<RelationUser> result;
    if (widget.isFollowings) {
      result = await UserApiService().getUserFollowings(vmid: widget.mid, pn: _page);
    } else {
      result = await UserApiService().getUserFollowers(vmid: widget.mid, pn: _page);
    }

    if (mounted) {
      setState(() {
        if (result.isEmpty) {
          _hasMore = false;
        } else {
          _users.addAll(result);
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _toggleFollow(RelationUser user, int index) async {
    final newFollowState = !user.isFollowing;
    // Optimistic UI update
    setState(() {
      _users[index] = RelationUser(
        mid: user.mid,
        uname: user.uname,
        face: user.face,
        sign: user.sign,
        vipType: user.vipType,
        vipLabel: user.vipLabel,
        mtime: user.mtime,
        attribute: newFollowState ? 2 : 0,
        isFollowing: newFollowState,
      );
    });

    final success = await UserApiService().modifyRelation(
      user.mid,
      act: newFollowState ? 1 : 2,
    );

    if (!success && mounted) {
      // Rollback on failure
      setState(() {
        _users[index] = user;
      });
      AppToast.show(context, '操作失败，请先登录', icon: Icons.info_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _users.isEmpty) {
      return LoadingView(message: widget.isFollowings ? '正在加载关注列表...' : '正在加载粉丝列表...');
    }

    if (_users.isEmpty) {
      return EmptyView(
        message: widget.isFollowings ? '暂无关注的UP主' : '暂无粉丝',
        icon: widget.isFollowings ? Icons.people_outline_rounded : Icons.favorite_border_rounded,
        onRetry: () => _loadData(refresh: true),
      );
    }

    final displayedUsers = _searchQuery.isEmpty
        ? _users
        : _users.where((u) {
            final query = _searchQuery.toLowerCase();
            return u.uname.toLowerCase().contains(query) || u.sign.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        // Search Bar for Followings / Followers
        Container(
          height: 36,
          margin: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 4.0),
          decoration: BoxDecoration(
            color: context.colors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _searchController,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              hintText: widget.isFollowings ? '搜索已关注的UP主...' : '搜索粉丝...',
              hintStyle: TextStyle(
                color: context.colors.textHint,
                fontSize: 12,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 17,
                color: context.colors.textHint,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34, maxWidth: 34, maxHeight: 34),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.clear_rounded, size: 15),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34, maxWidth: 34, maxHeight: 34),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
            },
          ),
        ),

        // List
        Expanded(
          child: displayedUsers.isEmpty && _searchQuery.isNotEmpty
              ? EmptyView(
                  message: '未找到包含「$_searchQuery」的UP主',
                  icon: Icons.search_off_rounded,
                  onRetry: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  retryText: '清空搜索',
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: () => _loadData(refresh: true),
                    child: ListView.separated(
                      scrollCacheExtent: ScrollCacheExtent.pixels(500.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                      itemCount: displayedUsers.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (ctx, _) => Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 58,
                        color: context.colors.divider,
                      ),
                      itemBuilder: (ctx, idx) {
                        final primaryColor = Theme.of(context).colorScheme.primary;

                        if (idx == displayedUsers.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                            ),
                          );
                        }

                        final user = displayedUsers[idx];
                        final rawIndex = _users.indexOf(user);
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => UpSpaceScreen(mid: user.mid)),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                            child: Row(
                              children: [
                                UserAvatar(url: user.face, size: 44),
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
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: user.vipLabel.isNotEmpty ? primaryColor : null,
                                              ),
                                            ),
                                          ),
                                          if (user.vipLabel.isNotEmpty) ...[
                                            const SizedBox(width: 4.0),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: primaryColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                user.vipLabel,
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        user.sign.isNotEmpty ? user.sign : '这个UP主很神秘，什么都没有写',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.colors.textSub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                if (widget.isFollowings)
                                  OutlinedButton(
                                    onPressed: () => _toggleFollow(user, rawIndex != -1 ? rawIndex : idx),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: user.isFollowing
                                          ? (context.colors.textSub)
                                          : primaryColor,
                                      side: BorderSide(
                                        color: user.isFollowing
                                            ? (context.colors.divider)
                                            : primaryColor,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      user.isFollowing ? '已关注' : '+ 关注',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: context.colors.textHint,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
