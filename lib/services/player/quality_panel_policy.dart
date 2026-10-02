import '../../models/play_url_model.dart';

/// 画质面板条目。
typedef QualityPanelItem = ({int quality, String description, bool locked});

/// 画质面板可选条目：**只列视频真实提供的画质**。
///
/// 实测：DASH 响应的 `support_formats`/`accept_quality` 是视频真实提供的档位
/// （例如大量 4K30 视频是 [120, 112, 80, 64, 32, 16]，**没有** 116）。
/// 此前这里无条件补一档"1080P 60帧"，大会员点了必被降级并弹出误导性的
/// "需大会员"提示——视频根本没有该画质，与账号权限无关。
///
/// 优先级：support_formats → accept_quality → DASH 实际视频轨；
/// 全部缺省时才用当前画质 + 常规低档兜底，且**不虚构 60帧/4K 等高阶档位**。
List<QualityPanelItem> buildQualityPanelItems(
  PlayUrlInfo info, {
  required bool isLoggedIn,
  required String Function(int quality) labelOf,
}) {
  final List<QualityPanelItem> list = [];
  final seen = <int>{};
  // 1080P 及以上需要登录（未登录时服务端最高只给 720P 渐进 / 480P DASH）
  bool isLocked(int quality) => quality >= 80 && !isLoggedIn;

  void add(int quality, String description) {
    if (quality <= 0 || seen.contains(quality)) return;
    seen.add(quality);
    list.add((quality: quality, description: description, locked: isLocked(quality)));
  }

  // 1. support_formats：每个条目自带 id 与文案
  for (final sf in info.supportFormats) {
    if (sf.quality > 0) {
      final desc = sf.newDescription.isNotEmpty
          ? sf.newDescription
          : (sf.displayDesc.isNotEmpty ? sf.displayDesc : labelOf(sf.quality));
      add(sf.quality, desc);
    }
  }

  // 2. accept_quality / accept_description（按下标对齐，缺文案回退通用名）
  for (int i = 0; i < info.acceptQuality.length; i++) {
    final q = info.acceptQuality[i];
    final desc = i < info.acceptDescription.length && info.acceptDescription[i].isNotEmpty
        ? info.acceptDescription[i]
        : labelOf(q);
    add(q, desc);
  }

  // 3. 服务端未声明任何画质时，退回 DASH 实际可播的视频轨画质
  if (list.isEmpty) {
    final trackIds = info.videoTracks.map((t) => t.id).where((q) => q > 0).toList()
      ..sort((a, b) => b.compareTo(a));
    for (final q in trackIds) {
      add(q, labelOf(q));
    }
  }

  // 4. 最终兜底（渐进式且无任何声明）：当前画质 + 其下的常规档，不虚构高阶档位
  if (list.isEmpty) {
    final current = info.currentQuality;
    if (current > 0) add(current, labelOf(current));
    for (final q in const [80, 64, 32, 16]) {
      if (q < current) add(q, labelOf(q));
    }
  }

  list.sort((a, b) => b.quality.compareTo(a.quality));
  return list;
}

/// 视频声明提供的画质集合（support_formats ∪ accept_quality）。
Set<int> declaredQualities(PlayUrlInfo info) {
  return {
    for (final sf in info.supportFormats)
      if (sf.quality > 0) sf.quality,
    ...info.acceptQuality.where((q) => q > 0),
  };
}

/// 画质切换被降级（granted < requested）时的提示文案；null 表示无需提示。
///
/// 降级有两种性质完全不同的原因，文案必须区分：
/// - 视频本身没有该画质 → 与账号无关，不能说"需大会员"；
/// - 视频有该画质但账号权限不足 → 未登录提示登录，1080P+ 高阶档提示大会员。
String? qualityDowngradeMessage({
  required int requested,
  required int granted,
  required bool isLogin,
  required bool videoOffersQuality,
  required String Function(int quality) labelOf,
}) {
  if (granted <= 0 || granted >= requested) return null;
  final target = labelOf(requested);
  final fallback = labelOf(granted);
  if (!videoOffersQuality) {
    return '该视频未提供$target画质，已切换至$fallback';
  }
  if (!isLogin) {
    return '$target需登录后观看，已切换至$fallback';
  }
  if (requested >= 112) {
    return '$target需大会员，已切换至$fallback';
  }
  return '已为当前流适配最高可用画质$fallback';
}
