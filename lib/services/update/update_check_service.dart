import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_constants.dart';
import '../../widgets/app_update_dialog.dart';

/// GitHub Release 检查更新结果
class AppUpdateInfo {
  /// 原始标签，如 v1.0.9
  final String tagName;

  /// 归一化版本号，如 1.0.9
  final String version;

  /// Release 名称
  final String title;

  /// Release 说明（changelog 原文）
  final String changelog;

  /// Release 页面链接
  final String htmlUrl;

  /// 发布时间
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.changelog,
    required this.htmlUrl,
    this.publishedAt,
  });
}

/// 应用更新检查服务：
///  - 启动后延迟联网检查 GitHub 最新 Release（可在设置中关闭）
///  - 设置页可手动触发检查
///  - 当前版本号取自 package_info_plus（跟随 pubspec），避免手工维护失同步
class UpdateCheckService {
  static const String _keyAutoCheck = 'update_auto_check_enabled';
  static const String _repo = 'e69d8e/MoBili';
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  /// 启动自动检查的延迟：避开启动期网络请求高峰，等首帧稳定后再检查
  static const Duration _autoCheckDelay = Duration(seconds: 4);

  static bool _autoCheckEnabled = true;
  static String _installedVersion = '';
  static String _installedBuildNumber = '';
  static bool _autoDialogShownThisLaunch = false;

  /// 是否开启启动时自动检查更新
  static bool get autoCheckEnabled => _autoCheckEnabled;

  /// 当前安装版本号，如 1.0.8
  static String get installedVersion =>
      _installedVersion.isNotEmpty ? _installedVersion : _fallbackVersion;

  /// 当前版本展示文案，如 v1.0.8 (Build 9)
  static String get installedVersionDisplay =>
      'v$installedVersion (Build ${_installedBuildNumber.isNotEmpty ? _installedBuildNumber : _fallbackBuild})';

  static final ValueNotifier<bool> autoCheckListenable =
      ValueNotifier<bool>(true);

  static String get _fallbackVersion => AppConstants.appVersion.replaceFirst(RegExp(r'^v'), '');
  static String get _fallbackBuild => AppConstants.appBuildNumber.toString();

  /// 应用启动时预载设置与本地版本号
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCheckEnabled = prefs.getBool(_keyAutoCheck) ?? true;
      autoCheckListenable.value = _autoCheckEnabled;
    } catch (_) {}

    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersion = info.version;
      _installedBuildNumber = info.buildNumber;
    } catch (_) {}
  }

  static Future<void> setAutoCheckEnabled(bool val) async {
    _autoCheckEnabled = val;
    autoCheckListenable.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoCheck, val);
    } catch (_) {}
  }

  /// 拉取 GitHub 最新 Release 并与当前版本比较。
  /// 有新版本返回 [AppUpdateInfo]，已是最新（或无法解析远端版本号）返回 null。
  /// 网络失败时抛出异常，由调用方区分「无更新」与「检查失败」。
  static Future<AppUpdateInfo?> checkForUpdate() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    final res = await dio.get<Map<String, dynamic>>(
      _latestReleaseUrl,
      options: Options(headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'MoBili/$installedVersion',
      }),
    );
    final data = res.data;
    final tagName = data?['tag_name'] as String?;
    if (tagName == null || tagName.isEmpty) {
      return null;
    }

    final remoteVersion = normalizeVersion(tagName);
    if (remoteVersion == null ||
        !isNewerVersion(remoteVersion, installedVersion)) {
      return null;
    }

    return AppUpdateInfo(
      tagName: tagName,
      version: remoteVersion,
      title: (data?['name'] as String?)?.isNotEmpty == true
          ? data!['name'] as String
          : tagName,
      changelog: (data?['body'] as String?)?.trim() ?? '',
      htmlUrl: (data?['html_url'] as String?)?.isNotEmpty == true
          ? data!['html_url'] as String
          : 'https://github.com/$_repo/releases/latest',
      publishedAt: DateTime.tryParse(data?['published_at'] as String? ?? ''),
    );
  }

  /// 启动后的自动检查：静默失败，仅在确定有新版本时弹一次提示
  static Future<void> autoCheckOnLaunch(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (!_autoCheckEnabled) return;
    await Future.delayed(_autoCheckDelay);
    if (!_autoCheckEnabled) return;

    try {
      final info = await checkForUpdate();
      if (info == null || _autoDialogShownThisLaunch) return;
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      _autoDialogShownThisLaunch = true;
      AppUpdateDialog.show(context, info);
    } catch (e) {
      debugPrint('UpdateCheckService: auto check failed (ignored): $e');
    }
  }

  /// 归一化版本号：'v1.0.9' / '1.0.9' / '1.0.9-beta' → '1.0.9'，无法解析返回 null
  static String? normalizeVersion(String raw) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^[vV]'), '').trim();
    final match = RegExp(r'^\d+(\.\d+)*').firstMatch(cleaned);
    if (match == null) return null;
    return match.group(0);
  }

  /// 比较 a 是否比 b 更新（按 '.' 分段逐段比较数值，缺省段视为 0）
  static bool isNewerVersion(String a, String b) {
    final aSegs = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bSegs = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = aSegs.length > bSegs.length ? aSegs.length : bSegs.length;
    for (var i = 0; i < len; i++) {
      final av = i < aSegs.length ? aSegs[i] : 0;
      final bv = i < bSegs.length ? bSegs[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }
}
