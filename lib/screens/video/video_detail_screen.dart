import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/comment_model.dart';
import '../../models/danmaku_model.dart';
import '../../models/play_url_model.dart';
import '../../models/video_model.dart';
import '../../providers/listen_video_provider.dart';
import '../../services/api/bili_http_client.dart';
import '../../services/api/comment_api_service.dart';
import '../../services/api/danmaku_service.dart';
import '../../services/api/user_api_service.dart';
import '../../services/api/video_api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/comment_item_widget.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/player/bili_video_player.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/video_card.dart';
import '../up/up_space_screen.dart';
import 'listen_video_screen.dart';

class VideoDetailScreen extends StatefulWidget {
  final String bvid;
  final VideoItem? initialVideo;
  final Duration? initialPosition;

  const VideoDetailScreen({
    super.key,
    required this.bvid,
    this.initialVideo,
    this.initialPosition,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VideoDetail? _detail;
  PlayUrlInfo? _playUrlInfo;
  List<DanmakuItem> _danmakus = [];
  List<VideoItem> _relatedVideos = [];

  // Comments
  List<CommentItem> _comments = [];
  int _commentNextCursor = 0;
  String _commentNextOffset = '';
  bool _commentIsEnd = false;
  int _commentTotalCount = 0;
  int _commentMode = 3; // 3: hot, 2: time
  int _commentPage = 1;
  bool _commentInMode2Stream = false;
  bool _commentLoading = false;
  bool _commentLoadingMore = false;

  late String _currentBvid;
  int _selectedPageIndex = 0;
  bool _isLiked = false;
  bool _isFav = false;
  bool _isFollowing = false;
  int _coinCount = 0;
  bool _isInWatchLater = false;
  bool _descExpanded = false;
  bool _isLoading = true;
  bool _isPlayerFullScreen = false;

  @override
  void initState() {
    super.initState();
    _currentBvid = widget.bvid;
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    // 1. Fetch Video Detail
    final detail = await VideoApiService().getVideoDetail(_currentBvid);
    if (detail != null && mounted) {
      setState(() {
        _detail = detail;
      });

      // 2. Fetch User-Video Relation (attention/follow, like, fav, coin)
      _loadRelation();

      // 3. Fetch PlayUrl & Danmaku for selected Page (P1 default)
      final cid = detail.pages.isNotEmpty ? detail.pages[_selectedPageIndex].cid : detail.videoItem.cid;
      await _loadPlayUrlAndDanmaku(cid);

      // 4. Fetch Related Videos
      VideoApiService().getRelatedVideos(_currentBvid).then((list) {
        if (mounted) setState(() => _relatedVideos = list);
      });

      // 5. Fetch Comments with the real video AID
      _loadComments(detail.videoItem.aid, refresh: true);
    } else {
      _loadRelation();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRelation() async {
    final aid = _detail?.videoItem.aid ?? widget.initialVideo?.aid;
    final relation = await VideoApiService().getVideoRelation(
      bvid: _currentBvid,
      aid: aid,
    );
    if (relation != null && mounted) {
      setState(() {
        _isFollowing = relation.attention;
        _isLiked = relation.like;
        _isFav = relation.favorite;
        _coinCount = relation.coin;
      });
    }
    if (aid != null && aid > 0) {
      final inWL = await UserApiService().isInWatchLater(aid);
      if (mounted) {
        setState(() => _isInWatchLater = inWL);
      }
    }
  }

  int _videoLoadToken = 0;

  Future<void> _loadPlayUrlAndDanmaku(int cid) async {
    final token = ++_videoLoadToken;
    final playUrl = await VideoApiService().getVideoPlayUrl(bvid: _currentBvid, cid: cid);
    final danmakuList = await DanmakuService().getDanmakuList(cid);

    if (mounted && _videoLoadToken == token) {
      final listenProvider = context.read<ListenVideoProvider>();
      if (listenProvider.isPlaying) {
        await listenProvider.stopAndClear();
      }
      setState(() {
        _playUrlInfo = playUrl;
        _danmakus = danmakuList;
      });
    }
  }

  Future<void> _switchQuality(int qn) async {
    final token = ++_videoLoadToken;
    final cid = _detail != null && _detail!.pages.isNotEmpty
        ? _detail!.pages[_selectedPageIndex].cid
        : (_detail?.videoItem.cid ?? 0);

    final playUrl = await VideoApiService().getVideoPlayUrl(bvid: _currentBvid, cid: cid, qn: qn);
    if (playUrl != null && mounted && _videoLoadToken == token) {
      setState(() {
        _playUrlInfo = playUrl;
      });
      if (playUrl.currentQuality == qn) {
        AppToast.show(context, '已切换至 ${_getQualityName(qn)}');
      } else if (playUrl.currentQuality < qn) {
        final isLogin = BiliHttpClient().isLoggedIn;
        if (!isLogin) {
          AppToast.show(
            context,
            '${_getQualityName(qn)}需登录，已切换至 ${_getQualityName(playUrl.currentQuality)}',
            icon: Icons.info_outline_rounded,
          );
        } else if (qn >= 112) {
          AppToast.show(
            context,
            '${_getQualityName(qn)}需大会员，已切换至 ${_getQualityName(playUrl.currentQuality)}',
            icon: Icons.info_outline_rounded,
          );
        } else {
          AppToast.show(
            context,
            '已为当前流适配最高可用画质 ${_getQualityName(playUrl.currentQuality)}',
            icon: Icons.info_outline_rounded,
          );
        }
      }
    }
  }

  String _getQualityName(int q) {
    switch (q) {
      case 127:
        return '8K';
      case 120:
        return '4K';
      case 116:
        return '1080P 60帧';
      case 112:
        return '1080P 高码率';
      case 80:
        return '1080P 高清';
      case 74:
        return '720P 60帧';
      case 64:
        return '720P 高清';
      case 32:
        return '480P 清晰';
      case 16:
        return '360P 流畅';
      default:
        return '$q P';
    }
  }

  Future<void> _switchPart(int index) async {
    if (_detail == null || index >= _detail!.pages.length || index == _selectedPageIndex) return;
    setState(() {
      _selectedPageIndex = index;
      _playUrlInfo = null;
      _danmakus = [];
    });
    final cid = _detail!.pages[index].cid;
    await _loadPlayUrlAndDanmaku(cid);
  }

  Future<void> _switchEpisode(UgcEpisode ep) async {
    if (ep.bvid == _currentBvid) return;
    setState(() {
      _currentBvid = ep.bvid;
      _selectedPageIndex = 0;
      _isLoading = true;
      _playUrlInfo = null;
      _danmakus = [];
      _comments = [];
      _relatedVideos = [];
    });

    final detail = await VideoApiService().getVideoDetail(_currentBvid);
    if (detail != null && mounted) {
      setState(() {
        _detail = detail;
      });

      final cid = detail.pages.isNotEmpty ? detail.pages[0].cid : (ep.cid != 0 ? ep.cid : detail.videoItem.cid);
      await _loadPlayUrlAndDanmaku(cid);

      VideoApiService().getRelatedVideos(_currentBvid).then((list) {
        if (mounted) setState(() => _relatedVideos = list);
      });

      _loadComments(detail.videoItem.aid, refresh: true);
      _loadRelation();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showUgcSeasonBottomSheet(UgcSeason season) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEpisodes = season.sections.expand((s) => s.episodes).toList();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '合集选集',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final dialogWidth = screenWidth > 380 ? 290.0 : (screenWidth * 0.78);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              constraints: const BoxConstraints(maxHeight: 420),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xC7181820) : const Color(0xEBFFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.video_library_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '合集选集',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${season.title} · 共${season.epCount}集',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                      ),
                      const SizedBox(height: 8),

                      // Episode List
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: allEpisodes.length,
                          separatorBuilder: (c, _) => const SizedBox(height: 6),
                          itemBuilder: (c, idx) {
                            final ep = allEpisodes[idx];
                            final isPlaying = ep.bvid == _currentBvid;
                            final primaryColor = Theme.of(context).colorScheme.primary;
                            return InkWell(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _switchEpisode(ep);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isPlaying
                                      ? primaryColor.withValues(alpha: 0.14)
                                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPlaying ? primaryColor : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (isPlaying)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6.0),
                                        child: Icon(Icons.play_circle_fill_rounded, color: primaryColor, size: 14),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${idx + 1}. ${ep.title}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                              color: isPlaying
                                                  ? primaryColor
                                                  : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                                            ),
                                          ),
                                          if (ep.duration > 0) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              Formatters.formatDuration(ep.duration),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
        } else {
          final existingIds = _comments.map((c) => c.rpid).toSet();
          for (final r in res.replies) {
            if (!existingIds.contains(r.rpid)) {
              _comments.add(r);
            }
          }
        }
        _commentNextCursor = res.nextCursor;
        _commentNextOffset = res.nextOffset;
        _commentIsEnd = res.isEnd && (_comments.length >= res.totalCount || res.replies.isEmpty);
        if (res.totalCount > 0) {
          _commentTotalCount = res.totalCount;
        }
        _commentLoading = false;
      });
    }
  }

  void _loadMoreComments() async {
    if (_commentLoadingMore || _commentLoading || _commentIsEnd || _detail == null) return;
    setState(() => _commentLoadingMore = true);

    _commentPage++;

    int effectiveMode = _commentMode;
    int effectiveNext = _commentNextCursor;
    String effectiveOffset = _commentNextOffset;

    // If we started with hot preview (mode=3) and there is no cursor offset, transition to all comments stream
    if (_commentMode == 3 && !_commentInMode2Stream && effectiveOffset.isEmpty && effectiveNext == 0) {
      effectiveMode = 2;
      effectiveNext = 0;
      _commentInMode2Stream = true;
    }

    final res = await CommentApiService().getComments(
      oid: _detail!.videoItem.aid,
      mode: effectiveMode,
      next: effectiveNext,
      nextOffset: effectiveOffset,
      pn: _commentPage,
    );

    if (mounted) {
      setState(() {
        final existingIds = _comments.map((c) => c.rpid).toSet();
        int addedCount = 0;
        for (final r in res.replies) {
          if (!existingIds.contains(r.rpid)) {
            _comments.add(r);
            addedCount++;
          }
        }
        _commentNextCursor = res.nextCursor;
        _commentNextOffset = res.nextOffset;
        _commentIsEnd = res.isEnd || (res.replies.isEmpty || addedCount == 0) || (_commentTotalCount > 0 && _comments.length >= _commentTotalCount);
        if (res.totalCount > 0) {
          _commentTotalCount = res.totalCount;
        }
        _commentLoadingMore = false;
      });
    }
  }

  void _switchCommentMode(int mode) {
    if (_commentMode == mode || _detail == null) return;
    setState(() {
      _commentMode = mode;
      _comments = [];
      _commentPage = 1;
      _commentInMode2Stream = false;
      _commentNextCursor = 0;
      _commentNextOffset = '';
      _commentIsEnd = false;
    });
    _loadComments(_detail!.videoItem.aid, refresh: true);
  }

  void _navigateToUpSpace(int mid) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => UpSpaceScreen(mid: mid),
      ),
    );
    if (mounted) {
      _loadRelation();
    }
  }

  void _toggleLike() async {
    setState(() => _isLiked = !_isLiked);
    final ok = await VideoApiService().likeVideo(_currentBvid, like: _isLiked);
    if (!ok && mounted) {
      AppToast.show(context, '请先登录', icon: Icons.info_outline_rounded);
      setState(() => _isLiked = !_isLiked);
    }
  }

  void _triggerTriple() async {
    final ok = await VideoApiService().tripleCombo(_currentBvid);
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

  Future<void> _executeAddCoin(int selectedCoins, bool selectLike) async {
    final res = await VideoApiService().addCoin(
      bvid: _currentBvid,
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
    if (_coinCount >= 2) {
      AppToast.show(context, '上限2枚硬币，您已投过2枚硬币啦', icon: Icons.monetization_on_rounded);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    int selectedCoins = 1;
    final maxAvailable = 2 - _coinCount;
    bool selectLike = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text('给UP主投币', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _coinCount > 0 ? '已投 $_coinCount 枚硬币，还能投 $maxAvailable 枚' : '选择投币数量：',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('1 硬币'),
                        selected: selectedCoins == 1,
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: selectedCoins == 1
                              ? Theme.of(context).colorScheme.onPrimary
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: selectedCoins == 1 ? FontWeight.bold : FontWeight.normal,
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setDialogState(() => selectedCoins = 1),
                      ),
                      if (maxAvailable >= 2) ...[
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('2 硬币'),
                          selected: selectedCoins == 2,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: selectedCoins == 2
                                ? Theme.of(context).colorScheme.onPrimary
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: selectedCoins == 2 ? FontWeight.bold : FontWeight.normal,
                          ),
                          showCheckmark: false,
                          onSelected: (_) => setDialogState(() => selectedCoins = 2),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => setDialogState(() => selectLike = !selectLike),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selectLike,
                            activeColor: primaryColor,
                            onChanged: (val) => setDialogState(() => selectLike = val ?? true),
                          ),
                          const Text('同时点赞视频', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('取消', style: TextStyle(color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight)),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _executeAddCoin(selectedCoins, selectLike);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('确定投币'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleFollow(int mid) async {
    setState(() => _isFollowing = !_isFollowing);
    final ok = await UserApiService().modifyRelation(mid, act: _isFollowing ? 1 : 2);
    if (!ok && mounted) {
      setState(() => _isFollowing = !_isFollowing);
      AppToast.show(context, '操作失败，请先登录', icon: Icons.info_outline_rounded);
    } else if (mounted) {
      AppToast.show(context, _isFollowing ? '已关注' : '已取消关注');
    }
  }

  void _toggleWatchLater() async {
    final aid = _detail?.videoItem.aid ?? widget.initialVideo?.aid ?? 0;
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
      final ok = await UserApiService().addToWatchLater(aid: aid, bvid: _currentBvid);
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

  void _showSubRepliesBottomSheet(CommentItem rootComment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final aid = _detail?.videoItem.aid ?? widget.initialVideo?.aid ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SubRepliesSheet(
          oid: aid,
          rootComment: rootComment,
          isDark: isDark,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Future<void> _executeSendComment(int aid, String msg, int root, int parent) async {
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
          _commentTotalCount++;
        });
      } else {
        _loadComments(aid, refresh: true);
      }
    } else {
      AppToast.show(context, res.message, icon: Icons.info_outline_rounded);
    }
  }

  void _showCommentInputDialog({int root = 0, int parent = 0, String? replyToUname}) {
    final aid = _detail?.videoItem.aid ?? widget.initialVideo?.aid ?? 0;
    if (aid == 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: replyToUname != null ? '回复 @$replyToUname...' : '发一条友善的评论...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    final msg = textController.text.trim();
                    if (msg.isEmpty) {
                      AppToast.show(context, '评论内容不能为空', icon: Icons.info_outline_rounded);
                      return;
                    }
                    Navigator.of(ctx).pop();
                    _executeSendComment(aid, msg, root, parent);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('发送'),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  final GlobalKey<BiliVideoPlayerState> _playerKey = GlobalKey<BiliVideoPlayerState>();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startListenMode() async {
    final video = _detail?.videoItem ?? widget.initialVideo;
    final url = _playUrlInfo?.primaryVideoUrl;
    if (video == null || url == null || url.isEmpty) {
      AppToast.show(context, '正在获取播放地址，请稍候...', icon: Icons.info_outline_rounded);
      return;
    }

    final pos = _playerKey.currentState?.controller?.value.position ?? Duration.zero;
    final speed = _playerKey.currentState?.playbackSpeed ?? 1.0;
    
    // Explicitly pause the video and danmaku
    await _playerKey.currentState?.pause();

    final totalDur = (_playUrlInfo != null && _playUrlInfo!.timelength > 0)
        ? Duration(milliseconds: _playUrlInfo!.timelength)
        : (video.duration > 0 ? Duration(seconds: video.duration) : null);

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ListenVideoScreen(
          bvid: video.bvid,
          cid: video.cid,
          title: video.title,
          coverUrl: video.pic,
          upName: video.owner.name,
          playUrl: _playUrlInfo?.primaryVideoUrl,
          initialPosition: pos,
          totalDuration: totalDur,
          initialSpeed: speed,
          onSwitchToVideo: (curPos) async {
            await _playerKey.currentState?.controller?.seekTo(curPos);
            await _playerKey.currentState?.play();
          },
        ),
      ),
    );
  }

  Widget _buildPlayer(VideoItem? video, Color primaryColor) {
    if (_playUrlInfo != null) {
      return BiliVideoPlayer(
        key: _playerKey,
        playUrlInfo: _playUrlInfo!,
        danmakus: _danmakus,
        title: video?.title ?? '',
        initialPosition: widget.initialPosition,
        onQualityChanged: _switchQuality,
        onFullScreenChanged: (full) {
          setState(() => _isPlayerFullScreen = full);
        },
        onListenMode: _startListenMode,
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null && video.pic.isNotEmpty)
              NetworkImageView(
                url: video.pic,
                fit: BoxFit.cover,
                memCacheWidth: 640,
                memCacheHeight: 360,
              ),
            Container(color: Colors.black45),
            Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isFullScreen = _isPlayerFullScreen || isLandscape;
    final video = _detail?.videoItem ?? widget.initialVideo;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: !isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isFullScreen) {
          _playerKey.currentState?.exitFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: isFullScreen ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          top: !isFullScreen,
          bottom: false,
          left: !isFullScreen,
          right: !isFullScreen,
          child: Column(
            children: [
              // Top: Video Player (Full height in landscape/fullscreen, 16:9 in portrait)
              if (isFullScreen)
                Expanded(
                  child: _buildPlayer(video, primaryColor),
                )
              else
                _buildPlayer(video, primaryColor),

              // Tab Bar & Details (only when NOT fullscreen)
              if (!isFullScreen) ...[
                // Tab Bar: 简介 / 评论
                Container(
                  height: 40,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryColor,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: primaryColor,
                    unselectedLabelColor: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    unselectedLabelStyle: const TextStyle(fontSize: 13.5),
                    dividerColor: Colors.transparent,
                    dividerHeight: 0,
                    tabs: [
                      const Tab(text: '简介'),
                      Tab(text: '评论 ${_commentTotalCount > 0 ? Formatters.formatCount(_commentTotalCount) : (_detail?.videoItem.stat.reply != null ? Formatters.formatCount(_detail!.videoItem.stat.reply) : "")}'),
                    ],
                  ),
                ),

                // Tab View Body
                Expanded(
                  child: _isLoading && _detail == null
                      ? const LoadingView(message: '正在加载视频详情...')
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildInfoTab(isDark),
                            _buildCommentsTab(isDark),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab(bool isDark) {
    if (_detail == null && widget.initialVideo == null) {
      return const EmptyView(message: '暂无视频信息');
    }
    final item = _detail?.videoItem ?? widget.initialVideo!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // UP Profile Row
          Row(
            children: [
              GestureDetector(
                onTap: () => _navigateToUpSpace(item.owner.mid),
                child: UserAvatar(
                  url: item.owner.face,
                  size: 38,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateToUpSpace(item.owner.mid),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.owner.name,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.formatTime(item.pubdate)} · ${item.bvid}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Follow Button
              FilledButton(
                onPressed: () => _toggleFollow(item.owner.mid),
                style: FilledButton.styleFrom(
                  backgroundColor: _isFollowing
                      ? (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight)
                      : primaryColor,
                  foregroundColor: _isFollowing
                      ? (isDark ? AppTheme.textSubDark : AppTheme.textSubLight)
                      : Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isFollowing ? '已关注' : '+ 关注',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Video Title & Description
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
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                            color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                          ),
                        ),
                      ),
                      Icon(
                        _descExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Stats Row
                  Row(
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 14,
                        color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${Formatters.formatCount(item.stat.view)} 播放',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.subtitles_outlined,
                        size: 12,
                        color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${Formatters.formatCount(item.stat.danmaku)} 弹幕',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                    ],
                  ),
                  if (_descExpanded && item.desc.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.desc,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons Bar (Like, Coin, Fav, Watch Later, Listen Video, Triple)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: _isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                label: Formatters.formatCount(item.stat.like + (_isLiked ? 1 : 0)),
                active: _isLiked,
                onTap: _toggleLike,
              ),
              _buildActionButton(
                icon: _coinCount > 0 ? Icons.monetization_on_rounded : Icons.monetization_on_outlined,
                label: _coinCount > 0 ? '已投$_coinCount币' : Formatters.formatCount(item.stat.coin),
                active: _coinCount > 0,
                onTap: _showCoinDialog,
              ),
              _buildActionButton(
                icon: _isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                label: Formatters.formatCount(item.stat.favorite + (_isFav ? 1 : 0)),
                active: _isFav,
                onTap: () => setState(() => _isFav = !_isFav),
              ),
              _buildActionButton(
                icon: Icons.headphones_rounded,
                label: '听视频',
                active: false,
                onTap: _startListenMode,
              ),
              _buildActionButton(
                icon: _isInWatchLater ? Icons.watch_later_rounded : Icons.watch_later_outlined,
                label: _isInWatchLater ? '已添加' : '稍后看',
                active: _isInWatchLater,
                onTap: _toggleWatchLater,
              ),
              _buildActionButton(
                icon: Icons.auto_awesome_rounded,
                label: '三连',
                active: _isLiked && _isFav && _coinCount > 0,
                color: primaryColor,
                onTap: _triggerTriple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // UGC Season (合集)
          if (_detail?.ugcSeason != null && _detail!.ugcSeason!.sections.isNotEmpty) ...[
            Builder(builder: (ctx) {
              final season = _detail!.ugcSeason!;
              final episodes = season.sections.expand((s) => s.episodes).toList();
              if (episodes.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark.withValues(alpha: 0.5) : AppTheme.surfaceLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.video_library_rounded, size: 16, color: primaryColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '合集 · ${season.title}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _showUgcSeasonBottomSheet(season),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  '共 ${season.epCount} 集',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: episodes.length,
                        separatorBuilder: (c, _) => const SizedBox(width: 8),
                        itemBuilder: (c, idx) {
                          final ep = episodes[idx];
                          final isPlaying = ep.bvid == _currentBvid;
                          return InkWell(
                            onTap: () => _switchEpisode(ep),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isPlaying
                                    ? primaryColor.withValues(alpha: 0.12)
                                    : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPlaying ? primaryColor : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPlaying) ...[
                                    Icon(Icons.play_arrow_rounded, size: 14, color: primaryColor),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    '${idx + 1}. ${ep.title}',
                                    style: TextStyle(
                                      color: isPlaying
                                          ? primaryColor
                                          : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                                      fontSize: 11.5,
                                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Multi-part Selector (分P选集)
          if (_detail != null && _detail!.pages.length > 1) ...[
            Row(
              children: [
                const Text('分P选集', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Text(
                  '共 ${_detail!.pages.length} 集',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _detail!.pages.length,
                separatorBuilder: (ctx, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final page = _detail!.pages[idx];
                  final isSelected = _selectedPageIndex == idx;
                  return InkWell(
                    onTap: () => _switchPart(idx),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: 0.12)
                            : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'P${page.page} ${page.part}',
                        style: TextStyle(
                          color: isSelected
                              ? primaryColor
                              : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  ),
    if (_relatedVideos.isNotEmpty) ...[
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Text('相关推荐', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.96,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _relatedVideos.length,
          itemBuilder: (ctx, idx) {
            return RepaintBoundary(
              child: VideoCard(video: _relatedVideos[idx]),
            );
          },
        ),
      ),
    ],
  ],
);
}

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool active,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? activeColor : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: active ? activeColor : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsTab(bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_commentLoading && _comments.isEmpty) {
      return const LoadingView(message: '加载评论中...');
    }

    if (_comments.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: EmptyView(
              message: '暂无评论，快来抢沙发吧~',
              icon: Icons.chat_bubble_outline_rounded,
              onRetry: () => _detail != null ? _loadComments(_detail!.videoItem.aid, refresh: true) : null,
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
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                _loadMoreComments();
              }
              return false;
            },
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: () async {
                if (_detail != null) {
                  await _loadComments(_detail!.videoItem.aid, refresh: true);
                }
              },
              child: CustomScrollView(
                slivers: [
                  // Mode Header (Hot / Time)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            '全部评论 (${_commentTotalCount > 0 ? Formatters.formatCount(_commentTotalCount) : _comments.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _switchCommentMode(3),
                            child: Text(
                              '按热度',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: _commentMode == 3 ? FontWeight.bold : FontWeight.normal,
                                color: _commentMode == 3
                                    ? primaryColor
                                    : (isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '|',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _switchCommentMode(2),
                            child: Text(
                              '按时间',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: _commentMode == 2 ? FontWeight.bold : FontWeight.normal,
                                color: _commentMode == 2
                                    ? primaryColor
                                    : (isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Comments List
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final comment = _comments[idx];
                        return RepaintBoundary(
                          child: Column(
                            children: [
                              CommentItemWidget(
                                comment: comment,
                                onReplyTap: () => _showSubRepliesBottomSheet(comment),
                                onSubRepliesTap: () => _showSubRepliesBottomSheet(comment),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 58,
                                color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _comments.length,
                    ),
                  ),

                  // Bottom loading or end footer
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: _commentLoadingMore
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                              )
                            : _commentIsEnd
                                ? Text(
                                    '没有更多评论了',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                ),
                const SizedBox(width: 8),
                Text(
                  '发一条友善的评论...',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.send_rounded,
                  size: 16,
                  color: primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubRepliesSheet extends StatefulWidget {
  final int oid;
  final CommentItem rootComment;
  final bool isDark;
  final Color primaryColor;

  const _SubRepliesSheet({
    required this.oid,
    required this.rootComment,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<_SubRepliesSheet> createState() => _SubRepliesSheetState();
}

class _SubRepliesSheetState extends State<_SubRepliesSheet> {
  final List<CommentItem> _subReplies = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isEnd = false;
  final TextEditingController _inputController = TextEditingController();
  CommentItem? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadSubReplies();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadSubReplies() async {
    setState(() => _isLoading = true);
    final list = await CommentApiService().getSubComments(
      oid: widget.oid,
      rootRpid: widget.rootComment.rpid,
      pn: 1,
      ps: 20,
    );
    if (mounted) {
      setState(() {
        _subReplies.clear();
        _subReplies.addAll(list);
        _page = 1;
        _isLoading = false;
        _isEnd = list.length < 20;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isEnd) return;
    setState(() => _isLoadingMore = true);
    _page++;
    final more = await CommentApiService().getSubComments(
      oid: widget.oid,
      rootRpid: widget.rootComment.rpid,
      pn: _page,
      ps: 20,
    );
    if (mounted) {
      setState(() {
        _subReplies.addAll(more);
        _isLoadingMore = false;
        _isEnd = more.isEmpty || more.length < 20;
      });
    }
  }

  void _sendReply() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final targetParent = _replyingTo?.rpid ?? widget.rootComment.rpid;
    final res = await CommentApiService().sendComment(
      oid: widget.oid,
      message: text,
      root: widget.rootComment.rpid,
      parent: targetParent,
    );

    if (mounted) {
      if (res.success) {
        _inputController.clear();
        setState(() => _replyingTo = null);
        AppToast.show(context, '回复发送成功！', icon: Icons.check_circle_rounded);
        if (res.reply != null) {
          setState(() {
            _subReplies.add(res.reply!);
          });
        } else {
          _loadSubReplies();
        }
      } else {
        AppToast.show(context, res.message, icon: Icons.info_outline_rounded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final root = widget.rootComment;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '回复详情 (${root.rcount > 0 ? root.rcount : _subReplies.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: widget.isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),

          // Scrollable area
          Expanded(
            child: _isLoading
                ? const LoadingView(message: '加载回复中...')
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: 1 + (_subReplies.isEmpty ? 1 : _subReplies.length) + (_isLoadingMore || (_isEnd && _subReplies.isNotEmpty) ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 0: Root Comment Item
                        if (index == 0) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.02),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: CommentItemWidget(
                                  comment: root,
                                  onReplyTap: () {
                                    setState(() => _replyingTo = root);
                                  },
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                color: widget.isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                              ),
                            ],
                          );
                        }

                        // Empty State
                        if (_subReplies.isEmpty && index == 1) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                '暂无更多子级回复',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        // Sub Reply Items
                        final subIndex = index - 1;
                        if (subIndex < _subReplies.length) {
                          final sub = _subReplies[subIndex];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CommentItemWidget(
                                comment: sub,
                                onReplyTap: () {
                                  setState(() => _replyingTo = sub);
                                },
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 58,
                                color: widget.isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                              ),
                            ],
                          );
                        }

                        // Footer (Loading More or End Indicator)
                        if (_isLoadingMore) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: widget.primaryColor,
                                ),
                              ),
                            ),
                          );
                        }

                        if (_isEnd && _subReplies.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                '没有更多回复了',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                ),
                              ),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
          ),

          // Bottom Reply Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: widget.isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              border: Border(
                top: BorderSide(
                  color: widget.isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDark ? AppTheme.cardDark : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? '回复 @${_replyingTo!.member.uname}...'
                            : '回复 @${root.member.uname}...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: widget.isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.send_rounded, color: widget.primaryColor, size: 20),
                  onPressed: _sendReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

