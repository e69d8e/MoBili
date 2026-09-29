import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../screens/search/search_screen.dart';
import '../screens/up/up_space_screen.dart';
import '../screens/video/video_detail_screen.dart';
import '../widgets/app_toast.dart';
import 'api/video_api_service.dart';

/// 深度链接服务：解析 B 站链接并路由到对应页面。
///
/// 支持的链接形式：
///  - https://www.bilibili.com/video/BVxxxx / avxxxx （含 m.bilibili.com）
///  - https://b23.tv/xxxx 短链（302 重定向解析出真实地址）
///  - https://space.bilibili.com/{mid}
///  - https://search.bilibili.com/all?keyword=...
///  - mobili://video?bvid=BVxxxx / mobili://space?mid=123 / mobili://search?keyword=xx
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const String _customScheme = 'mobili';
  static final RegExp _bvRegExp = RegExp(r'(BV[0-9A-Za-z]{10})');
  static final RegExp _avRegExp = RegExp(r'av(\d+)');

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Navigator 未就绪（首帧前到达的冷启动链接）时暂存，首帧后消费
  Uri? _pendingUri;
  Uri? _lastHandledUri;
  DateTime _lastHandledAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    // 首帧渲染完成后消费早到的冷启动链接
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingUri;
      if (pending != null) {
        _pendingUri = null;
        _consume(pending);
      }
    });
    // 唯一入口：uriLinkStream 在冷启动时也会补发 initial link，
    // 不再额外调用 getInitialLink，避免同一链接被处理两次
    _sub = _appLinks.uriLinkStream.listen(
      _onLink,
      onError: (Object e) =>
          debugPrint('DeepLinkService: link stream error: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _onLink(Uri uri) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      _pendingUri = uri;
      return;
    }
    _consume(uri);
  }

  void _consume(Uri uri) {
    final now = DateTime.now();
    // 部分 ROM 会重复投递同一 intent：3 秒内相同链接去重
    if (uri == _lastHandledUri &&
        now.difference(_lastHandledAt) < const Duration(seconds: 3)) {
      return;
    }
    _lastHandledUri = uri;
    _lastHandledAt = now;

    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      _pendingUri = uri;
      return;
    }
    unawaited(_route(nav, uri));
  }

  /// 从文本中提取合法 BV 号（BV + 10 位字母数字）
  static String? _extractBvid(String? text) {
    if (text == null || text.isEmpty) return null;
    return _bvRegExp.firstMatch(text)?.group(1);
  }

  /// 链接分类解析（纯函数，便于单测）：从已解析的 URI 中提取路由目标。
  /// 无法识别时返回 null。
  static DeepLinkTarget? parseTarget(Uri resolved) {
    String? bvid;
    int? aid;
    int? mid;
    String? keyword;

    if (resolved.scheme == _customScheme) {
      // custom scheme 的 bvid 同样走格式校验，防止任意字符串注入 API 参数
      bvid = _extractBvid(resolved.queryParameters['bvid']);
      mid = int.tryParse(resolved.queryParameters['mid'] ?? '');
      keyword = resolved.queryParameters['keyword'];
    } else {
      final path = resolved.path;
      final bvMatch = _bvRegExp.firstMatch(path);
      if (bvMatch != null) {
        bvid = bvMatch.group(1);
      } else {
        final avMatch = _avRegExp.firstMatch(path);
        final parsed =
            avMatch == null ? null : int.tryParse(avMatch.group(1)!);
        if (parsed != null && parsed > 0) aid = parsed;
      }
      if (resolved.host == 'space.bilibili.com') {
        final segment =
            path.split('/').firstWhere((s) => s.isNotEmpty, orElse: () => '');
        mid = int.tryParse(segment);
      }
      keyword = resolved.queryParameters['keyword'];
    }

    if (bvid == null && aid == null && (mid == null || mid <= 0)) {
      final kw = keyword?.trim() ?? '';
      if (kw.isEmpty) return null;
      return DeepLinkTarget(keyword: kw);
    }
    return DeepLinkTarget(
      bvid: bvid,
      aid: (aid != null && aid > 0) ? aid : null,
      mid: (mid != null && mid > 0) ? mid : null,
    );
  }

  Future<void> _route(NavigatorState nav, Uri uri) async {
    final navContext = nav.context;
    Uri resolved = uri;
    if ((uri.host == 'b23.tv' || uri.host == 'b23.cn') &&
        uri.scheme == 'https') {
      final short = await _resolveShortLink(uri);
      if (short == null) {
        // 解析失败给用户反馈，而不是点了链接毫无反应
        if (navContext.mounted) {
          AppToast.show(navContext, '链接解析失败，请稍后重试');
        }
        return;
      }
      resolved = short;
    }

    final target = parseTarget(resolved);
    if (target == null) return;

    if (target.bvid != null) {
      _push(nav, VideoDetailScreen(bvid: target.bvid!));
      return;
    }
    if (target.aid != null) {
      // av 号链接：先换取 bvid 再路由
      final bvidFromAid = await VideoApiService().getBvidByAid(target.aid!);
      if (bvidFromAid != null) {
        _push(nav, VideoDetailScreen(bvid: bvidFromAid));
      } else if (navContext.mounted) {
        AppToast.show(navContext, '视频不存在或已下架');
      }
      return;
    }
    if (target.mid != null) {
      _push(nav, UpSpaceScreen(mid: target.mid!));
      return;
    }
    _push(nav, SearchScreen(initialKeyword: target.keyword!));
  }

  /// b23.tv 短链通过 302 Location 解析真实地址。
  /// 用 HEAD 避免下载整页 HTML（反爬时 b23.tv 可能直接返回 200 页面）；
  /// 相对跳转用 [Uri.resolve] 拼接，跨域重定向也能正确处理。
  Future<Uri?> _resolveShortLink(Uri uri) async {
    final dio = Dio(
      BaseOptions(
        followRedirects: false,
        // 3xx 也算有效响应，以便读取 Location
        validateStatus: (code) => code != null && code < 500,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ),
    );
    try {
      var current = uri.toString();
      for (var i = 0; i < 4; i++) {
        var res = await dio.head<dynamic>(current);
        var status = res.statusCode ?? 0;
        if (status == 405 || status == 501) {
          // 服务器不支持 HEAD：退回 GET（3xx 响应体为空，代价可接受）
          res = await dio.get<dynamic>(current);
          status = res.statusCode ?? 0;
        }
        final location = res.headers.value('location');
        if (status >= 300 && status < 400 && location != null) {
          final currentUri = Uri.tryParse(current);
          if (currentUri == null) return null;
          current = currentUri.resolve(location).toString();
          continue;
        }
        if (status < 300) {
          return Uri.tryParse(current);
        }
        return null; // 4xx：链接失效
      }
      return null; // 重定向次数过多
    } catch (e) {
      debugPrint('DeepLinkService: resolve short link failed: $e');
      return null;
    } finally {
      dio.close();
    }
  }

  void _push(NavigatorState nav, Widget screen) {
    nav.push(MaterialPageRoute(builder: (ctx) => screen));
  }
}

/// 解析出的链接路由目标（按优先级依次判断：bvid → aid → mid → keyword）
class DeepLinkTarget {
  final String? bvid;
  final int? aid;
  final int? mid;
  final String? keyword;

  const DeepLinkTarget({this.bvid, this.aid, this.mid, this.keyword});
}
