import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comment_model.dart';
import '../screens/up/up_space_screen.dart';
import '../services/api/comment_api_service.dart';
import '../theme/app_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.comment;
    final handleRepliesTap = widget.onSubRepliesTap ?? widget.onReplyTap;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          const SizedBox(width: 10),
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      Formatters.formatTime(item.ctime),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
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
                    color: isDark ? AppTheme.textMainDark : const Color(0xFF202020),
                  ),
                ),
                const SizedBox(height: 6),
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
                                color: _isLiked ? Theme.of(context).colorScheme.primary : (isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                              ),
                            ),
                            if (_likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                Formatters.formatCount(_likeCount),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: _isLiked ? Theme.of(context).colorScheme.primary : (isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: widget.onReplyTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                    ),
                  ],
                ),
                // Sub Replies
                if (item.replies.isNotEmpty || item.rcount > 0) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: handleRepliesTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
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
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                      text: sub.message,
                                      style: TextStyle(
                                        color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                                        fontSize: 11.5,
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
                                  fontSize: 11.5,
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
