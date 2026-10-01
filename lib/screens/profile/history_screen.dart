import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/user_model.dart';
import '../../services/api/user_api_service.dart';
import '../../services/storage/history_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/state_views.dart';
import '../video/video_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _history = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      if (refresh) _page = 1;
    });

    final list = await UserApiService().getUserHistory(pn: _page);
    if (mounted) {
      setState(() {
        if (refresh || _history.isEmpty) {
          _history = list;
        } else {
          _history.addAll(list);
        }
        // 空页视为到底
        _hasMore = list.isNotEmpty;
        _page++;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final list = await UserApiService().getUserHistory(pn: _page);
    if (mounted) {
      setState(() {
        _history.addAll(list);
        _hasMore = list.isNotEmpty;
        _page++;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
      ),
      body: _isLoading
          ? const VideoListSkeleton()
          : _history.isEmpty
              ? const EmptyView(message: '暂无历史记录或未登录', icon: Icons.history_rounded)
              : NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: () => _loadHistory(refresh: true),
                    child: ListView.separated(
                      scrollCacheExtent: ScrollCacheExtent.pixels(500.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      itemCount: _history.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (ctx, _) => Divider(
                        height: 16,
                        thickness: 0.5,
                        color: context.colors.divider,
                      ),
                      itemBuilder: (ctx, idx) {
                        if (idx == _history.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                            ),
                          );
                        }

                        final item = _history[idx];
                        final effectiveProgress = item.progress > 0
                            ? item.progress
                            : HistoryStorageService().getProgress(item.bvid);

                        return RepaintBoundary(
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
                                // Cover
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
                                            url: item.cover,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 360,
                                            memCacheHeight: 225,
                                          ),
                                        if (effectiveProgress > 0)
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
                                                '看到 ${Formatters.formatDuration(effectiveProgress)}',
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
                              // Info
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
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                        color: context.colors.textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      item.ownerName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.colors.textHint,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Formatters.formatTime(item.viewAt),
                                      style: TextStyle(
                                        fontSize: 11,
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
                ),
    );
  }
}
