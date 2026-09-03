import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiliSecurityService {
  static final BiliSecurityService _instance = BiliSecurityService._internal();
  factory BiliSecurityService() => _instance;
  BiliSecurityService._internal();

  static const List<int> mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
  ];

  String? _buvid3;
  String? _buvid4;
  String? _imgKey;
  String? _subKey;
  DateTime? _keyUpdateTime;
  bool _initialized = false;
  Future<void>? _initFuture;

  String? get buvid3 => _buvid3;
  String? get buvid4 => _buvid4;

  Future<void> init() {
    if (_initialized) return Future.value();
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _buvid3 = prefs.getString('buvid3');
      _buvid4 = prefs.getString('buvid4');
      _imgKey = prefs.getString('wbi_img_key');
      _subKey = prefs.getString('wbi_sub_key');
      final updateMs = prefs.getInt('wbi_key_time');
      if (updateMs != null) {
        _keyUpdateTime = DateTime.fromMillisecondsSinceEpoch(updateMs);
      }
      _initialized = true;
    } catch (_) {
      if (!_initialized) {
        _initFuture = null;
      }
      rethrow;
    }
  }

  void updateBuvid(String b3, String b4) async {
    _buvid3 = b3;
    _buvid4 = b4;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('buvid3', b3);
    await prefs.setString('buvid4', b4);
  }

  void updateWbiKeys(String imgUrl, String subUrl) async {
    try {
      final img = imgUrl.split('/').last.split('.').first;
      final sub = subUrl.split('/').last.split('.').first;
      _imgKey = img;
      _subKey = sub;
      _keyUpdateTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wbi_img_key', img);
      await prefs.setString('wbi_sub_key', sub);
      await prefs.setInt('wbi_key_time', _keyUpdateTime!.millisecondsSinceEpoch);
    } catch (_) {}
  }

  bool areWbiKeysValid() {
    if (_imgKey == null || _subKey == null || _keyUpdateTime == null) {
      return false;
    }
    // Wbi keys are updated daily; invalidate after 12 hours
    return DateTime.now().difference(_keyUpdateTime!).inHours < 12;
  }

  static String getMixinKey(String imgKey, String subKey) {
    final rawKey = imgKey + subKey;
    final buffer = StringBuffer();
    for (int i = 0; i < 32; i++) {
      if (mixinKeyEncTab[i] < rawKey.length) {
        buffer.write(rawKey[mixinKeyEncTab[i]]);
      }
    }
    return buffer.toString();
  }

  static final RegExp _sanitizeRegExp = RegExp(r"[!'()*]");

  /// Encodes parameters with WBI signature
  Map<String, dynamic> signWbi(Map<String, dynamic> params) {
    final imgKey = _imgKey ?? '7cd084941338484aae1ad9425b84077c';
    final subKey = _subKey ?? '4932caff0ff746eab6f01bf08b70ac45';

    final mixinKey = getMixinKey(imgKey, subKey);
    final currTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    final newParams = Map<String, dynamic>.from(params);
    newParams['wts'] = currTime;

    // Filter characters and sort keys alphabetically
    final sortedKeys = newParams.keys.toList()..sort();
    final queryList = <String>[];

    for (final key in sortedKeys) {
      final val = newParams[key].toString();
      // Remove characters !'()*
      final sanitizedVal = val.replaceAll(_sanitizeRegExp, '');
      final encodedKey = Uri.encodeQueryComponent(key);
      final encodedVal = Uri.encodeQueryComponent(sanitizedVal);
      queryList.add('$encodedKey=$encodedVal');
    }

    final queryString = queryList.join('&');
    final stringToSign = '$queryString$mixinKey';
    final wRid = md5.convert(utf8.encode(stringToSign)).toString();
    newParams['w_rid'] = wRid;

    return newParams;
  }
}
