import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../screens/video/video_detail_screen.dart';
import '../services/api/user_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_toast.dart';
import 'network_image_view.dart';
import 'stat_badge.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onTap;
  final bool showViewCount;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.showViewCount = true,
  });

  void _addToWatchLater(BuildContext context) async {
    final ok = await UserApiService().addToWatchLater(aid: video.aid, bvid: video.bvid);
    if (context.mounted) {
      AppToast.show(
        context,
        ok ? '已添加稍后看' : '添加失败，请先登录',
        icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (video.bvid.isEmpty || video.title.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => VideoDetailScreen(
                    bvid: video.bvid,
                    initialVideo: video,
                  ),
                ),
              );
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail & Overlay Badges
            AspectRatio(
              aspectRatio: 16 / 9.6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageView(
                    url: video.pic,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    memCacheHeight: 300,
                  ),
                  // Subtle bottom vignette gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                           begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0x99000000),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Left stats (Plays & Danmaku)
                  if ((showViewCount && video.stat.view > 0) || video.stat.danmaku > 0)
                    Positioned(
                      bottom: 5,
                      left: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showViewCount && video.stat.view > 0)
                            StatBadge(
                              icon: Icons.play_arrow_rounded,
                              text: Formatters.formatCount(video.stat.view),
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 10.0,
                              iconSize: 13,
                            ),
                          if (showViewCount && video.stat.view > 0 && video.stat.danmaku > 0)
                            const SizedBox(width: 6),
                          if (video.stat.danmaku > 0)
                            StatBadge(
                              icon: Icons.subtitles_outlined,
                              text: Formatters.formatCount(video.stat.danmaku),
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 10.0,
                              iconSize: 11,
                            ),
                        ],
                      ),
                    ),
                  // Right Duration Pill
                  if (video.duration > 0)
                    Positioned(
                      bottom: 5,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          Formatters.formatDuration(video.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  // Recommendation Tag
                  if (video.rcmdReason != null && video.rcmdReason!.isNotEmpty)
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.rcmdReason!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Video Meta & UP
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // UP Row & Watch Later button
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          video.owner.name.isNotEmpty ? video.owner.name : 'UP主',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                          ),
                        ),
                      ),
                      // Add to Watch Later button at the bottom right
                      InkWell(
                        onTap: () => _addToWatchLater(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Tooltip(
                            message: '添加至稍后观看',
                            child: Icon(
                              Icons.watch_later_outlined,
                              size: 14.5,
                              color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                            ),
                          ),
                        ),
                      ),
                    ],
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
