import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../models/dynamic_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/dynamic_api_service.dart';
import '../../services/api/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/dynamic_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../profile/login_dialog.dart';

class DynamicScreen extends StatefulWidget {
  const DynamicScreen({super.key});

  @override
  State<DynamicScreen> createState() => DynamicScreenState();
}

class DynamicScreenState extends State<DynamicScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<GlobalKey<_DynamicFeedTabState>> _tabKeys = [
    GlobalKey<_DynamicFeedTabState>(),
    GlobalKey<_DynamicFeedTabState>(),
    GlobalKey<_DynamicFeedTabState>(),
  ];

  int _loadedFollowMid = 0;
  List<RelationUser> _followings = const [];
  int? _selectedHostMid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _syncFollowingsIfNeeded(AuthProvider auth) {
    final targetMid = auth.isLogin ? auth.userInfo.mid : 0;
    if (targetMid == _loadedFollowMid) return;
    _loadedFollowMid = targetMid;
    if (targetMid <= 0) {
      if (_followings.isNotEmpty || _selectedHostMid != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _followings = const [];
            _selectedHostMid = null;
          });
        });
      }
      return;
    }
    unawaited(_loadFollowings(targetMid));
  }

  Future<void> _loadFollowings(int mid) async {
    try {
      final list = await UserApiService().getUserFollowings(
        vmid: mid,
        pn: 1,
        ps: 20,
        order: 'desc',
      );
      if (mounted && _loadedFollowMid == mid) {
        setState(() => _followings = list);
      }
    } catch (_) {
      // 关注条加载失败时静默降级，不阻塞动态主列表
    }
  }

  Future<void> refreshAndScrollToTop() async {
    final activeKey = _tabKeys[_tabController.index];
    if (activeKey.currentState != null) {
      await activeKey.currentState!.refreshAndScrollToTop();
    }
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const LoginDialog(),
    );
  }

  Widget _buildUpFilterStrip(Color primaryColor) {
    return DynamicUpFilterStrip(
      followings: _followings,
      selectedHostMid: _selectedHostMid,
      primaryColor: primaryColor,
      onSelectAll: () {
        if (_selectedHostMid != null) {
          setState(() => _selectedHostMid = null);
        }
      },
      onSelectHost: (mid) {
        setState(() {
          _selectedHostMid = _selectedHostMid == mid ? null : mid;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    _syncFollowingsIfNeeded(auth);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          width: 220,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorColor: primaryColor,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: primaryColor,
            unselectedLabelColor: context.colors.textSub,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
            ),
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            tabs: const [
              Tab(text: '全部'),
              Tab(text: '视频'),
              Tab(text: '图文'),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: !auth.isLogin
          ? EmptyView(
              message: '登录后即可查看关注UP主的最新动态与投稿',
              icon: Icons.lock_outline_rounded,
              onRetry: () => _showLoginDialog(context),
              retryText: '立即登录',
            )
          : ResponsiveMaxConstraint(
              child: Column(
                children: [
                  if (_followings.isNotEmpty) _buildUpFilterStrip(primaryColor),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _DynamicFeedTab(
                          key: _tabKeys[0],
                          type: 'all',
                          hostMid: _selectedHostMid,
                        ),
                        _DynamicFeedTab(
                          key: _tabKeys[1],
                          type: 'video',
                          hostMid: _selectedHostMid,
                        ),
                        _DynamicFeedTab(
                          key: _tabKeys[2],
                          type: 'article',
                          hostMid: _selectedHostMid,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DynamicFeedTab extends StatefulWidget {
  final String type;
  final int? hostMid;

  const _DynamicFeedTab({super.key, required this.type, this.hostMid});

  @override
  State<_DynamicFeedTab> createState() => _DynamicFeedTabState();
}

class _DynamicFeedTabState extends State<_DynamicFeedTab>
    with AutomaticKeepAliveClientMixin {
  final List<DynamicItem> _items = [];
  // 按非空动态 id 去重，避免分页重叠导致 Hero tag 在列表子树内冲突
  final Set<String> _seenIds = {};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  String _offset = '';
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _DynamicFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hostMid != oldWidget.hostMid) {
      _loadData(refresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refreshAndScrollToTop() async {
    // 两段式回顶：距顶部较远时先平滑回顶，已在顶部时再触发刷新
    if (_scrollController.hasClients && _scrollController.offset > 100) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else {
      await _loadData(refresh: true);
      if (mounted) AppToast.show(context, '已刷新');
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      _offset = '';
      _page = 1;
      _hasMore = true;
    }
    final requestMid = widget.hostMid;

    setState(() {
      if (_items.isEmpty || refresh) {
        _isLoading = true;
        _errorMessage = null;
      }
    });

    final res = await DynamicApiService().fetchDynamicFeed(
      type: widget.type,
      offset: refresh ? '' : _offset,
      page: refresh ? 1 : _page,
      hostMid: requestMid,
    );

    if (mounted && requestMid == widget.hostMid) {
      setState(() {
        if (res.data != null) {
          final feed = res.data!;
          if (refresh || _page == 1) {
            _items.clear();
            _seenIds.clear();
          }
          for (final item in feed.items) {
            if (item.id.isEmpty || _seenIds.add(item.id)) {
              _items.add(item);
            }
          }
          _offset = feed.offset;
          _hasMore = feed.hasMore;
          _errorMessage = null;
        } else {
          if (refresh || _page == 1) {
            _items.clear();
            _seenIds.clear();
            _hasMore = false;
            _errorMessage = res.error ?? '动态加载失败';
          }
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore || _offset.isEmpty) return;
    setState(() => _isLoadingMore = true);

    final requestMid = widget.hostMid;
    _page++;
    final res = await DynamicApiService().getDynamicFeed(
      type: widget.type,
      offset: _offset,
      page: _page,
      hostMid: requestMid,
    );

    if (mounted && requestMid == widget.hostMid) {
      setState(() {
        if (res != null && res.items.isNotEmpty) {
          for (final item in res.items) {
            if (item.id.isEmpty || _seenIds.add(item.id)) {
              _items.add(item);
            }
          }
          _offset = res.offset;
          _hasMore = res.hasMore;
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData(refresh: true);
    if (mounted && _errorMessage == null) {
      AppToast.show(context, '已刷新');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _items.isEmpty) {
      return const DynamicCardSkeleton(itemCount: 4);
    }

    if (_errorMessage != null && _items.isEmpty) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: () => _loadData(refresh: true),
      );
    }

    if (_items.isEmpty) {
      return EmptyView(
        message: widget.hostMid != null
            ? '该 UP 主近期暂无动态'
            : '关注的 UP 主近期暂无新动态',
        icon: Icons.dynamic_feed_rounded,
        onRetry: () => _loadData(refresh: true),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        key: _refreshKey,
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _handleRefresh,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          itemCount: _items.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, idx) {
            if (idx == _items.length) {
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

            return RepaintBoundary(
              child: DynamicCard(item: _items[idx]),
            );
          },
        ),
      ),
    );
  }
}

/// 动态页顶部关注 UP 主横向筛选条：随系统字号缩放自适应高度，避免小字号跨平台行高溢出。
class DynamicUpFilterStrip extends StatelessWidget {
  final List<RelationUser> followings;
  final int? selectedHostMid;
  final Color primaryColor;
  final VoidCallback onSelectAll;
  final ValueChanged<int> onSelectHost;

  const DynamicUpFilterStrip({
    super.key,
    required this.followings,
    required this.selectedHostMid,
    required this.primaryColor,
    required this.onSelectAll,
    required this.onSelectHost,
  });

  static const double _circleSize = 44.0;

  @override
  Widget build(BuildContext context) {
    // 为单行 11px 文本预留跨平台行高与 1.4x 字体缩放余量，杜绝底部 0.5px 溢出
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(AppTypography.caption * 1.45) + 2;
    final stripHeight =
        _circleSize + 4 + labelHeight.ceilToDouble() + AppSpacing.sm * 2 + 2;

    return Container(
      height: stripHeight,
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(
          bottom: BorderSide(color: context.colors.divider, width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: followings.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (ctx, idx) {
          if (idx == 0) {
            final selected = selectedHostMid == null;
            return _buildItem(
              context: ctx,
              width: 52,
              label: '全部',
              selected: selected,
              onTap: onSelectAll,
              avatar: Container(
                width: _circleSize,
                height: _circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? primaryColor.withValues(alpha: 0.14)
                      : ctx.colors.fill,
                  border: Border.all(
                    color: selected ? primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.apps_rounded,
                  size: 20,
                  color: selected ? primaryColor : ctx.colors.textSub,
                ),
              ),
            );
          }

          final user = followings[idx - 1];
          final selected = selectedHostMid == user.mid;
          return _buildItem(
            context: ctx,
            width: 56,
            label: user.uname,
            selected: selected,
            onTap: () => onSelectHost(user.mid),
            avatar: Container(
              width: _circleSize,
              height: _circleSize,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: UserAvatar(url: user.face, size: _circleSize - 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required double width,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Widget avatar,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: label == '全部' ? '全部UP主动态' : '筛选 $label 的动态',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.of(AppRadius.sm),
          onTap: onTap,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    height: 1.25,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? primaryColor : context.colors.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
