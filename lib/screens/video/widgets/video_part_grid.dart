import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/video_model.dart';
import '../../../services/settings/player_settings_service.dart';
import '../../../services/storage/video_cache_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/formatters.dart';

/// 分 P 宫格单元：序号 / 标题 / 时长 / 缓存角标，对齐官方「选集」宫格。
///
/// 序号始终用真实分 P 序号（倒序展示时也不跟着翻），避免用户看到
/// 「P1」点进去却是最后一集。
class VideoPartTile extends StatelessWidget {
  const VideoPartTile({
    super.key,
    required this.page,
    required this.number,
    required this.isPlaying,
    required this.isCached,
    required this.isDownloading,
    required this.onTap,
  });

  final VideoPage page;
  final int number;
  final bool isPlaying;
  final bool isCached;
  final bool isDownloading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: isPlaying
                ? primaryColor.withValues(alpha: 0.12)
                : context.colors.fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPlaying ? primaryColor : context.colors.divider,
              width: isPlaying ? 1.2 : 0.8,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isPlaying)
                        Padding(
                          padding: const EdgeInsets.only(right: 3.0),
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 12,
                            color: primaryColor,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          'P$number',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPlaying
                                ? primaryColor
                                : context.colors.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    page.part.isEmpty ? '第 $number 集' : page.part,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: isPlaying ? primaryColor : context.colors.textSub,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (page.duration > 0)
                    Text(
                      Formatters.formatDuration(page.duration),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.textHint,
                      ),
                    ),
                ],
              ),
              if (isCached || isDownloading)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    isCached
                        ? Icons.download_done_rounded
                        : Icons.downloading_rounded,
                    size: 13,
                    color: isCached
                        ? context.colors.success
                        : context.colors.textHint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分 P 宫格：支持正序/倒序、内联预览（[maxItems]）与完整面板。
///
/// [onSelect] 回传的是真实分 P 下标，调用方可直接交给 _switchPart。
class VideoPartGrid extends StatelessWidget {
  const VideoPartGrid({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.bvid,
    required this.onSelect,
    this.reversed = false,
    this.maxItems,
    this.shrinkWrap = false,
    this.crossAxisCount,
    this.controller,
  });

  final List<VideoPage> pages;
  final int selectedIndex;
  final String bvid;
  final void Function(int realIndex) onSelect;
  final bool reversed;
  final int? maxItems;
  final bool shrinkWrap;
  final int? crossAxisCount;
  final ScrollController? controller;

  /// 宫格单元固定高度；面板据此估算自身高度，短列表不会被撑满全屏。
  static const double tileHeight = 76.0;

  static int columnsForWidth(double width) {
    if (width >= 1000) return 6;
    if (width >= 720) return 5;
    if (width >= 520) return 4;
    return 3;
  }

  /// 内联预览只取一段，但当前播放的分 P 必须落在这一段里，
  /// 否则用户看到的是「没有一集高亮」的选集区，找不到自己正在看哪一集。
  List<int> _windowSlice(List<int> display) {
    final limit = maxItems;
    if (limit == null || display.length <= limit) return display;
    final position = display.indexOf(selectedIndex);
    if (position < 0) return display.take(limit).toList();
    final maxStart = display.length - limit;
    final start = (position - limit ~/ 2).clamp(0, maxStart);
    return display.sublist(start, start + limit);
  }

  @override
  Widget build(BuildContext context) {
    final order = List<int>.generate(pages.length, (i) => i);
    final display = reversed ? order.reversed.toList() : order;
    final shown = _windowSlice(display);
    final columns =
        crossAxisCount ?? columnsForWidth(MediaQuery.of(context).size.width);

    // 缓存状态收敛到单个分P节点内部监听，避免下载进度每 400ms 触发整张网格重建
    return GridView.builder(
      controller: controller,
      primary: false,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
        mainAxisExtent: tileHeight,
      ),
      itemCount: shown.length,
      itemBuilder: (ctx, i) {
        final realIndex = shown[i];
        final page = pages[realIndex];
        return AnimatedBuilder(
          animation: VideoCacheService(),
          builder: (context, _) {
            return VideoPartTile(
              page: page,
              number: realIndex + 1,
              isPlaying: realIndex == selectedIndex,
              isCached: VideoCacheService().isCached(bvid, page.cid),
              isDownloading: VideoCacheService().isDownloadingOrPending(
                bvid,
                page.cid,
              ),
              onTap: () => onSelect(realIndex),
            );
          },
        );
      },
    );
  }
}

/// 分 P 选集面板：正序/倒序切换 + 自动连播开关 + 完整宫格。
///
/// 自动连播直接复用设置页里的 player_auto_play_next_episode，
/// 不另建一份状态，避免两处开关互相打架。
class VideoPartGridSheet extends StatefulWidget {
  const VideoPartGridSheet({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.bvid,
    required this.onSelect,
  });

  final List<VideoPage> pages;
  final int selectedIndex;
  final String bvid;
  final void Function(int realIndex) onSelect;

  static Future<void> show(
    BuildContext context, {
    required List<VideoPage> pages,
    required int selectedIndex,
    required String bvid,
    required void Function(int realIndex) onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoPartGridSheet(
        pages: pages,
        selectedIndex: selectedIndex,
        bvid: bvid,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<VideoPartGridSheet> createState() => _VideoPartGridSheetState();
}

class _VideoPartGridSheetState extends State<VideoPartGridSheet> {
  bool _reversed = false;
  late bool _autoPlayNext = PlayerSettingsService.autoPlayNextEpisode;
  final ScrollController _gridController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 长分 P 视频打开面板时，当前播放的那一集往往在可视区外，首帧后滚过去
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrentPart());
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  void _revealCurrentPart({bool animate = false}) {
    if (!mounted || !_gridController.hasClients) return;
    final columns = VideoPartGrid.columnsForWidth(
      MediaQuery.of(context).size.width,
    );
    final displayIndex = _reversed
        ? (widget.pages.length - 1 - widget.selectedIndex)
        : widget.selectedIndex;
    final row = displayIndex ~/ columns;
    final target = row * (VideoPartGrid.tileHeight + 8.0);
    final maxExtent = _gridController.position.maxScrollExtent;
    final clamped = target.clamp(0.0, maxExtent);
    if (animate) {
      _gridController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _gridController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final columns = VideoPartGrid.columnsForWidth(
      MediaQuery.of(context).size.width,
    );
    final rows = (widget.pages.length / columns).ceil();
    final gridHeight =
        rows * VideoPartGrid.tileHeight + math.max(0, rows - 1) * 8.0;
    // 把手 + 标题行 + 自动连播行 + 分隔 + 内边距
    const chromeHeight = 14.0 + 48.0 + 40.0 + 9.0 + 12.0;
    final sheetHeight = math.min(
      screenHeight * 0.72,
      chromeHeight + gridHeight + bottomInset + 8.0,
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: sheetHeight,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 拖拽把手
            Padding(
              padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题 + 正倒序
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 8.0, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '选集',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '共 ${widget.pages.length} 集',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _reversed = !_reversed);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _revealCurrentPart(animate: true),
                        );
                      },
                      icon: Icon(
                        _reversed
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _reversed ? '倒序' : '正序',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            // 自动连播（与设置页共用一份持久化状态）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.playlist_play_rounded,
                        size: 16,
                        color: context.colors.textHint,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('播完自动连播下一集', style: TextStyle(fontSize: 12)),
                      ),
                      Switch(
                        value: _autoPlayNext,
                        onChanged: (val) {
                          setState(() => _autoPlayNext = val);
                          PlayerSettingsService.setAutoPlayNextEpisode(val);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 0.5, color: context.colors.divider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                child: VideoPartGrid(
                  pages: widget.pages,
                  selectedIndex: widget.selectedIndex,
                  bvid: widget.bvid,
                  reversed: _reversed,
                  crossAxisCount: columns,
                  controller: _gridController,
                  onSelect: (idx) {
                    Navigator.of(context).pop();
                    widget.onSelect(idx);
                  },
                ),
              ),
            ),
            SizedBox(height: bottomInset + 8.0),
          ],
        ),
      ),
    );
  }
}
