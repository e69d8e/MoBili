import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api/user_api_service.dart';
import '../../services/storage/history_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/state_views.dart';
import '../video/video_detail_screen.dart';

class WatchLaterScreen extends StatefulWidget {
  const WatchLaterScreen({super.key});

  @override
  State<WatchLaterScreen> createState() => _WatchLaterScreenState();
}

class _WatchLaterScreenState extends State<WatchLaterScreen> {
  final List<WatchLaterItem> _items = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    setState(() {
      if (_items.isEmpty || refresh) _isLoading = true;
    });

    final list = await UserApiService().getWatchLaterList(pn: _page, ps: 30);

    if (mounted) {
      setState(() {
        if (refresh || _page == 1) {
          _items.clear();
          _items.addAll(list);
        } else {
          _items.addAll(list);
        }
        _hasMore = list.isNotEmpty;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    _page++;
    final list = await UserApiService().getWatchLaterList(pn: _page, ps: 30);

    if (mounted) {
      setState(() {
        if (list.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(list);
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _deleteItem(WatchLaterItem item, int index) async {
    final removedItem = _items[index];
    setState(() {
      _items.removeAt(index);
    });

    final ok = await UserApiService().deleteFromWatchLater(aid: item.aid);
    if (!ok && mounted) {
      setState(() {
        _items.insert(index, removedItem);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败，请重试')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已从稍后观看移除'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空稍后观看', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('确定要清空稍后观看列表中的所有视频吗？', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await UserApiService().clearWatchLater();
    if (ok && mounted) {
      setState(() {
        _items.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空稍后观看列表')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('清空失败，请重试')),
      );
    }
  }

  void _playAll() {
    if (_items.isEmpty) return;
    final first = _items.first;
    final firstProgress = first.progress > 0
        ? first.progress
        : HistoryStorageService().getProgress(first.bvid);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => VideoDetailScreen(
          bvid: first.bvid,
          initialPosition: firstProgress > 0
              ? Duration(seconds: firstProgress)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('稍后观看'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 22),
              tooltip: '清空列表',
              onPressed: _clearAll,
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading && _items.isEmpty
          ? const LoadingView(message: '正在加载稍后观看...')
          : _items.isEmpty
              ? EmptyView(
                  message: '暂无稍后观看视频',
                  icon: Icons.watch_later_outlined,
                  onRetry: () => _loadData(refresh: true),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: () => _loadData(refresh: true),
                    child: ListView.builder(
                      cacheExtent: 500.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: _items.length + 1 + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (ctx, idx) {
                        final primaryColor = Theme.of(context).colorScheme.primary;
                        final onPrimary = Theme.of(context).colorScheme.onPrimary;

                        // Header: Play All action bar
                        if (idx == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Text(
                                  '共 ${_items.length} 个视频',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                                  ),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _playAll,
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('播放全部', style: TextStyle(fontSize: 12.5)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: onPrimary,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final itemIndex = idx - 1;

                        if (itemIndex == _items.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                            ),
                          );
                        }

                        final item = _items[itemIndex];
                        final effectiveProgress = item.progress > 0
                            ? item.progress
                            : HistoryStorageService().getProgress(item.bvid);

                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => VideoDetailScreen(
                                      bvid: item.bvid,
                                      initialPosition: effectiveProgress > 0
                                          ? Duration(seconds: effectiveProgress)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Thumbnail
                                  SizedBox(
                                    width: 124,
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
                                              memCacheWidth: 360,
                                              memCacheHeight: 225,
                                            ),
                                          if (item.duration > 0)
                                            Positioned(
                                              bottom: 4,
                                              right: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  Formatters.formatDuration(item.duration),
                                                  style: const TextStyle(color: Colors.white, fontSize: 9.5),
                                                ),
                                              ),
                                            ),
                                          if (effectiveProgress > 0)
                                            Positioned(
                                              bottom: 4,
                                              left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: primaryColor.withValues(alpha: 0.85),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '看到 ${Formatters.formatDuration(effectiveProgress)}',
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
                                // Video Info
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
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                          color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.ownerName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.addAt > 0 ? '添加于 ${Formatters.formatTime(item.addAt)}' : item.bvid,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete menu button
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                  ),
                                  tooltip: '从稍后观看移除',
                                  onPressed: () => _deleteItem(item, itemIndex),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      },
                    ),
                  ),
                ),
    );
  }
}
