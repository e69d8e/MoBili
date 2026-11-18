import 'package:flutter/foundation.dart';

import 'bili_stream_proxy.dart';

/// 播放流形态：渐进式单流（音视频合一）或 DASH 双流（视频轨 + 独立音轨）。
enum PlayStreamKind { progressive, dash }

/// 一次播放流请求的计划。
class PlayStreamPlan {
  final PlayStreamKind kind;

  /// B 站 `fnval` 参数：0 = 渐进式 flv/mp4，4048 = DASH 全开（HDR/4K/杜比/8K/AV1）。
  final int fnval;

  /// 请求画质 `qn`（80 = 1080P）。
  final int qn;

  const PlayStreamPlan({
    required this.kind,
    required this.fnval,
    required this.qn,
  });

  @override
  String toString() => 'PlayStreamPlan(${kind.name}, fnval=$fnval, qn=$qn)';
}

/// 渐进式（音视频合一）的 fnval。
const int kProgressiveFnval = 0;

/// DASH 全开：16 DASH + 64 HDR + 128 4K + 256 杜比音频 + 512 杜比视界 + 1024 8K + 2048 AV1。
const int kDashFnvalAll = 4048;

/// 需要 DASH 才能获取的最低画质（1080P）。低于该画质沿用渐进式单流。
const int kMinDashQuality = 80;

/// 首轮请求计划。
///
/// 实测（2026-09，未登录 + buvid3）：`fnval=0` 最高只能拿到 720P(64)，
/// 且 `accept_quality=[64,16]`；`fnval=16/4048` 的 `accept_quality` 虽然列出 112/80，
/// 但 `dash.video` 实际只返回 16/32（360P/480P）。因此：
///   - 访客：恒用渐进式，避免"看起来是 1080P、实际掉到 480P"的倒退；
///   - 登录用户目标画质 >= 1080P：走 DASH 才可能被授权 1080P 及以上。
PlayStreamPlan planFirstRequest({required bool isLoggedIn, required int qn}) {
  final target = qn <= 0 ? kMinDashQuality : qn;
  if (isLoggedIn && target >= kMinDashQuality) {
    return PlayStreamPlan(
      kind: PlayStreamKind.dash,
      fnval: kDashFnvalAll,
      qn: target,
    );
  }
  return PlayStreamPlan(
    kind: PlayStreamKind.progressive,
    fnval: kProgressiveFnval,
    qn: target,
  );
}

/// DASH 授权不足（视频本身最高 720P、或登录态失效被降级）时的二次请求计划。
///
/// 返回 null 表示无需二次请求：非 DASH 首轮，或 DASH 已授权 >= 1080P。
/// 二次请求用渐进式单流，保证这些场景下的音视频合一与播放稳定性。
PlayStreamPlan? planProgressiveFallback({
  required PlayStreamKind currentKind,
  required int grantedQuality,
  required int requestedQn,
}) {
  if (currentKind != PlayStreamKind.dash) return null;
  if (grantedQuality >= kMinDashQuality) return null;
  return PlayStreamPlan(
    kind: PlayStreamKind.progressive,
    fnval: kProgressiveFnval,
    qn: requestedQn <= 0 ? kMinDashQuality : requestedQn,
  );
}

/// DASH 视频/音轨 CDN 地址以 `.m4s` 结尾（无标准扩展名语义）。
bool isDashStreamUrl(String url) {
  if (url.isEmpty) return false;
  final path = Uri.tryParse(url)?.path ?? url;
  return path.toLowerCase().endsWith('.m4s');
}

/// 把远程流地址解析成播放器可直接使用的地址。
///
/// 所有远程轨道统一经本地代理：
/// - DASH 轨道（.m4s）：音轨 CDN 返回 `application/octet-stream`，且 `.m4s`
///   扩展名会让 iOS AVPlayer 拒绝加载；代理解析后是 `.mp4` + 正确的
///   `video/mp4` / `audio/mp4`，并附带 Referer/Cookie 与 Range 支持；
/// - 渐进式 mp4：直连本可用，但走代理可获得「边播边缓存」，回拖/重播秒开。
///
/// [cacheKey] 为稳定缓存键（bvid+cid+轨+画质）。CDN 签名地址每次请求都会
/// 变化，不提供稳定键时缓存仅在会话内有效。
Future<String> resolvePlayableUrl(
  String url, {
  required bool isAudio,
  String? cacheKey,
  List<String> backupUrls = const [],
}) async {
  if (url.isEmpty || kIsWeb) return url;
  if (url.startsWith('file:')) return url;
  try {
    return await BiliStreamProxy().getProxyUrl(
      url,
      isAudio: isAudio,
      cacheKey: cacheKey,
      backupUrls: backupUrls,
    );
  } catch (_) {
    return url;
  }
}

/// 把本地 DASH 轨道文件映射为本地 HTTP 地址（MIME/扩展名正确、支持 Range）。
/// 失败时回退 `file://` URI，由调用方决定是否用 `VideoPlayerController.file`。
Future<String> resolveLocalDashUrl(
  String filePath, {
  required bool isAudio,
}) async {
  if (filePath.isEmpty || kIsWeb) return filePath;
  try {
    final proxyUrl = await BiliStreamProxy()
        .getLocalFileProxyUrl(filePath, isAudio: isAudio);
    if (proxyUrl.startsWith('http://127.0.0.1:')) return proxyUrl;
  } catch (_) {}
  return Uri.file(filePath).toString();
}

/// 伴音轨与视频轨的最大允许漂移。
const Duration kDashAudioDriftThreshold = Duration(milliseconds: 500);

/// 缓冲恢复 / 切前台重新起播时，立即对齐伴音轨的最小偏差阈值。
const Duration kDashAudioResumeAlignThreshold = Duration(milliseconds: 120);

/// 两次纠偏之间的最小间隔，避免频繁 seek 造成音频断续。
const Duration kDashAudioResyncInterval = Duration(seconds: 2);

/// 视频持续处于缓冲态且进度不推进的卡死判定阈值。
const Duration kVideoBufferingStallTimeout = Duration(seconds: 12);

/// 视频显示播放中但进度不推进的静默卡帧判定阈值。
const Duration kVideoSilentFreezeTimeout = Duration(seconds: 3);

/// DASH 双流下伴音继续往前走、视频却停滞时的快速静默卡帧判定阈值。
const Duration kVideoSilentFreezeWithAudioTimeout = Duration(milliseconds: 1500);

/// 非用户主动暂停情况下，视频意外停住的恢复判定阈值。
const Duration kVideoUnexpectedStopTimeout = Duration(milliseconds: 2500);

/// 是否需要用视频轨位置纠正伴音轨位置。
///
/// 以视频轨为时钟：音轨轻微滞后/领先不处理，超过阈值才 seek 一次。
/// 拖动进度中不纠偏（避免与拖动 seek 抢跑）。
bool shouldCorrectDrift({
  required Duration videoPosition,
  required Duration audioPosition,
  required bool isSeeking,
  DateTime? lastSyncAt,
  DateTime? now,
}) {
  if (isSeeking) return false;
  final drift = (videoPosition - audioPosition).abs();
  if (drift < kDashAudioDriftThreshold) return false;
  final ts = now ?? DateTime.now();
  if (lastSyncAt != null && ts.difference(lastSyncAt) < kDashAudioResyncInterval) {
    return false;
  }
  return true;
}

/// DASH 双流音视频同步协同决策结果。
class DualStreamSyncDecision {
  final bool pauseAudio;
  final bool pauseVideo;
  final bool resumeVideo;
  final bool resumeAudio;
  final bool nextSyncPausedAudio;
  final bool nextSyncPausedVideo;

  const DualStreamSyncDecision({
    this.pauseAudio = false,
    this.pauseVideo = false,
    this.resumeVideo = false,
    this.resumeAudio = false,
    this.nextSyncPausedAudio = false,
    this.nextSyncPausedVideo = false,
  });

  bool get hasAction =>
      pauseAudio || pauseVideo || resumeVideo || resumeAudio;
}

/// 计算 DASH 双流的音画协同动作：
/// - 视频缓冲 / 异常 / 意外停播时立即暂停伴音，杜绝"画面卡住、声音继续"；
/// - 伴音缓冲时暂停视频等待伴音，双方都就绪后对齐位置再一起恢复。
DualStreamSyncDecision evaluateDualStreamSync({
  required bool isExplicitlyPaused,
  required bool isRecovering,
  required bool videoInitialized,
  required bool videoPlaying,
  required bool videoBuffering,
  required bool videoCompleted,
  required bool videoHasError,
  required bool audioInitialized,
  required bool audioPlaying,
  required bool audioBuffering,
  required bool audioCompleted,
  required bool audioHasError,
  required bool isSyncPausedAudio,
  required bool isSyncPausedVideo,
}) {
  if (!videoInitialized ||
      !audioInitialized ||
      isExplicitlyPaused ||
      isRecovering) {
    return DualStreamSyncDecision(
      nextSyncPausedAudio: isSyncPausedAudio,
      nextSyncPausedVideo: isSyncPausedVideo,
    );
  }

  if (videoHasError || videoCompleted) {
    return DualStreamSyncDecision(
      pauseAudio: audioPlaying,
      nextSyncPausedAudio: audioPlaying || isSyncPausedAudio,
      nextSyncPausedVideo: false,
    );
  }

  if (audioHasError) {
    return DualStreamSyncDecision(
      pauseVideo: videoPlaying,
      nextSyncPausedAudio: false,
      nextSyncPausedVideo: videoPlaying || isSyncPausedVideo,
    );
  }

  if (videoBuffering) {
    final shouldResumeVideo =
        isSyncPausedVideo && !audioBuffering && !videoPlaying;
    return DualStreamSyncDecision(
      pauseAudio: audioPlaying,
      resumeVideo: shouldResumeVideo,
      nextSyncPausedAudio: true,
      nextSyncPausedVideo: shouldResumeVideo ? false : isSyncPausedVideo,
    );
  }

  if (audioBuffering && !audioCompleted) {
    return DualStreamSyncDecision(
      pauseVideo: videoPlaying,
      nextSyncPausedAudio: isSyncPausedAudio,
      nextSyncPausedVideo: true,
    );
  }

  if (isSyncPausedVideo) {
    return DualStreamSyncDecision(
      resumeVideo: !videoPlaying,
      resumeAudio: !audioPlaying && !audioCompleted,
      nextSyncPausedAudio: false,
      nextSyncPausedVideo: false,
    );
  }

  if (!videoPlaying) {
    return DualStreamSyncDecision(
      pauseAudio: audioPlaying,
      nextSyncPausedAudio: audioPlaying || isSyncPausedAudio,
      nextSyncPausedVideo: false,
    );
  }

  if ((isSyncPausedAudio || !audioPlaying) && !audioCompleted) {
    return const DualStreamSyncDecision(
      resumeAudio: true,
      nextSyncPausedAudio: false,
      nextSyncPausedVideo: false,
    );
  }

  return const DualStreamSyncDecision(
    nextSyncPausedAudio: false,
    nextSyncPausedVideo: false,
  );
}

/// 视频轨播放停滞类型。
enum VideoStallKind { none, bufferTimeout, silentFreeze, unexpectedStop }

/// 评估当前视频轨是否发生画面卡住 / 缓冲挂死 / 意外停播。
VideoStallKind evaluateVideoStall({
  required bool isInitialized,
  required bool isPlaying,
  required bool isBuffering,
  required bool isCompleted,
  required bool hasError,
  required bool isExplicitlyPaused,
  required bool isSyncPausedVideo,
  required bool isSeeking,
  required bool isRecovering,
  required Duration videoPosition,
  required Duration videoDuration,
  required Duration stalledFor,
  bool audioPlaying = false,
  Duration? audioPosition,
}) {
  if (!isInitialized ||
      isExplicitlyPaused ||
      isSyncPausedVideo ||
      isSeeking ||
      isRecovering ||
      isCompleted ||
      hasError) {
    return VideoStallKind.none;
  }

  if (videoDuration > Duration.zero &&
      videoPosition >= videoDuration - const Duration(milliseconds: 500)) {
    return VideoStallKind.none;
  }

  if (isBuffering) {
    return stalledFor >= kVideoBufferingStallTimeout
        ? VideoStallKind.bufferTimeout
        : VideoStallKind.none;
  }

  if (isPlaying) {
    if (audioPlaying &&
        audioPosition != null &&
        (audioPosition - videoPosition) >= const Duration(milliseconds: 800) &&
        stalledFor >= kVideoSilentFreezeWithAudioTimeout) {
      return VideoStallKind.silentFreeze;
    }
    if (stalledFor >= kVideoSilentFreezeTimeout) {
      return VideoStallKind.silentFreeze;
    }
    return VideoStallKind.none;
  }

  return stalledFor >= kVideoUnexpectedStopTimeout
      ? VideoStallKind.unexpectedStop
      : VideoStallKind.none;
}
