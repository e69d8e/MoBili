import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/bili_http_client.dart';
import '../services/api/user_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final UserApiService _userApiService;
  final AuthApiService _authApiService;
  final BiliHttpClient _biliHttpClient;

  AuthProvider({
    UserApiService? userApiService,
    AuthApiService? authApiService,
    BiliHttpClient? biliHttpClient,
  })  : _userApiService = userApiService ?? UserApiService(),
        _authApiService = authApiService ?? AuthApiService(),
        _biliHttpClient = biliHttpClient ?? BiliHttpClient();

  UserInfo _userInfo = UserInfo(isLogin: false);
  bool _isLoading = false;
  bool _isCookieExpired = false;

  UserInfo get userInfo => _userInfo;
  bool get isLogin => _userInfo.isLogin;
  bool get isLoading => _isLoading;
  bool get isCookieExpired => _isCookieExpired;

  /// Fast local initialization from persistent cache (no blocking network calls)
  Future<void> initLocal() async {
    await _biliHttpClient.initLocal();
  }

  /// Asynchronous network credentials check and user profile fetch in background
  Future<void> initNetwork() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _biliHttpClient.init();
      await refreshUserInfo();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backwards-compatible init method
  Future<void> init() async {
    await initLocal();
    await initNetwork();
  }

  Future<void> refreshUserInfo() async {
    final hadLoginCookies = _biliHttpClient.isLoggedIn;
    try {
      _userInfo = await _userApiService.getUserNav();
      if (hadLoginCookies && !_userInfo.isLogin) {
        _isCookieExpired = true;
      } else if (_userInfo.isLogin) {
        _isCookieExpired = false;
      }
      notifyListeners();
    } catch (_) {}
  }

  void dismissCookieExpiryNotice() {
    _isCookieExpired = false;
    notifyListeners();
  }

  /// Start polling QR Code status
  /// Returns a cancel token function
  void Function() startQrPolling({
    required String qrcodeKey,
    required Function(QrPollResult result) onStatus,
    required VoidCallback onSuccess,
  }) {
    bool cancelled = false;
    Timer? timer;

    timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (cancelled) {
        t.cancel();
        return;
      }

      final result = await _authApiService.pollQrCode(qrcodeKey);
      if (cancelled) return;

      onStatus(result);

      if (result.isSuccess) {
        t.cancel();
        _isCookieExpired = false;
        await refreshUserInfo();
        onSuccess();
      } else if (result.isExpired) {
        t.cancel();
      }
    });

    return () {
      cancelled = true;
      timer?.cancel();
    };
  }

  Future<void> logout() async {
    await _authApiService.logout();
    _userInfo = UserInfo(isLogin: false);
    _isCookieExpired = false;
    notifyListeners();
  }
}
