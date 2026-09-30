import 'dart:async';

import '../../models/video_model.dart';
import '../api/video_api_service.dart';
import '../settings/player_settings_service.dart';

class _TtlEntry<T> {
  final T value;
  final DateTime storedAt = DateTime.now();
  _TtlEntry(this.value);
}

/// 播放信息预取：在看当前视频时，后台预取相关视频 / 下一 P 的详情与播放地址。
///
/// 预取的都是几 KB 的 JSON 接口，不预取媒体字节。用户点开下一个视频时，
/// 详情与播放地址直接命中内存缓存，起播前的大头网络等待被消掉。
/// CDN 播放地址有效期通常数小时，这里用更保守的 10 分钟 TTL。
class VideoPrefetchService {
  VideoPrefetchService._();
  static final VideoPrefetchService instance = VideoPrefetchService._();

  static const Duration _ttl = Duration(minutes: 10);
  static const int _maxEntries = 8;

  final Map<String, _TtlEntry<VideoDetail>> _details = {};
  final Map<String, _TtlEntry<PlayStreamResult>> _streams = {};
  final Map<String, Future<VideoDetail?>> _inFlightDetails = {};
  final Map<String, Future<PlayStreamResult?>> _inFlightStreams = {};

  String _streamKey(String bvid, int cid) => '$bvid:$cid';

  /// 取详情：优先预取缓存，否则走网络（结果同样入缓存供复用）。
  Future<VideoDetail?> getDetail(String bvid) async {
    final cached = _details[bvid];
    if (cached != null && DateTime.now().difference(cached.storedAt) < _ttl) {
      return cached.value;
    }
    _details.remove(bvid);

    final inFlight = _inFlightDetails[bvid];
    if (inFlight != null) return inFlight;

    final future = _fetchDetail(bvid);
    _inFlightDetails[bvid] = future;
    try {
      return await future;
    } finally {
      _inFlightDetails.remove(bvid);
    }
  }

  Future<VideoDetail?> _fetchDetail(String bvid) async {
    try {
      final detail = await VideoApiService().getVideoDetail(bvid);
      if (detail != null) {
        _details[bvid] = _TtlEntry(detail);
        _evict(_details);
      }
      return detail;
    } catch (_) {
      return null;
    }
  }

  /// 取播放流：优先预取缓存，否则按画质策略请求（结果同样入缓存）。
  Future<PlayStreamResult?> getPlayStream(String bvid, int cid) async {
    final key = _streamKey(bvid, cid);
    final cached = _streams[key];
    if (cached != null && DateTime.now().difference(cached.storedAt) < _ttl) {
      return cached.value;
    }
    _streams.remove(key);

    final inFlight = _inFlightStreams[key];
    if (inFlight != null) return inFlight;

    final future = _fetchPlayStream(bvid, cid);
    _inFlightStreams[key] = future;
    try {
      return await future;
    } finally {
      _inFlightStreams.remove(key);
    }
  }

  Future<PlayStreamResult?> _fetchPlayStream(String bvid, int cid) async {
    try {
      final result = await VideoApiService().fetchPlayStream(
        bvid: bvid,
        cid: cid,
        qn: PlayerSettingsService.defaultQuality,
      );
      if (result.ok) {
        _streams[_streamKey(bvid, cid)] = _TtlEntry(result);
        _evict(_streams);
      }
      return result.ok ? result : null;
    } catch (_) {
      return null;
    }
  }

  /// 预取相关视频（详情 + 播放流）。带 cid 的直接请求播放流，
  /// 不带的先取详情。串行低优先级执行，失败静默。
  void prefetchVideos(List<VideoItem> videos, {int limit = 3}) {
    if (videos.isEmpty) return;
    unawaited(() async {
      for (final video in videos.take(limit)) {
        if (video.bvid.isEmpty) continue;
        try {
          if (video.cid > 0) {
            await getPlayStream(video.bvid, video.cid);
            await getDetail(video.bvid);
          } else {
            await getDetail(video.bvid);
          }
        } catch (_) {}
      }
    }());
  }

  void _evict(Map<String, _TtlEntry<dynamic>> map) {
    // Dart Map 保持插入序：淘汰最早写入的条目
    while (map.length > _maxEntries) {
      map.remove(map.keys.first);
    }
  }

  /// 清空（换账号 / 退出登录等场景可调用）。
  void clear() {
    _details.clear();
    _streams.clear();
  }
}
