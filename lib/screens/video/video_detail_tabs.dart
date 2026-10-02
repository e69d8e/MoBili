part of 'video_detail_screen.dart';

// ==========================================================
// 信息 Tab（简介）：自持关系状态（点赞/收藏/投币/关注/稍后再看），
// 交互 setState 仅重建本 Tab，不再波及整页与播放器
// ==========================================================
class _VideoInfoTab extends StatefulWidget {
  final _VideoDetailScreenState state;
  const _VideoInfoTab({super.key, required this.state});

  @override
  State<_VideoInfoTab> createState() => _VideoInfoTabState();
}

class _VideoInfoTabState extends State<_VideoInfoTab>
    with AutomaticKeepAliveClientMixin {
  _VideoDetailScreenState get state => widget.state;

  bool _isLiked = false;
  bool _isFav = false;
  bool _isFollowing = false;
  int _coinCount = 0;
  int _upFans = 0;
  bool _isInWatchLater = false;
  bool _descExpanded = false;
  int _loadedAid = 0;

  int get _effectiveAid =>
      state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid ?? 0;

  @override
  void initState() {
    super.initState();
    if (_effectiveAid > 0) {
      _loadedAid = _effectiveAid;
      _loadRelation();
    }
  }

  @override
  void didUpdateWidget(covariant _VideoInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final aid = _effectiveAid;
    if (aid != _loadedAid) {
      _loadedAid = aid;
      if (aid > 0) {
        _loadRelation();
      }
    }
  }

  Future<void> _loadRelation() async {
    final aid = state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid;
    // 关系状态与稍后再看状态无依赖，并行请求省一次往返
    final relationFuture = VideoApiService().getVideoRelation(
      bvid: state._currentBvid,
      aid: aid,
    );
    final watchLaterFuture = (aid != null && aid > 0)
        ? UserApiService().isInWatchLater(aid)
        : null;

    final relation = await relationFuture;
    if (relation != null && mounted) {
      setState(() {
        _isFollowing = relation.attention;
        _isLiked = relation.like;
        _isFav = relation.favorite;
        _coinCount = relation.coin;
      });
    }
    if (watchLaterFuture != null) {
      final inWL = await watchLaterFuture;
      if (mounted) {
        setState(() => _isInWatchLater = inWL);
      }
    }
    final ownerMid =
        state._detail?.videoItem.owner.mid ?? state.widget.initialVideo?.owner.mid;
    if (ownerMid != null && ownerMid > 0) {
      UserApiService().getUserRelationStat(ownerMid).then((stat) {
        if (stat != null && mounted) {
          setState(() {
            _upFans = stat.follower;
          });
        }
      });
    }
  }

  void _toggleLike() async {
    HapticFeedback.lightImpact();
    setState(() => _isLiked = !_isLiked);
    final ok = await VideoApiService().likeVideo(state._currentBvid, like: _isLiked);
    if (!ok && mounted) {
      AppToast.show(context, '请先登录', icon: Icons.info_outline_rounded);
      setState(() => _isLiked = !_isLiked);
    }
  }

  void _triggerTriple() async {
    HapticFeedback.heavyImpact();
    final ok = await VideoApiService().tripleCombo(state._currentBvid);
    if (mounted) {
      if (ok) {
        setState(() {
          _isLiked = true;
          _isFav = true;
          _coinCount = (_coinCount + 1).clamp(1, 2);
        });
        AppToast.show(context, '三连成功！', icon: Icons.auto_awesome_rounded);
      } else {
        AppToast.show(context, '三连失败，请先登录', icon: Icons.info_outline_rounded);
      }
    }
  }

  void _showFavoriteBottomSheet() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLogin || auth.userInfo.mid <= 0) {
      showDialog(context: context, builder: (ctx) => const LoginDialog());
      return;
    }

    final aid = state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid ?? 0;
    if (aid <= 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    VideoFavoriteFolderSheet.show(
      context,
      aid: aid,
      mid: auth.userInfo.mid,
      isDark: isDark,
      primaryColor: primaryColor,
      onFavStatusChanged: (isFav) {
        setState(() {
          _isFav = isFav;
        });
      },
    );
  }

  Future<void> _executeAddCoin(int selectedCoins, bool selectLike) async {
    final res = await VideoApiService().addCoin(
      bvid: state._currentBvid,
      multiply: selectedCoins,
      selectLike: selectLike,
    );
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _coinCount += selectedCoins;
        if (selectLike || res.liked) {
          _isLiked = true;
        }
      });
      AppToast.show(context, '投币成功！', icon: Icons.monetization_on_rounded);
    } else {
      AppToast.show(context, res.message, icon: Icons.info_outline_rounded);
    }
  }

  void _showCoinDialog() {
    VideoCoinDialog.show(
      context,
      coinCount: _coinCount,
      onConfirm: (selectedCoins, selectLike) =>
          _executeAddCoin(selectedCoins, selectLike),
    );
  }

  void _toggleFollow(int mid) async {
    setState(() => _isFollowing = !_isFollowing);
    final ok = await UserApiService().modifyRelation(
      mid,
      act: _isFollowing ? 1 : 2,
    );
    if (!ok && mounted) {
      setState(() => _isFollowing = !_isFollowing);
      AppToast.show(context, '操作失败，请先登录', icon: Icons.info_outline_rounded);
    } else if (mounted) {
      AppToast.show(context, _isFollowing ? '已关注' : '已取消关注');
    }
  }

  void _toggleWatchLater() async {
    final aid = state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid ?? 0;
    if (aid == 0) return;

    if (_isInWatchLater) {
      final ok = await UserApiService().deleteFromWatchLater(aid: aid);
      if (mounted) {
        if (ok) {
          setState(() => _isInWatchLater = false);
          AppToast.show(context, '已从稍后看移除', icon: Icons.check_circle_rounded);
        } else {
          AppToast.show(context, '移除失败，请先登录', icon: Icons.info_outline_rounded);
        }
      }
    } else {
      final ok = await UserApiService().addToWatchLater(
        aid: aid,
        bvid: state._currentBvid,
      );
      if (mounted) {
        if (ok) {
          setState(() => _isInWatchLater = true);
          AppToast.show(context, '已添加稍后看', icon: Icons.check_circle_rounded);
        } else {
          AppToast.show(context, '添加失败，请先登录', icon: Icons.info_outline_rounded);
        }
      }
    }
  }

  Widget _buildInfoTab() {
    if (state._detail == null && state.widget.initialVideo == null) {
      if (state._detailError) {
        return ErrorView(
          message: '视频详情加载失败，请检查网络',
          onRetry: state._loadAll,
        );
      }
      return const EmptyView(message: '暂无视频信息');
    }
    final item = state._detail?.videoItem ?? state.widget.initialVideo!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // 元信息合并为一行：播放 / 弹幕 / 发布时间（离线缓存等缺省项自动略过）
    final metaParts = <String>[
      if (item.stat.view > 0) '${Formatters.formatCount(item.stat.view)} 播放',
      if (item.stat.danmaku > 0)
        '${Formatters.formatCount(item.stat.danmaku)} 弹幕',
      if (Formatters.formatTime(item.pubdate).isNotEmpty)
        Formatters.formatTime(item.pubdate),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题 + 元信息（点击展开简介）
                InkWell(
                  onTap: () => setState(() => _descExpanded = !_descExpanded),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: context.colors.textMain,
                                ),
                              ),
                            ),
                            Icon(
                              _descExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: context.colors.textHint,
                            ),
                          ],
                        ),
                        if (metaParts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            metaParts.join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textHint,
                            ),
                          ),
                        ],
                        if (_descExpanded && item.desc.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.colors.fill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.desc,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: context.colors.textSub,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // UP 主行：头像 / 昵称 / 粉丝数 + 关注
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => state._navigateToUpSpace(item.owner.mid),
                      child: UserAvatar(url: item.owner.face, size: 36),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => state._navigateToUpSpace(item.owner.mid),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.owner.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textMain,
                              ),
                            ),
                            if (_upFans > 0) ...[
                              const SizedBox(height: 1),
                              Text(
                                '${Formatters.formatCount(_upFans)} 粉丝',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textHint,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Follow Button
                    FilledButton(
                      onPressed: () => _toggleFollow(item.owner.mid),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? (context.colors.fill)
                            : primaryColor,
                        foregroundColor: _isFollowing
                            ? (context.colors.textSub)
                            : Theme.of(context).colorScheme.onPrimary,
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isFollowing ? '已关注' : '+ 关注',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Action Buttons Bar (Like, Coin, Fav, Cache, Listen Video, Watch Later, Triple)
                AnimatedBuilder(
                  animation: VideoCacheService(),
                  builder: (context, _) {
                    final cid = state._detail != null && state._detail!.pages.isNotEmpty
                        ? state._detail!.pages[state._selectedPageIndex].cid
                        : (state._detail?.videoItem.cid ??
                              state.widget.initialVideo?.cid ??
                              0);
                    final isCached = VideoCacheService().isCached(
                      state._currentBvid,
                      cid,
                    );
                    final isDownloading = VideoCacheService()
                        .isDownloadingOrPending(state._currentBvid, cid);

                    return VideoActionBar(
                      likeCount: item.stat.like + (_isLiked ? 1 : 0),
                      isLiked: _isLiked,
                      tripleComboAnimation: state._tripleComboAnimController,
                      onLikeTap: _toggleLike,
                      onLikeLongPressStart: (_) {
                        final auth = context.read<AuthProvider>();
                        if (!auth.isLogin) {
                          showDialog(
                            context: context,
                            builder: (ctx) => const LoginDialog(),
                          );
                          return;
                        }
                        HapticFeedback.selectionClick();
                        state._tripleComboAnimController.forward(from: 0.0);
                      },
                      onLikeLongPressEnd: (_) {
                        if (state._tripleComboAnimController.isAnimating) {
                          state._tripleComboAnimController.reverse();
                        }
                      },
                      onLikeLongPressCancel: () {
                        if (state._tripleComboAnimController.isAnimating) {
                          state._tripleComboAnimController.reverse();
                        }
                      },
                      coinCount: _coinCount,
                      totalCoins: item.stat.coin,
                      onCoinTap: _showCoinDialog,
                      isFav: _isFav,
                      favCount: item.stat.favorite + (_isFav ? 1 : 0),
                      onFavTap: _showFavoriteBottomSheet,
                      isCached: isCached,
                      isDownloading: isDownloading,
                      onCacheTap: state._showCacheBottomSheet,
                      onListenTap: state._startListenMode,
                      isInWatchLater: _isInWatchLater,
                      onWatchLaterTap: _toggleWatchLater,
                    );
                  },
                ),

                // Watch Later Playlist (稍后看播放列表)
                if (state._watchLaterList != null && state._watchLaterList!.isNotEmpty)
                  VideoWatchLaterSection(
                    items: state._watchLaterList!,
                    currentIndex: state._currentWatchLaterIndex,
                    currentBvid: state._currentBvid,
                    onSelectItem: (item, idx) =>
                        state._switchWatchLaterItem(item, idx),
                    onTapMore: state._showWatchLaterBottomSheet,
                  ),

                // UGC Season (合集)
                if (state._detail?.ugcSeason != null &&
                    state._detail!.ugcSeason!.sections.isNotEmpty) ...[
                  Builder(
                    builder: (ctx) {
                      final season = state._detail!.ugcSeason!;
                      final episodes = season.sections
                          .expand((s) => s.episodes)
                          .toList();
                      if (episodes.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            '合集 · ${season.title}',
                            onMore: () => state._showUgcSeasonBottomSheet(season),
                            moreLabel: '共 ${season.epCount} 集',
                          ),
                          SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: episodes.length,
                              separatorBuilder: (c, _) =>
                                  const SizedBox(width: 8.0),
                              itemBuilder: (c, idx) {
                                final ep = episodes[idx];
                                return _infoChip(
                                  label: '${idx + 1}. ${ep.title}',
                                  selected: ep.bvid == state._currentBvid,
                                  onTap: () => state._switchEpisode(ep),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],

                // Video Chapters (视频章节)
                if (state._detail != null && state._detail!.chapters.isNotEmpty) ...[
                  _sectionHeader(
                    '章节',
                    count: '共 ${state._detail!.chapters.length} 节',
                  ),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state._detail!.chapters.length,
                      separatorBuilder: (ctx, _) => const SizedBox(width: 8.0),
                      itemBuilder: (ctx, idx) {
                        final ch = state._detail!.chapters[idx];
                        final timeStr = Formatters.formatDuration(ch.from);
                        return _infoChip(
                          badge: timeStr,
                          label: ch.title,
                          selected: false,
                          onTap: () {
                            state._playerKey.currentState?.controller?.seekTo(
                              Duration(seconds: ch.from),
                            );
                            state._playerKey.currentState?.play();
                            AppToast.show(context, '已跳转至 $timeStr ${ch.title}');
                          },
                        );
                      },
                    ),
                  ),
                ],

                // Multi-part Selector (分P选集)
                if (state._detail != null && state._detail!.pages.length > 1) ...[
                  _sectionHeader(
                    '选集',
                    count: '共 ${state._detail!.pages.length} 集',
                  ),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state._detail!.pages.length,
                      separatorBuilder: (ctx, _) => const SizedBox(width: 8.0),
                      itemBuilder: (ctx, idx) {
                        final page = state._detail!.pages[idx];
                        return _infoChip(
                          label: 'P${page.page} ${page.part}',
                          selected: state._selectedPageIndex == idx,
                          onTap: () => state._switchPart(idx),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (state._relatedVideos.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 8.0),
              child: Text(
                '相关推荐',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 16.0),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveGridConfig.calculateCrossAxisCount(
                  context,
                ),
                childAspectRatio:
                    ResponsiveGridConfig.calculateChildAspectRatio(context),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: state._relatedVideos.length,
              itemBuilder: (ctx, idx) {
                return RepaintBoundary(
                  child: VideoCard(
                    video: state._relatedVideos[idx],
                    onTap: () async {
                      await state._playerKey.currentState?.pause();
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (c) => VideoDetailScreen(
                            bvid: state._relatedVideos[idx].bvid,
                            initialVideo: state._relatedVideos[idx],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// 统一区块头：左侧标题（可带计数），右侧可选“更多”入口。
  Widget _sectionHeader(
    String title, {
    String? count,
    String? moreLabel,
    VoidCallback? onMore,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              count,
              style: TextStyle(fontSize: 12, color: context.colors.textHint),
            ),
          ],
          if (onMore != null)
            InkWell(
              onTap: onMore,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      moreLabel ?? '全部',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textHint,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: context.colors.textHint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 统一信息胶囊：选中 = 主题色浅底，未选中 = 中性底，无边框。
  Widget _infoChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? badge,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withValues(alpha: 0.12)
              : context.colors.fill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              Text(
                badge,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? primaryColor : context.colors.textMain,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildInfoTab();
  }
}

// ==========================================================
// 评论 Tab：自持评论数据与分页状态；aid/bvid 变化时自动刷新，
// 从未打开过评论 Tab 时不发起评论请求（懒加载）
// ==========================================================
class _VideoCommentsTab extends StatefulWidget {
  final _VideoDetailScreenState state;
  final ValueChanged<int>? onTotalCountChanged;
  const _VideoCommentsTab({required this.state, this.onTotalCountChanged});

  @override
  State<_VideoCommentsTab> createState() => _VideoCommentsTabState();
}

class _VideoCommentsTabState extends State<_VideoCommentsTab>
    with AutomaticKeepAliveClientMixin {
  _VideoDetailScreenState get state => widget.state;

  List<CommentItem> _comments = [];
  // 已加载评论的 rpid 集合：增量维护，避免每页去重时重建全量 Set（O(n²)）
  final Set<int> _knownRpid = {};
  int _commentNextCursor = 0;
  String _commentNextOffset = '';
  bool _commentIsEnd = false;
  int _commentTotalCount = 0;
  int _commentMode = 3; // 3: hot, 2: time
  int _commentPage = 1;
  bool _commentInMode2Stream = false;
  bool _commentLoading = false;
  bool _commentLoadingMore = false;

  String _loadedBvid = '';
  int _loadedAid = 0;

  void _reportCount() {
    widget.onTotalCountChanged?.call(_commentTotalCount);
  }

  @override
  void initState() {
    super.initState();
    final aid =
        state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid ?? 0;
    if (aid > 0) {
      _loadedAid = aid;
      _loadedBvid = state._currentBvid;
      _loadComments(aid, refresh: true);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoCommentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换视频（bvid 变化）时立即清空旧评论
    if (state._currentBvid != _loadedBvid) {
      _loadedBvid = state._currentBvid;
      _loadedAid = 0;
      _commentTotalCount = 0;
      _reportCount();
      setState(() {
        _comments = [];
        _knownRpid.clear();
        _commentPage = 1;
        _commentInMode2Stream = false;
        _commentNextCursor = 0;
        _commentNextOffset = '';
        _commentIsEnd = false;
      });
    }
    final aid =
        state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid ?? 0;
    if (aid > 0 && aid != _loadedAid) {
      _loadedAid = aid;
      _loadComments(aid, refresh: true);
    }
  }

  Future<void> _loadComments(int aid, {bool refresh = false}) async {
    if (_commentLoading) return;
    setState(() {
      _commentLoading = true;
      if (refresh) {
        _commentPage = 1;
        _commentInMode2Stream = false;
        _commentNextCursor = 0;
        _commentNextOffset = '';
        _commentIsEnd = false;
      }
    });

    final res = await CommentApiService().getComments(
      oid: aid,
      mode: _commentMode,
      next: _commentNextCursor,
      nextOffset: _commentNextOffset,
      pn: _commentPage,
    );

    if (mounted) {
      setState(() {
        if (refresh || _comments.isEmpty) {
          _comments = res.replies;
          _knownRpid
            ..clear()
            ..addAll(res.replies.map((c) => c.rpid));
        } else {
          for (final r in res.replies) {
            if (_knownRpid.add(r.rpid)) {
              _comments.add(r);
            }
          }
        }
        _commentNextCursor = res.nextCursor;
        _commentNextOffset = res.nextOffset;
        _commentIsEnd =
            res.isEnd &&
            (_comments.length >= res.totalCount || res.replies.isEmpty);
        if (res.totalCount > 0) {
          _commentTotalCount = res.totalCount;
        }
        _commentLoading = false;
      });
    }
  }

  void _loadMoreComments() async {
    if (_commentLoadingMore ||
        _commentLoading ||
        _commentIsEnd ||
        state._detail == null) {
      return;
    }
    setState(() => _commentLoadingMore = true);

    _commentPage++;

    int effectiveMode = _commentMode;
    int effectiveNext = _commentNextCursor;
    String effectiveOffset = _commentNextOffset;

    // If we started with hot preview (mode=3) and there is no cursor offset, transition to all comments stream
    if (_commentMode == 3 &&
        !_commentInMode2Stream &&
        effectiveOffset.isEmpty &&
        effectiveNext == 0) {
      effectiveMode = 2;
      effectiveNext = 0;
      _commentInMode2Stream = true;
    }

    final res = await CommentApiService().getComments(
      oid: state._detail!.videoItem.aid,
      mode: effectiveMode,
      next: effectiveNext,
      nextOffset: effectiveOffset,
      pn: _commentPage,
    );

    if (mounted) {
      setState(() {
        int addedCount = 0;
        for (final r in res.replies) {
          if (_knownRpid.add(r.rpid)) {
            _comments.add(r);
            addedCount++;
          }
        }
        _commentNextCursor = res.nextCursor;
        _commentNextOffset = res.nextOffset;
        _commentIsEnd =
            res.isEnd ||
            (res.replies.isEmpty || addedCount == 0) ||
            (_commentTotalCount > 0 && _comments.length >= _commentTotalCount);
        if (res.totalCount > 0) {
          _commentTotalCount = res.totalCount;
        }
        _commentLoadingMore = false;
      });
    }
  }

  void _switchCommentMode(int mode) {
    if (_commentMode == mode || state._detail == null) return;
    setState(() {
      _commentMode = mode;
      _comments = [];
      _knownRpid.clear();
      _commentPage = 1;
      _commentInMode2Stream = false;
      _commentNextCursor = 0;
      _commentNextOffset = '';
      _commentIsEnd = false;
    });
    _loadComments(state._detail!.videoItem.aid, refresh: true);
  }

  void _showSubRepliesBottomSheet(CommentItem rootComment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final aid = state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid ?? 0;

    VideoSubRepliesSheet.show(
      context,
      oid: aid,
      rootComment: rootComment,
      isDark: isDark,
      primaryColor: primaryColor,
    );
  }

  Future<void> _executeSendComment(
    int aid,
    String msg,
    int root,
    int parent,
  ) async {
    final res = await CommentApiService().sendComment(
      oid: aid,
      message: msg,
      root: root,
      parent: parent,
    );
    if (!mounted) return;
    if (res.success) {
      AppToast.show(context, '评论发表成功！', icon: Icons.check_circle_rounded);
      if (res.reply != null && root == 0) {
        setState(() {
          _comments.insert(0, res.reply!);
          _knownRpid.add(res.reply!.rpid);
          _commentTotalCount++;
        });
      } else {
        _loadComments(aid, refresh: true);
      }
    } else {
      AppToast.show(context, res.message, icon: Icons.info_outline_rounded);
    }
  }

  void _showCommentInputDialog({
    int root = 0,
    int parent = 0,
    String? replyToUname,
  }) async {
    final aid = state._detail?.videoItem.aid ?? state.widget.initialVideo?.aid ?? 0;
    if (aid == 0) return;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final textController = TextEditingController();

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      replyToUname != null ? '回复 @$replyToUname' : '发表评论',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: replyToUname != null
                        ? '回复 @$replyToUname...'
                        : '发一条友善的评论...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: context.colors.textHint,
                    ),
                    filled: true,
                    fillColor: context.colors.fill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12.0),
                  ),
                ),
                const SizedBox(height: 8.0),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      final msg = textController.text.trim();
                      if (msg.isEmpty) {
                        AppToast.show(
                          context,
                          '评论内容不能为空',
                          icon: Icons.info_outline_rounded,
                        );
                        return;
                      }
                      Navigator.of(ctx).pop();
                      _executeSendComment(aid, msg, root, parent);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('发送'),
                  ),
                ),
                const SizedBox(height: 12.0),
              ],
            ),
          );
        },
      );
    } finally {
      textController.dispose();
    }
  }

  Widget _buildCommentsTab(bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_commentLoading && _comments.isEmpty) {
      return const CommentSkeleton(itemCount: 6);
    }

    if (_comments.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: EmptyView(
              message: '暂无评论，快来抢沙发吧~',
              icon: Icons.chat_bubble_outline_rounded,
              onRetry: () => state._detail != null
                  ? _loadComments(state._detail!.videoItem.aid, refresh: true)
                  : null,
            ),
          ),
          _buildBottomCommentBar(isDark, primaryColor),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
                _loadMoreComments();
              }
              return false;
            },
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: () async {
                if (state._detail != null) {
                  await _loadComments(state._detail!.videoItem.aid, refresh: true);
                }
              },
              child: CustomScrollView(
                slivers: [
                  // Mode Header (Hot / Time)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '全部评论 (${_commentTotalCount > 0 ? Formatters.formatCount(_commentTotalCount) : _comments.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textSub,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _switchCommentMode(3),
                            child: Text(
                              '按热度',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _commentMode == 3
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _commentMode == 3
                                    ? primaryColor
                                    : (context.colors.textHint),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            '|',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.divider,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          GestureDetector(
                            onTap: () => _switchCommentMode(2),
                            child: Text(
                              '按时间',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _commentMode == 2
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _commentMode == 2
                                    ? primaryColor
                                    : (context.colors.textHint),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Comments List
                  SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, idx) {
                      final comment = _comments[idx];
                      return RepaintBoundary(
                        child: Column(
                          children: [
                            CommentItemWidget(
                              comment: comment,
                              onReplyTap: () =>
                                  _showSubRepliesBottomSheet(comment),
                              onSubRepliesTap: () =>
                                  _showSubRepliesBottomSheet(comment),
                            ),
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              indent: 58,
                              color: context.colors.divider,
                            ),
                          ],
                        ),
                      );
                    }, childCount: _comments.length),
                  ),

                  // Bottom loading or end footer
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Center(
                        child: _commentLoadingMore
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              )
                            : _commentIsEnd
                            ? Text(
                                '没有更多评论了',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textHint,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildBottomCommentBar(isDark, primaryColor),
      ],
    );
  }

  Widget _buildBottomCommentBar(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: context.colors.fill,
        border: Border(
          top: BorderSide(
            color: context.colors.divider,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => _showCommentInputDialog(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: context.colors.textHint,
                ),
                const SizedBox(width: 8.0),
                Text(
                  '发一条友善的评论...',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textHint,
                  ),
                ),
                const Spacer(),
                Icon(Icons.send_rounded, size: 16, color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCommentsTab(isDark);
  }
}

