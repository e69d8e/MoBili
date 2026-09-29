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

  /// 是否没有任何统计数据（用于合并时判断该来源是否可用）
  bool get isEmpty =>
      commentCount == 0 && forwardCount == 0 && likeCount == 0 && !isLiked;

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
  final int type; // 1: 文本, 2: 图片, 3: 分割线, 4: 标题, 5: 引用, 6: 代码
  final String text;
  final DynamicPicture? picture;

  const DynamicParagraph({
    required this.type,
    this.text = '',
    this.picture,
  });

  bool get isText => type == 1 || type == 4 || type == 5 || type == 6;
  bool get isQuote => type == 5;
  bool get isCode => type == 6;
  bool get isPicture => type == 2 && picture != null;
  bool get isDivider => type == 3;
}

/// 从 B 站各种富文本结构中抽取纯文本。
///
/// 兼容以下形态：
///  - `'纯文本'`
///  - `{'text': '纯文本'}` / `{'text': {'nodes': [...]}}`
///  - `{'rich_text_nodes': [{'text': '文字'}]}`
///  - `{'nodes': [{'word': {'words': '文字'}}, {'rich': {'text': '[表情]'}}]}`
String _extractRichText(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  if (raw is num || raw is bool) return raw.toString();
  if (raw is List) {
    final buffer = StringBuffer();
    for (final item in raw) {
      buffer.write(_extractRichText(item));
    }
    return buffer.toString();
  }
  if (raw is! Map) return '';

  final map = Map<String, dynamic>.from(raw);

  // 普通文本节点：{word: {words: '...'}}
  final word = map['word'];
  if (word is Map) {
    final words = word['words'];
    if (words != null) return words.toString();
  } else if (word is String && word.isNotEmpty) {
    return word;
  }

  // 富文本节点（表情、@、话题等）：{rich: {text: '...'}}
  final rich = map['rich'];
  if (rich is Map) {
    final richText = rich['text'] ?? rich['orig_text'];
    if (richText != null) return richText.toString();
  }

  // @用户节点
  final user = map['user'];
  if (user is Map && user['name'] != null) return '@${user['name']}';

  // 公式节点
  final formula = map['formula'];
  if (formula is Map) {
    final latex = formula['latex_content'] ?? formula['latex'];
    if (latex != null) return latex.toString();
  }

  if (map['text'] is String && (map['text'] as String).isNotEmpty) {
    return map['text'] as String;
  }
  if (map['text'] is Map || map['text'] is List) return _extractRichText(map['text']);

  for (final key in const ['nodes', 'rich_text_nodes', 'items']) {
    if (map[key] is List) return _extractRichText(map[key]);
  }

  if (map['content'] is String) return map['content'] as String;
  if (map['title'] is String) return map['title'] as String;
  return '';
}

/// 归一化 dynamic 接口的 modules 字段。
///
/// 动态列表 / 动态详情返回的是以 `module_author`、`module_dynamic` 等为键的对象，
/// 而 opus 详情接口返回的是 `module_type` + 具体模块组成的数组，
/// 这里统一转换成一个 Map，便于后续解析共用同一套逻辑。
Map<String, dynamic> _normalizeModules(dynamic rawModules) {
  if (rawModules is Map) {
    final modules = Map<String, dynamic>.from(rawModules);
    if (modules['modules'] is List &&
        modules['module_dynamic'] == null &&
        modules['module_author'] == null) {
      return _normalizeModules(modules['modules']);
    }
    return modules;
  }
  if (rawModules is List) {
    final modules = <String, dynamic>{};
    for (final raw in rawModules) {
      if (raw is! Map) continue;
      final module = Map<String, dynamic>.from(raw);
      switch (module['module_type']?.toString() ?? '') {
        case 'MODULE_TYPE_AUTHOR':
          modules['module_author'] = module['module_author'];
          break;
        case 'MODULE_TYPE_STAT':
          modules['module_stat'] = module['module_stat'];
          break;
        case 'MODULE_TYPE_TITLE':
          modules['module_title'] = module['module_title'];
          break;
        case 'MODULE_TYPE_TOP':
          modules['module_top'] = module['module_top'];
          break;
        case 'MODULE_TYPE_DYNAMIC':
          modules['module_dynamic'] = module['module_dynamic'];
          break;
        case 'MODULE_TYPE_CONTENT':
          modules['module_content'] = module['module_content'] ?? module;
          break;
        case 'MODULE_TYPE_BOTTOM':
          modules['module_bottom'] = module['module_bottom'];
          break;
      }
    }
    return modules;
  }
  return <String, dynamic>{};
}

/// 读取模块里的标题（opus 详情使用 MODULE_TYPE_TITLE，列表接口可能放在 module_top）
String _moduleTitleText(Map<String, dynamic> modules) {
  final moduleTitle = modules['module_title'];
  if (moduleTitle is Map) {
    final inner = moduleTitle['module_title'];
    if (inner is Map && inner['text'] != null) return inner['text'].toString();
    if (moduleTitle['text'] != null) return moduleTitle['text'].toString();
  }
  final moduleTop = modules['module_top'];
  if (moduleTop is Map) {
    if (moduleTop['title'] != null) return moduleTop['title'].toString();
    final display = moduleTop['display'];
    if (display is Map && display['title'] != null) {
      return display['title'].toString();
    }
  }
  return '';
}

/// 解析 opus 正文段落，并把段落中出现的图片同步写入 [pictures]。
///
/// 段落类型参见 module_content.paragraphs：
/// 1 文本 / 2 图片 / 3 分割线 / 4 块引用 / 5 列表 / 6 链接卡片 / 7 代码
List<DynamicParagraph> _parseRichParagraphs(
  dynamic rawParagraphs,
  List<DynamicPicture> pictures,
) {
  final paragraphs = <DynamicParagraph>[];
  if (rawParagraphs is! List) return paragraphs;

  for (final raw in rawParagraphs) {
    if (raw is! Map) continue;
    final p = Map<String, dynamic>.from(raw);
    final rawType = p['para_type'];
    final paraType = rawType is int
        ? rawType
        : (int.tryParse(rawType?.toString() ?? '') ?? 0);

    // 文本 / 块引用（引用同样使用 text.nodes）
    final text = _extractRichText(p['text']).trim();
    if (text.isNotEmpty) {
      paragraphs.add(DynamicParagraph(
        type: paraType == 4 ? 5 : (p['heading'] != null ? 4 : 1),
        text: text,
      ));
      continue;
    }

    // 图片
    final picData = p['pic'];
    if (picData is Map && picData['pics'] is List) {
      for (final sub in picData['pics'] as List) {
        final pic = DynamicPicture.fromJson(sub);
        if (pic.url.isEmpty) continue;
        paragraphs.add(DynamicParagraph(type: 2, picture: pic));
        if (!pictures.any((e) => e.url == pic.url)) pictures.add(pic);
      }
      continue;
    }
    if (picData != null) {
      final pic = DynamicPicture.fromJson(picData);
      if (pic.url.isNotEmpty) {
        paragraphs.add(DynamicParagraph(type: 2, picture: pic));
        if (!pictures.any((e) => e.url == pic.url)) pictures.add(pic);
      }
      continue;
    }

    // 列表
    final listData = p['list'];
    if (listData is Map && listData['items'] is List) {
      final ordered = listData['style'] == 1;
      final lines = <String>[];
      var index = 0;
      for (final item in listData['items'] as List) {
        if (item is! Map) continue;
        index++;
        final itemText = _extractRichText(item['nodes'] ?? item).trim();
        if (itemText.isEmpty) continue;
        final order = item['order'];
        final marker = ordered ? '${order is int ? order : index}. ' : '• ';
        final level = item['level'];
        final indent = (level is int && level > 1) ? '  ' * (level - 1) : '';
        lines.add('$indent$marker$itemText');
      }
      if (lines.isNotEmpty) {
        paragraphs.add(DynamicParagraph(type: 1, text: lines.join('\n')));
        continue;
      }
    }

    // 链接卡片（视频 / 图文 / 商品 / 投票 / 直播等）
    final linkCard = p['link_card'];
    if (linkCard is Map && linkCard['card'] is Map) {
      final cardText = _extractLinkCardText(
        Map<String, dynamic>.from(linkCard['card'] as Map),
      );
      if (cardText.isNotEmpty) {
        paragraphs.add(DynamicParagraph(type: 1, text: cardText));
        continue;
      }
    }

    // 代码块
    final codeData = p['code'];
    if (codeData is Map) {
      final code = (codeData['content'] ?? codeData['text'])?.toString().trim() ?? '';
      if (code.isNotEmpty) {
        paragraphs.add(DynamicParagraph(type: 6, text: code));
        continue;
      }
    }

    // 其它富文本块（标题 / 引用对象等）
    final richBlock = p['heading'] ?? p['blockquote'];
    if (richBlock != null) {
      final richText = _extractRichText(richBlock).trim();
      if (richText.isNotEmpty) {
        paragraphs.add(DynamicParagraph(
          type: p['heading'] != null ? 4 : 5,
          text: richText,
        ));
        continue;
      }
    }

    // 分割线
    if (p['line'] != null || paraType == 3) {
      paragraphs.add(const DynamicParagraph(type: 3));
    }
  }

  return paragraphs;
}

/// 从链接卡片中取出可展示的标题文本
String _extractLinkCardText(Map<String, dynamic> card) {
  const sections = ['common', 'ugc', 'opus', 'goods', 'vote', 'live', 'music', 'reserve'];
  for (final key in sections) {
    final section = card[key];
    if (section is Map) {
      for (final field in const ['title', 'name', 'sub_title', 'desc']) {
        final value = section[field];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      final matchInfo = section['match_info'];
      if (matchInfo is Map && matchInfo['title'] is String) {
        return (matchInfo['title'] as String).trim();
      }
    }
  }

  final nullHint = card['item_null'];
  if (nullHint is Map) {
    for (final field in const ['title', 'text', 'desc']) {
      final value = nullHint[field];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
  }
  return '';
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

    final basic = json['basic'] is Map
        ? Map<String, dynamic>.from(json['basic'] as Map)
        : <String, dynamic>{};
    int cId = int.tryParse(basic['comment_id_str']?.toString() ?? basic['comment_id']?.toString() ?? '') ?? 0;
    int cType = basic['comment_type'] is int
        ? basic['comment_type'] as int
        : (int.tryParse(basic['comment_type']?.toString() ?? '') ?? 0);

    // modules 有两种形态：动态列表/详情是对象，opus 详情是模块数组
    final modules = _normalizeModules(json['modules']);
    final authorObj = DynamicAuthor.fromJson(modules['module_author']);
    final statObj = DynamicStat.fromJson(modules['module_stat']);

    String descText = '';
    String titleStr = '';
    DynamicVideo? videoObj;
    final picturesList = <DynamicPicture>[];
    final parsedParagraphs = <DynamicParagraph>[];

    final dynamicModule = modules['module_dynamic'] is Map
        ? Map<String, dynamic>.from(modules['module_dynamic'] as Map)
        : <String, dynamic>{};

    // Parse Text
    if (dynamicModule['desc'] is Map) {
      descText = dynamicModule['desc']['text']?.toString() ?? '';
    }

    // Opus 对象：列表/详情接口位于 module_dynamic.major.opus，
    // opus 详情接口则拆成 module_title / module_content 等模块
    Map<String, dynamic>? opus;
    if (json['opus'] is Map) {
      opus = Map<String, dynamic>.from(json['opus'] as Map);
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

      // Opus
      if (majorType == 'MAJOR_TYPE_OPUS' && major['opus'] is Map) {
        opus = Map<String, dynamic>.from(major['opus'] as Map);
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

    if (opus != null) {
      final summaryText = _extractRichText(opus['summary']);
      titleStr = opus['title']?.toString() ?? '';
      if (titleStr.isEmpty) titleStr = json['title']?.toString() ?? '';
      if (titleStr.isEmpty) titleStr = _moduleTitleText(modules);

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
    } else {
      titleStr = json['title']?.toString() ?? '';
      if (titleStr.isEmpty) titleStr = _moduleTitleText(modules);
    }

    // 完整正文段落：opus 详情接口放在 module_content，
    // 列表/动态详情接口放在 opus.content / opus.paragraphs
    final rawParagraphs =
        (modules['module_content'] is Map ? (modules['module_content'] as Map)['paragraphs'] : null) ??
            (opus?['content'] is Map ? (opus!['content'] as Map)['paragraphs'] : null) ??
            opus?['paragraphs'] ??
            (opus?['content'] is List ? opus!['content'] : null) ??
            json['paragraphs'] ??
            (json['content'] is Map ? (json['content'] as Map)['paragraphs'] : null);
    parsedParagraphs.addAll(_parseRichParagraphs(rawParagraphs, picturesList));

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

    // 摘要缺失时，用完整段落文本兜底，保证纯文本渲染路径也有内容
    if (descText.trim().isEmpty) {
      final paragraphText = parsedParagraphs
          .where((p) => p.isText && p.text.isNotEmpty)
          .map((p) => p.text)
          .join('\n\n');
      if (paragraphText.isNotEmpty) descText = paragraphText;
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

  /// 合并两个来源的动态数据：以 [detail]（通常是接口最新返回）为主，
  /// 其缺失或为空的部分回退到 [fallback]（例如列表项），
  /// 避免详情接口只返回摘要时把列表里的正文/图片覆盖成空。
  static DynamicItem? merge(DynamicItem? detail, DynamicItem? fallback) {
    if (detail == null) return fallback;
    if (fallback == null) return detail;

    final mergedPictures = <DynamicPicture>[];
    for (final pic in [...detail.pictures, ...fallback.pictures]) {
      if (pic.url.isEmpty) continue;
      if (!mergedPictures.any((e) => e.url == pic.url)) mergedPictures.add(pic);
    }

    return DynamicItem(
      id: detail.id.isNotEmpty ? detail.id : fallback.id,
      type: detail.type.isNotEmpty ? detail.type : fallback.type,
      title: detail.title.isNotEmpty ? detail.title : fallback.title,
      author: (detail.author.mid > 0 || detail.author.name.isNotEmpty)
          ? detail.author
          : fallback.author,
      text: detail.text.isNotEmpty ? detail.text : fallback.text,
      video: detail.video ?? fallback.video,
      pictures: mergedPictures,
      stat: detail.stat.isEmpty && !fallback.stat.isEmpty ? fallback.stat : detail.stat,
      orig: detail.orig ?? fallback.orig,
      commentId: detail.commentId > 0 ? detail.commentId : fallback.commentId,
      commentType: detail.commentType > 0 ? detail.commentType : fallback.commentType,
      paragraphs: detail.paragraphs.isNotEmpty ? detail.paragraphs : fallback.paragraphs,
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
