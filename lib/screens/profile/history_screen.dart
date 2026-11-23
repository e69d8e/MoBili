import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/video_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/user_api_service.dart';
import '../../services/storage/history_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/network_image_view.dart';
import '../../widgets/state_views.dart';
import '../video/video_detail_screen.dart';
import 'login_dialog.dart';

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
      if (refresh || _history.isEmpty) _isLoading = true;
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
        _page = refresh ? 2 : _page + 1;
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

  String _dateBucket(int viewAtSec) {
    if (viewAtSec <= 0) return '更早';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final dt = DateTime.fromMillisecondsSinceEpoch(viewAtSec * 1000);
    if (!dt.isBefore(todayStart)) return '今天';
    if (!dt.isBefore(yesterdayStart)) return '昨天';
    return '更早';
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = context.watch<AuthProvider>().isLogin;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
      ),
      body: ResponsiveMaxConstraint(
        child: _isLoading
            ? const VideoListSkeleton()
            : _history.isEmpty
            ? EmptyView(
                message: isLogin ? '暂无历史记录' : '登录后可同步云端观看历史',
                icon: Icons.history_rounded,
                retryText: isLogin ? '刷新重试' : '立即登录',
                onRetry: isLogin
                    ? () => _loadHistory(refresh: true)
                    : () => showDialog(
                        context: context,
                        builder: (_) => const LoginDialog(),
                      ).then((_) => _loadHistory(refresh: true)),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (scrollInfo.metrics.maxScrollExtent > 0 &&
                      scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 200) {
                    _loadMore();
                  }
                  return false;
                },
                child: RefreshIndicator(
                  color: primaryColor,
                  onRefresh: () => _loadHistory(refresh: true),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    scrollCacheExtent: ScrollCacheExtent.pixels(500.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          ),
                        );
                      }

                      final item = _history[idx];
                      final bucket = _dateBucket(item.viewAt);
                      final prevBucket =
                          idx > 0 ? _dateBucket(_history[idx - 1].viewAt) : '';
                      final showHeader = idx == 0 || bucket != prevBucket;

                      final isFinished = item.progress == -1;
                      final effectiveProgress = item.progress > 0
                          ? item.progress
                          : HistoryStorageService().getProgress(item.bvid);
                      final ratio = item.duration > 0
                          ? (isFinished
                                ? 1.0
                                : (effectiveProgress / item.duration)
                                      .clamp(0.0, 1.0))
                          : 0.0;
                      final heroTag = 'hist_${item.bvid}_$idx';
                      final initialVideo = VideoItem(
                        aid: item.aid,
                        bvid: item.bvid,
                        cid: item.cid,
                        title: item.title,
                        pic: item.cover,
                        desc: '',
                        duration: item.duration,
                        pubdate: 0,
                        ctime: 0,
                        owner: Owner(
                          mid: item.ownerMid,
                          name: item.ownerName,
                          face: '',
                        ),
                        stat: Stat(),
                      );

                      final row = InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => VideoDetailScreen(
                                bvid: item.bvid,
                                initialVideo: initialVideo,
                                heroTag: heroTag,
                                initialPosition:
                                    (!isFinished && effectiveProgress > 0)
                                    ? Duration(seconds: effectiveProgress)
                                    : null,
                              ),
                            ),
                          );
                        },
                        borderRadius: AppRadius.card,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cover
                            SizedBox(
                              width: 124,
                              child: AspectRatio(
                                aspectRatio: 16 / 10,
                                child: Hero(
                                  tag: heroTag,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        NetworkImageView(
                                          url: item.cover,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 480,
                                          memCacheHeight: 300,
                                        ),
                                        if (isFinished || effectiveProgress > 0)
                                          Positioned(
                                            bottom: ratio > 0 ? 6 : 4,
                                            right: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.72,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isFinished
                                                    ? '已看完'
                                                    : '看到 ${Formatters.formatDuration(effectiveProgress)}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (ratio > 0)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: LinearProgressIndicator(
                                              value: ratio,
                                              minHeight: 3,
                                              backgroundColor: Colors.black
                                                  .withValues(alpha: 0.35),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    primaryColor,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
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
                      );

                      if (!showHeader) {
                        return RepaintBoundary(child: row);
                      }

                      return RepaintBoundary(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                bucket,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textSub,
                                ),
                              ),
                            ),
                            row,
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
