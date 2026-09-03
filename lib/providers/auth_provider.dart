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

  UserInfo get userInfo => _userInfo;
  bool get isLogin => _userInfo.isLogin;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _biliHttpClient.init();
    await refreshUserInfo();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshUserInfo() async {
    try {
      _userInfo = await _userApiService.getUserNav();
      notifyListeners();
    } catch (_) {}
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
    notifyListeners();
  }
}
