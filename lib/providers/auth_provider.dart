import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/bili_http_client.dart';
import '../services/api/user_api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserInfo _userInfo = UserInfo(isLogin: false);
  bool _isLoading = false;

  UserInfo get userInfo => _userInfo;
  bool get isLogin => _userInfo.isLogin;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await BiliHttpClient().init();
    await refreshUserInfo();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshUserInfo() async {
    try {
      _userInfo = await UserApiService().getUserNav();
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

      final result = await AuthApiService().pollQrCode(qrcodeKey);
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
    await AuthApiService().logout();
    _userInfo = UserInfo(isLogin: false);
    notifyListeners();
  }
}
