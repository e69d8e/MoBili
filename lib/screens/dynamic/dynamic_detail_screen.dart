import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/comment_model.dart';
import '../../models/dynamic_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/bili_http_client.dart';
import '../../services/api/comment_api_service.dart';
import '../../services/api/dynamic_api_service.dart';
import '../../services/api/user_api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/image_decode_sizing.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/audio/mini_audio_player.dart';
import '../../widgets/comment_item_widget.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../profile/login_dialog.dart';
import '../up/up_space_screen.dart';
import '../video/video_detail_screen.dart';

class DynamicDetailScreen extends StatefulWidget {
  final String dynamicId;
  final DynamicItem? initialItem;

  const DynamicDetailScreen({
    super.key,
    required this.dynamicId,
    this.initialItem,
  });

  @override
  State<DynamicDetailScreen> createState() => _DynamicDetailScreenState();
}

class _DynamicDetailScreenState extends State<DynamicDetailScreen> {
  DynamicItem? _item;
  bool _isLoading = true;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isFollowing = false;

  // Comments State
  final List<CommentItem> _comments = [];
  // 已加载评论的 rpid 集合：增量维护，避免每页去重时重建全量 Set（O(n²)）
  final Set<int> _knownRpid = {};
  int _commentMode = 3; // 3: 热门, 2: 最新
  int _commentNextCursor = 0;
  String _commentNextOffset = '';
  bool _commentIsEnd = false;
  int _commentTotalCount = 0;
  bool _commentLoading = false;
  bool _commentLoadingMore = false;
  int _commentPage = 1;

  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  CommentItem? _replyTarget;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    if (_item != null) {
      _isLiked = _item!.stat.isLiked;
      _likeCount = _item!.stat.likeCount;
      _isLoading = false;
      _loadComments(refresh: true);
      _checkUpRelation();
    }
    _loadDynamicDetail();
  }

  @override
  void dispose() {
    _commentInputController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkUpRelation() async {
    if (_item != null && _item!.author.mid > 0) {
      try {
        final info = await UserApiService().getUpSpaceInfo(_item!.author.mid);
        if (info != null && mounted) {
          setState(() {
            _isFollowing = info.isFollowing;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadDynamicDetail() async {
    try {
      final detail = await DynamicApiService().getDynamicDetail(widget.dynamicId);
      if (mounted && detail != null) {
        setState(() {
          // 详情接口可能缺少列表里已有的数据（例如图文接口只回摘要），
          // 合并后再展示，避免内容被覆盖成空或残缺。
          final merged = DynamicItem.merge(detail, _item) ?? detail;
          _item = merged;
          _isLiked = merged.stat.isLiked;
          _likeCount = merged.stat.likeCount;
          _isLoading = false;
        });

        if (_comments.isEmpty) {
          _loadComments(refresh: true);
        }
        _checkUpRelation();
      }
    } catch (_) {
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _commentOid => _item?.commentId ?? (int.tryParse(widget.dynamicId) ?? 0);
  int get _commentType => _item?.commentType ?? 17;

  Future<void> _loadComments({bool refresh = false}) async {
    final oid = _commentOid;
    if (oid <= 0) {
      if (mounted) {
        setState(() {
          _commentLoading = false;
          _commentLoadingMore = false;
        });
      }
      return;
    }

    if (refresh) {
      setState(() {
        _commentLoading = true;
        _commentNextCursor = 0;
        _commentNextOffset = '';
        _commentIsEnd = false;
        _commentPage = 1;
      });
    }

    try {
      final res = await CommentApiService().getComments(
        oid: oid,
        type: _commentType,
        mode: _commentMode,
        next: refresh ? 0 : _commentNextCursor,
        nextOffset: refresh ? '' : _commentNextOffset,
        pn: refresh ? 1 : _commentPage,
        ps: 20,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _comments.clear();
            _knownRpid.clear();
            _comments.addAll(res.replies);
            for (final r in res.replies) {
              _knownRpid.add(r.rpid);
            }
          } else {
            int added = 0;
            for (final r in res.replies) {
              if (_knownRpid.add(r.rpid)) {
                _comments.add(r);
                added++;
              }
            }
            if (res.replies.isEmpty || added == 0) {
              _commentIsEnd = true;
            }
          }
          _commentNextCursor = res.nextCursor;
          _commentNextOffset = res.nextOffset;
          _commentIsEnd = _commentIsEnd || res.isEnd || (_commentTotalCount > 0 && _comments.length >= _commentTotalCount);
          if (res.totalCount > 0) {
            _commentTotalCount = res.totalCount;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _commentLoading = false;
          _commentLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_commentLoadingMore || _commentLoading || _commentIsEnd || _comments.isEmpty) return;
    final oid = _commentOid;
    if (oid <= 0) return;

    setState(() => _commentLoadingMore = true);
    _commentPage++;
    await _loadComments(refresh: false);
  }

  void _switchCommentMode(int mode) {
    if (_commentMode == mode) return;
    setState(() {
      _commentMode = mode;
    });
    _loadComments(refresh: true);
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const LoginDialog(),
    );
  }

  void _toggleLike() async {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    if (!auth.isLogin || BiliHttpClient().biliJct == null) {
      _showLoginDialog();
      return;
    }

    final targetLike = !_isLiked;
    setState(() {
      _isLiked = targetLike;
      _likeCount += targetLike ? 1 : -1;
    });

    final ok = await DynamicApiService().likeDynamic(widget.dynamicId, like: targetLike);
    if (!ok && mounted) {
      setState(() {
        _isLiked = !targetLike;
        _likeCount += targetLike ? -1 : 1;
      });
      AppToast.show(context, '点赞操作失败，请重试');
    }
  }

  void _toggleFollow() async {
    HapticFeedback.lightImpact();
    if (_item == null || _item!.author.mid <= 0) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLogin) {
      _showLoginDialog();
      return;
    }

    final targetFollow = !_isFollowing;
    setState(() => _isFollowing = targetFollow);
    final ok = await UserApiService().modifyRelation(_item!.author.mid, act: targetFollow ? 1 : 2);
    if (!ok && mounted) {
      setState(() => _isFollowing = !targetFollow);
      AppToast.show(context, '操作失败，请重试');
    }
  }

  void _startReply(CommentItem item) {
    setState(() {
      _replyTarget = item;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyTarget = null;
    });
    _commentInputController.clear();
    _commentFocusNode.unfocus();
  }

  Future<void> _sendComment() async {
    final text = _commentInputController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLogin) {
      _showLoginDialog();
      return;
    }

    final oid = _commentOid;
    if (oid <= 0) return;

    setState(() => _isSendingComment = true);

    int root = 0;
    int parent = 0;
    if (_replyTarget != null) {
      root = _replyTarget!.root > 0 ? _replyTarget!.root : _replyTarget!.rpid;
      parent = _replyTarget!.rpid;
    }

    final res = await CommentApiService().sendComment(
      oid: oid,
      type: _commentType,
      message: text,
      root: root,
      parent: parent,
    );

    if (mounted) {
      setState(() => _isSendingComment = false);
      if (res.success) {
        _commentInputController.clear();
        _commentFocusNode.unfocus();
        setState(() {
          _replyTarget = null;
          if (res.reply != null) {
            _comments.insert(0, res.reply!);
            _knownRpid.add(res.reply!.rpid);
            _commentTotalCount++;
          }
        });
        AppToast.show(context, '评论发表成功', icon: Icons.check_circle_outline_rounded);
      } else {
        AppToast.show(context, res.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('动态详情', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadDynamicDetail();
              _loadComments(refresh: true);
            },
          ),
        ],
      ),
      bottomNavigationBar: const MiniAudioPlayer(),
      body: _isLoading && _item == null
          ? const LoadingView(message: '加载动态详情...')
          : _item == null
              ? ErrorView(
                  message: '动态不存在或已被删除',
                  onRetry: _loadDynamicDetail,
                )
              : Column(
                  children: [
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          if (scrollInfo is ScrollUpdateNotification &&
                              scrollInfo.metrics.maxScrollExtent > 50 &&
                              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                            _loadMoreComments();
                          }
                          return false;
                        },
                        child: CustomScrollView(
                          slivers: [
                            // Dynamic Main Content Card（正文分段懒加载）
                            ..._buildContentSlivers(context, _item!, isDark, primaryColor),

                            // Divider & Comments Header
                            SliverToBoxAdapter(
                              child: _buildCommentsHeader(isDark, primaryColor),
                            ),

                          // Comments List
                          if (_commentLoading && _comments.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 36),
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else if (_comments.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    '暂无评论，快来抢沙发吧~',
                                    style: TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, idx) {
                                  final comment = _comments[idx];
                                  return RepaintBoundary(
                                    child: CommentItemWidget(
                                      comment: comment,
                                      onReplyTap: () => _startReply(comment),
                                    ),
                                  );
                                },
                                childCount: _comments.length,
                                // 评论项各自带 RepaintBoundary，无需自动保活包装
                                addAutomaticKeepAlives: false,
                              ),
                            ),

                          if (_commentLoadingMore)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                                ),
                              ),
                            )
                          else if (_commentIsEnd && _comments.isNotEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    '没有更多评论了',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),

                          const SliverToBoxAdapter(
                            child: SizedBox(height: 80),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Comment Input Bar
                  _buildBottomInputBar(isDark, primaryColor),
                ],
              ),
    );
  }

  /// 内容区 slivers：作者信息 + 正文 + 底部互动区。
  ///
  /// 图文正文按段拆进 [SliverList] 懒加载：只有滚动到可见范围附近的段落
  /// 才会构建并解码图片。此前整篇正文放在同一个 sliver 里，进入页面就会
  /// 一次性解码全部大图，长图（单张位图可达十几 MB）导致上下滑动明显卡顿。
  List<Widget> _buildContentSlivers(
    BuildContext context,
    DynamicItem item,
    bool isDark,
    Color primaryColor,
  ) {
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final video = item.video;
    final hasVideo = video != null && video.bvid.isNotEmpty;

    return [
      SliverToBoxAdapter(
        child: _buildAuthorHeader(context, item, isDark, primaryColor, cardColor),
      ),
      if (item.paragraphs.isNotEmpty)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, index) {
              if (index >= item.paragraphs.length) {
                return ColoredBox(
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildVideoCard(ctx, video!, isDark),
                  ),
                );
              }
              return ColoredBox(
                color: cardColor,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, index == 0 ? 14 : 0, 16, 0),
                  child: _buildParagraph(ctx, item.paragraphs[index], item.pictures, isDark),
                ),
              );
            },
            childCount: item.paragraphs.length + (hasVideo ? 1 : 0),
            // 纯内容段落无需 KeepAlive，省掉每项的自动保活包装开销
            addAutomaticKeepAlives: false,
          ),
        )
      else
        SliverToBoxAdapter(
          child: _buildPlainContent(context, item, isDark, cardColor),
        ),
      SliverToBoxAdapter(
        child: _buildStatsFooter(context, item, isDark, primaryColor, cardColor),
      ),
    ];
  }

  Widget _buildAuthorHeader(
    BuildContext context,
    DynamicItem item,
    bool isDark,
    Color primaryColor,
    Color cardColor,
  ) {
    return Container(
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (item.author.mid > 0) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => UpSpaceScreen(mid: item.author.mid),
                      ),
                    );
                  }
                },
                child: UserAvatar(url: item.author.face, size: 42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (item.author.mid > 0) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => UpSpaceScreen(mid: item.author.mid),
                        ),
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.author.name,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            item.author.pubTime.isNotEmpty
                                ? item.author.pubTime
                                : (item.author.pubTs > 0 ? Formatters.formatTime(item.author.pubTs) : ''),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                            ),
                          ),
                          if (item.author.pubAction.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${item.author.pubAction}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (item.author.mid > 0)
                FilledButton.icon(
                  onPressed: _toggleFollow,
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
                  icon: Icon(_isFollowing ? Icons.check : Icons.add, size: 14),
                  label: Text(
                    _isFollowing ? '已关注' : '关注',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),

          // Title (for article / opus if present and not already first paragraph)
          if (item.title.isNotEmpty &&
              (item.paragraphs.isEmpty || item.paragraphs.first.text != item.title)) ...[
            const SizedBox(height: 14),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
              ),
            ),
          ],

        ],
      ),
    );
  }

  /// 没有段落结构的动态正文（普通图文、视频动态等）。
  Widget _buildPlainContent(
    BuildContext context,
    DynamicItem item,
    bool isDark,
    Color cardColor,
  ) {
    final video = item.video;
    final hasVideo = video != null && video.bvid.isNotEmpty;
    final hasText = item.text.isNotEmpty;
    final hasPictures = item.pictures.isNotEmpty;
    if (!hasText && !hasVideo && !hasPictures) return const SizedBox.shrink();

    return Container(
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasText)
            Text(
              item.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
              ),
            ),

          // Video Card (if any)
          if (hasVideo) ...[
            if (hasText) const SizedBox(height: 12),
            _buildVideoCard(context, video, isDark),
          ],

          // Pictures (if any)
          if (hasPictures) ...[
            if (hasText || hasVideo) const SizedBox(height: 12),
            _buildImages(context, item.pictures, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsFooter(
    BuildContext context,
    DynamicItem item,
    bool isDark,
    Color primaryColor,
    Color cardColor,
  ) {
    return Container(
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Forwarded Dynamic (if any)
          if (item.orig != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                if (item.orig!.id.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => DynamicDetailScreen(
                        dynamicId: item.orig!.id,
                        initialItem: item.orig,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF191920) : const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${item.orig!.author.name}: ${item.orig!.text}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                        height: 1.45,
                      ),
                    ),
                    if (item.orig!.video != null && item.orig!.video!.bvid.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildVideoCard(context, item.orig!.video!, isDark),
                    ],
                    if (item.orig!.pictures.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildImages(context, item.orig!.pictures, isDark),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, thickness: 0.5, color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight),

          // Action Stats Row (Like, Forward, Comment Count)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                          size: 17,
                          color: _isLiked ? primaryColor : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _likeCount > 0 ? Formatters.formatCount(_likeCount) : '赞',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isLiked ? primaryColor : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                            fontWeight: _isLiked ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 17, color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                      const SizedBox(width: 5),
                      Text(
                        _commentTotalCount > 0
                            ? Formatters.formatCount(_commentTotalCount)
                            : (item.stat.commentCount > 0 ? Formatters.formatCount(item.stat.commentCount) : '评论'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.stat.forwardCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 17, color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                        const SizedBox(width: 5),
                        Text(
                          Formatters.formatCount(item.stat.forwardCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, DynamicVideo video, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => VideoDetailScreen(bvid: video.bvid),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFF0F1F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 75,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageView(
                    url: video.cover,
                    fit: BoxFit.cover,
                    memCacheWidth: 240,
                    memCacheHeight: 150,
                  ),
                  if (video.durationText.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.durationText,
                          style: const TextStyle(color: Colors.white, fontSize: 9.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (video.playCount.isNotEmpty) ...[
                          Icon(Icons.play_arrow_rounded, size: 13, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                          const SizedBox(width: 2),
                          Text(
                            video.playCount,
                            style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                          ),
                        ],
                        if (video.danmakuCount.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.subtitles_outlined, size: 11, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                          const SizedBox(width: 3),
                          Text(
                            video.danmakuCount,
                            style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单个正文段落。作为 [SliverList] 的子项按需构建，
  /// 所以图片只有滚动到可见范围附近时才会开始解码。
  Widget _buildParagraph(
    BuildContext context,
    DynamicParagraph p,
    List<DynamicPicture> allPictures,
    bool isDark,
  ) {
    if (p.isQuote) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                width: 3,
              ),
            ),
          ),
          child: Text(
            p.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
            ),
          ),
        ),
      );
    }
    if (p.isCode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16161C) : const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              p.text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                fontFamily: 'monospace',
                color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
              ),
            ),
          ),
        ),
      );
    }
    if (p.type == 4) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          p.text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.45,
            color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
          ),
        ),
      );
    }
    if (p.isText) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          p.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.65,
            color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
          ),
        ),
      );
    }
    if (p.isPicture) {
      final pic = p.picture!;
      final picIndex = allPictures.indexWhere((item) => item.url == pic.url);
      final effectiveIndex = picIndex >= 0 ? picIndex : 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: () => ImageViewer.show(
            context,
            pictures: allPictures.isNotEmpty ? allPictures : [pic],
            initialIndex: effectiveIndex,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFEEEEEE),
              child: _buildPictureBlock(context, pic),
            ),
          ),
        ),
      );
    }
    if (p.isDivider) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Divider(
          height: 1,
          thickness: 0.6,
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildImages(
    BuildContext context,
    List<DynamicPicture> pictures,
    bool isDark,
  ) {
    final count = pictures.length;
    if (count == 0) return const SizedBox.shrink();

    if (count == 1) {
      final pic = pictures.first;
      return GestureDetector(
        onTap: () => ImageViewer.show(
          context,
          pictures: pictures,
          initialIndex: 0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFEEEEEE),
            child: _buildPictureBlock(context, pic),
          ),
        ),
      );
    }

    final cols = count == 4 ? 2 : (count >= 3 ? 3 : 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = 6.0 * (cols - 1);
        final itemWidth = cols == 2 && count == 4
            ? (min(constraints.maxWidth, 340.0) - totalSpacing) / cols
            : (constraints.maxWidth - totalSpacing) / cols;

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: pictures.asMap().entries.map((entry) {
            final idx = entry.key;
            final pic = entry.value;

            return GestureDetector(
              onTap: () => ImageViewer.show(
                context,
                pictures: pictures,
                initialIndex: idx,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: itemWidth,
                  height: itemWidth,
                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFEEEEEE),
                  child: NetworkImageView(
                    url: pic.url,
                    width: itemWidth,
                    height: itemWidth,
                    fit: BoxFit.cover,
                    alignment: pic.isLongImage ? Alignment.topCenter : Alignment.center,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// 详情页图片块：长图按原始比例完整展开（详情页以看全内容为准），
  /// 普通图片限制极端比例，始终使用 contain 避免裁掉内容。
  ///
  /// 解码宽度按「显示宽度 × 像素预算」计算：长图不再按全宽原样解码成
  /// 几十 MB 的位图，从而避免滚动时反复解码 / 回收导致的卡顿。
  /// 图片仍然保持原始宽高比，只是分辨率上限降低，不会被裁切。
  Widget _buildPictureBlock(BuildContext context, DynamicPicture pic) {
    final ratio = pic.aspectRatio;
    if (ratio == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 380),
        child: NetworkImageView(
          url: pic.url,
          fit: BoxFit.contain,
          memCacheWidth: 720,
          memCacheHeight: 720,
        ),
      );
    }

    final isLong = pic.isLongImage;
    final displayRatio = isLong ? ratio.clamp(0.02, 6.0) : ratio.clamp(0.4, 2.5);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
        final cacheWidth = ImageDecodeSizing.decodeWidthForDisplay(
          displayWidth: constraints.maxWidth,
          devicePixelRatio: dpr,
          aspectRatio: ratio,
        );
        // 图片单独成层，滚动时不会因为父级重绘而重新栅格化。
        return RepaintBoundary(
          child: AspectRatio(
            aspectRatio: displayRatio,
            child: NetworkImageView(
              url: pic.url,
              fit: BoxFit.contain,
              alignment: isLong ? Alignment.topCenter : Alignment.center,
              memCacheWidth: cacheWidth,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsHeader(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '评论 (${_commentTotalCount > 0 ? Formatters.formatCount(_commentTotalCount) : (_item?.stat.commentCount ?? 0)})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              InkWell(
                onTap: () => _switchCommentMode(3),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '热门',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _commentMode == 3 ? FontWeight.bold : FontWeight.normal,
                      color: _commentMode == 3 ? primaryColor : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                    ),
                  ),
                ),
              ),
              Text(' | ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight)),
              InkWell(
                onTap: () => _switchCommentMode(2),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '最新',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _commentMode == 2 ? FontWeight.bold : FontWeight.normal,
                      color: _commentMode == 2 ? primaryColor : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInputBar(bool isDark, Color primaryColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_replyTarget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '回复 @${_replyTarget!.member.uname}:',
                    style: TextStyle(fontSize: 11.5, color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF22222A) : const Color(0xFFEFF0F3),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _commentInputController,
                    focusNode: _commentFocusNode,
                    decoration: InputDecoration(
                      hintText: _replyTarget != null ? '回复 @${_replyTarget!.member.uname}...' : '发一条友善的动态评论...',
                      hintStyle: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _isSendingComment ? null : _sendComment,
                style: IconButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: _isSendingComment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
