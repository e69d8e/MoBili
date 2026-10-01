import 'package:flutter/material.dart';
import '../../models/video_cache_model.dart';
import '../../services/storage/video_cache_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/network_image_view.dart';
import '../video/cached_video_player_screen.dart';

class VideoCacheScreen extends StatefulWidget {
  const VideoCacheScreen({super.key});

  @override
  State<VideoCacheScreen> createState() => _VideoCacheScreenState();
}

class _VideoCacheScreenState extends State<VideoCacheScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VideoCacheService _cacheService = VideoCacheService();

  bool _isBatchEditing = false;
  final Set<String> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleBatchEdit() {
    setState(() {
      _isBatchEditing = !_isBatchEditing;
      _selectedTaskIds.clear();
    });
  }

  void _selectAll(List<VideoCacheItem> items) {
    setState(() {
      if (_selectedTaskIds.length >= items.length) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds.addAll(items.map((e) => e.taskId));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedTaskIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除离线缓存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('确定要删除选中的 ${_selectedTaskIds.length} 个离线缓存视频吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ids = _selectedTaskIds.toList();
      for (final id in ids) {
        await _cacheService.deleteTask(id);
      }
      setState(() {
        _selectedTaskIds.clear();
        _isBatchEditing = false;
      });
      if (mounted) {
        AppToast.show(context, '已删除选中缓存视频');
      }
    }
  }

  Future<void> _clearAllCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部缓存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text('确定要清空所有已下载的离线视频吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('清空', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cacheService.clearAllCompleted();
      if (mounted) {
        AppToast.show(context, '已清空所有已缓存视频');
      }
    }
  }

  void _playCachedVideo(VideoCacheItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CachedVideoPlayerScreen(
          item: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _cacheService,
      builder: (context, _) {
        final completed = _cacheService.completedTasks;
        final downloading = _cacheService.downloadingTasks;
        final activeCount = _cacheService.activeDownloadingCount;

        return Scaffold(
          appBar: AppBar(
            title: const Text('离线缓存'),
            actions: [
              if (_tabController.index == 0 && completed.isNotEmpty) ...[
                if (_isBatchEditing) ...[
                  TextButton(
                    onPressed: () => _selectAll(completed),
                    child: Text(
                      _selectedTaskIds.length >= completed.length ? '全不选' : '全选',
                      style: TextStyle(color: primaryColor, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedTaskIds.isEmpty ? null : _deleteSelected,
                    child: Text(
                      '删除(${_selectedTaskIds.length})',
                      style: TextStyle(
                        color: _selectedTaskIds.isEmpty ? context.colors.textHint : context.colors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(_isBatchEditing ? Icons.done_rounded : Icons.edit_note_rounded),
                  tooltip: _isBatchEditing ? '完成' : '批量管理',
                  onPressed: _toggleBatchEdit,
                ),
              ],
              if (_tabController.index == 1 && downloading.isNotEmpty) ...[
                if (activeCount > 0)
                  TextButton.icon(
                    onPressed: () => _cacheService.pauseAll(),
                    icon: const Icon(Icons.pause_rounded, size: 16),
                    label: const Text('全部暂停', style: TextStyle(fontSize: 13)),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _cacheService.resumeAll(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('全部开始', style: TextStyle(fontSize: 13)),
                  ),
              ],
              const SizedBox(width: 4.0),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.colors.divider,
                      width: 0.5,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: primaryColor,
                  indicatorWeight: 2.5,
                  labelColor: primaryColor,
                  unselectedLabelColor: context.colors.textSub,
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                  onTap: (_) => setState(() {
                    _isBatchEditing = false;
                    _selectedTaskIds.clear();
                  }),
                  tabs: [
                    Tab(text: '已缓存 (${completed.length})'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('下载中 (${downloading.length})'),
                          if (activeCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Completed
                    _buildCompletedTab(completed, isDark, primaryColor),
                    // Tab 2: Downloading
                    _buildDownloadingTab(downloading, isDark, primaryColor),
                  ],
                ),
              ),
              // Bottom Storage Info Banner
              _buildStorageBanner(isDark, primaryColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedTab(
    List<VideoCacheItem> items,
    bool isDark,
    Color primaryColor,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done_rounded,
              size: 56,
              color: context.colors.textHint,
            ),
            const SizedBox(height: 12.0),
            Text(
              '暂无已缓存视频',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textSub,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              '在视频详情页点击「缓存」即可离线下载视频',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: items.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8.0),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final isSelected = _selectedTaskIds.contains(item.taskId);

        return Material(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (_isBatchEditing) {
                setState(() {
                  if (isSelected) {
                    _selectedTaskIds.remove(item.taskId);
                  } else {
                    _selectedTaskIds.add(item.taskId);
                  }
                });
              } else {
                _playCachedVideo(item);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isBatchEditing) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: primaryColor,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTaskIds.add(item.taskId);
                          } else {
                            _selectedTaskIds.remove(item.taskId);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Video Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 110,
                      height: 68,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (item.cover.isNotEmpty)
                            NetworkImageView(
                              url: item.cover,
                              fit: BoxFit.cover,
                              memCacheWidth: 220,
                              memCacheHeight: 136,
                            )
                          else
                            Container(color: isDark ? Colors.white10 : Colors.black26),
                          // Duration badge
                          if (item.duration > 0)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  Formatters.formatDuration(item.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8.0),

                  // Metadata Info
                  Expanded(
                    child: SizedBox(
                      height: 68,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.pageTitle.isNotEmpty && item.pageCount > 1
                                ? '${item.title} - ${item.pageTitle}'
                                : item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.qualityDesc,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                VideoCacheService.formatBytes(item.totalBytes),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textHint,
                                ),
                              ),
                              if (item.ownerName.isNotEmpty) ...[
                                const SizedBox(width: 4.0),
                                Expanded(
                                  child: Text(
                                    '· ${item.ownerName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.textHint,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!_isBatchEditing)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: context.colors.textHint,
                      ),
                      tooltip: '删除',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('删除离线视频', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            content: Text('确定要删除「${item.pageTitle.isNotEmpty ? item.pageTitle : item.title}」的离线缓存吗？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('删除', style: TextStyle(color: context.colors.danger)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _cacheService.deleteTask(item.taskId);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadingTab(
    List<VideoCacheItem> items,
    bool isDark,
    Color primaryColor,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.downloading_rounded,
              size: 56,
              color: context.colors.textHint,
            ),
            const SizedBox(height: 12.0),
            Text(
              '暂无正在下载的任务',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textSub,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: items.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8.0),
      itemBuilder: (ctx, i) {
        final item = items[i];

        return Material(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 48,
                        child: item.cover.isNotEmpty
                            ? NetworkImageView(
                                url: item.cover,
                                fit: BoxFit.cover,
                                memCacheWidth: 144,
                                memCacheHeight: 96,
                              )
                            : Container(color: isDark ? Colors.white10 : Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    // Title & Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.pageTitle.isNotEmpty && item.pageCount > 1
                                ? '${item.title} - ${item.pageTitle}'
                                : item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildStatusTag(item, primaryColor, isDark),
                              const SizedBox(width: 4.0),
                              Text(
                                item.qualityDesc,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Controls (Pause, Resume, Retry, Cancel)
                    _buildTaskControls(item, primaryColor, isDark),
                  ],
                ),

                const SizedBox(height: 8.0),

                // Linear Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.status == VideoCacheStatus.pending
                        ? null
                        : item.progress,
                    minHeight: 4,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item.status == VideoCacheStatus.failed ? context.colors.danger : primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 4.0),

                // Progress Size & Speed
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${VideoCacheService.formatBytes(item.downloadedBytes)} / ${item.totalBytes > 0 ? VideoCacheService.formatBytes(item.totalBytes) : '--'} (${(item.progress * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textHint,
                      ),
                    ),
                    if (item.isDownloading && item.downloadSpeed > 0)
                      Text(
                        '${VideoCacheService.formatBytes(item.downloadSpeed)}/s',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      )
                    else if (item.errorMsg != null)
                      Text(
                        item.errorMsg!,
                        style: TextStyle(fontSize: 11, color: context.colors.danger),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusTag(VideoCacheItem item, Color primaryColor, bool isDark) {
    String label;
    Color color;

    switch (item.status) {
      case VideoCacheStatus.downloading:
        label = '下载中';
        color = primaryColor;
        break;
      case VideoCacheStatus.pending:
        label = '排队中';
        color = context.colors.warning;
        break;
      case VideoCacheStatus.paused:
        label = '已暂停';
        color = context.colors.textHint;
        break;
      case VideoCacheStatus.failed:
        label = '失败';
        color = context.colors.danger;
        break;
      case VideoCacheStatus.completed:
        label = '已完成';
        color = context.colors.success;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTaskControls(VideoCacheItem item, Color primaryColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isDownloading)
          IconButton(
            icon: Icon(Icons.pause_circle_outline_rounded, color: primaryColor, size: 22),
            tooltip: '暂停',
            onPressed: () => _cacheService.pauseTask(item.taskId),
          )
        else if (item.isPaused || item.isPending)
          IconButton(
            icon: Icon(Icons.play_circle_outline_rounded, color: primaryColor, size: 22),
            tooltip: '继续',
            onPressed: () => _cacheService.resumeTask(item.taskId),
          )
        else if (item.isFailed)
          IconButton(
            icon: Icon(Icons.replay_rounded, color: context.colors.danger, size: 20),
            tooltip: '重试',
            onPressed: () => _cacheService.retryTask(item.taskId),
          ),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: context.colors.textHint),
          tooltip: '取消',
          onPressed: () => _cacheService.deleteTask(item.taskId),
        ),
      ],
    );
  }

  Widget _buildStorageBanner(bool isDark, Color primaryColor) {
    final formattedSize = _cacheService.getFormattedTotalCacheSize();
    final completedCount = _cacheService.totalCompletedCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: context.colors.fill,
        border: Border(
          top: BorderSide(
            color: context.colors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 16, color: primaryColor),
            const SizedBox(width: 4.0),
            Expanded(
              child: Text(
                '已缓存 $completedCount 个视频 · 占用 $formattedSize',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSub,
                ),
              ),
            ),
            if (completedCount > 0)
              InkWell(
                onTap: _clearAllCompleted,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4),
                  child: Text(
                    '清空全部',
                    style: TextStyle(fontSize: 12, color: context.colors.danger),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
