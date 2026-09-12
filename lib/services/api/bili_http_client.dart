import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';
import 'bili_security_service.dart';

class BiliHttpClient {
  static final BiliHttpClient _instance = BiliHttpClient._internal();
  factory BiliHttpClient() => _instance;

  late final Dio dio;
  final Map<String, String> _cookies = {};
  bool _initialized = false;
  Future<void>? _initFuture;

  String _cachedCookieHeader = '';
  SharedPreferences? _prefs;

  static const String defaultUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  BiliHttpClient._internal() {
    final Map<String, dynamic> baseHeaders = {
      'Accept': 'application/json, text/plain, */*',
    };
    if (!kIsWeb) {
      baseHeaders['User-Agent'] = defaultUserAgent;
      baseHeaders['Referer'] = 'https://www.bilibili.com';
    }

    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        headers: baseHeaders,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Attach cookies (only on non-web, as browsers manage cookies directly and forbid manual Cookie header)
          if (!kIsWeb && _cachedCookieHeader.isNotEmpty) {
            options.headers['Cookie'] = _cachedCookieHeader;
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Extract set-cookie headers
          final setCookieHeaders = response.headers['set-cookie'];
          if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
            _saveSetCookies(setCookieHeaders);
          }
          return handler.next(response);
        },
      ),
    );
  }

  void _updateCookieHeaderCache() {
    if (_cookies.isEmpty) {
      _cachedCookieHeader = '';
    } else {
      _cachedCookieHeader = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> initLocal() async {
    try {
      await BiliSecurityService().init();
      await _loadPersistedCookies();
      if (_cookies.containsKey('buvid3')) {
        _cookies['buvid3'] = BiliSecurityService().buvid3 ?? _cookies['buvid3']!;
      }
      if (BiliSecurityService().buvid4 != null) {
        _cookies['buvid4'] = BiliSecurityService().buvid4!;
      }
      _updateCookieHeaderCache();
    } catch (_) {}
  }

  Future<void> init() {
    if (_initialized) return Future.value();
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      await initLocal();

      // Ensure buvid3 exists
      if (!_cookies.containsKey('buvid3') || BiliSecurityService().buvid3 == null) {
        await refreshSpiFingerprint();
      } else {
        _cookies['buvid3'] = BiliSecurityService().buvid3!;
        if (BiliSecurityService().buvid4 != null) {
          _cookies['buvid4'] = BiliSecurityService().buvid4!;
        }
      }
      _updateCookieHeaderCache();

      // Ensure WBI keys are up-to-date
      if (!BiliSecurityService().areWbiKeysValid()) {
        await refreshWbiKeys();
      }

      _initialized = true;
    } catch (_) {
      if (!_initialized) {
        _initFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _loadPersistedCookies() async {
    final prefs = await _getPrefs();
    final cookieString = prefs.getString('bili_cookies');
    if (cookieString != null && cookieString.isNotEmpty) {
      final pairs = cookieString.split('; ');
      for (final pair in pairs) {
        final idx = pair.indexOf('=');
        if (idx > 0) {
          final k = pair.substring(0, idx).trim();
          final v = pair.substring(idx + 1).trim();
          _cookies[k] = v;
        }
      }
      _updateCookieHeaderCache();
    }
  }

  Future<void> saveCookies(Map<String, String> newCookies) async {
    _cookies.addAll(newCookies);
    _updateCookieHeaderCache();
    final prefs = await _getPrefs();
    await prefs.setString('bili_cookies', _cachedCookieHeader);
  }

  void _saveSetCookies(List<String> rawSetCookies) async {
    final Map<String, String> updated = {};
    for (final raw in rawSetCookies) {
      final parts = raw.split(';').first.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        updated[key] = value;
      }
    }
    if (updated.isNotEmpty) {
      await saveCookies(updated);
    }
  }

  Future<void> clearUserCookies() async {
    _cookies.remove('SESSDATA');
    _cookies.remove('bili_jct');
    _cookies.remove('DedeUserID');
    _cookies.remove('DedeUserID__ckMd5');
    _cookies.remove('sid');
    _updateCookieHeaderCache();
    final prefs = await _getPrefs();
    await prefs.setString('bili_cookies', _cachedCookieHeader);
  }

  Map<String, String> get cookies => Map.unmodifiable(_cookies);
  String get cookieHeader => _cachedCookieHeader;
  String? get sessData => _cookies['SESSDATA'];
  String? get biliJct => _cookies['bili_jct'];
  String? get dedeUserId => _cookies['DedeUserID'];
  bool get isLoggedIn => _cookies.containsKey('SESSDATA') && _cookies['SESSDATA']!.isNotEmpty;

  /// Fetch SPI fingerprint for buvid3 and buvid4
  Future<void> refreshSpiFingerprint() async {
    try {
      final res = await dio.get(ApiEndpoints.spiFinger);
      if (res.data != null && res.data['code'] == 0) {
        final b3 = res.data['data']['b_3'] as String?;
        final b4 = res.data['data']['b_4'] as String?;
        if (b3 != null && b4 != null) {
          BiliSecurityService().updateBuvid(b3, b4);
          await saveCookies({'buvid3': b3, 'buvid4': b4});
        }
      }
    } catch (_) {}
  }

  /// Refresh WBI keys from Nav API
  Future<void> refreshWbiKeys() async {
    try {
      final res = await dio.get(ApiEndpoints.nav);
      if (res.data != null && res.data['data'] != null) {
        final wbiImg = res.data['data']['wbi_img'];
        if (wbiImg != null) {
          final imgUrl = wbiImg['img_url'] as String?;
          final subUrl = wbiImg['sub_url'] as String?;
          if (imgUrl != null && subUrl != null) {
            BiliSecurityService().updateWbiKeys(imgUrl, subUrl);
          }
        }
      }
    } catch (_) {}
  }

  /// Perform standard GET request
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await init();
    return await dio.get(url, queryParameters: queryParameters, options: options);
  }

  /// Perform GET request with WBI parameter signing
  Future<Response> getWbi(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await init();
    final params = queryParameters != null ? Map<String, dynamic>.from(queryParameters) : <String, dynamic>{};
    final signedParams = BiliSecurityService().signWbi(params);
    return await dio.get(url, queryParameters: signedParams, options: options);
  }

  /// Perform POST request
  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await init();
    return await dio.post(url, data: data, queryParameters: queryParameters, options: options);
  }

  /// Perform GET request returning raw bytes (e.g. for Danmaku XML stream)
  Future<Uint8List> getBytes(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    await init();
    final res = await dio.get<List<int>>(
      url,
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.bytes,
        headers: kIsWeb
            ? null
            : {
                'Accept-Encoding': 'gzip, deflate',
              },
      ),
    );
    return Uint8List.fromList(res.data ?? []);
  }
}
