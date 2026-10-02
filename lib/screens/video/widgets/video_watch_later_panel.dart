import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/network_image_view.dart';

/// Horizontal section displaying watch-later playlist preview on video detail screen.
class VideoWatchLaterSection extends StatelessWidget {
  final List<WatchLaterItem> items;
  final int currentIndex;
  final String currentBvid;
  final void Function(WatchLaterItem item, int index) onSelectItem;
  final VoidCallback onTapMore;

  const VideoWatchLaterSection({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.currentBvid,
    required this.onSelectItem,
    required this.onTapMore,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Text(
                  '稍后看',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '第 ${currentIndex + 1}/${items.length} 个',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textHint,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onTapMore,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '全部',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textHint,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: context.colors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (c, _) => const SizedBox(width: 8.0),
              itemBuilder: (c, idx) {
                final item = items[idx];
                final isPlaying = idx == currentIndex || item.bvid == currentBvid;

                return InkWell(
                  onTap: () => onSelectItem(item, idx),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? primaryColor.withValues(alpha: 0.12)
                          : (context.colors.fill),
                      borderRadius: BorderRadius.circular(8),
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
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          Formatters.formatDuration(item.duration),
                                          style: const TextStyle(color: Colors.white, fontSize: 10),
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
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '播放中',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
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
                                  fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                                  color: isPlaying
                                      ? primaryColor
                                      : (context.colors.textMain),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.ownerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.colors.textHint,
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
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: Row(
                  children: [
                    Icon(Icons.watch_later_rounded, size: 18, color: primaryColor),
                    const SizedBox(width: 8.0),
                    Text(
                      '稍后观看列表 (共 ${items.length} 个视频)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                color: context.colors.divider,
              ),
              Flexible(
                child: ListView.separated(
                  // 长列表懒加载；短列表保持 shrinkWrap 以免弹窗被撑满
                  shrinkWrap: items.length <= 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  itemCount: items.length,
                  separatorBuilder: (c, _) => const SizedBox(height: 8.0),
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
                        padding: const EdgeInsets.all(8.0),
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
                                  borderRadius: BorderRadius.circular(8),
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
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              Formatters.formatDuration(item.duration),
                                              style: const TextStyle(color: Colors.white, fontSize: 10),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                                      color: isPlaying
                                          ? primaryColor
                                          : (context.colors.textMain),
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
                                            color: context.colors.textHint,
                                          ),
                                        ),
                                      ),
                                      if (isPlaying)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            '播放中',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
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
