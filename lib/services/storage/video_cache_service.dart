import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/play_url_model.dart';
import '../../models/video_cache_model.dart';
import '../api/api_endpoints.dart';
import '../api/bili_http_client.dart';
import '../api/video_api_service.dart';

/// 在后台 isolate 中解析缓存索引并校验本地文件是否存在（compute 顶层函数）
List<VideoCacheItem> _parseCacheIndex(String content) {
  final result = <VideoCacheItem>[];
  final decoded = jsonDecode(content);
  if (decoded is List) {
    for (final itemJson in decoded) {
      if (itemJson is Map<String, dynamic>) {
        final item = VideoCacheItem.fromJson(itemJson);
        if (item.status == VideoCacheStatus.completed) {
          // Verify completed file on disk
          final hasVideo = item.localVideoPath.isNotEmpty &&
              File(item.localVideoPath).existsSync();
          final hasAudio = item.localAudioPath.isEmpty ||
              File(item.localAudioPath).existsSync();
          if (hasVideo && hasAudio) {
            result.add(item);
          }
        } else {
          // Revert pending/downloading to paused on startup
          result.add(item.copyWith(
            status: VideoCacheStatus.paused,
            downloadSpeed: 0,
          ));
        }
      }
    }
  }
  return result;
}

class VideoCacheService extends ChangeNotifier {  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  static const int _maxConcurrent = 2;
  static const String _indexFileName = 'index.json';

  Directory? _cacheDir;
  final Map<String, VideoCacheItem> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, int> _lastReportedTime = {};
  final Map<String, int> _lastReportedBytes = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  List<VideoCacheItem> get allTasks => _tasks.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<VideoCacheItem> get completedTasks => _tasks.values
      .where((t) => t.status == VideoCacheStatus.completed)
      .toList()
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  List<VideoCacheItem> get downloadingTasks => _tasks.values
      .where((t) => t.status != VideoCacheStatus.completed)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get totalCompletedCount =>
      _tasks.values.where((t) => t.status == VideoCacheStatus.completed).length;

  int get activeDownloadingCount =>
      _tasks.values.where((t) => t.status == VideoCacheStatus.downloading).length;

  /// Initialize video cache storage & recover tasks.
  /// 目录创建失败时向上抛出（下载功能不可用，由启动层记录）；索引损坏则按空列表自愈。
  Future<void> init() async {
    if (_initialized) return;
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/video_cache');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheDir = dir;

    try {
      // Load index（在后台 isolate 解析并校验，避免阻塞 UI 线程）
      final indexFile = File('${dir.path}/$_indexFileName');
      if (indexFile.existsSync()) {
        final content = await indexFile.readAsString();
        if (content.isNotEmpty) {
          final items = await compute(_parseCacheIndex, content);
          for (final item in items) {
            _tasks[item.taskId] = item;
          }
        }
      }
    } catch (_) {
      // 索引损坏可自愈：按空任务列表继续，下次保存会重建索引
      _tasks.clear();
    }

    _initialized = true;
    notifyListeners();
  }

  /// Check if a video CID is completely cached locally
  bool isCached(String bvid, int cid) {
    final taskId = '${bvid}_$cid';
    final task = _tasks[taskId];
    if (task == null || task.status != VideoCacheStatus.completed) return false;
    if (task.localVideoPath.isEmpty || !File(task.localVideoPath).existsSync()) return false;
    if (task.localAudioPath.isNotEmpty && !File(task.localAudioPath).existsSync()) return false;
    return true;
  }

  /// Check if a video CID is in queue or downloading
  bool isDownloadingOrPending(String bvid, int cid) {
    final taskId = '${bvid}_$cid';
    final task = _tasks[taskId];
    if (task == null) return false;
    return task.status == VideoCacheStatus.downloading ||
        task.status == VideoCacheStatus.pending;
  }

  VideoCacheItem? getCacheItem(String bvid, int cid) {
    return _tasks['${bvid}_$cid'];
  }

  String? getLocalVideoPath(String bvid, int cid) {
    final task = _tasks['${bvid}_$cid'];
    if (task != null &&
        task.status == VideoCacheStatus.completed &&
        task.localVideoPath.isNotEmpty &&
        File(task.localVideoPath).existsSync()) {
      return task.localVideoPath;
    }
    return null;
  }

  String? getLocalAudioPath(String bvid, int cid) {
    final task = _tasks['${bvid}_$cid'];
    if (task != null &&
        task.status == VideoCacheStatus.completed &&
        task.localAudioPath.isNotEmpty &&
        File(task.localAudioPath).existsSync()) {
      return task.localAudioPath;
    }
    return null;
  }

  String? getLocalDanmakuPath(int cid) {
    if (_cacheDir == null) return null;
    final path = '${_cacheDir!.path}/danmaku_$cid.xml';
    if (File(path).existsSync()) {
      return path;
    }
    return null;
  }

  /// Add a video caching task
  Future<void> addTask({
    required String bvid,
    required int aid,
    required int cid,
    required String title,
    String cover = '',
    String ownerName = '',
    String ownerFace = '',
    String pageTitle = '',
    int pageIndex = 0,
    int pageCount = 1,
    int duration = 0,
    int quality = 80,
    String qualityDesc = '1080P 高清',
    bool isAudioOnly = false,
  }) async {
    await init();
    if (_cacheDir == null) return;

    final taskId = isAudioOnly ? 'audio_${bvid}_$cid' : '${bvid}_$cid';
    if (_tasks.containsKey(taskId) &&
        _tasks[taskId]!.status == VideoCacheStatus.completed &&
        File(_tasks[taskId]!.localVideoPath).existsSync()) {
      return;
    }

    final isDash = !isAudioOnly && quality >= 80;
    final localVideoPath = isAudioOnly
        ? '${_cacheDir!.path}/audio_${bvid}_$cid.m4a'
        : (isDash
            ? '${_cacheDir!.path}/video_${bvid}_$cid.m4s'
            : '${_cacheDir!.path}/video_${bvid}_$cid.mp4');
    final localAudioPath = isDash
        ? '${_cacheDir!.path}/audio_${bvid}_$cid.m4s'
        : '';
    final localDanmakuPath = '${_cacheDir!.path}/danmaku_$cid.xml';
    final localCoverPath = '${_cacheDir!.path}/cover_$bvid.jpg';

    final task = VideoCacheItem(
      taskId: taskId,
      bvid: bvid,
      aid: aid,
      cid: cid,
      title: title,
      cover: cover,
      ownerName: ownerName,
      ownerFace: ownerFace,
      pageTitle: pageTitle.isNotEmpty ? pageTitle : title,
      pageIndex: pageIndex,
      pageCount: pageCount,
      duration: duration,
      quality: quality,
      qualityDesc: isAudioOnly ? '纯音频 (极省空间)' : qualityDesc,
      localVideoPath: localVideoPath,
      localAudioPath: localAudioPath,
      localDanmakuPath: localDanmakuPath,
      localCoverPath: localCoverPath,
      status: VideoCacheStatus.pending,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      isAudioOnly: isAudioOnly,
    );

    _tasks[taskId] = task;
    await _saveIndex();
    notifyListeners();

    _scheduleNext();
  }

  /// Add multiple episodes at once
  Future<void> addBatchTasks(List<VideoCacheItem> items) async {
    await init();
    for (final item in items) {
      if (!_tasks.containsKey(item.taskId) ||
          _tasks[item.taskId]!.status != VideoCacheStatus.completed) {
        _tasks[item.taskId] = item;
      }
    }
    await _saveIndex();
    notifyListeners();
    _scheduleNext();
  }

  /// Pause a task
  void pauseTask(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.status == VideoCacheStatus.completed) return;

    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]?.cancel('User paused download');
      _cancelTokens.remove(taskId);
    }

    _tasks[taskId] = task.copyWith(
      status: VideoCacheStatus.paused,
      downloadSpeed: 0,
    );
    _saveIndex();
    notifyListeners();

    _scheduleNext();
  }

  /// Resume a task
  void resumeTask(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.status == VideoCacheStatus.completed) return;

    _tasks[taskId] = task.copyWith(
      status: VideoCacheStatus.pending,
      downloadSpeed: 0,
      errorMsg: null,
    );
    _saveIndex();
    notifyListeners();

    _scheduleNext();
  }

  /// Retry a failed task
  void retryTask(String taskId) {
    resumeTask(taskId);
  }

  /// Pause all active downloading and pending tasks
  void pauseAll() {
    for (final taskId in _cancelTokens.keys.toList()) {
      _cancelTokens[taskId]?.cancel('User paused all');
    }
    _cancelTokens.clear();

    for (final entry in _tasks.entries) {
      if (entry.value.status == VideoCacheStatus.downloading ||
          entry.value.status == VideoCacheStatus.pending) {
        _tasks[entry.key] = entry.value.copyWith(
          status: VideoCacheStatus.paused,
          downloadSpeed: 0,
        );
      }
    }
    _saveIndex();
    notifyListeners();
  }

  /// Resume all paused tasks
  void resumeAll() {
    for (final entry in _tasks.entries) {
      if (entry.value.status == VideoCacheStatus.paused ||
          entry.value.status == VideoCacheStatus.failed) {
        _tasks[entry.key] = entry.value.copyWith(
          status: VideoCacheStatus.pending,
          downloadSpeed: 0,
          errorMsg: null,
        );
      }
    }
    _saveIndex();
    notifyListeners();
    _scheduleNext();
  }

  /// Delete a task and its associated files
  Future<void> deleteTask(String taskId, {bool deleteFiles = true}) async {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]?.cancel('User deleted task');
      _cancelTokens.remove(taskId);
    }

    final task = _tasks.remove(taskId);
    if (task != null && deleteFiles) {
      try {
        if (task.localVideoPath.isNotEmpty) {
          final file = File(task.localVideoPath);
          if (file.existsSync()) file.deleteSync();
        }
        final tmpFile = File('${task.localVideoPath}.tmp');
        if (tmpFile.existsSync()) tmpFile.deleteSync();

        if (task.localAudioPath.isNotEmpty) {
          final audioFile = File(task.localAudioPath);
          if (audioFile.existsSync()) audioFile.deleteSync();
        }
        final tmpAudioFile = File('${task.localAudioPath}.tmp');
        if (tmpAudioFile.existsSync()) tmpAudioFile.deleteSync();

        if (task.localDanmakuPath.isNotEmpty) {
          final danmakuFile = File(task.localDanmakuPath);
          if (danmakuFile.existsSync()) danmakuFile.deleteSync();
        }
      } catch (_) {}
    }

    await _saveIndex();
    notifyListeners();
    _scheduleNext();
  }

  /// Clear all completed cache files
  Future<void> clearAllCompleted() async {
    final completedIds = _tasks.values
        .where((t) => t.status == VideoCacheStatus.completed)
        .map((t) => t.taskId)
        .toList();

    for (final id in completedIds) {
      await deleteTask(id, deleteFiles: true);
    }
  }

  /// Schedule next tasks in queue
  void _scheduleNext() {
    if (_cacheDir == null) return;

    final activeCount = _tasks.values
        .where((t) => t.status == VideoCacheStatus.downloading)
        .length;

    if (activeCount >= _maxConcurrent) return;

    final pendingTasks = _tasks.values
        .where((t) => t.status == VideoCacheStatus.pending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final slotsAvailable = _maxConcurrent - activeCount;
    for (int i = 0; i < slotsAvailable && i < pendingTasks.length; i++) {
      final task = pendingTasks[i];
      _startDownload(task.taskId);
    }
  }

  /// Download execution worker
  Future<void> _startDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status == VideoCacheStatus.downloading) return;

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    _tasks[taskId] = task.copyWith(
      status: VideoCacheStatus.downloading,
      downloadSpeed: 0,
      errorMsg: null,
    );
    notifyListeners();

    try {
      // 1. Download Danmaku if not already cached
      _downloadDanmakuQuietly(task.cid, task.localDanmakuPath);

      // 2. Fetch fresh Play URL (Audio stream for audio-only, progressive/DASH for video)
      String videoUrl = task.videoUrl;
      String audioUrl = task.audioUrl;
      int currentQuality = task.quality;
      String qualityDesc = task.qualityDesc;

      if (task.isAudioOnly) {
        final aUrl = await VideoApiService().getVideoAudioUrl(
          bvid: task.bvid,
          cid: task.cid,
        );
        if (aUrl != null && aUrl.isNotEmpty) {
          videoUrl = aUrl;
          qualityDesc = '纯音频 (极省空间)';
        } else {
          throw Exception('无法获取音频流地址');
        }
      } else {
        // 与在线播放同一套画质策略：登录用户 >= 1080P 走 DASH，
        // 否则渐进式单流（实测渐进式上限 720P，访客 DASH 只有 480P）
        final result = await VideoApiService().fetchPlayStream(
          bvid: task.bvid,
          cid: task.cid,
          qn: task.quality,
        );
        final playUrlInfo = result.ok ? result.info : null;

        if (playUrlInfo != null) {
          currentQuality = playUrlInfo.grantedQuality > 0
              ? playUrlInfo.grantedQuality
              : playUrlInfo.currentQuality;
          final separateAudio = playUrlInfo.separateAudioUrl;
          if (playUrlInfo.primaryVideoUrl != null) {
            videoUrl = playUrlInfo.primaryVideoUrl!;
            if (separateAudio != null) {
              audioUrl = separateAudio;
            }
          }

          final sf = playUrlInfo.supportFormats.firstWhere(
            (f) => f.quality == currentQuality,
            orElse: () => SupportFormat(
              quality: currentQuality,
              format: '',
              newDescription: '${currentQuality}P',
              displayDesc: '${currentQuality}P',
            ),
          );
          final baseDesc = sf.newDescription.isNotEmpty
              ? sf.newDescription
              : (sf.displayDesc.isNotEmpty ? sf.displayDesc : '${currentQuality}P');
          if (currentQuality < task.quality) {
            qualityDesc = '$baseDesc (权限自动适配)';
          } else {
            qualityDesc = baseDesc;
          }
        }
      }

      if (videoUrl.isEmpty) {
        throw Exception(task.isAudioOnly ? '无法获取音频下载地址' : '无法获取视频播放地址');
      }

      _tasks[taskId] = _tasks[taskId]!.copyWith(
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        quality: currentQuality,
        qualityDesc: qualityDesc,
      );

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Referer': 'https://www.bilibili.com',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      int totalDownloaded = 0;

      // 3. Download Video Stream
      final videoBytes = await _downloadStreamToFile(
        url: videoUrl,
        targetPath: task.localVideoPath,
        cancelToken: cancelToken,
        taskId: taskId,
        initialDownloaded: 0,
        dio: dio,
      );
      totalDownloaded += videoBytes;

      // 4. Download Audio Stream if separate DASH audio exists
      if (audioUrl.isNotEmpty && task.localAudioPath.isNotEmpty) {
        final audioBytes = await _downloadStreamToFile(
          url: audioUrl,
          targetPath: task.localAudioPath,
          cancelToken: cancelToken,
          taskId: taskId,
          initialDownloaded: totalDownloaded,
          dio: dio,
        );
        totalDownloaded += audioBytes;
      }

      _cancelTokens.remove(taskId);
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: VideoCacheStatus.completed,
        downloadedBytes: totalDownloaded,
        totalBytes: totalDownloaded,
        quality: currentQuality,
        qualityDesc: qualityDesc,
        downloadSpeed: 0,
        completedAt: DateTime.now().millisecondsSinceEpoch,
        errorMsg: null,
      );

      await _saveIndex();
      notifyListeners();
    } catch (e) {
      if (cancelToken.isCancelled) {
        // Task paused or cancelled by user, already handled
        return;
      }
      _cancelTokens.remove(taskId);
      if (_tasks.containsKey(taskId)) {
        _tasks[taskId] = _tasks[taskId]!.copyWith(
          status: VideoCacheStatus.failed,
          downloadSpeed: 0,
          errorMsg: e.toString().contains('403')
              ? '获取视频流权限受限'
              : '下载失败，请检查网络后重试',
        );
        await _saveIndex();
        notifyListeners();
      }
    } finally {
      _scheduleNext();
    }
  }

  Future<int> _downloadStreamToFile({
    required String url,
    required String targetPath,
    required CancelToken cancelToken,
    required String taskId,
    required int initialDownloaded,
    required Dio dio,
  }) async {
    final tmpFile = File('$targetPath.tmp');
    int downloaded = 0;
    if (tmpFile.existsSync()) {
      downloaded = tmpFile.lengthSync();
    }

    final openMode = downloaded > 0 ? FileMode.append : FileMode.write;
    final fileSink = tmpFile.openWrite(mode: openMode);

    try {
      final response = await dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: downloaded > 0 ? {'Range': 'bytes=$downloaded-'} : null,
        ),
      );

      final isPartial = response.statusCode == 206;
      if (!isPartial && downloaded > 0) {
        // Range not supported, restart from beginning
        await fileSink.close();
        tmpFile.writeAsBytesSync([], mode: FileMode.write);
        downloaded = 0;
      }

      final contentLength = response.headers.value(Headers.contentLengthHeader);
      int streamTotal = 0;
      if (contentLength != null) {
        final serverBytes = int.tryParse(contentLength) ?? 0;
        streamTotal = isPartial ? (downloaded + serverBytes) : serverBytes;
      }

      final currentTotal = initialDownloaded + (streamTotal > 0 ? streamTotal : downloaded);
      if (_tasks.containsKey(taskId)) {
        _tasks[taskId] = _tasks[taskId]!.copyWith(
          totalBytes: currentTotal > _tasks[taskId]!.totalBytes
              ? currentTotal
              : _tasks[taskId]!.totalBytes,
          downloadedBytes: initialDownloaded + downloaded,
        );
      }

      _lastReportedTime[taskId] = DateTime.now().millisecondsSinceEpoch;
      _lastReportedBytes[taskId] = initialDownloaded + downloaded;

      // Pipe stream
      await response.data!.stream.listen(
        (chunk) {
          fileSink.add(chunk);
          downloaded += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          final lastTime = _lastReportedTime[taskId] ?? now;
          final elapsed = now - lastTime;

          if (elapsed >= 400) {
            final totalCurrent = initialDownloaded + downloaded;
            final lastBytes = _lastReportedBytes[taskId] ?? totalCurrent;
            final bytesDelta = totalCurrent - lastBytes;
            final speed = (bytesDelta / (elapsed / 1000.0)).round();

            _lastReportedTime[taskId] = now;
            _lastReportedBytes[taskId] = totalCurrent;

            if (_tasks.containsKey(taskId)) {
              _tasks[taskId] = _tasks[taskId]!.copyWith(
                downloadedBytes: totalCurrent,
                totalBytes: currentTotal > totalCurrent ? currentTotal : totalCurrent,
                downloadSpeed: speed > 0 ? speed : 0,
              );
              notifyListeners();
            }
          }
        },
        cancelOnError: true,
      ).asFuture();

      await fileSink.flush();
    } finally {
      await fileSink.close();
    }

    final finalFile = File(targetPath);
    if (finalFile.existsSync()) finalFile.deleteSync();
    tmpFile.renameSync(targetPath);

    return downloaded;
  }

  /// Download and parse Danmaku XML to local cache directory
  Future<void> _downloadDanmakuQuietly(int cid, String targetPath) async {
    if (targetPath.isEmpty) return;
    final file = File(targetPath);
    if (file.existsSync() && file.lengthSync() > 0) return;

    try {
      final bytes = await BiliHttpClient().getBytes(
        ApiEndpoints.danmakuList,
        queryParameters: {'oid': cid},
      );
      if (bytes.isNotEmpty) {
        await file.writeAsBytes(bytes, flush: true);
      }
    } catch (_) {}
  }

  /// Calculate total cached video files size on disk
  int getTotalCacheSizeBytes() {
    int total = 0;
    for (final task in _tasks.values) {
      if (task.status == VideoCacheStatus.completed) {
        if (task.localVideoPath.isNotEmpty) {
          final f = File(task.localVideoPath);
          if (f.existsSync()) {
            total += f.lengthSync();
          }
        }
        if (task.localAudioPath.isNotEmpty) {
          final f = File(task.localAudioPath);
          if (f.existsSync()) {
            total += f.lengthSync();
          }
        }
      }
    }
    return total;
  }

  /// Get formatted cache size string (e.g. 1.25 GB, 345.8 MB)
  String getFormattedTotalCacheSize() {
    final bytes = getTotalCacheSizeBytes();
    return formatBytes(bytes);
  }

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

  /// Persist cache index to disk
  Future<void> _saveIndex() async {
    if (_cacheDir == null) return;
    try {
      final indexFile = File('${_cacheDir!.path}/$_indexFileName');
      final list = _tasks.values.map((t) => t.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(list));
    } catch (_) {}
  }
}
