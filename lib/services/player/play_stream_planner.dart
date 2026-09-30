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
}) async {
  if (url.isEmpty || kIsWeb) return url;
  if (url.startsWith('file:')) return url;
  try {
    return await BiliStreamProxy().getProxyUrl(
      url,
      isAudio: isAudio,
      cacheKey: cacheKey,
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

/// 两次纠偏之间的最小间隔，避免频繁 seek 造成音频断续。
const Duration kDashAudioResyncInterval = Duration(seconds: 2);

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
