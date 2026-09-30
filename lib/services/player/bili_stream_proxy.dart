import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/bili_http_client.dart';

/// 判定向后 seek 的阈值：新出流位置低于水位超过该值时重置预取锚点。
const int _kSeekBackResetThreshold = 8 * 1024 * 1024;

/// 缓存块大小。取流与落盘都按块对齐：回拖最坏多取一块（≤2MiB）。
const int _kStreamBlockSize = 2 * 1024 * 1024;

/// Lightweight local streaming proxy to serve Bilibili DASH and MP4 streams
/// with standard video/mp4 and audio/mp4 MIME types, proper Referer/User-Agent/Cookie headers,
/// and Range request support. Resolves B站 CDN 403 Forbidden and player unsupported format errors.
///
/// 在纯转发之上实现了「边播边缓存」：
/// - 播放过的字节按 [_kStreamBlockSize] 块落盘，LRU 总量上限（默认 512MB）；
/// - 回拖 / 重播 / 切画质回到旧位置时直接命中磁盘块，不再回源；
/// - 缓存键由调用方提供稳定 key（bvid+cid+轨+画质），CDN 签名地址每次变化不影响命中。
class BiliStreamProxy {
  static final BiliStreamProxy _instance = BiliStreamProxy._internal();
  factory BiliStreamProxy() => _instance;
  BiliStreamProxy._internal();

  HttpServer? _server;
  int _port = 0;

  /// token -> 远程 URL，或 `local:<绝对路径>`（本地文件映射）
  final Map<String, String> _urlMap = {};
  HttpClient? _httpClient;

  static const String _localPrefix = 'local:';

  /// 磁盘缓存总量上限（LRU 淘汰）。
  static const int _defaultMaxCacheBytes = 512 * 1024 * 1024;
  int _maxCacheBytes = _defaultMaxCacheBytes;

  /// 预测预取：是否在出流间隙主动回源，把播放位置前方填到预取深度。
  ///
  /// 渐进式下载 + 预测预取：播放器自身的缓冲窗口有限（通常几十秒），
  /// 缓冲满后播放器停止拉流，网络空闲；预取在此时继续向前取流落盘，
  /// 网络波动 / CDN 限速时由磁盘缓存顶上，播放不中断。
  static bool prefetchEnabled = true;

  /// 预取深度：保持缓存的「播放位置前方」字节数。
  /// 16MiB ≈ 1080P（2-4Mbps）下 40-60 秒，音频轨约 15 分钟。
  static const int _prefetchAheadBytes = 16 * 1024 * 1024;

  /// 单次预取批量（块对齐），摊薄每次回源的建连开销。
  static const int _prefetchBatchBytes = 4 * _kStreamBlockSize;

  Directory? _cacheDir;
  bool _cacheDirChecked = false;
  String? _debugCacheDir;

  /// 以缓存哈希（token 去掉前缀）为键的条目索引。
  final Map<String, _StreamCacheEntry> _cacheEntries = {};
  int _totalCacheBytes = 0;
  Timer? _metaFlushTimer;

  HttpClient get _client {
    return _httpClient ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 30)
      ..autoUncompress = false;
  }

  bool get isRunning => _server != null;

  /// 仅供测试注入缓存目录；同时清空内存中的缓存索引。
  void debugSetCacheDirectory(String path) {
    _debugCacheDir = path;
    _cacheDir = null;
    _cacheDirChecked = false;
    _resetCacheIndex();
  }

  /// 仅供测试调整缓存总量上限。
  void debugSetMaxCacheBytes(int bytes) {
    _maxCacheBytes = bytes <= 0 ? _defaultMaxCacheBytes : bytes;
  }

  /// 仅供测试：等待挂起的块写入落盘并刷新元数据。
  Future<void> debugFlushPendingWrites() async {
    // awaitWrites 期间可能触发 LRU 淘汰修改索引，需遍历副本
    for (final entry in _cacheEntries.values.toList()) {
      await entry.awaitWrites();
      entry.flushMetaIfNeeded();
    }
  }

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.idleTimeout = null;
      _port = _server!.port;
      _server!.listen(
        _handleRequest,
        onError: (e) {
          debugPrint('BiliStreamProxy server error: $e');
        },
      );
    } catch (e) {
      debugPrint('BiliStreamProxy failed to bind: $e');
    }
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final token = path.replaceFirst('/', '').replaceAll('.mp4', '');
    final targetUrl = _urlMap[token];
    if (targetUrl == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final method = request.method;
    if (method != 'GET' && method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    if (targetUrl.startsWith(_localPrefix)) {
      await _serveLocalFile(
        request,
        targetUrl.substring(_localPrefix.length),
        token.startsWith('locala_'),
      );
      return;
    }

    try {
      if (method == 'HEAD') {
        await _forwardHead(request, targetUrl, token.startsWith('audio_'));
        return;
      }

      // 缓存目录拿不到（测试环境 / Web）时 _entryFor 返回 null → 纯转发
      // 缓存目录拿不到（测试环境 / Web）时 _entryFor 返回 null → 纯转发
      final entry = await _entryFor(token);
      if (entry == null) {
        await _passthrough(request, targetUrl, null);
        return;
      }
      entry.touch();
      entry.activeRequests++;
      try {
        await _serveWithCache(request, entry, targetUrl);
      } finally {
        entry.activeRequests = math.max(0, entry.activeRequests - 1);
      }
      // 渐进式预取：出流结束后把缓存向前补到预测深度（网络波动时顶上）
      if (prefetchEnabled) {
        unawaited(_runPrefetchLoop(entry, targetUrl));
      }
    } catch (e) {
      debugPrint('BiliStreamProxy _handleRequest error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _forwardHead(
    HttpRequest request,
    String targetUrl,
    bool isAudio,
  ) async {
    final clientReq = await _client.openUrl('HEAD', Uri.parse(targetUrl));
    _setUpstreamHeaders(clientReq, rangeHeader: null);
    final clientRes = await clientReq.close();
    request.response.statusCode = clientRes.statusCode;
    _setResponseHeaders(request, isAudio: isAudio);
    final contentLength = clientRes.headers.value(HttpHeaders.contentLengthHeader);
    if (contentLength != null) {
      request.response.headers.set(HttpHeaders.contentLengthHeader, contentLength);
    }
    await clientRes.drain<void>();
    await request.response.close();
  }

  void _setUpstreamHeaders(HttpClientRequest clientReq, {String? rangeHeader}) {
    clientReq.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );
    clientReq.headers.set(HttpHeaders.refererHeader, 'https://www.bilibili.com');

    final cookie = BiliHttpClient().cookieHeader;
    if (cookie.isNotEmpty) {
      clientReq.headers.set(HttpHeaders.cookieHeader, cookie);
    }
    if (rangeHeader != null) {
      clientReq.headers.set(HttpHeaders.rangeHeader, rangeHeader);
    }
  }

  void _setResponseHeaders(HttpRequest request, {required bool isAudio}) {
    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      isAudio ? 'audio/mp4' : 'video/mp4',
    );
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Headers', '*');
  }

  // ==================== 纯转发路径（顺带喂缓存） ====================

  /// 纯转发（缓存不可用 / 区间无法对齐时回退）。
  /// 上游流可对齐时（206，或 200 且从头取）把字节同步喂给磁盘缓存。
  Future<void> _passthrough(
    HttpRequest request,
    String targetUrl,
    _StreamCacheEntry? entry,
  ) async {
    final clientReq = await _client.openUrl(request.method, Uri.parse(targetUrl));
    _setUpstreamHeaders(
      clientReq,
      rangeHeader: request.headers.value(HttpHeaders.rangeHeader),
    );
    final clientRes = await clientReq.close();
    request.response.statusCode = clientRes.statusCode;

    final token = request.uri.path.replaceFirst('/', '').replaceAll('.mp4', '');
    _setResponseHeaders(request, isAudio: token.startsWith('audio_'));

    final contentLength = clientRes.headers.value(HttpHeaders.contentLengthHeader);
    if (contentLength != null) {
      request.response.headers.set(HttpHeaders.contentLengthHeader, contentLength);
    }
    final contentRange = clientRes.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      request.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
    }

    final e = entry;
    final alignStart = e == null
        ? null
        : _upstreamAlignedStart(
            clientRes.statusCode,
            contentRange,
            requestedStart: _requestedRangeStart(request),
          );
    if (e == null || alignStart == null) {
      try {
        await clientRes.pipe(request.response);
      } catch (_) {
        // Player closed connection early (e.g. seek/buffer fulfilled)
      }
      return;
    }

    // 可对齐：登记总长并边转发边喂缓存
    if (e.total == null && contentRange != null) {
      final m = RegExp(r'/(\d+)$').firstMatch(contentRange.trim());
      final t = m != null ? int.tryParse(m.group(1)!) : null;
      if (t != null && t > 0) {
        e.total = t;
        e.markDirty();
      }
    }
    e.activeRequests++;
    var served = alignStart;
    try {
      var offset = alignStart;
      await for (final chunk in clientRes) {
        _feedCache(e, offset, chunk);
        offset += chunk.length;
        request.response.add(chunk);
        // 逐块 flush：播放器断开（缓冲已满 / seek）能在下一个分块内感知，
        // 已送出的字节数即为预取水位
        await request.response.flush();
        served = offset;
      }
      e.noteServed(served);
    } catch (_) {
      // 播放器提前断开（seek / 缓冲已满足）：
      // await for 的取消会把上游连接一并销毁，无需（也不能）继续读流
      e.noteServed(served);
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
      e.activeRequests = math.max(0, e.activeRequests - 1);
    }
  }

  /// 上游响应字节流的实际起始偏移；无法对齐时返回 null。
  int? _upstreamAlignedStart(
    int statusCode,
    String? contentRange, {
    required int? requestedStart,
  }) {
    if (statusCode == HttpStatus.partialContent && contentRange != null) {
      final m = RegExp(r'^bytes (\d+)-').firstMatch(contentRange.trim());
      if (m != null) return int.tryParse(m.group(1)!);
      return null;
    }
    if (statusCode == HttpStatus.ok) {
      // 上游忽略 Range 返回整段：只有从头取才对齐
      if ((requestedStart ?? 0) == 0) return 0;
      return null;
    }
    return null;
  }

  int? _requestedRangeStart(HttpRequest request) {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range == null || !range.startsWith('bytes=')) return null;
    final spec = range.substring(6).split(',').first.trim();
    final start = spec.split('-').first.trim();
    if (start.isEmpty) return 0;
    return int.tryParse(start);
  }

  // ==================== 磁盘缓存索引 ====================

  Future<Directory?> _ensureCacheDir() async {
    if (_cacheDirChecked) return _cacheDir;
    _cacheDirChecked = true;
    try {
      if (kIsWeb) return null;
      final Directory base;
      if (_debugCacheDir != null) {
        base = Directory(_debugCacheDir!);
      } else {
        base =
            Directory('${(await getTemporaryDirectory()).path}/bili_stream_cache');
      }
      if (!base.existsSync()) {
        base.createSync(recursive: true);
      }
      _cacheDir = base;
      _loadEntries(base);
      _startMetaFlushTimer();
      _maybeEvict();
    } catch (_) {
      _cacheDir = null;
    }
    return _cacheDir;
  }

  void _loadEntries(Directory base) {
    _totalCacheBytes = 0;
    _cacheEntries.clear();
    try {
      for (final entity in base.listSync()) {
        if (entity is! Directory) continue;
        final metaFile = File('${entity.path}/meta.json');
        if (!metaFile.existsSync()) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
          continue;
        }
        try {
          final raw = jsonDecode(metaFile.readAsStringSync());
          if (raw is! Map) continue;
          final hash = entity.path.split('/').last;
          final entry = _StreamCacheEntry(
            hash: hash,
            isAudio: raw['audio'] == true,
            total: (raw['total'] as num?)?.toInt(),
            lastAccess: DateTime.fromMillisecondsSinceEpoch(
              (raw['la'] as num?)?.toInt() ?? 0,
            ),
          );
          final blocks = raw['blocks'];
          if (blocks is Map) {
            blocks.forEach((k, v) {
              final idx = int.tryParse(k.toString());
              final len = (v is num) ? v.toInt() : null;
              if (idx != null && len != null && len > 0) {
                entry.blocks[idx] = len;
              }
            });
          }
          // 剔除元数据之外的孤儿块文件（中断写入残留），避免读到未登记数据
          for (final f in entity.listSync()) {
            if (f is! File) continue;
            final name = f.path.split('/').last;
            if (name == 'meta.json') continue;
            final idx = _blockIndexFromFile(name);
            if (idx == null || !entry.blocks.containsKey(idx)) {
              try {
                f.deleteSync();
              } catch (_) {}
            }
          }
          // 反向校验：meta 登记的块文件必须存在（iOS 会随时清空 tmp 目录），
          // 缺失的块从索引剔除，避免「计划命中 → 读文件失败」反复中止出流
          entry.blocks.removeWhere(
            (idx, _) => !File('${entity.path}/b$idx.blk').existsSync(),
          );
          if (entry.blocks.isEmpty) {
            try {
              entity.deleteSync(recursive: true);
            } catch (_) {}
            continue;
          }
          _cacheEntries[hash] = entry;
          _totalCacheBytes += entry.cachedBytes;
        } catch (_) {}
      }
    } catch (_) {}
  }

  int? _blockIndexFromFile(String name) {
    if (!name.startsWith('b') || !name.endsWith('.blk')) return null;
    return int.tryParse(name.substring(1, name.length - 4));
  }

  Future<_StreamCacheEntry?> _entryFor(String token) async {
    await _ensureCacheDir();
    if (_cacheDir == null) return null;
    final prefixEnd = token.indexOf('_');
    final hash = prefixEnd >= 0 ? token.substring(prefixEnd + 1) : token;
    final existing = _cacheEntries[hash];
    if (existing != null) return existing;

    final entry = _StreamCacheEntry(
      hash: hash,
      isAudio: token.startsWith('audio_'),
    );
    _cacheEntries[hash] = entry;
    _maybeEvict();
    return entry;
  }

  void _onBlockWritten(int addedBytes) {
    _totalCacheBytes += addedBytes;
  }

  void _startMetaFlushTimer() {
    _metaFlushTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      _flushDirtyMeta();
    });
  }

  void _flushDirtyMeta() {
    for (final entry in _cacheEntries.values.toList()) {
      entry.flushMetaIfNeeded();
    }
  }

  void _maybeEvict() {
    if (_totalCacheBytes <= _maxCacheBytes) return;
    final candidates =
        _cacheEntries.values.where((e) => e.activeRequests == 0).toList()
          ..sort((a, b) => a.lastAccess.compareTo(b.lastAccess));
    for (final entry in candidates) {
      if (_totalCacheBytes <= _maxCacheBytes) break;
      _totalCacheBytes -= entry.cachedBytes;
      _cacheEntries.remove(entry.hash);
      entry.deleteFromDisk();
    }
  }

  /// 用户清缓存（临时目录被整体删除）后同步内存索引。
  void invalidateAll() {
    _resetCacheIndex();
  }

  void _resetCacheIndex() {
    for (final entry in _cacheEntries.values) {
      entry.disposeData();
    }
    _cacheEntries.clear();
    _totalCacheBytes = 0;
  }

  // ==================== 缓存出流 ====================

  ({int start, int? endInclusive, bool hasRange})? _parseRange(
    HttpRequest request,
    int? total,
  ) {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range == null || !range.startsWith('bytes=')) {
      return (
        start: 0,
        endInclusive: total == null ? null : total - 1,
        hasRange: false,
      );
    }
    final spec = range.substring(6).split(',').first.trim();
    final parts = spec.split('-');
    final rawStart = parts.isNotEmpty ? parts[0].trim() : '';
    final rawEnd = parts.length > 1 ? parts[1].trim() : '';

    if (rawStart.isEmpty) {
      // bytes=-N 后缀区间：必须知道总长
      if (total == null) return null;
      final suffix = int.tryParse(rawEnd) ?? 0;
      if (suffix <= 0 || total <= 0) return null;
      final start = suffix >= total ? 0 : total - suffix;
      return (start: start, endInclusive: total - 1, hasRange: true);
    }

    final start = int.tryParse(rawStart);
    if (start == null || start < 0) return null;
    if (total != null && start >= total) return null;

    int? end;
    if (rawEnd.isNotEmpty) {
      end = int.tryParse(rawEnd);
      if (end == null) return null;
      if (total != null && end > total - 1) end = total - 1;
    } else if (total != null) {
      end = total - 1;
    }
    return (start: start, endInclusive: end, hasRange: true);
  }

  Future<void> _serveWithCache(
    HttpRequest request,
    _StreamCacheEntry entry,
    String targetUrl,
  ) async {
    final total = entry.total;
    final range = _parseRange(request, total);
    // 后缀区间缺总长、总长未知的开放区间等 → 透传（顺带喂缓存）
    if (range == null || range.endInclusive == null) {
      await _passthrough(request, targetUrl, entry);
      return;
    }

    final start = range.start;
    final endInclusive = range.endInclusive!;
    if (total != null && start >= total) {
      _setResponseHeaders(request, isAudio: entry.isAudio);
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes */$total');
      await request.response.close();
      return;
    }

    final plan =
        _planServe(entry, start: start, endExclusive: endInclusive + 1);
    // 出流水位 = 播放器最近一次请求覆盖到的位置（预取锚点）
    entry.noteServed(plan.endExclusive);

    final response = request.response;
    _setResponseHeaders(request, isAudio: entry.isAudio);
    response.statusCode =
        range.hasRange ? HttpStatus.partialContent : HttpStatus.ok;
    response.headers.set(
      HttpHeaders.contentLengthHeader,
      '${plan.endExclusive - plan.start}',
    );
    if (range.hasRange) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${plan.start}-${plan.endExclusive - 1}/${total ?? '*'}',
      );
    }

    try {
      for (final seg in plan.segments) {
        if (seg.cached) {
          await _readCachedTo(response, entry, seg.start, seg.endExclusive);
        } else {
          await _fetchFillTo(
            response,
            entry,
            targetUrl,
            fetchStart: seg.fetchStart,
            fetchEndExclusive: seg.fetchEndExclusive,
            playerStart: seg.start,
            playerEndExclusive: seg.endExclusive,
          );
        }
      }
      await response.flush();
    } catch (_) {
      // 播放器断开或上游失败：中断出流，播放器会按 Range 重试
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// 把 [start, endExclusive) 切成「磁盘命中」与「需回源」段；
  /// 回源段向两侧扩展到块边界，多取的字节顺带进缓存。
  _ServePlan _planServe(
    _StreamCacheEntry entry, {
    required int start,
    required int endExclusive,
  }) {
    final segments = <_ServeSegment>[];
    var pos = start;
    while (pos < endExclusive) {
      // cachedUpTo 返回从 pos 起连续命中的「长度」
      final hitLength = entry.cachedUpTo(pos);
      if (hitLength > 0) {
        final hitEnd = math.min(pos + hitLength, endExclusive);
        segments.add(_ServeSegment(
          cached: true,
          start: pos,
          endExclusive: hitEnd,
        ));
        pos = hitEnd;
        continue;
      }
      // 未命中：扩到连续未命中块的边界
      var holeEnd = pos;
      while (holeEnd < endExclusive && !entry.hasBlock(holeEnd ~/ _kStreamBlockSize)) {
        holeEnd = ((holeEnd ~/ _kStreamBlockSize) + 1) * _kStreamBlockSize;
      }
      holeEnd = math.min(holeEnd, endExclusive);
      if (holeEnd <= pos) {
        // 防御：异常缓存状态下保证前进
        holeEnd = math.min(endExclusive, pos + _kStreamBlockSize);
      }
      final fetchStart = (pos ~/ _kStreamBlockSize) * _kStreamBlockSize;
      var fetchEnd =
          ((holeEnd - 1) ~/ _kStreamBlockSize + 1) * _kStreamBlockSize;
      if (entry.total != null) {
        fetchEnd = math.min(fetchEnd, entry.total!);
      } else {
        fetchEnd = math.min(fetchEnd, endExclusive);
      }
      segments.add(_ServeSegment(
        cached: false,
        start: pos,
        endExclusive: holeEnd,
        fetchStart: fetchStart,
        fetchEndExclusive: math.max(fetchEnd, holeEnd),
      ));
      pos = holeEnd;
    }
    return _ServePlan(
      start: start,
      endExclusive: endExclusive,
      segments: segments,
    );
  }

  Future<void> _readCachedTo(
    HttpResponse response,
    _StreamCacheEntry entry,
    int start,
    int endExclusive,
  ) async {
    var pos = start;
    while (pos < endExclusive) {
      final blockIndex = pos ~/ _kStreamBlockSize;
      final len = entry.blocks[blockIndex];
      if (len == null) {
        throw StateError('cache block $blockIndex missing during serve');
      }
      final blockEnd = blockIndex * _kStreamBlockSize + len;
      final sliceEnd = math.min(endExclusive, blockEnd);
      if (sliceEnd <= pos) {
        throw StateError('cache block $blockIndex shorter than expected');
      }
      final file = entry.blockFile(blockIndex);
      if (!file.existsSync()) {
        // 已登记但尚未落盘：等写入队列完成后重试一次
        await entry.awaitWrites();
        if (!file.existsSync()) {
          entry.dropBlock(blockIndex);
          entry.flushMetaIfNeeded();
          throw StateError('cache block file vanished: $blockIndex');
        }
      }
      final bytes = await file.readAsBytes();
      final from = pos - blockIndex * _kStreamBlockSize;
      response.add(bytes.sublist(from, from + (sliceEnd - pos)));
      pos = sliceEnd;
    }
  }

  /// 回源一段并顺带写缓存：播放器要的字节同步出流，
  /// 块对齐多取的字节只进缓存（填充到块边界 / 已知总长为止）。
  ///
  /// [response] 为 null 时是纯缓存填充（预测预取），不向播放器出流。
  Future<void> _fetchFillTo(
    HttpResponse? response,
    _StreamCacheEntry entry,
    String targetUrl, {
    required int fetchStart,
    required int fetchEndExclusive,
    required int playerStart,
    required int playerEndExclusive,
  }) async {
    final clientReq = await _client.openUrl('GET', Uri.parse(targetUrl));
    _setUpstreamHeaders(
      clientReq,
      rangeHeader: 'bytes=$fetchStart-${fetchEndExclusive - 1}',
    );
    final clientRes = await clientReq.close();

    final aligned = clientRes.statusCode == HttpStatus.partialContent ||
        (clientRes.statusCode == HttpStatus.ok && fetchStart == 0);
    if (!aligned) {
      // 不再读取响应体：取消订阅即销毁上游连接，避免为坏响应拉完整段视频
      throw StateError('upstream range fetch failed: ${clientRes.statusCode}');
    }

    // 首个回源响应顺带登记总长（影响后续块完整性判断）
    final contentRange = clientRes.headers.value(HttpHeaders.contentRangeHeader);
    if (entry.total == null && contentRange != null) {
      final m = RegExp(r'/(\d+)$').firstMatch(contentRange.trim());
      final t = m != null ? int.tryParse(m.group(1)!) : null;
      if (t != null && t > 0) {
        entry.total = t;
        entry.markDirty();
      }
    }

    var offset = fetchStart;
    await for (final chunk in clientRes) {
      final chunkStart = offset;
      _feedCache(entry, offset, chunk);
      offset += chunk.length;

      if (response != null) {
        final from = math.max(0, playerStart - chunkStart);
        final to = math.min(chunk.length, playerEndExclusive - chunkStart);
        if (to > from) {
          response.add(chunk.sublist(from, to));
          await response.flush();
        }
      }
      if (offset >= fetchEndExclusive) {
        // 缓存要填的完成了（fetch 段是播放器段的超集）；提前退出会取消
        // 订阅并销毁上游连接
        break;
      }
    }
  }

  // ==================== 预测预取 ====================

  /// 预测预取循环：在出流间隙把缓存从「播放位置」向前补到 [_prefetchAheadBytes]。
  ///
  /// 播放器缓冲满后会停止拉流，网络随之空闲；此时由预取继续向前取流落盘，
  /// 网络波动 / CDN 限速时播放器请求直接命中磁盘缓存，播放不中断。
  /// 每次出流结束后触发一次；预取深度已达标则立即返回。
  Future<void> _runPrefetchLoop(
    _StreamCacheEntry entry,
    String targetUrl,
  ) async {
    if (entry.prefetchActive) return;
    entry.prefetchActive = true;
    entry.activeRequests++; // 预取期间不参与 LRU 淘汰
    try {
      while (true) {
        final total = entry.total;
        if (total == null) return; // 总长未知（首个请求尚未对齐），无从规划
        final depthEnd = math.min(
          entry.servedWatermark + _prefetchAheadBytes,
          total,
        );
        final from = math.max(
          entry.prefetchCursor,
          _firstMissingBlockAtOrAfter(entry, entry.servedWatermark),
        );
        if (from >= depthEnd) return; // 预取深度已达标 / 已到 EOF
        final batchEnd = math.min(from + _prefetchBatchBytes, depthEnd);
        try {
          await _fetchFillTo(
            null,
            entry,
            targetUrl,
            fetchStart: from,
            fetchEndExclusive: batchEnd,
            playerStart: from,
            playerEndExclusive: from,
          );
        } catch (_) {
          return; // 回源失败：等下一次出流触发再试，避免死循环
        }
        entry.prefetchCursor = batchEnd;
      }
    } finally {
      entry.prefetchActive = false;
      entry.activeRequests = math.max(0, entry.activeRequests - 1);
    }
  }

  /// [bytePos] 所在块起，第一个未缓存块的字节偏移（块对齐）。
  int _firstMissingBlockAtOrAfter(_StreamCacheEntry entry, int bytePos) {
    var index = bytePos ~/ _kStreamBlockSize;
    while (entry.hasBlock(index)) {
      index++;
    }
    return index * _kStreamBlockSize;
  }

  /// 把一段字节流喂进块缓冲；从块头连续凑满整块（或到达已知总长）才落盘。
  void _feedCache(_StreamCacheEntry entry, int offset, List<int> bytes) {
    if (bytes.isEmpty) return;
    var off = offset;
    var i = 0;
    while (i < bytes.length) {
      final blockIndex = off ~/ _kStreamBlockSize;
      final posInBlock = off % _kStreamBlockSize;
      final buf = entry.bufferFor(blockIndex);
      final expected = buf.nextExpectedPosInBlock;
      if (expected >= 0 && posInBlock != expected) {
        // 与已有缓冲不连续（空洞或重叠）：该块放弃缓存，跳到下一块边界
        entry.dropBuffer(blockIndex);
        final skip = math.min(
          _kStreamBlockSize - posInBlock,
          bytes.length - i,
        );
        i += skip;
        off += skip;
        continue;
      }
      final take = math.min(
        math.min(bytes.length - i, _kStreamBlockSize - posInBlock),
        _kStreamBlockSize - buf.filled,
      );
      buf.append(bytes, i, take, posInBlock);
      i += take;
      off += take;

      final complete = buf.startInBlock == 0 &&
          (buf.filled >= _kStreamBlockSize ||
              (entry.total != null &&
                  blockIndex * _kStreamBlockSize + buf.filled >= entry.total!));
      if (complete) {
        final data = buf.takeBytes();
        final added = entry.blocks.containsKey(blockIndex) ? 0 : data.length;
        entry.enqueueBlockWrite(
          blockIndex,
          data,
          onWritten: () {
            _onBlockWritten(added);
            _maybeEvict();
          },
        );
        entry.dropBuffer(blockIndex);
      }
    }
  }

  // ==================== 注册与本地文件服务 ====================

  /// Registers an upstream remote URL and returns a local proxy URL ending with .mp4
  ///
  /// [cacheKey] 提供稳定的缓存键（如 `BV1xx_cid|v80`）：CDN 签名地址每次请求都会
  /// 变化，用稳定键才能在重进页面 / 回拖 / 切画质回退时命中已缓存的块。
  /// 缺省退化为 URL 本身（仅会话内有效）。
  Future<String> getProxyUrl(
    String remoteUrl, {
    bool isAudio = false,
    String? cacheKey,
  }) async {
    if (kIsWeb || remoteUrl.isEmpty) return remoteUrl;
    if (remoteUrl.startsWith('file://') ||
        (_port > 0 && remoteUrl.startsWith('http://127.0.0.1:$_port/')) ||
        (!kIsWeb && File(remoteUrl).existsSync())) {
      return remoteUrl;
    }

    if (_server == null) {
      await start();
    }
    if (_server == null) {
      return remoteUrl; // fallback if bind failed
    }

    final prefix = isAudio ? 'audio' : 'video';
    final hash = md5.convert(utf8.encode(cacheKey ?? remoteUrl)).toString();
    final key = '${prefix}_$hash';

    if (_urlMap.length > 200) {
      _urlMap.remove(_urlMap.keys.first);
    }
    _urlMap[key] = remoteUrl;
    return 'http://127.0.0.1:$_port/$key.mp4';
  }

  /// 把本地文件映射为本地 HTTP 播放地址（`.mp4` 扩展名 + 正确 MIME + Range 支持）。
  ///
  /// 缓存下来的 DASH 轨道是 `.m4s` 文件，iOS AVPlayer 会因未知扩展名拒绝加载，
  /// 且纯音频轨需要 `audio/mp4` 声明，因此本地音轨也统一走本地服务。
  Future<String> getLocalFileProxyUrl(String filePath, {bool isAudio = false}) async {
    if (kIsWeb || filePath.isEmpty) return filePath;
    final cleanPath = filePath.startsWith('file://')
        ? (Uri.tryParse(filePath)?.toFilePath() ?? filePath)
        : filePath;

    if (_server == null) {
      await start();
    }
    if (_server == null) {
      return Uri.file(cleanPath).toString(); // fallback if bind failed
    }

    final prefix = isAudio ? 'locala' : 'localv';
    final hash = md5.convert(utf8.encode(cleanPath)).toString();
    final key = '${prefix}_$hash';

    if (_urlMap.length > 200) {
      _urlMap.remove(_urlMap.keys.first);
    }
    _urlMap[key] = '$_localPrefix$cleanPath';
    return 'http://127.0.0.1:$_port/$key.mp4';
  }

  /// 服务本地文件，支持单区间 Range 请求（播放器 seek 依赖）。
  Future<void> _serveLocalFile(
    HttpRequest request,
    String filePath,
    bool isAudio,
  ) async {
    final response = request.response;
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }

      final length = await file.length();
      response.headers.set(
        HttpHeaders.contentTypeHeader,
        isAudio ? 'audio/mp4' : 'video/mp4',
      );
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set('Access-Control-Allow-Origin', '*');

      int start = 0;
      int end = length - 1;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final hasRange = rangeHeader != null && rangeHeader.startsWith('bytes=');

      if (hasRange && length > 0) {
        final spec = rangeHeader.substring('bytes='.length).split(',').first.trim();
        final parts = spec.split('-');
        final rawStart = parts.isNotEmpty ? parts[0].trim() : '';
        final rawEnd = parts.length > 1 ? parts[1].trim() : '';
        if (rawStart.isEmpty && rawEnd.isNotEmpty) {
          // 后缀区间：bytes=-N（取末尾 N 字节）
          final suffix = int.tryParse(rawEnd) ?? 0;
          start = suffix >= length ? 0 : length - suffix;
          end = length - 1;
        } else {
          start = int.tryParse(rawStart) ?? 0;
          end = rawEnd.isEmpty ? length - 1 : (int.tryParse(rawEnd) ?? length - 1);
          if (end > length - 1) end = length - 1;
        }
      }

      if (length == 0 || start > end || start >= length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        await response.close();
        return;
      }

      final count = end - start + 1;
      response.statusCode = hasRange ? HttpStatus.partialContent : HttpStatus.ok;
      if (hasRange) {
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$length',
        );
      }
      response.headers.set(HttpHeaders.contentLengthHeader, '$count');

      if (request.method == 'HEAD') {
        await response.close();
        return;
      }

      try {
        await response.addStream(file.openRead(start, end + 1));
      } catch (_) {
        // 播放器提前断开（seek/缓冲已满足）
      }
      await response.close();
    } catch (e) {
      debugPrint('BiliStreamProxy _serveLocalFile error: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    }
  }

  void dispose() {
    _server?.close(force: true);
    _server = null;
    _urlMap.clear();
    _metaFlushTimer?.cancel();
    _metaFlushTimer = null;
    _flushDirtyMeta();
    _resetCacheIndex();
    _cacheDir = null;
    _cacheDirChecked = false;
    _maxCacheBytes = _defaultMaxCacheBytes;
    _debugCacheDir = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }
}

/// 单条播放流的磁盘缓存状态：以块为单位记录已缓存字节区间。
class _StreamCacheEntry {
  _StreamCacheEntry({
    required this.hash,
    required this.isAudio,
    this.total,
    DateTime? lastAccess,
  }) : lastAccess = lastAccess ?? DateTime.now();

  final String hash;
  final bool isAudio;

  /// 上游总字节数；未知为 null（首个回源响应的 Content-Range 会补上）。
  int? total;

  /// 已缓存块：块号 -> 块实际字节数（普通块 = 块大小，流的最后一块可以更小）。
  final Map<int, int> blocks = {};

  final Map<int, _BlockBuffer> _buffers = {};
  Future<void> _writeQueue = Future.value();
  bool _dirty = false;
  bool _disposed = false;
  int activeRequests = 0;
  DateTime lastAccess;

  /// 出流水位：播放器最近一次请求覆盖到的字节位置（预取锚点）。
  int servedWatermark = 0;

  /// 预取已填充到的前沿位置（避免重复扫描 / 半块反复重取）。
  int prefetchCursor = 0;

  /// 预取循环是否在执行（防重入）。
  bool prefetchActive = false;

  /// 记录一次出流覆盖到的位置。向前推进时直接采用；
  /// 向后回退超过阈值视为 seek，重置预取游标从新位置重新规划。
  void noteServed(int endExclusive) {
    if (endExclusive > servedWatermark ||
        endExclusive < servedWatermark - _kSeekBackResetThreshold) {
      servedWatermark = endExclusive;
      prefetchCursor = 0;
    }
  }

  int get cachedBytes {
    var n = 0;
    for (final len in blocks.values) {
      n += len;
    }
    return n;
  }

  Directory get dir => Directory(
      '${(BiliStreamProxy()._cacheDir ?? Directory.systemTemp).path}/$hash');
  File get metaFile => File('${dir.path}/meta.json');
  File blockFile(int index) => File('${dir.path}/b$index.blk');

  void touch() {
    lastAccess = DateTime.now();
    _dirty = true;
  }

  void markDirty() {
    _dirty = true;
  }

  bool hasBlock(int index) => blocks.containsKey(index);

  /// [pos] 起连续命中的字节数（未命中返回 0）。
  int cachedUpTo(int pos) {
    final index = pos ~/ _kStreamBlockSize;
    final len = blocks[index];
    if (len == null) return 0;
    final end = index * _kStreamBlockSize + len;
    return end > pos ? end - pos : 0;
  }

  _BlockBuffer bufferFor(int index) {
    return _buffers.putIfAbsent(index, () => _BlockBuffer());
  }

  void dropBuffer(int index) {
    _buffers.remove(index);
  }

  void dropBlock(int index) {
    if (blocks.remove(index) != null) {
      _dirty = true;
    }
    _buffers.remove(index);
  }

  void enqueueBlockWrite(int index, Uint8List data, {void Function()? onWritten}) {
    // 入队即登记：后续请求立刻能按缓存规划；磁盘写入异步跟上
    if (!blocks.containsKey(index)) {
      blocks[index] = data.length;
      onWritten?.call();
      _dirty = true;
    }
    _writeQueue = _writeQueue.then((_) async {
      // 条目已被淘汰/清空后再完成的写入直接丢弃，避免重建孤儿目录
      if (_disposed) return;
      try {
        final d = dir;
        if (!d.existsSync()) {
          d.createSync(recursive: true);
        }
        await blockFile(index).writeAsBytes(data, flush: false);
      } catch (_) {
        // 磁盘满 / 目录被清理：撤销登记，不影响播放（回源兜底）
        blocks.remove(index);
        _dirty = true;
      }
    });
  }

  /// 串行执行挂起的块写入（测试/退出前确保落盘）。
  Future<void> awaitWrites() => _writeQueue;

  void disposeData() {
    _buffers.clear();
  }

  void deleteFromDisk() {
    _disposed = true;
    _buffers.clear();
    blocks.clear();
    try {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  void flushMetaIfNeeded() {
    if (!_dirty) return;
    _dirty = false;
    try {
      final d = dir;
      if (!d.existsSync()) {
        d.createSync(recursive: true);
      }
      final payload = jsonEncode({
        'audio': isAudio,
        'total': total,
        'la': lastAccess.millisecondsSinceEpoch,
        'blocks': blocks.map((k, v) => MapEntry('$k', v)),
      });
      metaFile.writeAsStringSync(payload, flush: false);
    } catch (_) {}
  }
}

class _BlockBuffer {
  final Uint8List _data = Uint8List(_kStreamBlockSize);

  /// 本缓冲从块内哪个偏移开始（-1 = 尚未写入）。
  int startInBlock = -1;
  int filled = 0;

  /// 下一次写入应落在的块内偏移；-1 表示空缓冲（接受任意起点）。
  int get nextExpectedPosInBlock =>
      startInBlock < 0 ? -1 : startInBlock + filled;

  void append(List<int> bytes, int offset, int count, int posInBlock) {
    if (startInBlock < 0) {
      startInBlock = posInBlock;
    }
    final end = filled + count;
    if (end > _data.length) return;
    _data.setRange(filled, end, bytes, offset);
    filled = end;
  }

  Uint8List takeBytes() {
    return Uint8List.fromList(_data.sublist(0, filled));
  }
}

class _ServeSegment {
  final bool cached;
  final int start;
  final int endExclusive;
  final int fetchStart;
  final int fetchEndExclusive;

  _ServeSegment({
    required this.cached,
    required this.start,
    required this.endExclusive,
    this.fetchStart = 0,
    this.fetchEndExclusive = 0,
  });
}

class _ServePlan {
  final int start;
  final int endExclusive;
  final List<_ServeSegment> segments;

  _ServePlan({required this.start, required this.endExclusive, required this.segments});
}
