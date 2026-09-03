import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/dynamic_model.dart';
import '../providers/auth_provider.dart';
import '../screens/dynamic/dynamic_detail_screen.dart';
import '../screens/profile/login_dialog.dart';
import '../screens/up/up_space_screen.dart';
import '../screens/video/video_detail_screen.dart';
import '../services/api/bili_http_client.dart';
import '../services/api/dynamic_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_toast.dart';
import 'image_viewer.dart';
import 'network_image_view.dart';
import 'user_avatar.dart';

class DynamicCard extends StatefulWidget {
  final DynamicItem item;

  const DynamicCard({super.key, required this.item});

  @override
  State<DynamicCard> createState() => _DynamicCardState();
}

class _DynamicCardState extends State<DynamicCard> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.stat.isLiked;
    _likeCount = widget.item.stat.likeCount;
  }

  @override
  void didUpdateWidget(covariant DynamicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id ||
        widget.item.stat.isLiked != oldWidget.item.stat.isLiked ||
        widget.item.stat.likeCount != oldWidget.item.stat.likeCount) {
      _isLiked = widget.item.stat.isLiked;
      _likeCount = widget.item.stat.likeCount;
    }
  }

  void _navigateToDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => DynamicDetailScreen(
          dynamicId: widget.item.id,
          initialItem: widget.item,
        ),
      ),
    );
  }

  void _toggleLike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLogin || BiliHttpClient().biliJct == null) {
      showDialog(
        context: context,
        builder: (ctx) => const LoginDialog(),
      );
      return;
    }

    final targetLike = !_isLiked;
    setState(() {
      _isLiked = targetLike;
      _likeCount += targetLike ? 1 : -1;
    });

    final ok = await DynamicApiService().likeDynamic(widget.item.id, like: targetLike);
    if (!ok && mounted) {
      setState(() {
        _isLiked = !targetLike;
        _likeCount += targetLike ? -1 : 1;
      });
      AppToast.show(
        context,
        '点赞操作失败，请重试',
        icon: Icons.info_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToDetail,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Row(
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
                  child: UserAvatar(
                    url: item.author.face,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 10),
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
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              item.author.pubTime.isNotEmpty
                                  ? item.author.pubTime
                                  : (item.author.pubTs > 0
                                      ? Formatters.formatTime(item.author.pubTs)
                                      : ''),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                              ),
                            ),
                            if (item.author.pubAction.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· ${item.author.pubAction}',
                                style: TextStyle(
                                  fontSize: 11,
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
              ],
            ),
          ),

          // Text Content
          if (item.text.isNotEmpty)
            GestureDetector(
              onTap: _navigateToDetail,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                  ),
                ),
              ),
            ),

          // Video Card (if any)
          if (item.video != null && item.video!.bvid.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: _buildVideoCard(context, item.video!, isDark),
            ),

          // Images (if any)
          if (item.pictures.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: _buildImages(
                context,
                item.pictures,
                heroPrefix: 'dyn_${item.id}',
                isDark: isDark,
              ),
            ),

          // Forwarded Dynamic (if any)
          if (item.orig != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: GestureDetector(
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1B20) : const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${item.orig!.author.name}: ${item.orig!.text}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                          height: 1.4,
                        ),
                      ),
                      if (item.orig!.video != null && item.orig!.video!.bvid.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildVideoCard(context, item.orig!.video!, isDark),
                      ],
                      if (item.orig!.pictures.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildImages(
                          context,
                          item.orig!.pictures,
                          heroPrefix: 'orig_${item.orig!.id}',
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 4),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),

          // Action Stats Bar (Comment, Like)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: item.stat.commentCount > 0 ? Formatters.formatCount(item.stat.commentCount) : '评论',
                  active: false,
                  isDark: isDark,
                  onTap: _navigateToDetail,
                ),
                _buildActionButton(
                  icon: _isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                  label: _likeCount > 0 ? Formatters.formatCount(_likeCount) : '赞',
                  active: _isLiked,
                  isDark: isDark,
                  onTap: _toggleLike,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
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
          color: isDark ? const Color(0xFF1F1F26) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Video Cover Thumbnail
            SizedBox(
              width: 120,
              height: 75,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageView(url: video.cover, fit: BoxFit.cover),
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
            // Video Title & Stats
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
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
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

  Widget _buildImages(
    BuildContext context,
    List<DynamicPicture> pictures, {
    required String heroPrefix,
    required bool isDark,
  }) {
    if (pictures.isEmpty) return const SizedBox.shrink();

    if (pictures.length == 1) {
      return _buildSingleImage(
        context,
        pictures.first,
        heroPrefix: heroPrefix,
        isDark: isDark,
      );
    }

    return _buildMultiImages(
      context,
      pictures,
      heroPrefix: heroPrefix,
      isDark: isDark,
    );
  }

  Widget _buildSingleImage(
    BuildContext context,
    DynamicPicture pic, {
    required String heroPrefix,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        double displayWidth;
        double displayHeight;
        Alignment alignment = Alignment.center;
        final bool isLong = pic.isLongImage;
        final bool isGif = pic.url.toLowerCase().contains('.gif');

        if (pic.aspectRatio != null) {
          final ratio = pic.aspectRatio!;
          if (ratio >= 1.0) {
            // Landscape or square image
            displayWidth = maxWidth;
            displayHeight = (displayWidth / ratio).clamp(120.0, 240.0);
          } else {
            // Portrait or long image
            displayWidth = (maxWidth * 0.65).clamp(160.0, 230.0);
            if (isLong || ratio < 0.55) {
              displayHeight = 260.0;
              alignment = Alignment.topCenter; // Crop from top to show head/start
            } else {
              displayHeight = (displayWidth / ratio).clamp(160.0, 260.0);
            }
          }
        } else {
          displayWidth = min(maxWidth, 280.0);
          displayHeight = 200.0;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            ImageViewer.show(
              context,
              pictures: [pic],
              initialIndex: 0,
              heroPrefix: heroPrefix,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: displayWidth,
              height: displayHeight,
              color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFEEEEEE),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageView(
                    url: pic.url,
                    width: displayWidth,
                    height: displayHeight,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    memCacheWidth: (displayWidth * 2.2).round().clamp(200, 960),
                    memCacheHeight: (displayHeight * 2.2).round().clamp(200, 960),
                  ),
                  if (isLong)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: _buildBadge('长图'),
                    )
                  else if (isGif)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: _buildBadge('GIF'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultiImages(
    BuildContext context,
    List<DynamicPicture> pictures, {
    required String heroPrefix,
    required bool isDark,
  }) {
    final totalCount = pictures.length;
    final displayCount = totalCount.clamp(1, 9);
    final cols = displayCount == 4 ? 2 : (displayCount >= 3 ? 3 : 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = 6.0 * (cols - 1);
        final itemWidth = cols == 2 && displayCount == 4
            ? (min(constraints.maxWidth, 320.0) - totalSpacing) / cols
            : (constraints.maxWidth - totalSpacing) / cols;
        final itemHeight = itemWidth;

        final rows = <Widget>[];
        for (int i = 0; i < displayCount; i += cols) {
          final rowItems = <Widget>[];
          for (int j = 0; j < cols; j++) {
            final idx = i + j;
            if (idx < displayCount) {
              final pic = pictures[idx];
              final isLastOfNine = idx == 8 && totalCount > 9;
              final isLong = pic.isLongImage;
              final isGif = pic.url.toLowerCase().contains('.gif');

              rowItems.add(
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ImageViewer.show(
                      context,
                      pictures: pictures,
                      initialIndex: idx,
                      heroPrefix: heroPrefix,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: itemWidth,
                      height: itemHeight,
                      color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFEEEEEE),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetworkImageView(
                            url: pic.url,
                            width: itemWidth,
                            height: itemHeight,
                            fit: BoxFit.cover,
                            alignment: isLong ? Alignment.topCenter : Alignment.center,
                            memCacheWidth: (itemWidth * 2.2).round().clamp(150, 480),
                            memCacheHeight: (itemHeight * 2.2).round().clamp(150, 480),
                          ),
                          if (isLastOfNine)
                            Container(
                              color: Colors.black.withValues(alpha: 0.6),
                              alignment: Alignment.center,
                              child: Text(
                                '+${totalCount - 9}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (isLong)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: _buildBadge('长图'),
                            )
                          else if (isGif)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: _buildBadge('GIF'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else {
              rowItems.add(SizedBox(width: itemWidth, height: itemHeight));
            }
            if (j < cols - 1) {
              rowItems.add(const SizedBox(width: 6));
            }
          }
          rows.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: rowItems,
            ),
          );
          if (i + cols < displayCount) {
            rows.add(const SizedBox(height: 6));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final color = active ? Theme.of(context).colorScheme.primary : (isDark ? AppTheme.textSubDark : AppTheme.textSubLight);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            AnimatedScale(
              scale: active ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
