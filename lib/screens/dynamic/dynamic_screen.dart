import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../models/dynamic_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/dynamic_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/dynamic_card.dart';
import '../../widgets/state_views.dart';
import '../profile/login_dialog.dart';

class DynamicScreen extends StatefulWidget {
  const DynamicScreen({super.key});

  @override
  State<DynamicScreen> createState() => DynamicScreenState();
}

class DynamicScreenState extends State<DynamicScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<GlobalKey<DynamicFeedTabState>> _tabKeys = [
    GlobalKey<DynamicFeedTabState>(),
    GlobalKey<DynamicFeedTabState>(),
    GlobalKey<DynamicFeedTabState>(),
  ];

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _DynamicFeedTab(key: _tabKeys[0], type: 'all'),
                _DynamicFeedTab(key: _tabKeys[1], type: 'video'),
                _DynamicFeedTab(key: _tabKeys[2], type: 'article'),
              ],
            ),
    );
  }
}

class _DynamicFeedTab extends StatefulWidget {
  final String type;

  const _DynamicFeedTab({super.key, required this.type});

  @override
  State<_DynamicFeedTab> createState() => DynamicFeedTabState();
}

class DynamicFeedTabState extends State<_DynamicFeedTab> with AutomaticKeepAliveClientMixin {
  final List<DynamicItem> _items = [];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  String _offset = '';
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

    setState(() {
      if (_items.isEmpty || refresh) _isLoading = true;
    });

    final res = await DynamicApiService().getDynamicFeed(
      type: widget.type,
      offset: refresh ? '' : _offset,
      page: refresh ? 1 : _page,
    );

    if (mounted) {
      setState(() {
        if (res != null) {
          if (refresh || _page == 1) {
            _items.clear();
            _items.addAll(res.items);
          } else {
            _items.addAll(res.items);
          }
          _offset = res.offset;
          _hasMore = res.hasMore;
        } else if (refresh || _page == 1) {
          _items.clear();
          _hasMore = false;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore || _offset.isEmpty) return;
    setState(() => _isLoadingMore = true);

    _page++;
    final res = await DynamicApiService().getDynamicFeed(
      type: widget.type,
      offset: _offset,
      page: _page,
    );

    if (mounted) {
      setState(() {
        if (res != null && res.items.isNotEmpty) {
          _items.addAll(res.items);
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
    if (mounted) {
      AppToast.show(context, '已刷新');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _items.isEmpty) {
      return const LoadingView(message: '正在加载动态...');
    }

    if (_items.isEmpty) {
      return EmptyView(
        message: '关注的UP主近期暂无新动态',
        icon: Icons.dynamic_feed_rounded,
        onRetry: () => _loadData(refresh: true),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
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
          scrollCacheExtent: ScrollCacheExtent.pixels(600.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          itemCount: _items.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, idx) {
            if (idx == _items.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
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
