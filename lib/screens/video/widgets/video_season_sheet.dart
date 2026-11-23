import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/video_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../utils/formatters.dart';

/// 底部抽屉形式展示 UGC 合集选集，统一支持手势下拉关闭与自动定位当前剧集。
class VideoSeasonSheet {
  static Future<void> show(
    BuildContext context, {
    required UgcSeason season,
    required String currentBvid,
    required void Function(UgcEpisode ep) onSelectEpisode,
  }) {
    final allEpisodes = season.sections.expand((s) => s.episodes).toList();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        final bottomInset = MediaQuery.of(ctx).padding.bottom;

        return Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.65),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: AppRadius.sheet,
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14.0,
                10.0,
                14.0,
                math.max(12.0, bottomInset > 0 ? 4.0 : 12.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10.0),
                      decoration: BoxDecoration(
                        color: context.colors.divider,
                        borderRadius: AppRadius.of(AppRadius.pill),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: AppRadius.of(AppRadius.sm),
                        ),
                        child: Icon(
                          Icons.video_library_rounded,
                          size: 15,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '合集选集',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${season.title} · 共${season.epCount}集',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textHint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: context.colors.divider,
                  ),
                  const SizedBox(height: 8.0),

                  // Episode List（打开时自动定位到正在播放的剧集）
                  Flexible(
                    child: _EpisodeList(
                      episodes: allEpisodes,
                      currentBvid: currentBvid,
                      onSelectEpisode: onSelectEpisode,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 合集选集列表：打开时自动滚动定位到正在播放的剧集。
///
/// 长列表（懒加载）下目标项初始时可能尚未构建，因此先用与真实布局一致的
/// 行高估算设置 initialScrollOffset 让目标项落在可视范围内，首帧后再用
/// GlobalKey + Scrollable.ensureVisible 做精确校正。
class _EpisodeList extends StatefulWidget {
  const _EpisodeList({
    required this.episodes,
    required this.currentBvid,
    required this.onSelectEpisode,
  });

  final List<UgcEpisode> episodes;
  final String currentBvid;
  final void Function(UgcEpisode ep) onSelectEpisode;

  @override
  State<_EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends State<_EpisodeList> {
  // 与下方 item 布局保持一致：vertical 7×2 padding + 1×2 border
  static const double _itemOuterHeight = 16;
  static const double _separatorHeight = 6;
  static const double _durationGap = 2;

  ScrollController? _scrollController;
  final GlobalKey _currentItemKey = GlobalKey();

  late final int _currentIndex =
      widget.episodes.indexWhere((ep) => ep.bvid == widget.currentBvid);

  @override
  void initState() {
    super.initState();
    if (_currentIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealCurrentEpisode();
      });
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  void _revealCurrentEpisode() {
    if (!mounted) return;
    final itemContext = _currentItemKey.currentContext;
    if (itemContext == null) return;
    Scrollable.ensureVisible(
      itemContext,
      alignment: 0.2,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// 估算第 [index] 项顶部的累计偏移。行高用 TextPainter 按与真实渲染
  /// 相同的合并样式（DefaultTextStyle + 显式样式）测量，误差在像素级。
  double _estimateOffsetTo(int index) {
    final baseStyle = DefaultTextStyle.of(context).style;
    double offset = 0;
    for (var i = 0; i < index; i++) {
      final ep = widget.episodes[i];
      final isPlaying = ep.bvid == widget.currentBvid;
      double contentHeight = _measureOneLineHeight(
        '${i + 1}. ${ep.title}',
        baseStyle.merge(TextStyle(
          fontSize: 12,
          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
        )),
      );
      if (ep.duration > 0) {
        contentHeight += _durationGap;
        contentHeight += _measureOneLineHeight(
          Formatters.formatDuration(ep.duration),
          baseStyle.merge(const TextStyle(fontSize: 10)),
        );
      }
      offset += contentHeight + _itemOuterHeight + _separatorHeight;
    }
    return offset;
  }

  static double _measureOneLineHeight(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 10000);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final shrinkWrap = widget.episodes.length <= 12;

    // 短列表整体可见无需初始偏移；长列表按估算定位，-24px 余量吸收
    // 估算误差并保证目标项一定在已构建范围内。
    _scrollController ??= ScrollController(
      initialScrollOffset: (_currentIndex > 0 && !shrinkWrap)
          ? math.max(0.0, _estimateOffsetTo(_currentIndex) - 24)
          : 0.0,
    );

    return ListView.separated(
      // 长列表懒加载；短列表保持 shrinkWrap 以免弹窗被撑满
      controller: _scrollController,
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.zero,
      itemCount: widget.episodes.length,
      separatorBuilder: (c, _) => const SizedBox(height: _separatorHeight),
      itemBuilder: (c, idx) {
        final ep = widget.episodes[idx];
        final isPlaying = ep.bvid == widget.currentBvid;
        return InkWell(
          key: isPlaying ? _currentItemKey : null,
          onTap: () {
            Navigator.of(c).pop();
            widget.onSelectEpisode(ep);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isPlaying
                  ? primaryColor.withValues(alpha: 0.14)
                  : c.colors.fill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPlaying ? primaryColor : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (isPlaying)
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: primaryColor,
                      size: 14,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${idx + 1}. ${ep.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isPlaying
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isPlaying
                              ? primaryColor
                              : (context.colors.textMain),
                        ),
                      ),
                      if (ep.duration > 0) ...[
                        const SizedBox(height: _durationGap),
                        Text(
                          Formatters.formatDuration(ep.duration),
                          style: TextStyle(
                            fontSize: 10,
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
        );
      },
    );
  }
}
