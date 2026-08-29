enum VideoCacheStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

class VideoCacheItem {
  final String taskId;
  final String bvid;
  final int aid;
  final int cid;
  final String title;
  final String cover;
  final String ownerName;
  final String ownerFace;
  final String pageTitle;
  final int pageIndex;
  final int pageCount;
  final int duration;
  final int quality;
  final String qualityDesc;
  final String videoUrl;
  final String localVideoPath;
  final String localDanmakuPath;
  final String localCoverPath;
  final VideoCacheStatus status;
  final int totalBytes;
  final int downloadedBytes;
  final int downloadSpeed; // bytes per second
  final int createdAt;
  final int completedAt;
  final String? errorMsg;

  VideoCacheItem({
    required this.taskId,
    required this.bvid,
    this.aid = 0,
    required this.cid,
    required this.title,
    this.cover = '',
    this.ownerName = '',
    this.ownerFace = '',
    this.pageTitle = '',
    this.pageIndex = 0,
    this.pageCount = 1,
    this.duration = 0,
    this.quality = 80,
    this.qualityDesc = '1080P 高清',
    this.videoUrl = '',
    this.localVideoPath = '',
    this.localDanmakuPath = '',
    this.localCoverPath = '',
    this.status = VideoCacheStatus.pending,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.downloadSpeed = 0,
    required this.createdAt,
    this.completedAt = 0,
    this.errorMsg,
  });

  double get progress {
    if (status == VideoCacheStatus.completed) return 1.0;
    if (totalBytes <= 0) return 0.0;
    final p = downloadedBytes / totalBytes;
    return p.clamp(0.0, 1.0);
  }

  bool get isCompleted => status == VideoCacheStatus.completed;
  bool get isDownloading => status == VideoCacheStatus.downloading;
  bool get isPaused => status == VideoCacheStatus.paused;
  bool get isPending => status == VideoCacheStatus.pending;
  bool get isFailed => status == VideoCacheStatus.failed;

  VideoCacheItem copyWith({
    String? taskId,
    String? bvid,
    int? aid,
    int? cid,
    String? title,
    String? cover,
    String? ownerName,
    String? ownerFace,
    String? pageTitle,
    int? pageIndex,
    int? pageCount,
    int? duration,
    int? quality,
    String? qualityDesc,
    String? videoUrl,
    String? localVideoPath,
    String? localDanmakuPath,
    String? localCoverPath,
    VideoCacheStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    int? downloadSpeed,
    int? createdAt,
    int? completedAt,
    String? errorMsg,
  }) {
    return VideoCacheItem(
      taskId: taskId ?? this.taskId,
      bvid: bvid ?? this.bvid,
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      ownerName: ownerName ?? this.ownerName,
      ownerFace: ownerFace ?? this.ownerFace,
      pageTitle: pageTitle ?? this.pageTitle,
      pageIndex: pageIndex ?? this.pageIndex,
      pageCount: pageCount ?? this.pageCount,
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      qualityDesc: qualityDesc ?? this.qualityDesc,
      videoUrl: videoUrl ?? this.videoUrl,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      localDanmakuPath: localDanmakuPath ?? this.localDanmakuPath,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'bvid': bvid,
      'aid': aid,
      'cid': cid,
      'title': title,
      'cover': cover,
      'ownerName': ownerName,
      'ownerFace': ownerFace,
      'pageTitle': pageTitle,
      'pageIndex': pageIndex,
      'pageCount': pageCount,
      'duration': duration,
      'quality': quality,
      'qualityDesc': qualityDesc,
      'videoUrl': videoUrl,
      'localVideoPath': localVideoPath,
      'localDanmakuPath': localDanmakuPath,
      'localCoverPath': localCoverPath,
      'status': status.name,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'errorMsg': errorMsg,
    };
  }

  factory VideoCacheItem.fromJson(Map<String, dynamic> json) {
    VideoCacheStatus status = VideoCacheStatus.pending;
    final statusStr = json['status']?.toString();
    if (statusStr != null) {
      for (final s in VideoCacheStatus.values) {
        if (s.name == statusStr) {
          status = s;
          break;
        }
      }
    }

    return VideoCacheItem(
      taskId: json['taskId']?.toString() ?? '${json['bvid']}_${json['cid']}',
      bvid: json['bvid']?.toString() ?? '',
      aid: json['aid'] is int ? json['aid'] : int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
      cid: json['cid'] is int ? json['cid'] : int.tryParse(json['cid']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      ownerFace: json['ownerFace']?.toString() ?? '',
      pageTitle: json['pageTitle']?.toString() ?? '',
      pageIndex: json['pageIndex'] is int ? json['pageIndex'] : 0,
      pageCount: json['pageCount'] is int ? json['pageCount'] : 1,
      duration: json['duration'] is int ? json['duration'] : 0,
      quality: json['quality'] is int ? json['quality'] : 80,
      qualityDesc: json['qualityDesc']?.toString() ?? '1080P 高清',
      videoUrl: json['videoUrl']?.toString() ?? '',
      localVideoPath: json['localVideoPath']?.toString() ?? '',
      localDanmakuPath: json['localDanmakuPath']?.toString() ?? '',
      localCoverPath: json['localCoverPath']?.toString() ?? '',
      status: status,
      totalBytes: json['totalBytes'] is int ? json['totalBytes'] : 0,
      downloadedBytes: json['downloadedBytes'] is int ? json['downloadedBytes'] : 0,
      downloadSpeed: 0,
      createdAt: json['createdAt'] is int ? json['createdAt'] : 0,
      completedAt: json['completedAt'] is int ? json['completedAt'] : 0,
      errorMsg: json['errorMsg']?.toString(),
    );
  }
}
