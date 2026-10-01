import 'package:flutter/material.dart';
import '../../../models/comment_model.dart';
import '../../../services/api/comment_api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/comment_item_widget.dart';
import '../../../widgets/state_views.dart';

/// Bottom sheet displaying nested sub-replies to a root comment with replying capability.
class VideoSubRepliesSheet extends StatefulWidget {
  final int oid;
  final CommentItem rootComment;
  final bool isDark;
  final Color primaryColor;

  const VideoSubRepliesSheet({
    super.key,
    required this.oid,
    required this.rootComment,
    required this.isDark,
    required this.primaryColor,
  });

  static void show(
    BuildContext context, {
    required int oid,
    required CommentItem rootComment,
    required bool isDark,
    required Color primaryColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return VideoSubRepliesSheet(
          oid: oid,
          rootComment: rootComment,
          isDark: isDark,
          primaryColor: primaryColor,
        );
      },
    );
  }

  @override
  State<VideoSubRepliesSheet> createState() => _VideoSubRepliesSheetState();
}

class _VideoSubRepliesSheetState extends State<VideoSubRepliesSheet> {
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
        color: context.colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '回复详情 (${root.rcount > 0 ? root.rcount : _subReplies.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
            color: context.colors.divider,
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
                                color: context.colors.divider,
                              ),
                            ],
                          );
                        }

                        // Empty State
                        if (_subReplies.isEmpty && index == 1) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                '暂无更多子级回复',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textHint,
                                ),
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
                                color: context.colors.divider,
                              ),
                            ],
                          );
                        }

                        // Footer (Loading More or End Indicator)
                        if (_isLoadingMore) {
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
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
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Center(
                              child: Text(
                                '没有更多回复了',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textHint,
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
              color: context.colors.fill,
              border: Border(
                top: BorderSide(
                  color: context.colors.divider,
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? '回复 @${_replyingTo!.member.uname}...'
                            : '回复 @${root.member.uname}...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: context.colors.textHint,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
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
