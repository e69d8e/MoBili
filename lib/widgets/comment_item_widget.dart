import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comment_model.dart';
import '../screens/up/up_space_screen.dart';
import '../services/api/comment_api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'user_avatar.dart';

class CommentItemWidget extends StatefulWidget {
  final CommentItem comment;
  final VoidCallback? onReplyTap;
  final VoidCallback? onSubRepliesTap;

  const CommentItemWidget({
    super.key,
    required this.comment,
    this.onReplyTap,
    this.onSubRepliesTap,
  });

  @override
  State<CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<CommentItemWidget> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.like;
  }

  @override
  void didUpdateWidget(covariant CommentItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comment.rpid != oldWidget.comment.rpid ||
        widget.comment.isLiked != oldWidget.comment.isLiked ||
        widget.comment.like != oldWidget.comment.like) {
      _isLiked = widget.comment.isLiked;
      _likeCount = widget.comment.like;
    }
  }

  void _navigateToUpSpace(int mid) {
    if (mid > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => UpSpaceScreen(mid: mid),
        ),
      );
    }
  }

  void _toggleLike() async {
    HapticFeedback.lightImpact();
    final newLike = !_isLiked;
    setState(() {
      _isLiked = newLike;
      _likeCount += newLike ? 1 : -1;
    });

    final success = await CommentApiService().likeComment(
      oid: widget.comment.oid,
      rpid: widget.comment.rpid,
      action: newLike ? 1 : 0,
    );

    if (!success && mounted) {
      setState(() {
        _isLiked = !newLike;
        _likeCount += newLike ? -1 : 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.comment;
    final handleRepliesTap = widget.onSubRepliesTap ?? widget.onReplyTap;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (Tap to open UP space)
          GestureDetector(
            onTap: () => _navigateToUpSpace(item.member.mid),
            child: UserAvatar(
              url: item.member.avatar,
              size: 34,
              level: item.member.level,
            ),
          ),
          const SizedBox(width: 8.0),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username & Timestamp (Tap username to open UP space)
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToUpSpace(item.member.mid),
                      child: Text(
                        item.member.uname,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      Formatters.formatTime(item.ctime),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Message
                Text(
                  item.message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.colors.textMain,
                  ),
                ),
                const SizedBox(height: 4.0),
                // Like & Reply button
                Row(
                  children: [
                    InkWell(
                      onTap: _toggleLike,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: _isLiked ? 1.2 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                _isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                                size: 13,
                                color: _isLiked ? Theme.of(context).colorScheme.primary : (context.colors.textHint),
                              ),
                            ),
                            if (_likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                Formatters.formatCount(_likeCount),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _isLiked ? Theme.of(context).colorScheme.primary : (context.colors.textHint),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    InkWell(
                      onTap: widget.onReplyTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: context.colors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
                // Sub Replies
                if (item.replies.isNotEmpty || item.rcount > 0) ...[
                  const SizedBox(height: 4.0),
                  InkWell(
                    onTap: handleRepliesTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: context.colors.fill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...item.replies.take(3).map((sub) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => _navigateToUpSpace(sub.member.mid),
                                        child: Text(
                                          '${sub.member.uname}: ',
                                          style: const TextStyle(
                                            color: AppTheme.biliBlue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                      text: sub.message,
                                      style: TextStyle(
                                        color: context.colors.textSub,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          if (item.rcount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '共 ${item.rcount} 条回复 >',
                                style: const TextStyle(
                                  color: AppTheme.biliBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
