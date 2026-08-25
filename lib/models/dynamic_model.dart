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
      if (map['pic'] is Map) {
        return DynamicPicture.fromJson(map['pic']);
      }
      if (map['pics'] is List && (map['pics'] as List).isNotEmpty) {
        return DynamicPicture.fromJson((map['pics'] as List).first);
      }

      String src = map['src']?.toString() ??
          map['url']?.toString() ??
          map['img_src']?.toString() ??
          map['image_src']?.toString() ??
          map['pic']?.toString() ??
          map['pic_url']?.toString() ??
          map['cover']?.toString() ??
          map['raw_url']?.toString() ??
          '';
      if (src.startsWith('//')) {
        src = 'https:$src';
      } else if (src.startsWith('http://')) {
        src = src.replaceFirst('http://', 'https://');
      }

      final rawW = map['width'] ?? map['img_width'] ?? map['image_width'] ?? map['w'];
      final rawH = map['height'] ?? map['img_height'] ?? map['image_height'] ?? map['h'];
      final rawS = map['size'] ?? map['img_size'] ?? map['s'];

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

class DynamicParagraph {
  final int type; // 1: text, 2: picture, 3: divider, 4: title
  final String text;
  final DynamicPicture? picture;

  const DynamicParagraph({
    required this.type,
    this.text = '',
    this.picture,
  });

  bool get isText => type == 1 || type == 4;
  bool get isPicture => type == 2 && picture != null;
  bool get isDivider => type == 3;
}

class DynamicItem {
  final String id;
  final String type;
  final String title;
  final DynamicAuthor author;
  final String text;
  final DynamicVideo? video;
  final List<DynamicPicture> pictures;
  final List<String> images;
  final DynamicStat stat;
  final DynamicItem? orig; // Forwarded dynamic
  final int commentId;
  final int commentType;
  final List<DynamicParagraph> paragraphs;

  DynamicItem({
    required this.id,
    required this.type,
    this.title = '',
    required this.author,
    required this.text,
    this.video,
    List<DynamicPicture>? pictures,
    List<String>? images,
    required this.stat,
    this.orig,
    this.commentId = 0,
    this.commentType = 1,
    List<DynamicParagraph>? paragraphs,
  })  : pictures = pictures ??
            (images?.map((u) => DynamicPicture.fromUrl(u)).toList() ?? const []),
        images = images ??
            (pictures?.map((p) => p.url).toList() ?? const []),
        paragraphs = paragraphs ?? const [];

  String get cleanText {
    return text.replaceAll('[图片]', '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  DynamicItem copyWith({
    String? id,
    String? type,
    String? title,
    DynamicAuthor? author,
    String? text,
    DynamicVideo? video,
    List<DynamicPicture>? pictures,
    List<String>? images,
    DynamicStat? stat,
    DynamicItem? orig,
    int? commentId,
    int? commentType,
    List<DynamicParagraph>? paragraphs,
  }) {
    return DynamicItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      author: author ?? this.author,
      text: text ?? this.text,
      video: video ?? this.video,
      pictures: pictures ?? this.pictures,
      images: images ?? this.images,
      stat: stat ?? this.stat,
      orig: orig ?? this.orig,
      commentId: commentId ?? this.commentId,
      commentType: commentType ?? this.commentType,
      paragraphs: paragraphs ?? this.paragraphs,
    );
  }

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

    final basic = json['basic'] is Map ? json['basic'] as Map<String, dynamic> : {};
    int cId = int.tryParse(basic['comment_id_str']?.toString() ?? basic['comment_id']?.toString() ?? '') ?? 0;
    int cType = basic['comment_type'] is int
        ? basic['comment_type'] as int
        : (int.tryParse(basic['comment_type']?.toString() ?? '') ?? 0);

    final modules = json['modules'] is Map ? json['modules'] as Map<String, dynamic> : {};
    final authorObj = DynamicAuthor.fromJson(modules['module_author']);
    final statObj = DynamicStat.fromJson(modules['module_stat']);

    String descText = '';
    String titleStr = '';
    DynamicVideo? videoObj;
    List<DynamicPicture> picturesList = [];
    List<DynamicParagraph> parsedParagraphs = [];

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
      if (majorType == 'MAJOR_TYPE_DRAW' && major['draw'] is Map) {
        final draw = major['draw'] as Map<String, dynamic>;
        final items = draw['items'] ?? draw['pics'] ?? draw['images'];
        if (items is List) {
          for (final img in items) {
            final pic = DynamicPicture.fromJson(img);
            if (pic.url.isNotEmpty && !picturesList.any((e) => e.url == pic.url)) {
              picturesList.add(pic);
            }
          }
        }
      }

      // Opus / Articles
      Map<String, dynamic>? opus;
      if (majorType == 'MAJOR_TYPE_OPUS' && major['opus'] is Map) {
        opus = major['opus'] as Map<String, dynamic>;
      } else if (json['opus'] is Map) {
        opus = json['opus'] as Map<String, dynamic>;
      }

      if (opus != null) {
        String summaryText = '';
        if (opus['summary'] is Map) {
          summaryText = opus['summary']['text']?.toString() ?? '';
        }
        titleStr = opus['title']?.toString() ??
            json['title']?.toString() ??
            (modules['module_top'] is Map ? modules['module_top']['title']?.toString() ?? '' : '');

        if (titleStr.isNotEmpty) {
          if (descText.isNotEmpty && !descText.contains(titleStr)) {
            descText = '$titleStr\n\n$descText';
          } else if (descText.isEmpty) {
            descText = summaryText.isNotEmpty ? '$titleStr\n\n$summaryText' : titleStr;
          }
        } else if (descText.isEmpty && summaryText.isNotEmpty) {
          descText = summaryText;
        }

        // 1. Check opus['pics']
        if (opus['pics'] is List) {
          for (final p in opus['pics']) {
            final pic = DynamicPicture.fromJson(p);
            if (pic.url.isNotEmpty && !picturesList.any((e) => e.url == pic.url)) {
              picturesList.add(pic);
            }
          }
        }

        // 2. Check opus['summary']['pics'] if picturesList is still empty
        if (opus['summary'] is Map && opus['summary']['pics'] is List) {
          for (final p in opus['summary']['pics']) {
            final pic = DynamicPicture.fromJson(p);
            if (pic.url.isNotEmpty && !picturesList.any((e) => e.url == pic.url)) {
              picturesList.add(pic);
            }
          }
        }

        // 3. Check opus['content']['paragraphs'] or opus['paragraphs'] for inline pictures & paragraphs
        final rawParas = (opus['content'] is Map ? opus['content']['paragraphs'] : null) ??
            opus['paragraphs'] ??
            (opus['content'] is List ? opus['content'] : null) ??
            json['paragraphs'] ??
            (json['content'] is Map ? json['content']['paragraphs'] : null);
        if (rawParas is List) {
          for (final p in rawParas) {
            if (p is Map) {
              final pType = p['para_type'] is int ? p['para_type'] as int : 1;
              if (pType == 1 || p['text'] != null) {
                String t = '';
                if (p['text'] is Map) {
                  final textMap = p['text'] as Map;
                  if (textMap['nodes'] is List) {
                    final nodes = textMap['nodes'] as List;
                    final sb = StringBuffer();
                    for (final n in nodes) {
                      if (n is Map) {
                        sb.write(n['word']?.toString() ?? n['text']?.toString() ?? '');
                      } else if (n is String) {
                        sb.write(n);
                      }
                    }
                    t = sb.toString();
                  } else if (textMap['text'] != null) {
                    t = textMap['text'].toString();
                  }
                } else if (p['text'] is String) {
                  t = p['text'] as String;
                }
                if (t.trim().isNotEmpty) {
                  parsedParagraphs.add(DynamicParagraph(type: 1, text: t.trim()));
                }
              } else if (pType == 2 || p['pic'] != null) {
                final picData = p['pic'];
                if (picData is Map && picData['pics'] is List) {
                  for (final subP in picData['pics']) {
                    final pic = DynamicPicture.fromJson(subP);
                    if (pic.url.isNotEmpty) {
                      parsedParagraphs.add(DynamicParagraph(type: 2, picture: pic));
                      if (!picturesList.any((e) => e.url == pic.url)) {
                        picturesList.add(pic);
                      }
                    }
                  }
                } else if (picData != null) {
                  final pic = DynamicPicture.fromJson(picData);
                  if (pic.url.isNotEmpty) {
                    parsedParagraphs.add(DynamicParagraph(type: 2, picture: pic));
                    if (!picturesList.any((e) => e.url == pic.url)) {
                      picturesList.add(pic);
                    }
                  }
                }
              } else if (pType == 3) {
                parsedParagraphs.add(const DynamicParagraph(type: 3));
              }
            }
          }
        }
      }

      // Article Covers
      if (majorType == 'MAJOR_TYPE_ARTICLE' && major['article'] is Map) {
        final article = major['article'] as Map<String, dynamic>;
        final covers = article['covers'] ?? article['pics'] ?? article['images'];
        if (covers is List) {
          for (final c in covers) {
            final pic = DynamicPicture.fromJson(c);
            if (pic.url.isNotEmpty && !picturesList.any((e) => e.url == pic.url)) {
              picturesList.add(pic);
            }
          }
        } else if (article['cover'] != null) {
          final pic = DynamicPicture.fromJson(article['cover']);
          if (pic.url.isNotEmpty && !picturesList.any((e) => e.url == pic.url)) {
            picturesList.add(pic);
          }
        }
      }
    }

    // Fallback pictures in module_dynamic or root json if major had no pictures
    if (picturesList.isEmpty) {
      final dynDraw = dynamicModule['draw'] ?? dynamicModule['pics'] ?? dynamicModule['pictures'];
      if (dynDraw is Map && dynDraw['items'] is List) {
        for (final img in dynDraw['items']) {
          final pic = DynamicPicture.fromJson(img);
          if (pic.url.isNotEmpty) picturesList.add(pic);
        }
      } else if (dynDraw is List) {
        for (final img in dynDraw) {
          final pic = DynamicPicture.fromJson(img);
          if (pic.url.isNotEmpty) picturesList.add(pic);
        }
      }

      final rootPictures = json['pictures'] ?? json['pics'] ?? json['images'];
      if (rootPictures is List) {
        for (final img in rootPictures) {
          final pic = DynamicPicture.fromJson(img);
          if (pic.url.isNotEmpty && !picturesList.any((e) => e.url == pic.url)) {
            picturesList.add(pic);
          }
        }
      }
    }

    // Parse Forwarded dynamic if any
    DynamicItem? origItem;
    if (json['orig'] is Map) {
      origItem = DynamicItem.fromJson(json['orig']);
    }

    // Fallback for comment oid and type if not provided in basic
    if (cId == 0) {
      if (videoObj != null && videoObj.aid > 0) {
        cId = videoObj.aid;
        cType = 1;
      } else {
        cId = int.tryParse(idStr) ?? 0;
        cType = picturesList.isNotEmpty ? 11 : 17;
      }
    }
    if (cType == 0) {
      cType = videoObj != null ? 1 : (picturesList.isNotEmpty ? 11 : 17);
    }

    // Fallback: If parsedParagraphs is empty, but descText contains [图片]:
    if (parsedParagraphs.isEmpty && descText.contains('[图片]')) {
      final parts = descText.split('[图片]');
      int picIdx = 0;
      for (int i = 0; i < parts.length; i++) {
        final segment = parts[i].trim();
        if (segment.isNotEmpty) {
          parsedParagraphs.add(DynamicParagraph(type: 1, text: segment));
        }
        if (i < parts.length - 1 && picIdx < picturesList.length) {
          parsedParagraphs.add(DynamicParagraph(type: 2, picture: picturesList[picIdx++]));
        }
      }
      while (picIdx < picturesList.length) {
        parsedParagraphs.add(DynamicParagraph(type: 2, picture: picturesList[picIdx++]));
      }
    }

    return DynamicItem(
      id: idStr,
      type: typeStr,
      title: titleStr,
      author: authorObj,
      text: descText,
      video: videoObj,
      pictures: picturesList,
      stat: statObj,
      orig: origItem,
      commentId: cId,
      commentType: cType,
      paragraphs: parsedParagraphs,
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
