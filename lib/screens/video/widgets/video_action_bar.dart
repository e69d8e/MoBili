import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/formatters.dart';

/// 主操作按钮（点赞/投币/收藏/分享）：图标弹性反馈 + 计数文字，支持长按三连联动光环。
class VideoActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  // 无障碍朗读文案：可携带比单行 label 更完整的信息（例如投币总数与本人已投数）
  final String? semanticLabel;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final double? progress;

  const VideoActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.semanticLabel,
    required this.active,
    this.color,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? Theme.of(context).colorScheme.primary;
    final hasProgress = progress != null && progress! > 0;

    return Expanded(
      child: Semantics(
        button: true,
        label: semanticLabel ?? label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.of(AppRadius.sm),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            onLongPress: onLongPressStart != null ? () {} : null,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: onLongPressStart,
              onLongPressEnd: onLongPressEnd,
              onLongPressCancel: onLongPressCancel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (hasProgress)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  activeColor,
                                ),
                                backgroundColor: context.colors.divider,
                              ),
                            ),
                          TweenAnimationBuilder<double>(
                            key: ValueKey('act_$active'),
                            tween: Tween(
                              begin: active ? 0.78 : 1.0,
                              end: hasProgress ? 1.12 : 1.0,
                            ),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(scale: scale, child: child);
                            },
                            child: Icon(
                              icon,
                              size: 21,
                              color: (active || hasProgress)
                                  ? activeColor
                                  : context.colors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: (active || hasProgress)
                            ? activeColor
                            : context.colors.textSub,
                        fontWeight: (active || hasProgress)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 次操作按钮（缓存/听视频/稍后看）：纯图标，带轻水波纹反馈。
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            radius: 20,
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                icon,
                size: 21,
                color: active ? activeColor : context.colors.textHint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 互动操作（点赞/投币/收藏/分享，带计数）+ 工具操作（缓存/听视频/稍后看，仅图标）分组排列。
class VideoActionBar extends StatelessWidget {
  final int likeCount;
  final bool isLiked;
  final Animation<double> tripleComboAnimation;
  final VoidCallback onLikeTap;
  final GestureLongPressStartCallback onLikeLongPressStart;
  final GestureLongPressEndCallback onLikeLongPressEnd;
  final VoidCallback onLikeLongPressCancel;

  final int coinCount;
  final int totalCoins;
  final VoidCallback onCoinTap;

  final bool isFav;
  final int favCount;
  // 单击一键收藏/取消；长按打开收藏夹管理，对齐官方客户端的收藏交互
  final VoidCallback onFavTap;
  final VoidCallback onFavLongPress;

  // 分享：对齐官方客户端底部「点赞 / 投币 / 收藏 / 分享」四项主操作
  final int shareCount;
  final VoidCallback onShareTap;

  final bool isCached;
  final bool isDownloading;
  final VoidCallback onCacheTap;

  final VoidCallback onListenTap;

  final bool isInWatchLater;
  final VoidCallback onWatchLaterTap;

  const VideoActionBar({
    super.key,
    required this.likeCount,
    required this.isLiked,
    required this.tripleComboAnimation,
    required this.onLikeTap,
    required this.onLikeLongPressStart,
    required this.onLikeLongPressEnd,
    required this.onLikeLongPressCancel,
    required this.coinCount,
    required this.totalCoins,
    required this.onCoinTap,
    required this.isFav,
    required this.favCount,
    required this.onFavTap,
    required this.onFavLongPress,
    this.shareCount = 0,
    required this.onShareTap,
    required this.isCached,
    required this.isDownloading,
    required this.onCacheTap,
    required this.onListenTap,
    required this.isInWatchLater,
    required this.onWatchLaterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // 三连进度同时联动点赞/投币/收藏三个主按钮光环
          Expanded(
            flex: 3,
            child: AnimatedBuilder(
              animation: tripleComboAnimation,
              builder: (context, _) {
                final tripleProgress = tripleComboAnimation.value;
                return Row(
                  children: [
                    VideoActionButton(
                      icon: isLiked
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_up_alt_outlined,
                      label: Formatters.formatCount(likeCount),
                      active: isLiked,
                      progress: tripleProgress,
                      onTap: onLikeTap,
                      onLongPressStart: onLikeLongPressStart,
                      onLongPressEnd: onLikeLongPressEnd,
                      onLongPressCancel: onLikeLongPressCancel,
                    ),
                    VideoActionButton(
                      icon: coinCount > 0
                          ? Icons.monetization_on_rounded
                          : Icons.monetization_on_outlined,
                      label: Formatters.formatCount(totalCoins),
                      semanticLabel: coinCount > 0
                          ? '投币，共${Formatters.formatCount(totalCoins)}，本人已投$coinCount币'
                          : '投币，共${Formatters.formatCount(totalCoins)}',
                      active: coinCount > 0,
                      progress: tripleProgress,
                      onTap: onCoinTap,
                    ),
                    VideoActionButton(
                      icon: isFav
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      label: Formatters.formatCount(favCount),
                      semanticLabel: isFav
                          ? '已收藏，${Formatters.formatCount(favCount)}，单击取消收藏，长按选择收藏夹'
                          : '收藏，${Formatters.formatCount(favCount)}，单击一键收藏，长按选择收藏夹',
                      active: isFav,
                      progress: tripleProgress,
                      onTap: onFavTap,
                      onLongPressStart: (_) => onFavLongPress(),
                    ),
                  ],
                );
              },
            ),
          ),
          VideoActionButton(
            icon: Icons.share_outlined,
            label: shareCount > 0 ? Formatters.formatCount(shareCount) : '分享',
            semanticLabel: '分享视频',
            active: false,
            onTap: onShareTap,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 1,
                thickness: 0.8,
                color: context.colors.divider,
              ),
            ),
          ),
          _IconAction(
            icon: isCached
                ? Icons.download_done_rounded
                : (isDownloading
                      ? Icons.downloading_rounded
                      : Icons.download_for_offline_outlined),
            tooltip: isCached ? '已缓存' : (isDownloading ? '缓存中' : '缓存'),
            active: isCached || isDownloading,
            color: isCached ? context.colors.success : null,
            onTap: onCacheTap,
          ),
          _IconAction(
            icon: Icons.headphones_rounded,
            tooltip: '听视频',
            active: false,
            onTap: onListenTap,
          ),
          _IconAction(
            icon: isInWatchLater
                ? Icons.watch_later_rounded
                : Icons.watch_later_outlined,
            tooltip: isInWatchLater ? '已添加稍后看' : '稍后看',
            active: isInWatchLater,
            onTap: onWatchLaterTap,
          ),
        ],
      ),
    );
  }
}
