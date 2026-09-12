class SubtitleTrack {
  final int id;
  final String lan;
  final String lanDoc;
  final String subtitleUrl;
  final bool isAi;
  final bool isLock;
  final int type;

  SubtitleTrack({
    required this.id,
    required this.lan,
    required this.lanDoc,
    required this.subtitleUrl,
    this.isAi = false,
    this.isLock = false,
    this.type = 0,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    var url = json['subtitle_url']?.toString() ?? json['url']?.toString() ?? '';
    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    final lanStr = json['lan']?.toString() ?? '';
    final lanDocStr = json['lan_doc']?.toString() ?? '';
    final isAiType = lanStr.startsWith('ai-') || json['ai_type'] != null && json['ai_type'] > 0;

    return SubtitleTrack(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      lan: lanStr,
      lanDoc: lanDocStr.isNotEmpty ? lanDocStr : lanStr,
      subtitleUrl: url,
      isAi: isAiType,
      isLock: json['is_lock'] == true,
      type: json['type'] is int ? json['type'] : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lan': lan,
        'lan_doc': lanDoc,
        'subtitle_url': subtitleUrl,
        'is_ai': isAi,
        'is_lock': isLock,
        'type': type,
      };
}

class SubtitleItem {
  final double from;
  final double to;
  final String content;
  final int sid;

  SubtitleItem({
    required this.from,
    required this.to,
    required this.content,
    this.sid = 0,
  });

  factory SubtitleItem.fromJson(Map<String, dynamic> json) {
    return SubtitleItem(
      from: (json['from'] as num?)?.toDouble() ?? 0.0,
      to: (json['to'] as num?)?.toDouble() ?? 0.0,
      content: json['content']?.toString() ?? '',
      sid: json['sid'] is int ? json['sid'] : 0,
    );
  }

  bool isCurrent(double currentSeconds) {
    return currentSeconds >= from && currentSeconds <= to;
  }
}

class SubtitleData {
  final SubtitleTrack track;
  final List<SubtitleItem> items;

  SubtitleData({
    required this.track,
    required this.items,
  });

  factory SubtitleData.fromJson(SubtitleTrack track, Map<String, dynamic> json) {
    final List<SubtitleItem> itemList = [];
    if (json['body'] is List) {
      for (final item in json['body']) {
        if (item is Map<String, dynamic>) {
          itemList.add(SubtitleItem.fromJson(item));
        } else if (item is Map) {
          itemList.add(SubtitleItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    // Ensure sorted by from timestamp
    itemList.sort((a, b) => a.from.compareTo(b.from));
    return SubtitleData(track: track, items: itemList);
  }

  /// Binary search to find subtitle item at current timestamp
  SubtitleItem? getActiveItem(double currentSeconds) {
    if (items.isEmpty) return null;
    int low = 0;
    int high = items.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final item = items[mid];

      if (currentSeconds < item.from) {
        high = mid - 1;
      } else if (currentSeconds > item.to) {
        low = mid + 1;
      } else {
        return item; // Match found
      }
    }

    return null;
  }
}
