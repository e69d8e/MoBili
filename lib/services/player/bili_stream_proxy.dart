import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../api/bili_http_client.dart';

/// Lightweight local streaming proxy to serve Bilibili DASH and MP4 streams
/// with standard video/mp4 and audio/mp4 MIME types, proper Referer/User-Agent/Cookie headers,
/// and Range request support. Resolves B站 CDN 403 Forbidden and player unsupported format errors.
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

  HttpClient get _client {
    return _httpClient ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 30)
      ..autoUncompress = false;
  }

  bool get isRunning => _server != null;

  /// Start the local loopback HTTP server
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
      final clientReq = await _client.openUrl(method, Uri.parse(targetUrl));
      clientReq.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      clientReq.headers.set(HttpHeaders.refererHeader, 'https://www.bilibili.com');

      final cookie = BiliHttpClient().cookieHeader;
      if (cookie.isNotEmpty) {
        clientReq.headers.set(HttpHeaders.cookieHeader, cookie);
      }

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null) {
        clientReq.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      }

      final clientRes = await clientReq.close();
      request.response.statusCode = clientRes.statusCode;

      final isAudio = token.startsWith('audio_');
      request.response.headers.set(
        HttpHeaders.contentTypeHeader,
        isAudio ? 'audio/mp4' : 'video/mp4',
      );
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Headers', '*');

      final contentLength = clientRes.headers.value(HttpHeaders.contentLengthHeader);
      if (contentLength != null) {
        request.response.headers.set(HttpHeaders.contentLengthHeader, contentLength);
      }

      final contentRange = clientRes.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null) {
        request.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
      }

      if (method == 'HEAD') {
        await clientRes.drain();
        await request.response.close();
        return;
      }

      try {
        await clientRes.pipe(request.response);
      } catch (_) {
        // Player closed connection early (e.g. seek/buffer fulfilled)
      }
    } catch (e) {
      debugPrint('BiliStreamProxy _handleRequest error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Registers an upstream remote URL and returns a local proxy URL ending with .mp4
  Future<String> getProxyUrl(String remoteUrl, {bool isAudio = false}) async {
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
    final hash = md5.convert(utf8.encode(remoteUrl)).toString();
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
    _httpClient?.close(force: true);
    _httpClient = null;
  }
}
