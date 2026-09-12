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

  factory PlayUrlInfo.fromJson(Map<String, dynamic> json) {
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
    );
  }

  bool get isDash => videoTracks.isNotEmpty && audioTracks.isNotEmpty;

  String? getVideoUrlForQuality(int targetQuality) {
    if (durls.isNotEmpty) {
      final u = durls.first.effectiveUrl;
      if (u.isNotEmpty) return u;
    }
    // 1. Prioritize AVC (H.264 / avc1) for target quality (universal hardware/software compatibility)
    for (final track in videoTracks) {
      if (track.id == targetQuality && track.codecs.startsWith('avc1')) {
        final u = track.effectiveUrl;
        if (u.isNotEmpty) return u;
      }
    }
    // 2. Fall back to any codec for target quality
    for (final track in videoTracks) {
      if (track.id == targetQuality) {
        final u = track.effectiveUrl;
        if (u.isNotEmpty) return u;
      }
    }
    // 3. Fall back to AVC in first available track
    for (final track in videoTracks) {
      if (track.codecs.startsWith('avc1')) {
        final u = track.effectiveUrl;
        if (u.isNotEmpty) return u;
      }
    }
    if (videoTracks.isNotEmpty) {
      final u = videoTracks.first.effectiveUrl;
      if (u.isNotEmpty) return u;
    }
    return null;
  }

  String? get primaryVideoUrl {
    final url = getVideoUrlForQuality(currentQuality);
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

  String? get primaryAudioUrl {
    for (final track in audioTracks) {
      final u = track.effectiveUrl;
      if (u.isNotEmpty) return u;
    }
    return primaryVideoUrl;
  }
}
