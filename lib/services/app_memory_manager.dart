import 'dart:async';

import 'package:flutter/widgets.dart';

import 'player/bili_stream_proxy.dart';
import 'player/video_prefetch_service.dart';

/// 全局内存管理：退后台 / 系统内存告急时收缩位图缓存与播放器内存。
///
/// 听书模式要在后台长期持有音频解码器，后台内存越低越不容易被系统杀掉；
/// 前台收到内存压力信号时先自我收缩，避免等 LMK 直接清掉整个进程。
/// 图片回前台后会按需重新解码（轻微闪一下），属标准取舍。
class AppMemoryManager with WidgetsBindingObserver {
  AppMemoryManager._();

  static final AppMemoryManager instance = AppMemoryManager._();

  /// 与 main.dart 中的初始配置保持一致（图文长图反复解码会卡顿，不能长期调低）。
  static const int _normalImageCacheBytes = 256 << 20;
  static const int _trimmedImageCacheBytes = 96 << 20;

  /// 收缩后恢复上限的延时：给系统留出喘息窗口，避免刚回前台就重新堆满。
  static const Duration _restoreDelay = Duration(minutes: 2);

  bool _started = false;
  bool _trimmed = false;
  Timer? _restoreTimer;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didHaveMemoryPressure() {
    _trim('memoryPressure');
    _scheduleRestore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _trim('background');
    } else if (state == AppLifecycleState.resumed) {
      _scheduleRestore();
    }
  }

  void _scheduleRestore() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(_restoreDelay, _restore);
  }

  void _trim(String reason) {
    _restoreTimer?.cancel();
    _trimmed = true;
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSizeBytes = _trimmedImageCacheBytes;
    // 默认保留 live images：正在屏幕上的位图不闪、不重解码
    imageCache.clear();
    BiliStreamProxy().trimInMemoryBuffers();
    VideoPrefetchService.instance.clear();
    debugPrint('AppMemoryManager: trimmed ($reason)');
  }

  void _restore() {
    if (!_trimmed) return;
    _trimmed = false;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        _normalImageCacheBytes;
  }
}
