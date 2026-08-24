class DynamicAuthor {
  final int mid;
  final String name;
  final String face;
  final String pubTime;
  final String pubAction;
  final int pubTs;

  DynamicAuthor({
    required this.mid,
    required this.name,
    required this.face,
    required this.pubTime,
    required this.pubAction,
    this.pubTs = 0,
  });

  factory DynamicAuthor.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      return DynamicAuthor(
        mid: 0,
        name: '',
        face: '',
        pubTime: '',
        pubAction: '',
      );
    }
    final json = Map<String, dynamic>.from(rawJson);

    String faceUrl = json['face']?.toString() ?? '';
    if (faceUrl.isEmpty && json['avatar'] is Map) {
      try {
        final layers = json['avatar']['fallback_layers']?['layers'] as List?;
        if (layers != null && layers.isNotEmpty) {
          faceUrl = layers.first['resource']?['res_image']?['image_src']?['remote']?['url']?.toString() ?? '';
        }
      } catch (_) {}
    }

    if (faceUrl.startsWith('//')) {
      faceUrl = 'https:$faceUrl';
    } else if (faceUrl.startsWith('http://')) {
      faceUrl = faceUrl.replaceFirst('http://', 'https://');
    }

    return DynamicAuthor(
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      face: faceUrl,
      pubTime: json['pub_time']?.toString() ?? '',
      pubAction: json['pub_action']?.toString() ?? '',
      pubTs: json['pub_ts'] is int ? json['pub_ts'] : 0,
    );
  }
}

class DynamicVideo {
  final int aid;
  final String bvid;
  final String title;
  final String cover;
  final String desc;
  final String durationText;
  final String playCount;
  final String danmakuCount;

  DynamicVideo({
    required this.aid,
    required this.bvid,
    required this.title,
    required this.cover,
    required this.desc,
    required this.durationText,
    required this.playCount,
    required this.danmakuCount,
  });

  factory DynamicVideo.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      return DynamicVideo(
        aid: 0,
        bvid: '',
        title: '',
        cover: '',
        desc: '',
        durationText: '',
        playCount: '',
        danmakuCount: '',
      );
    }
    final json = Map<String, dynamic>.from(rawJson);

    String coverUrl = json['cover']?.toString() ?? json['pic']?.toString() ?? '';
    if (coverUrl.startsWith('//')) {
      coverUrl = 'https:$coverUrl';
    } else if (coverUrl.startsWith('http://')) {
      coverUrl = coverUrl.replaceFirst('http://', 'https://');
    }

    String playStr = '';
    String dmStr = '';
    if (json['stat'] is Map) {
      playStr = json['stat']['play']?.toString() ?? '';
      dmStr = json['stat']['danmaku']?.toString() ?? '';
    }

    return DynamicVideo(
      aid: json['aid'] is int ? json['aid'] : int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
      bvid: json['bvid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      cover: coverUrl,
      desc: json['desc']?.toString() ?? '',
      durationText: json['duration_text']?.toString() ?? '',
      playCount: playStr,
      danmakuCount: dmStr,
    );
  }
}

class DynamicStat {
  final int commentCount;
  final int forwardCount;
  final int likeCount;
  final bool isLiked;

  DynamicStat({
    this.commentCount = 0,
    this.forwardCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory DynamicStat.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) return DynamicStat();
    final json = Map<String, dynamic>.from(rawJson);

    int comments = 0;
    int forwards = 0;
    int likes = 0;
    bool liked = false;

    if (json['comment'] is Map) {
      comments = json['comment']['count'] is int ? json['comment']['count'] : 0;
    }
    if (json['forward'] is Map) {
      forwards = json['forward']['count'] is int ? json['forward']['count'] : 0;
    }
    if (json['like'] is Map) {
      likes = json['like']['count'] is int ? json['like']['count'] : 0;
      liked = json['like']['status'] == true;
    }

    return DynamicStat(
      commentCount: comments,
      forwardCount: forwards,
      likeCount: likes,
      isLiked: liked,
    );
  }
}

class DynamicPicture {
  final String url;
  final double? width;
  final double? height;
  final double? size;

  const DynamicPicture({
    required this.url,
    this.width,
    this.height,
    this.size,
  });

  /// Image aspect ratio (width / height)
  double? get aspectRatio {
    if (width != null && height != null && height! > 0 && width! > 0) {
      return width! / height!;
    }
    return null;
  }

  /// Whether the image is a long portrait image (height >= 2.0 * width)
  bool get isLongImage {
    if (width != null && height != null && height! > 0 && width! > 0) {
      return (height! / width!) >= 2.0;
    }
    return false;
  }

  factory DynamicPicture.fromJson(dynamic data) {
    if (data is String) {
      return DynamicPicture.fromUrl(data);
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      String src = map['src']?.toString() ??
          map['url']?.toString() ??
          map['img_src']?.toString() ??
          map['image_src']?.toString() ??
          map['pic']?.toString() ??
          '';
      if (src.startsWith('//')) {
        src = 'https:$src';
      } else if (src.startsWith('http://')) {
        src = src.replaceFirst('http://', 'https://');
      }

      final rawW = map['width'] ?? map['img_width'] ?? map['image_width'];
      final rawH = map['height'] ?? map['img_height'] ?? map['image_height'];
      final rawS = map['size'] ?? map['img_size'];

      double? w = rawW is num ? rawW.toDouble() : double.tryParse(rawW?.toString() ?? '');
      double? h = rawH is num ? rawH.toDouble() : double.tryParse(rawH?.toString() ?? '');
      double? s = rawS is num ? rawS.toDouble() : double.tryParse(rawS?.toString() ?? '');

      return DynamicPicture(
        url: src,
        width: w,
        height: h,
        size: s,
      );
    }
    return const DynamicPicture(url: '');
  }

  factory DynamicPicture.fromUrl(String url) {
    String src = url.trim();
    if (src.startsWith('//')) {
      src = 'https:$src';
    } else if (src.startsWith('http://')) {
      src = src.replaceFirst('http://', 'https://');
    }
    return DynamicPicture(url: src);
  }
}

class DynamicItem {
  final String id;
  final String type;
  final DynamicAuthor author;
  final String text;
  final DynamicVideo? video;
  final List<DynamicPicture> pictures;
  final List<String> images;
  final DynamicStat stat;
  final DynamicItem? orig; // Forwarded dynamic

  DynamicItem({
    required this.id,
    required this.type,
    required this.author,
    required this.text,
    this.video,
    List<DynamicPicture>? pictures,
    List<String>? images,
    required this.stat,
    this.orig,
  })  : pictures = pictures ??
            (images?.map((u) => DynamicPicture.fromUrl(u)).toList() ?? const []),
        images = images ??
            (pictures?.map((p) => p.url).toList() ?? const []);

  factory DynamicItem.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      return DynamicItem(
        id: '',
        type: '',
        author: DynamicAuthor.fromJson(null),
        text: '',
        stat: DynamicStat.fromJson(null),
      );
    }
    final json = Map<String, dynamic>.from(rawJson);
    final idStr = json['id_str']?.toString() ?? json['id']?.toString() ?? '';
    final typeStr = json['type']?.toString() ?? '';

    final modules = json['modules'] is Map ? json['modules'] as Map<String, dynamic> : {};
    final authorObj = DynamicAuthor.fromJson(modules['module_author']);
    final statObj = DynamicStat.fromJson(modules['module_stat']);

    String descText = '';
    DynamicVideo? videoObj;
    List<DynamicPicture> picturesList = [];

    final dynamicModule = modules['module_dynamic'] is Map ? modules['module_dynamic'] as Map<String, dynamic> : {};

    // Parse Text
    if (dynamicModule['desc'] is Map) {
      descText = dynamicModule['desc']['text']?.toString() ?? '';
    }

    // Parse Major Content
    if (dynamicModule['major'] is Map) {
      final major = dynamicModule['major'] as Map<String, dynamic>;
      final majorType = major['type']?.toString() ?? '';

      // Video
      if (majorType == 'MAJOR_TYPE_ARCHIVE' && major['archive'] is Map) {
        videoObj = DynamicVideo.fromJson(major['archive']);
      }

      // Draw / Pictures
      if (majorType == 'MAJOR_TYPE_DRAW' && major['draw'] is Map && major['draw']['items'] is List) {
        for (final img in major['draw']['items']) {
          final pic = DynamicPicture.fromJson(img);
          if (pic.url.isNotEmpty) picturesList.add(pic);
        }
      }

      // Opus / Articles
      if (majorType == 'MAJOR_TYPE_OPUS' && major['opus'] is Map) {
        final opus = major['opus'] as Map<String, dynamic>;
        if (descText.isEmpty && opus['summary'] is Map) {
          descText = opus['summary']['text']?.toString() ?? '';
        }
        if (opus['pics'] is List) {
          for (final p in opus['pics']) {
            final pic = DynamicPicture.fromJson(p);
            if (pic.url.isNotEmpty) picturesList.add(pic);
          }
        }
      }

      // Article Covers
      if (majorType == 'MAJOR_TYPE_ARTICLE' && major['article'] is Map) {
        final article = major['article'] as Map<String, dynamic>;
        if (article['covers'] is List) {
          for (final c in article['covers']) {
            final pic = DynamicPicture.fromJson(c);
            if (pic.url.isNotEmpty) picturesList.add(pic);
          }
        }
      }
    }

    // Parse Forwarded dynamic if any
    DynamicItem? origItem;
    if (json['orig'] is Map) {
      origItem = DynamicItem.fromJson(json['orig']);
    }

    return DynamicItem(
      id: idStr,
      type: typeStr,
      author: authorObj,
      text: descText,
      video: videoObj,
      pictures: picturesList,
      stat: statObj,
      orig: origItem,
    );
  }
}

class DynamicFeedResponse {
  final List<DynamicItem> items;
  final String offset;
  final bool hasMore;
  final String updateBaseline;

  DynamicFeedResponse({
    required this.items,
    required this.offset,
    required this.hasMore,
    this.updateBaseline = '',
  });

  factory DynamicFeedResponse.fromJson(Map<String, dynamic> json) {
    final List<DynamicItem> list = [];
    if (json['items'] is List) {
      for (final it in json['items']) {
        try {
          list.add(DynamicItem.fromJson(it));
        } catch (_) {}
      }
    }

    return DynamicFeedResponse(
      items: list,
      offset: json['offset']?.toString() ?? '',
      hasMore: json['has_more'] == true,
      updateBaseline: json['update_baseline']?.toString() ?? '',
    );
  }
}
