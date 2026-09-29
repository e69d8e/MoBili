class PlayUrlDurl {
  final int order;
  final int length;
  final int size;
  final String url;
  final List<String> backupUrls;

  PlayUrlDurl({
    required this.order,
    required this.length,
    required this.size,
    required this.url,
    required this.backupUrls,
  });

  factory PlayUrlDurl.fromJson(Map<String, dynamic> json) {
    final List<String> backups = [];
    final rawBackup = json['backup_url'] ?? json['backupUrl'];
    if (rawBackup is List) {
      for (final u in rawBackup) {
        backups.add(u.toString());
      }
    }
    return PlayUrlDurl(
      order: json['order'] is int ? json['order'] : 1,
      length: json['length'] is int ? json['length'] : 0,
      size: json['size'] is int ? json['size'] : 0,
      url: json['url']?.toString() ?? '',
      backupUrls: backups,
    );
  }
  String get effectiveUrl => PlayUrlInfo.getEffectiveUrl(url, backupUrls);
}

class SupportFormat {
  final int quality;
  final String format;
  final String newDescription;
  final String displayDesc;

  SupportFormat({
    required this.quality,
    required this.format,
    required this.newDescription,
    required this.displayDesc,
  });

  factory SupportFormat.fromJson(Map<String, dynamic> json) {
    return SupportFormat(
      quality: json['quality'] is int ? json['quality'] : 0,
      format: json['format']?.toString() ?? '',
      newDescription: json['new_description']?.toString() ?? json['description']?.toString() ?? '',
      displayDesc: json['display_desc']?.toString() ?? '',
    );
  }
}

class DashSegmentBase {
  final String initialization;
  final String indexRange;

  DashSegmentBase({
    required this.initialization,
    required this.indexRange,
  });

  factory DashSegmentBase.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DashSegmentBase(initialization: '', indexRange: '');
    final init = json['Initialization']?.toString() ?? json['initialization']?.toString() ?? '';
    final index = json['indexRange']?.toString() ?? json['index_range']?.toString() ?? '';
    return DashSegmentBase(initialization: init, indexRange: index);
  }
}

class DashVideoItem {
  final int id;
  final String baseUrl;
  final String mimeType;
  final String codecs;
  final int width;
  final int height;
  final int bandwidth;
  final List<String> backupUrls;
  final DashSegmentBase? segmentBase;

  DashVideoItem({
    required this.id,
    required this.baseUrl,
    required this.mimeType,
    required this.codecs,
    required this.width,
    required this.height,
    required this.bandwidth,
    required this.backupUrls,
    this.segmentBase,
  });

  String get effectiveUrl => PlayUrlInfo.getEffectiveUrl(baseUrl, backupUrls);

  factory DashVideoItem.fromJson(Map<String, dynamic> json) {
    final List<String> backups = [];
    final rawBackup = json['backupUrl'] ?? json['backup_url'];
    if (rawBackup is List) {
      for (final u in rawBackup) {
        backups.add(u.toString());
      }
    }

    final rawSeg = json['SegmentBase'] ?? json['segment_base'];
    final seg = rawSeg is Map<String, dynamic> ? DashSegmentBase.fromJson(rawSeg) : null;

    return DashVideoItem(
      id: json['id'] is int ? json['id'] : 0,
      baseUrl: json['baseUrl']?.toString() ?? json['base_url']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? json['mime_type']?.toString() ?? 'video/mp4',
      codecs: json['codecs']?.toString() ?? '',
      width: json['width'] is int ? json['width'] : 0,
      height: json['height'] is int ? json['height'] : 0,
      bandwidth: json['bandwidth'] is int ? json['bandwidth'] : 0,
      backupUrls: backups,
      segmentBase: seg,
    );
  }
}

class DashAudioItem {
  final int id;
  final String baseUrl;
  final String mimeType;
  final String codecs;
  final int bandwidth;
  final List<String> backupUrls;
  final DashSegmentBase? segmentBase;

  DashAudioItem({
    required this.id,
    required this.baseUrl,
    required this.mimeType,
    required this.codecs,
    required this.bandwidth,
    required this.backupUrls,
    this.segmentBase,
  });

  String get effectiveUrl => PlayUrlInfo.getEffectiveUrl(baseUrl, backupUrls);

  factory DashAudioItem.fromJson(Map<String, dynamic> json) {
    final List<String> backups = [];
    final rawBackup = json['backupUrl'] ?? json['backup_url'];
    if (rawBackup is List) {
      for (final u in rawBackup) {
        backups.add(u.toString());
      }
    }

    final rawSeg = json['SegmentBase'] ?? json['segment_base'];
    final seg = rawSeg is Map<String, dynamic> ? DashSegmentBase.fromJson(rawSeg) : null;

    return DashAudioItem(
      id: json['id'] is int ? json['id'] : 0,
      baseUrl: json['baseUrl']?.toString() ?? json['base_url']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? json['mime_type']?.toString() ?? 'audio/mp4',
      codecs: json['codecs']?.toString() ?? '',
      bandwidth: json['bandwidth'] is int ? json['bandwidth'] : 0,
      backupUrls: backups,
      segmentBase: seg,
    );
  }
}

class PlayUrlInfo {
  final int currentQuality;
  final String format;
  final int timelength;
  final List<int> acceptQuality;
  final List<String> acceptDescription;
  final List<PlayUrlDurl> durls;
  final List<SupportFormat> supportFormats;
  final List<DashVideoItem> videoTracks;
  final List<DashAudioItem> audioTracks;
  final int videoCodecid;

  /// 本次请求的 `qn`（0 = 未知）。
  ///
  /// 实测：DASH 响应里的 `dash.video` **不受 qn 过滤**，返回的是该账号权限内的全部画质
  /// （访客请求 qn=16 与 qn=80 都拿到 [16, 32]）。因此判断"实际可用画质"必须以请求的
  /// qn 截断，否则大会员请求 1080P(80) 时会被误判成 1080P60(116)/4K(120) 并真的去播更高码率。
  final int requestedQuality;

  PlayUrlInfo({
    required this.currentQuality,
    required this.format,
    required this.timelength,
    required this.acceptQuality,
    required this.acceptDescription,
    required this.durls,
    required this.supportFormats,
    this.videoTracks = const [],
    this.audioTracks = const [],
    required this.videoCodecid,
    this.requestedQuality = 0,
  });

  /// Check if a URL belongs to Bilibili's P2P MCDN domains which are prone to 404s/connection failures.
  static bool isMcdn(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('mcdn') ||
        lower.contains('szbdyd.com') ||
        lower.contains('mountaintoys.cn') ||
        lower.contains(':8082') ||
        lower.contains(':4483') ||
        lower.contains(':8000');
  }

  /// Resolve effective stream URL, prioritizing high-speed official UPOS CDN over unreliable P2P MCDN nodes.
  static String getEffectiveUrl(String primary, List<String> backups) {
    // 1. If primary is official UPOS CDN and not MCDN, use it directly
    if (primary.isNotEmpty && !isMcdn(primary) && primary.contains('bilivideo.com')) {
      return primary;
    }
    // 2. Look for official upos bilivideo.com backup
    for (final b in backups) {
      if (b.isNotEmpty && !isMcdn(b) && b.contains('bilivideo.com')) {
        return b;
      }
    }
    // 3. Fallback: Any non-MCDN primary or backup
    if (primary.isNotEmpty && !isMcdn(primary)) {
      return primary;
    }
    for (final b in backups) {
      if (b.isNotEmpty && !isMcdn(b)) {
        return b;
      }
    }
    return primary;
  }

  factory PlayUrlInfo.fromJson(
    Map<String, dynamic> json, {
    int requestedQuality = 0,
  }) {
    final List<int> acceptQ = [];
    if (json['accept_quality'] is List) {
      for (final q in json['accept_quality']) {
        if (q is int) acceptQ.add(q);
      }
    }

    final List<String> acceptDesc = [];
    if (json['accept_description'] is List) {
      for (final d in json['accept_description']) {
        acceptDesc.add(d.toString());
      }
    }

    final List<PlayUrlDurl> durls = [];
    if (json['durl'] is List) {
      for (final d in json['durl']) {
        durls.add(PlayUrlDurl.fromJson(d));
      }
    }

    final List<SupportFormat> formats = [];
    if (json['support_formats'] is List) {
      for (final sf in json['support_formats']) {
        formats.add(SupportFormat.fromJson(sf));
      }
    }

    final List<DashVideoItem> videos = [];
    if (json['dash'] is Map && json['dash']['video'] is List) {
      for (final v in json['dash']['video']) {
        videos.add(DashVideoItem.fromJson(v));
      }
    }

    final List<DashAudioItem> audios = [];
    if (json['dash'] is Map) {
      final dashMap = json['dash'] as Map;
      if (dashMap['audio'] is List) {
        for (final a in dashMap['audio']) {
          if (a is Map<String, dynamic>) {
            audios.add(DashAudioItem.fromJson(a));
          } else if (a is Map) {
            audios.add(DashAudioItem.fromJson(Map<String, dynamic>.from(a)));
          }
        }
      }
      if (audios.isEmpty && dashMap['dolby'] is Map && dashMap['dolby']['audio'] is List) {
        for (final a in dashMap['dolby']['audio']) {
          if (a is Map<String, dynamic>) {
            audios.add(DashAudioItem.fromJson(a));
          } else if (a is Map) {
            audios.add(DashAudioItem.fromJson(Map<String, dynamic>.from(a)));
          }
        }
      }
      if (audios.isEmpty && dashMap['flac'] is Map && dashMap['flac']['audio'] is Map) {
        audios.add(DashAudioItem.fromJson(Map<String, dynamic>.from(dashMap['flac']['audio'])));
      }
    }

    return PlayUrlInfo(
      currentQuality: json['quality'] is int ? json['quality'] : 0,
      format: json['format']?.toString() ?? '',
      timelength: json['timelength'] is int ? json['timelength'] : 0,
      acceptQuality: acceptQ,
      acceptDescription: acceptDesc,
      durls: durls,
      supportFormats: formats,
      videoTracks: videos,
      audioTracks: audios,
      videoCodecid: json['video_codecid'] is int ? json['video_codecid'] : 0,
      requestedQuality: requestedQuality,
    );
  }

  bool get isDash => videoTracks.isNotEmpty && audioTracks.isNotEmpty;

  /// 编码兼容性优先级：H.264 (avc) > H.265 (hevc) > AV1 > 其它。
  /// `fnval` 含 2048 时会返回 AV1 轨道，而部分 iOS/Android 机型无法解码，
  /// 因此只在没有更兼容的编码时才回退到它。
  static int codecPriority(String codecs) {
    final c = codecs.toLowerCase();
    if (c.startsWith('avc1') || c.startsWith('avc3')) return 0;
    if (c.startsWith('hev1') || c.startsWith('hvc1')) return 1;
    if (c.startsWith('av01')) return 2;
    return 3;
  }

  /// 同一画质下按编码兼容性选轨，同编码取更高带宽。
  static DashVideoItem? _bestTrack(Iterable<DashVideoItem> tracks) {
    DashVideoItem? best;
    int bestRank = 1 << 30;
    int bestBandwidth = -1;
    for (final track in tracks) {
      if (track.effectiveUrl.isEmpty) continue;
      final rank = codecPriority(track.codecs);
      if (rank < bestRank || (rank == bestRank && track.bandwidth > bestBandwidth)) {
        best = track;
        bestRank = rank;
        bestBandwidth = track.bandwidth;
      }
    }
    return best;
  }

  /// 服务端**实际可用**的画质。
  ///
  /// DASH 下响应体的 `quality` 字段不可信（实测：访客请求 1080P 时返回 64，
  /// 而 `dash.video` 只有 16/32），且 `dash.video` 返回的是权限内全部画质而非请求的
  /// 那一档（访客请求 qn=16 也返回 [16, 32]），所以：
  ///   - 已知请求 qn 时，取"不高于请求 qn 的最高档"——请求 1080P 就是 1080P(80)，
  ///     不会被大会员响应里的 1080P60(116)/4K(120) 顶掉；请求 1080P60 才会得到 116；
  ///   - 请求档位不存在时（视频没有该画质）退到最接近的更高一档。
  int get grantedQuality {
    if (videoTracks.isNotEmpty) {
      var best = 0;
      for (final track in videoTracks) {
        if (requestedQuality > 0 && track.id > requestedQuality) continue;
        if (track.id > best) best = track.id;
      }
      if (best > 0) return best;

      // 请求的画质一档都没有（例如视频最高只有 720P）→ 取最接近的更高一档
      var nearest = 0;
      for (final track in videoTracks) {
        if (track.id > 0 && (nearest == 0 || track.id < nearest)) {
          nearest = track.id;
        }
      }
      if (nearest > 0) return nearest;
    }
    return currentQuality > 0 ? currentQuality : 0;
  }

  /// 视频声明支持的最高画质（`support_formats` / `accept_quality`），未必已授权。
  int get maxSelectableQuality {
    var max = 0;
    for (final sf in supportFormats) {
      if (sf.quality > max) max = sf.quality;
    }
    for (final q in acceptQuality) {
      if (q > max) max = q;
    }
    if (max == 0) max = grantedQuality;
    return max;
  }

  static const List<int> _audioIdPriority = [30280, 30232, 30216];

  /// 最优音轨：30280(192K) > 30232(132K) > 30216(64K)，同级取更高带宽。
  /// 实测服务端返回顺序不按码率排序（30232 可能在 30280 之前），不能直接取第一条。
  DashAudioItem? get bestAudioTrack {
    if (audioTracks.isEmpty) return null;
    DashAudioItem? best;
    int bestRank = 1 << 30;
    int bestBandwidth = -1;
    for (final track in audioTracks) {
      final rank = _audioIdPriority.indexOf(track.id);
      final r = rank < 0 ? _audioIdPriority.length : rank;
      if (r < bestRank || (r == bestRank && track.bandwidth > bestBandwidth)) {
        best = track;
        bestRank = r;
        bestBandwidth = track.bandwidth;
      }
    }
    return best;
  }

  /// DASH 场景下与视频轨配对的独立音轨地址。
  /// null 表示音轨已内嵌在视频流中（渐进式单流、或服务端未返回音轨），
  /// 此时播放器**不得**再创建第二个播放器（否则会重复播放视频流）。
  String? get separateAudioUrl {
    if (durls.isNotEmpty) return null;
    final track = bestAudioTrack;
    if (track == null) return null;
    final url = track.effectiveUrl;
    return url.isEmpty ? null : url;
  }

  String? getVideoUrlForQuality(int targetQuality) {
    if (durls.isNotEmpty) {
      final u = durls.first.effectiveUrl;
      if (u.isNotEmpty) return u;
    }

    // 1. 目标画质内按编码兼容性选轨
    final exact = _bestTrack(videoTracks.where((t) => t.id == targetQuality));
    if (exact != null) return exact.effectiveUrl;

    // 2. 目标画质缺失时，退到不高于目标的最高可用画质
    final lower = videoTracks.where((t) => t.id < targetQuality).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    if (lower.isNotEmpty) {
      final best = _bestTrack(lower.where((t) => t.id == lower.first.id));
      if (best != null) return best.effectiveUrl;
    }

    // 3. 只剩高于目标的画质时，取最接近的一档，避免为低画质请求拉高码率
    final higher = videoTracks.where((t) => t.id > targetQuality).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (higher.isNotEmpty) {
      final best = _bestTrack(higher.where((t) => t.id == higher.first.id));
      if (best != null) return best.effectiveUrl;
    }

    // 4. 兜底：任意一轨（编码兼容性优先）
    final any = _bestTrack(videoTracks);
    if (any != null) return any.effectiveUrl;

    return null;
  }

  String? get primaryVideoUrl {
    final url = getVideoUrlForQuality(
      grantedQuality > 0 ? grantedQuality : currentQuality,
    );
    if (url != null && url.isNotEmpty) return url;
    if (durls.isNotEmpty) {
      final u = durls.first.effectiveUrl;
      if (u.isNotEmpty) return u;
    }
    if (videoTracks.isNotEmpty) {
      final u = videoTracks.first.effectiveUrl;
      if (u.isNotEmpty) return u;
    }
    return null;
  }

  /// 纯音频播放（听视频模式）使用的最优音轨；无独立音轨时回退视频流本身。
  String? get primaryAudioUrl {
    final track = bestAudioTrack;
    if (track != null) {
      final u = track.effectiveUrl;
      if (u.isNotEmpty) return u;
    }
    return primaryVideoUrl;
  }
}
