import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_model.dart';
import '../screens/up/up_space_screen.dart';
import '../screens/video/video_detail_screen.dart';
import '../services/api/user_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';
import '../utils/app_routes.dart';
import '../utils/formatters.dart';
import 'app_toast.dart';
import 'network_image_view.dart';
import 'stat_badge.dart';
import 'video_share_sheet.dart';

class VideoCard extends StatefulWidget {
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

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isPressed = false;

  void _showQuickMenu(BuildContext context) {
    final video = widget.video;
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部把手
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colors.divider,
                  borderRadius: AppRadius.of(AppRadius.pill),
                ),
              ),
              // 视频概览条
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.of(AppRadius.sm),
                      child: SizedBox(
                        width: 72,
                        height: 45,
                        child: NetworkImageView(
                          url: video.pic,
                          fit: BoxFit.cover,
                          memCacheWidth: 240,
                          memCacheHeight: 150,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTypography.body2,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textMain,
                            ),
                          ),
                          if (video.owner.name.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              video.owner.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: context.colors.textHint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.divider),
              ListTile(
                leading: Icon(
                  Icons.watch_later_outlined,
                  color: context.colors.textSub,
                ),
                title: const Text('添加至稍后观看'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _addToWatchLater(context);
                },
              ),
              if (video.owner.mid > 0)
                ListTile(
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: context.colors.textSub,
                  ),
                  title: Text('进入 ${video.owner.name.isNotEmpty ? video.owner.name : "UP主"} 的空间'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      AppRoutes.page(UpSpaceScreen(mid: video.owner.mid)),
                    );
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.share_outlined,
                  color: context.colors.textSub,
                ),
                title: const Text('分享 / 复制链接'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  VideoShareSheet.show(
                    context,
                    bvid: video.bvid,
                    title: video.title,
                  );
                },
              ),
              if (widget.showMoreMenu && widget.onNotInterested != null)
                ListTile(
                  leading: Icon(
                    Icons.visibility_off_outlined,
                    color: context.colors.textSub,
                  ),
                  title: const Text('不感兴趣'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onNotInterested?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToWatchLater(BuildContext context) async {
    HapticFeedback.lightImpact();
    final ok = await UserApiService().addToWatchLater(
      aid: widget.video.aid,
      bvid: widget.video.bvid,
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
  /// 不会跟随，因此飞行中的封面自己带圆角，避免过渡瞬间变成直角。
  Widget _buildCover() {
    final cover = NetworkImageView(
      url: widget.video.pic,
      fit: BoxFit.cover,
      memCacheWidth: 480,
      memCacheHeight: 300,
    );
    if (widget.heroTag == null) return cover;
    return Hero(
      tag: widget.heroTag!,
      child: ClipRRect(borderRadius: AppRadius.card, child: cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    if (video.bvid.isEmpty || video.title.isEmpty) {
      return const SizedBox.shrink();
    }
    final primaryColor = Theme.of(context).colorScheme.primary;
    final hasRcmd = video.rcmdReason != null && video.rcmdReason!.isNotEmpty;

    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedScale(
      scale: (!disableAnimations && _isPressed) ? 0.985 : 1.0,
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: AppRadius.card,
          // 无边框纯净分层：浅色下极微弱自然阴影，深色模式自动融于背景
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onHighlightChanged: (pressed) {
              if (_isPressed != pressed) {
                setState(() => _isPressed = pressed);
              }
            },
            onLongPress: () => _showQuickMenu(context),
            onTap:
                widget.onTap ??
                () {
                  Navigator.of(context).push(
                    AppRoutes.page(
                      VideoDetailScreen(
                        bvid: video.bvid,
                        initialVideo: video,
                        heroTag: widget.heroTag,
                      ),
                    ),
                  );
                },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面区（16:10 国际版通透比例）
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCover(),
                      // 底部柔暗角渐变，保障白色角标可读性
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 36,
                        child: IgnorePointer(
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
                      ),
                      // 左下角：播放量与弹幕数
                      if ((widget.showViewCount && video.stat.view > 0) ||
                          video.stat.danmaku > 0)
                        Positioned(
                          bottom: 5,
                          left: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.showViewCount && video.stat.view > 0)
                                StatBadge(
                                  icon: Icons.play_arrow_rounded,
                                  text: Formatters.formatCount(video.stat.view),
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: AppTypography.tiny,
                                  iconSize: 13,
                                ),
                              if (widget.showViewCount &&
                                  video.stat.view > 0 &&
                                  video.stat.danmaku > 0)
                                const SizedBox(width: 5.0),
                              if (video.stat.danmaku > 0)
                                StatBadge(
                                  icon: Icons.subtitles_outlined,
                                  text: Formatters.formatCount(
                                    video.stat.danmaku,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: AppTypography.tiny,
                                  iconSize: 11,
                                ),
                            ],
                          ),
                        ),
                      // 右下角：时长胶囊
                      if (video.duration > 0)
                        Positioned(
                          bottom: 5,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: AppRadius.of(AppRadius.xs),
                            ),
                            child: Text(
                              Formatters.formatDuration(video.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppTypography.tiny,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 元信息区（标题 + 柔色推荐标签/UP主 + ⋮ 更多）
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.body2,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: context.colors.textMain,
                          ),
                        ),
                        Row(
                          children: [
                            if (hasRcmd) ...[
                              Flexible(
                                flex: 0,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 68),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: AppRadius.of(AppRadius.xs),
                                  ),
                                  child: Text(
                                    video.rcmdReason!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: AppTypography.tiny,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                            ] else ...[
                              Icon(
                                Icons.person_outline_rounded,
                                size: 12,
                                color: context.colors.textHint,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                video.owner.name.isNotEmpty
                                    ? video.owner.name
                                    : 'UP主',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTypography.caption,
                                  color: context.colors.textSub,
                                ),
                              ),
                            ),
                            // 单一「更多」入口：收拢稍后看/不感兴趣/进空间/分享，扩展触控涟漪半径且不撑高底部行
                            Semantics(
                              button: true,
                              label: '更多选项',
                              child: Tooltip(
                                message: '更多选项',
                                child: InkResponse(
                                  onTap: () => _showQuickMenu(context),
                                  radius: 22,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(6, 2, 0, 2),
                                    child: Icon(
                                      Icons.more_vert_rounded,
                                      size: 16,
                                      color: context.colors.textHint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
