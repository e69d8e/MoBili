import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_storage_service.dart';
import 'video_cache_service.dart';

enum AutoCleanInterval {
  launch('launch', '每次启动应用', Duration.zero),
  days1('days1', '每 1 天', Duration(days: 1)),
  days3('days3', '每 3 天', Duration(days: 3)),
  days7('days7', '每 7 天', Duration(days: 7)),
  days15('days15', '每 15 天', Duration(days: 15)),
  days30('days30', '每 30 天', Duration(days: 30));

  final String key;
  final String label;
  final Duration duration;

  const AutoCleanInterval(this.key, this.label, this.duration);

  static AutoCleanInterval fromKey(String? key) {
    return AutoCleanInterval.values.firstWhere(
      (e) => e.key == key,
      orElse: () => AutoCleanInterval.days7,
    );
  }
}

enum AutoCleanTarget {
  images('images', '网络图片缓存', '封面、头像、动态插图及表情包', true),
  temp('temp', '系统临时与播放缓冲', '音视频播放缓冲分片、网络传输临时数据', true),
  searchHistory('searchHistory', '搜索关键词历史', '清空本地搜索框历史词', false),
  playbackHistory('playbackHistory', '本地播放历史与进度', '清空本地记录的视频播放秒数与历史', false);

  final String key;
  final String label;
  final String description;
  final bool isDefaultEnabled;

  const AutoCleanTarget(this.key, this.label, this.description, this.isDefaultEnabled);

  static AutoCleanTarget? fromKey(String key) {
    for (final t in AutoCleanTarget.values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

class CacheSizeInfo {
  final int imageCacheBytes;
  final int tempDirBytes;
  final int videoCacheBytes;
  final int videoCacheCount;
  final int historyCount;
  final int searchHistoryCount;

  const CacheSizeInfo({
    this.imageCacheBytes = 0,
    this.tempDirBytes = 0,
    this.videoCacheBytes = 0,
    this.videoCacheCount = 0,
    this.historyCount = 0,
    this.searchHistoryCount = 0,
  });

  int get cleanableBytes => imageCacheBytes + tempDirBytes;
  int get totalAppStorageBytes => imageCacheBytes + tempDirBytes + videoCacheBytes;

  CacheSizeInfo copyWith({
    int? imageCacheBytes,
    int? tempDirBytes,
    int? videoCacheBytes,
    int? videoCacheCount,
    int? historyCount,
    int? searchHistoryCount,
  }) {
    return CacheSizeInfo(
      imageCacheBytes: imageCacheBytes ?? this.imageCacheBytes,
      tempDirBytes: tempDirBytes ?? this.tempDirBytes,
      videoCacheBytes: videoCacheBytes ?? this.videoCacheBytes,
      videoCacheCount: videoCacheCount ?? this.videoCacheCount,
      historyCount: historyCount ?? this.historyCount,
      searchHistoryCount: searchHistoryCount ?? this.searchHistoryCount,
    );
  }
}

class AppCacheService extends ChangeNotifier {
  static final AppCacheService _instance = AppCacheService._internal();
  factory AppCacheService() => _instance;
  AppCacheService._internal();

  static const String _keyAutoCleanEnabled = 'auto_clean_enabled';
  static const String _keyAutoCleanInterval = 'auto_clean_interval';
  static const String _keyAutoCleanTargets = 'auto_clean_targets';
  static const String _keyLastAutoCleanTimestamp = 'auto_clean_last_run_timestamp';

  CacheSizeInfo _cacheInfo = const CacheSizeInfo();
  CacheSizeInfo get cacheInfo => _cacheInfo;

  bool _isCalculating = false;
  bool get isCalculating => _isCalculating;

  bool _isCleaning = false;
  bool get isCleaning => _isCleaning;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool _autoCleanEnabled = false;
  bool get autoCleanEnabled => _autoCleanEnabled;

  AutoCleanInterval _autoCleanInterval = AutoCleanInterval.days7;
  AutoCleanInterval get autoCleanInterval => _autoCleanInterval;

  Set<String> _autoCleanTargets = {'images', 'temp'};
  Set<String> get autoCleanTargets => Set.unmodifiable(_autoCleanTargets);

  int _lastAutoCleanTimestamp = 0;
  int get lastAutoCleanTimestamp => _lastAutoCleanTimestamp;

  /// Initialize and check auto-clean schedule on app start
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCleanEnabled = prefs.getBool(_keyAutoCleanEnabled) ?? false;
      _autoCleanInterval = AutoCleanInterval.fromKey(prefs.getString(_keyAutoCleanInterval));
      final rawTargets = prefs.getStringList(_keyAutoCleanTargets);
      if (rawTargets != null && rawTargets.isNotEmpty) {
        _autoCleanTargets = rawTargets.toSet();
      } else {
        _autoCleanTargets = {'images', 'temp'};
      }
      _lastAutoCleanTimestamp = prefs.getInt(_keyLastAutoCleanTimestamp) ?? 0;
      _initialized = true;

      // Trigger background auto clean check if scheduled
      if (_autoCleanEnabled) {
        unawaited(checkAndTriggerAutoClean());
      }
    } catch (_) {
      _initialized = true;
    }
  }

  /// Toggle auto-clean master switch
  Future<void> setAutoCleanEnabled(bool enabled) async {
    _autoCleanEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoCleanEnabled, enabled);
      if (enabled) {
        unawaited(checkAndTriggerAutoClean());
      }
    } catch (_) {}
  }

  /// Change auto-clean interval
  Future<void> setAutoCleanInterval(AutoCleanInterval interval) async {
    _autoCleanInterval = interval;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAutoCleanInterval, interval.key);
      if (_autoCleanEnabled) {
        unawaited(checkAndTriggerAutoClean());
      }
    } catch (_) {}
  }

  /// Toggle single target cache type for auto-cleaning
  Future<void> toggleAutoCleanTarget(String targetKey, bool enabled) async {
    final updated = Set<String>.from(_autoCleanTargets);
    if (enabled) {
      updated.add(targetKey);
    } else {
      updated.remove(targetKey);
    }
    _autoCleanTargets = updated;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyAutoCleanTargets, _autoCleanTargets.toList());
    } catch (_) {}
  }

  /// Check if auto clean should be triggered based on interval and elapsed time
  Future<bool> checkAndTriggerAutoClean() async {
    if (!_autoCleanEnabled || _autoCleanTargets.isEmpty) return false;

    final now = DateTime.now();
    bool shouldRun = false;

    if (_autoCleanInterval == AutoCleanInterval.launch) {
      shouldRun = true;
    } else {
      if (_lastAutoCleanTimestamp <= 0) {
        shouldRun = true;
      } else {
        final lastRun = DateTime.fromMillisecondsSinceEpoch(_lastAutoCleanTimestamp);
        final diff = now.difference(lastRun);
        if (diff >= _autoCleanInterval.duration) {
          shouldRun = true;
        }
      }
    }

    if (shouldRun) {
      await executeAutoClean();
      return true;
    }

    return false;
  }

  /// Execute auto-clean strictly on configured target categories
  Future<int> executeAutoClean() async {
    int freed = 0;
    try {
      if (_autoCleanTargets.contains(AutoCleanTarget.images.key)) {
        freed += await clearImageCache();
      }
      if (_autoCleanTargets.contains(AutoCleanTarget.temp.key)) {
        freed += await clearTempFiles();
      }
      if (_autoCleanTargets.contains(AutoCleanTarget.searchHistory.key)) {
        await clearSearchHistory();
      }
      if (_autoCleanTargets.contains(AutoCleanTarget.playbackHistory.key)) {
        await clearPlaybackHistory();
      }

      _lastAutoCleanTimestamp = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastAutoCleanTimestamp, _lastAutoCleanTimestamp);
      notifyListeners();
    } catch (_) {}
    return freed;
  }

  /// Calculate total size of a directory recursively using non-blocking asynchronous stream
  Future<int> _calculateDirectorySize(Directory? dir) async {
    if (dir == null || !dir.existsSync()) return 0;
    int totalSize = 0;
    try {
      final Stream<FileSystemEntity> stream = dir.list(recursive: true, followLinks: false);
      await for (final entity in stream) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return totalSize;
  }

  /// Scan and calculate all cache sizes asynchronously
  Future<CacheSizeInfo> calculateAllCacheSizes() async {
    if (_isCalculating) return _cacheInfo;
    _isCalculating = true;
    notifyListeners();

    try {
      int imageBytes = 0;
      int tempBytes = 0;

      // 1. Image cache calculation (libCachedImageData and common cache directories)
      try {
        final tempDir = await getTemporaryDirectory();
        final imageCacheDir = Directory('${tempDir.path}/libCachedImageData');
        if (imageCacheDir.existsSync()) {
          imageBytes += await _calculateDirectorySize(imageCacheDir);
        }
      } catch (_) {}

      try {
        final cacheDir = await getApplicationCacheDirectory();
        final imageCacheDir = Directory('${cacheDir.path}/libCachedImageData');
        if (imageCacheDir.existsSync()) {
          imageBytes += await _calculateDirectorySize(imageCacheDir);
        }
      } catch (_) {}

      // 2. Temp directory calculation (excluding imageCacheDir to prevent double counting)
      try {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          final Stream<FileSystemEntity> stream = tempDir.list(recursive: false, followLinks: false);
          await for (final entity in stream) {
            if (entity.path.endsWith('libCachedImageData')) continue;
            if (entity is File) {
              try {
                tempBytes += await entity.length();
              } catch (_) {}
            } else if (entity is Directory) {
              tempBytes += await _calculateDirectorySize(entity);
            }
          }
        }
      } catch (_) {}

      // 3. Video cache calculation from VideoCacheService
      int videoBytes = 0;
      int videoCount = 0;
      try {
        videoBytes = VideoCacheService().getTotalCacheSizeBytes();
        videoCount = VideoCacheService().totalCompletedCount;
      } catch (_) {}

      // 4. History count from HistoryStorageService
      int histCount = 0;
      try {
        histCount = HistoryStorageService().totalRecordCount;
      } catch (_) {}

      // 5. Search history count from SharedPreferences
      int searchCount = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        final searchList = prefs.getStringList('search_history');
        searchCount = searchList?.length ?? 0;
      } catch (_) {}

      _cacheInfo = CacheSizeInfo(
        imageCacheBytes: imageBytes,
        tempDirBytes: tempBytes,
        videoCacheBytes: videoBytes,
        videoCacheCount: videoCount,
        historyCount: histCount,
        searchHistoryCount: searchCount,
      );
    } catch (_) {
    } finally {
      _isCalculating = false;
      notifyListeners();
    }

    return _cacheInfo;
  }

  /// Clear image cache (disk + memory)
  Future<int> clearImageCache() async {
    final freed = _cacheInfo.imageCacheBytes;
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await DefaultCacheManager().emptyCache();

      final tempDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (imageCacheDir.existsSync()) {
        try {
          await imageCacheDir.delete(recursive: true);
        } catch (_) {}
      }

      try {
        final cacheDir = await getApplicationCacheDirectory();
        final cacheImgDir = Directory('${cacheDir.path}/libCachedImageData');
        if (cacheImgDir.existsSync()) {
          await cacheImgDir.delete(recursive: true);
        }
      } catch (_) {}
    } catch (_) {}

    await calculateAllCacheSizes();
    return freed;
  }

  /// Clear temporary directory files safely
  Future<int> clearTempFiles() async {
    final freed = _cacheInfo.tempDirBytes;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final Stream<FileSystemEntity> stream = tempDir.list(recursive: false, followLinks: false);
        await for (final entity in stream) {
          if (entity.path.endsWith('libCachedImageData')) continue;
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    await calculateAllCacheSizes();
    return freed;
  }

  /// Clear all cleanable caches (Image + Temp)
  Future<int> clearAllCleanableCaches() async {
    _isCleaning = true;
    notifyListeners();

    int totalFreed = _cacheInfo.cleanableBytes;
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await DefaultCacheManager().emptyCache();

      // Clear temp image directory
      try {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          final Stream<FileSystemEntity> stream = tempDir.list(recursive: false, followLinks: false);
          await for (final entity in stream) {
            try {
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                await entity.delete(recursive: true);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Clear app cache directory
      try {
        final cacheDir = await getApplicationCacheDirectory();
        if (cacheDir.existsSync()) {
          final Stream<FileSystemEntity> stream = cacheDir.list(recursive: false, followLinks: false);
          await for (final entity in stream) {
            try {
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                await entity.delete(recursive: true);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      _isCleaning = false;
      await calculateAllCacheSizes();
    }

    return totalFreed;
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
    } catch (_) {}
    await calculateAllCacheSizes();
  }

  /// Clear playback history
  Future<void> clearPlaybackHistory() async {
    try {
      await HistoryStorageService().clearAll();
    } catch (_) {}
    await calculateAllCacheSizes();
  }

  /// Format bytes into human readable string (e.g. 0 B, 128.5 KB, 345.8 MB, 1.25 GB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
