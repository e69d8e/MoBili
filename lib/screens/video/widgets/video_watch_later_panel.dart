import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/network_image_view.dart';

/// Horizontal section displaying watch-later playlist preview on video detail screen.
class VideoWatchLaterSection extends StatelessWidget {
  final List<WatchLaterItem> items;
  final int currentIndex;
  final String currentBvid;
  final bool isDark;
  final Color primaryColor;
  final void Function(WatchLaterItem item, int index) onSelectItem;
  final VoidCallback onTapMore;

  const VideoWatchLaterSection({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.currentBvid,
    required this.isDark,
    required this.primaryColor,
    required this.onSelectItem,
    required this.onTapMore,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surfaceDark.withValues(alpha: 0.5)
            : AppTheme.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.watch_later_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '稍后看列表 · 第 ${currentIndex + 1}/${items.length} 个视频',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onTapMore,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '共 ${items.length} 个',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (c, _) => const SizedBox(width: 8),
              itemBuilder: (c, idx) {
                final item = items[idx];
                final isPlaying = idx == currentIndex || item.bvid == currentBvid;

                return InkWell(
                  onTap: () => onSelectItem(item, idx),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? primaryColor.withValues(alpha: 0.12)
                          : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPlaying ? primaryColor : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  NetworkImageView(
                                    url: item.pic,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                    memCacheHeight: 125,
                                  ),
                                  if (item.duration > 0)
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          Formatters.formatDuration(item.duration),
                                          style: const TextStyle(color: Colors.white, fontSize: 8.5),
                                        ),
                                      ),
                                    ),
                                  if (isPlaying)
                                    Positioned(
                                      top: 2,
                                      left: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          '播放中',
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                  color: isPlaying
                                      ? primaryColor
                                      : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.ownerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet displaying complete watch-later list.
class VideoWatchLaterSheet {
  static void show(
    BuildContext context, {
    required List<WatchLaterItem> items,
    required int currentIndex,
    required String currentBvid,
    required void Function(WatchLaterItem item, int index) onSelectItem,
  }) {
    if (items.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.watch_later_rounded, size: 18, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      '稍后观看列表 (共 ${items.length} 个视频)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
              ),
              Flexible(
                child: ListView.separated(
                  // 长列表懒加载；短列表保持 shrinkWrap 以免弹窗被撑满
                  shrinkWrap: items.length <= 12,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (c, _) => const SizedBox(height: 8),
                  itemBuilder: (c, idx) {
                    final item = items[idx];
                    final isPlaying = idx == currentIndex || item.bvid == currentBvid;

                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelectItem(item, idx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? primaryColor.withValues(alpha: 0.12)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPlaying ? primaryColor : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: AspectRatio(
                                aspectRatio: 16 / 10,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      NetworkImageView(
                                        url: item.pic,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 240,
                                        memCacheHeight: 150,
                                      ),
                                      if (item.duration > 0)
                                        Positioned(
                                          bottom: 3,
                                          right: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.7),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              Formatters.formatDuration(item.duration),
                                              style: const TextStyle(color: Colors.white, fontSize: 9),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                      color: isPlaying
                                          ? primaryColor
                                          : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.ownerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                          ),
                                        ),
                                      ),
                                      if (isPlaying)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            '播放中',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
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
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
