import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/formatters.dart';

/// 主操作按钮（点赞/投币/收藏）：图标 + 计数文字，支持长按三连进度圈。
class VideoActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPressStart: onLongPressStart,
          onLongPressEnd: onLongPressEnd,
          onLongPressCancel: onLongPressCancel,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (progress != null && progress! > 0)
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      Icon(
                        icon,
                        size: 21,
                        color: active ? activeColor : (context.colors.textSub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? activeColor : (context.colors.textSub),
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 次操作按钮（缓存/听视频/稍后看）：纯图标，靠间距分组弱化视觉权重。
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
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
              color: active ? activeColor : (context.colors.textHint),
            ),
          ),
        ),
      ),
    );
  }
}

/// 互动操作（点赞/投币/收藏，带计数）+ 工具操作（缓存/听视频/稍后看，仅图标）分组排列。
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
  final VoidCallback onFavTap;

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
          AnimatedBuilder(
            animation: tripleComboAnimation,
            builder: (context, _) {
              return VideoActionButton(
                icon: isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                label: Formatters.formatCount(likeCount),
                active: isLiked,
                progress: tripleComboAnimation.value,
                onTap: onLikeTap,
                onLongPressStart: onLikeLongPressStart,
                onLongPressEnd: onLikeLongPressEnd,
                onLongPressCancel: onLikeLongPressCancel,
              );
            },
          ),
          VideoActionButton(
            icon: coinCount > 0 ? Icons.monetization_on_rounded : Icons.monetization_on_outlined,
            label: coinCount > 0 ? '已投$coinCount币' : Formatters.formatCount(totalCoins),
            active: coinCount > 0,
            onTap: onCoinTap,
          ),
          VideoActionButton(
            icon: isFav ? Icons.star_rounded : Icons.star_outline_rounded,
            label: Formatters.formatCount(favCount),
            active: isFav,
            onTap: onFavTap,
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
            icon: isInWatchLater ? Icons.watch_later_rounded : Icons.watch_later_outlined,
            tooltip: isInWatchLater ? '已添加稍后看' : '稍后看',
            active: isInWatchLater,
            onTap: onWatchLaterTap,
          ),
        ],
      ),
    );
  }
}
