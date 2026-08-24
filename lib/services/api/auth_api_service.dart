import 'api_endpoints.dart';
import 'bili_http_client.dart';

class QrCodeResult {
  final String qrcodeKey;
  final String url;

  QrCodeResult({required this.qrcodeKey, required this.url});
}

class QrPollResult {
  final int code; // 0: success, 86101: not scanned, 86090: scanned not confirmed, 86038: expired
  final String message;
  final String? url;

  QrPollResult({required this.code, required this.message, this.url});

  bool get isSuccess => code == 0;
  bool get isExpired => code == 86038;
  bool get isScanned => code == 86090;
  bool get isWaiting => code == 86101;
}

class AuthApiService {
  static final AuthApiService _instance = AuthApiService._internal();
  factory AuthApiService() => _instance;
  AuthApiService._internal();

  /// Generate QR Code for Web Login
  Future<QrCodeResult?> generateQrCode() async {
    try {
      final res = await BiliHttpClient().get(ApiEndpoints.qrGenerate);
      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final key = res.data['data']['qrcode_key'] as String?;
        final url = res.data['data']['url'] as String?;
        if (key != null && url != null) {
          return QrCodeResult(qrcodeKey: key, url: url);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Poll QR Code status
  Future<QrPollResult> pollQrCode(String qrcodeKey) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.qrPoll,
        queryParameters: {'qrcode_key': qrcodeKey},
      );

      if (res.data != null && res.data['data'] != null) {
        final data = res.data['data'];
        final code = data['code'] is int ? data['code'] : -1;
        final msg = data['message']?.toString() ?? '';
        final url = data['url']?.toString();

        if (code == 0 && url != null && url.isNotEmpty) {
          try {
            final uri = Uri.parse(url);
            final Map<String, String> queryCookies = {};
            uri.queryParameters.forEach((k, v) {
              if (['DedeUserID', 'DedeUserID__ckMd5', 'SESSDATA', 'bili_jct', 'sid'].contains(k)) {
                queryCookies[k] = v;
              }
            });
            if (queryCookies.isNotEmpty) {
              await BiliHttpClient().saveCookies(queryCookies);
            }
          } catch (_) {}
        }

        return QrPollResult(code: code, message: msg, url: url);
      }
      return QrPollResult(code: -1, message: '网络请求错误');
    } catch (e) {
      return QrPollResult(code: -1, message: e.toString());
    }
  }

  /// Logout current user
  Future<void> logout() async {
    await BiliHttpClient().clearUserCookies();
  }
}
