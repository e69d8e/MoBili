import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_model.dart';
import '../screens/video/video_detail_screen.dart';
import '../services/api/user_api_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'app_toast.dart';
import 'network_image_view.dart';
import 'stat_badge.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onTap;
  final bool showViewCount;
  // 仅信息流网格启用「不感兴趣」菜单，其他复用场景保持原样
  final bool showMoreMenu;
  final VoidCallback? onNotInterested;

  /// 共享元素转场 tag：由入口传入，保证同一路由树内唯一；不传则不启用 Hero
  final String? heroTag;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.showViewCount = true,
    this.showMoreMenu = false,
    this.onNotInterested,
    this.heroTag,
  });

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.visibility_off_outlined,
                color: context.colors.textSub,
              ),
              title: Text(
                '不感兴趣',
                style: TextStyle(fontSize: 14, color: context.colors.textMain),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onNotInterested?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _addToWatchLater(BuildContext context) async {
    HapticFeedback.lightImpact();
    final ok = await UserApiService().addToWatchLater(
      aid: video.aid,
      bvid: video.bvid,
    );
    if (context.mounted) {
      AppToast.show(
        context,
        ok ? '已添加稍后看' : '添加失败，请先登录',
        icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
      );
    }
  }

  /// 封面单独封装：Hero 会把 child 提到 overlay 绘制，卡片外层的圆角裁剪
  /// 不会跟随，因此飞行中的封面自己带圆角，避免过渡瞬间变成直角
  Widget _buildCover() {
    final cover = NetworkImageView(
      url: video.pic,
      fit: BoxFit.cover,
      memCacheWidth: 480,
      memCacheHeight: 300,
    );
    if (heroTag == null) return cover;
    return Hero(
      tag: heroTag!,
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (video.bvid.isEmpty || video.title.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      // 内层透明 Material 让 InkWell 的涟漪绘制在卡片背景之上，
      // 否则不透明的 Container 装饰会把水波纹盖住
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => VideoDetailScreen(
                      bvid: video.bvid,
                      initialVideo: video,
                      heroTag: heroTag,
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
                    _buildCover(),
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
                            colors: [Color(0x99000000), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // Left stats (Plays & Danmaku)
                    if ((showViewCount && video.stat.view > 0) ||
                        video.stat.danmaku > 0)
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
                                fontSize: 10,
                                iconSize: 13,
                              ),
                            if (showViewCount &&
                                video.stat.view > 0 &&
                                video.stat.danmaku > 0)
                              const SizedBox(width: 4.0),
                            if (video.stat.danmaku > 0)
                              StatBadge(
                                icon: Icons.subtitles_outlined,
                                text: Formatters.formatCount(
                                  video.stat.danmaku,
                                ),
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 10,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            Formatters.formatDuration(video.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    // Recommendation Tag
                    if (video.rcmdReason != null &&
                        video.rcmdReason!.isNotEmpty)
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.rcmdReason!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Video Meta & UP
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: context.colors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    // UP Row & Watch Later button
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: context.colors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            video.owner.name.isNotEmpty
                                ? video.owner.name
                                : 'UP主',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textSub,
                            ),
                          ),
                        ),
                        // 稍后看：用 IconButton 保证至少 28dp 的点击热区
                        IconButton(
                          onPressed: () => _addToWatchLater(context),
                          tooltip: '添加至稍后观看',
                          padding: const EdgeInsets.all(4.0),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          iconSize: 16,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.watch_later_outlined,
                            size: 16,
                            color: context.colors.textHint,
                          ),
                        ),
                        // 信息流卡片右下角的「不感兴趣」入口
                        if (showMoreMenu && onNotInterested != null)
                          IconButton(
                            onPressed: () => _showMoreMenu(context),
                            tooltip: '更多',
                            padding: const EdgeInsets.all(4.0),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            iconSize: 16,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 16,
                              color: context.colors.textHint,
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
      ),
    );
  }
}
