import 'package:flutter/material.dart';
import '../../models/play_url_model.dart';
import '../../models/video_model.dart';
import '../../screens/profile/video_cache_screen.dart';
import '../../services/storage/video_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../app_toast.dart';

class VideoCacheBottomSheet extends StatefulWidget {
  final VideoDetail detail;
  final PlayUrlInfo? playUrlInfo;
  final int initialPageIndex;

  const VideoCacheBottomSheet({
    super.key,
    required this.detail,
    this.playUrlInfo,
    this.initialPageIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required VideoDetail detail,
    PlayUrlInfo? playUrlInfo,
    int initialPageIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoCacheBottomSheet(
        detail: detail,
        playUrlInfo: playUrlInfo,
        initialPageIndex: initialPageIndex,
      ),
    );
  }

  @override
  State<VideoCacheBottomSheet> createState() => _VideoCacheBottomSheetState();
}

class _VideoCacheBottomSheetState extends State<VideoCacheBottomSheet> {
  late int _selectedQuality;
  late String _selectedQualityDesc;
  final Set<int> _selectedPageIndices = {};

  @override
  void initState() {
    super.initState();
    final q = widget.playUrlInfo?.currentQuality ?? 80;
    _selectedQuality = q;
    _selectedQualityDesc = _getQualityDesc(q);

    final pages = _getEpisodes();
    for (int i = 0; i < pages.length; i++) {
      final cid = pages[i].cid;
      if (!VideoCacheService().isCached(widget.detail.videoItem.bvid, cid) &&
          !VideoCacheService().isDownloadingOrPending(widget.detail.videoItem.bvid, cid)) {
        if (i == widget.initialPageIndex || pages.length == 1) {
          _selectedPageIndices.add(i);
        }
      }
    }
  }

  String _getQualityDesc(int q) {
    if (widget.playUrlInfo != null) {
      for (final sf in widget.playUrlInfo!.supportFormats) {
        if (sf.quality == q) {
          return sf.newDescription.isNotEmpty
              ? sf.newDescription
              : (sf.displayDesc.isNotEmpty ? sf.displayDesc : '${q}P');
        }
      }
    }
    switch (q) {
      case 127:
        return '8K 超高清';
      case 120:
        return '4K 超清';
      case 116:
        return '1080P 60帧';
      case 112:
        return '1080P 高码率';
      case 80:
        return '1080P 高清';
      case 74:
        return '720P 60帧';
      case 64:
        return '720P 高清';
      case 32:
        return '480P 清晰';
      case 16:
        return '360P 流畅';
      default:
        return '${q}P';
    }
  }

  List<_CacheEpisodeItem> _getEpisodes() {
    if (widget.detail.pages.isNotEmpty) {
      return widget.detail.pages
          .asMap()
          .entries
          .map((e) => _CacheEpisodeItem(
                index: e.key,
                cid: e.value.cid,
                title: e.value.part.isNotEmpty ? e.value.part : '第 ${e.key + 1} 集',
                duration: e.value.duration,
              ))
          .toList();
    } else if (widget.detail.ugcSeason != null &&
        widget.detail.ugcSeason!.sections.isNotEmpty) {
      final eps = widget.detail.ugcSeason!.sections.expand((s) => s.episodes).toList();
      return eps
          .asMap()
          .entries
          .map((e) => _CacheEpisodeItem(
                index: e.key,
                cid: e.value.cid,
                title: e.value.title.isNotEmpty ? e.value.title : '第 ${e.key + 1} 集',
                duration: 0,
              ))
          .toList();
    } else {
      return [
        _CacheEpisodeItem(
          index: 0,
          cid: widget.detail.videoItem.cid,
          title: widget.detail.videoItem.title,
          duration: widget.detail.videoItem.duration,
        )
      ];
    }
  }

  void _toggleSelectAll(List<_CacheEpisodeItem> episodes) {
    final cacheService = VideoCacheService();
    final selectableIndices = <int>[];

    for (int i = 0; i < episodes.length; i++) {
      final cid = episodes[i].cid;
      if (!cacheService.isCached(widget.detail.videoItem.bvid, cid) &&
          !cacheService.isDownloadingOrPending(widget.detail.videoItem.bvid, cid)) {
        selectableIndices.add(i);
      }
    }

    setState(() {
      if (_selectedPageIndices.length >= selectableIndices.length) {
        _selectedPageIndices.clear();
      } else {
        _selectedPageIndices.addAll(selectableIndices);
      }
    });
  }

  void _startCaching(List<_CacheEpisodeItem> episodes) {
    if (_selectedPageIndices.isEmpty) {
      AppToast.show(context, '请先选择需要缓存的剧集/分P');
      return;
    }

    final cacheService = VideoCacheService();
    int addedCount = 0;

    for (final idx in _selectedPageIndices) {
      if (idx >= 0 && idx < episodes.length) {
        final ep = episodes[idx];
        cacheService.addTask(
          bvid: widget.detail.videoItem.bvid,
          aid: widget.detail.videoItem.aid,
          cid: ep.cid,
          title: widget.detail.videoItem.title,
          cover: widget.detail.videoItem.pic,
          ownerName: widget.detail.videoItem.owner.name,
          ownerFace: widget.detail.videoItem.owner.face,
          pageTitle: ep.title,
          pageIndex: ep.index,
          pageCount: episodes.length,
          duration: ep.duration,
          quality: _selectedQuality,
          qualityDesc: _selectedQualityDesc,
        );
        addedCount++;
      }
    }

    Navigator.of(context).pop();
    AppToast.show(
      context,
      '已将 $addedCount 个视频加入离线缓存队列',
      icon: Icons.download_done_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    final episodes = _getEpisodes();
    final cacheService = VideoCacheService();

    final qualities = widget.playUrlInfo != null &&
            widget.playUrlInfo!.acceptQuality.isNotEmpty
        ? widget.playUrlInfo!.acceptQuality
        : [80, 64, 32, 16];

    return AnimatedBuilder(
      animation: cacheService,
      builder: (context, _) {
        int selectableCount = 0;
        for (final ep in episodes) {
          if (!cacheService.isCached(widget.detail.videoItem.bvid, ep.cid) &&
              !cacheService.isDownloadingOrPending(widget.detail.videoItem.bvid, ep.cid)) {
            selectableCount++;
          }
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.download_for_offline_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '离线缓存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const VideoCacheScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '查看缓存',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),

                // Quality Selector Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '清晰度',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: qualities.map((q) {
                            final isSelected = _selectedQuality == q;
                            final desc = _getQualityDesc(q);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedQuality = q;
                                    _selectedQualityDesc = desc;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor
                                        : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : (isDark ? Colors.white12 : Colors.black12),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? onPrimary
                                          : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Episodes Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        episodes.length == 1 ? '视频剧集' : '剧集列表 (共 ${episodes.length} 集)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                        ),
                      ),
                      const Spacer(),
                      if (selectableCount > 1)
                        InkWell(
                          onTap: () => _toggleSelectAll(episodes),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              _selectedPageIndices.length >= selectableCount ? '取消全选' : '全选',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Episodes Content
                if (episodes.length == 1)
                  _buildSingleEpisodeItem(
                    context,
                    episodes.first,
                    isDark,
                    primaryColor,
                    onPrimary,
                    cacheService,
                  )
                else
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.42,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: episodes.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final ep = episodes[i];
                          return _buildEpisodeTile(
                            context,
                            ep,
                            isDark,
                            primaryColor,
                            onPrimary,
                            cacheService,
                          );
                        },
                      ),
                    ),
                  ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '已选 ${_selectedPageIndices.length} 集',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '画质：$_selectedQualityDesc',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _selectedPageIndices.isEmpty
                            ? null
                            : () => _startCaching(episodes),
                        icon: Icon(Icons.download_rounded, size: 18, color: onPrimary),
                        label: Text(
                          _selectedPageIndices.isEmpty
                              ? '请选择剧集'
                              : '开始缓存 (${_selectedPageIndices.length})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: onPrimary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: onPrimary,
                          disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                          disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
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
    );
  }

  Widget _buildSingleEpisodeItem(
    BuildContext context,
    _CacheEpisodeItem ep,
    bool isDark,
    Color primaryColor,
    Color onPrimary,
    VideoCacheService cacheService,
  ) {
    final bvid = widget.detail.videoItem.bvid;
    final isCached = cacheService.isCached(bvid, ep.cid);
    final inProgress = cacheService.isDownloadingOrPending(bvid, ep.cid);
    final isSelected = _selectedPageIndices.contains(ep.index);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Material(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: (isCached || inProgress)
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedPageIndices.remove(ep.index);
                    } else {
                      _selectedPageIndices.add(ep.index);
                    }
                  });
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : Colors.black12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ep.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ep.duration > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '时长：${Formatters.formatDuration(ep.duration)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isCached)
                  _buildBadge('已缓存', Colors.green)
                else if (inProgress)
                  _buildBadge('缓存中', primaryColor)
                else
                  Checkbox(
                    value: isSelected,
                    activeColor: primaryColor,
                    checkColor: onPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPageIndices.add(ep.index);
                        } else {
                          _selectedPageIndices.remove(ep.index);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeTile(
    BuildContext context,
    _CacheEpisodeItem ep,
    bool isDark,
    Color primaryColor,
    Color onPrimary,
    VideoCacheService cacheService,
  ) {
    final bvid = widget.detail.videoItem.bvid;
    final isCached = cacheService.isCached(bvid, ep.cid);
    final inProgress = cacheService.isDownloadingOrPending(bvid, ep.cid);
    final isSelected = _selectedPageIndices.contains(ep.index);

    return Material(
      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: (isCached || inProgress)
            ? null
            : () {
                setState(() {
                  if (isSelected) {
                    _selectedPageIndices.remove(ep.index);
                  } else {
                    _selectedPageIndices.add(ep.index);
                  }
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${ep.index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ep.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ep.duration > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatDuration(ep.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCached)
                _buildBadge('已缓存', Colors.green)
              else if (inProgress)
                _buildBadge('缓存中', primaryColor)
              else
                Checkbox(
                  value: isSelected,
                  activeColor: primaryColor,
                  checkColor: onPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedPageIndices.add(ep.index);
                      } else {
                        _selectedPageIndices.remove(ep.index);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CacheEpisodeItem {
  final int index;
  final int cid;
  final String title;
  final int duration;

  _CacheEpisodeItem({
    required this.index,
    required this.cid,
    required this.title,
    required this.duration,
  });
}
