class SearchHotItem {
  final String keyword;
  final String showName;
  final String icon;
  final int position;

  SearchHotItem({
    required this.keyword,
    required this.showName,
    required this.icon,
    required this.position,
  });

  factory SearchHotItem.fromJson(Map<String, dynamic> json) {
    return SearchHotItem(
      keyword: json['keyword']?.toString() ?? '',
      showName: json['show_name']?.toString() ?? json['keyword']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      position: json['position'] is int ? json['position'] : 0,
    );
  }
}

class SearchSuggestItem {
  final String value;
  final String term;

  SearchSuggestItem({
    required this.value,
    required this.term,
  });

  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');

  factory SearchSuggestItem.fromJson(Map<String, dynamic> json) {
    String val = json['value']?.toString() ?? '';
    // Clean highlight tags like <em class="suggest_high_light">
    val = val.replaceAll(_htmlTagRegex, '');
    return SearchSuggestItem(
      value: val,
      term: json['term']?.toString() ?? '',
    );
  }
}

class SearchUserItem {
  final int mid;
  final String uname;
  final String upic;
  final String usign;
  final int level;
  final int fans;
  final int videos;
  final bool isOfficial;
  final String officialDesc;

  SearchUserItem({
    required this.mid,
    required this.uname,
    required this.upic,
    required this.usign,
    required this.level,
    required this.fans,
    required this.videos,
    this.isOfficial = false,
    this.officialDesc = '',
  });

  factory SearchUserItem.fromJson(Map<String, dynamic> json) {
    String cleanUname = json['uname']?.toString() ?? '';
    cleanUname = cleanUname.replaceAll(SearchSuggestItem._htmlTagRegex, '');

    String picUrl = json['upic']?.toString() ?? json['face']?.toString() ?? '';
    if (picUrl.startsWith('//')) {
      picUrl = 'https:$picUrl';
    } else if (picUrl.startsWith('http://')) {
      picUrl = picUrl.replaceFirst('http://', 'https://');
    }

    final official = json['official_verify'] is Map ? json['official_verify'] : null;

    return SearchUserItem(
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      uname: cleanUname,
      upic: picUrl,
      usign: json['usign']?.toString() ?? '',
      level: json['level'] is int ? json['level'] : 0,
      fans: json['fans'] is int ? json['fans'] : 0,
      videos: json['videos'] is int ? json['videos'] : 0,
      isOfficial: official != null && official['type'] != -1,
      officialDesc: official != null ? official['desc']?.toString() ?? '' : '',
    );
  }
}

class SearchArticleItem {
  final int id;
  final String title;
  final String desc;
  final List<String> imageUrls;
  final String uname;
  final int mid;
  final int view;
  final int like;
  final int reply;
  final int pubTime;

  SearchArticleItem({
    required this.id,
    required this.title,
    required this.desc,
    required this.imageUrls,
    required this.uname,
    required this.mid,
    required this.view,
    required this.like,
    required this.reply,
    required this.pubTime,
  });

  factory SearchArticleItem.fromJson(Map<String, dynamic> json) {
    String cleanTitle = json['title']?.toString() ?? '';
    cleanTitle = cleanTitle.replaceAll(SearchSuggestItem._htmlTagRegex, '');

    String cleanDesc = json['desc']?.toString() ?? json['summary']?.toString() ?? '';
    cleanDesc = cleanDesc.replaceAll(SearchSuggestItem._htmlTagRegex, '');

    final List<String> imgs = [];
    if (json['image_urls'] is List) {
      for (final u in json['image_urls']) {
        var str = u.toString();
        if (str.startsWith('//')) {
          str = 'https:$str';
        } else if (str.startsWith('http://')) {
          str = str.replaceFirst('http://', 'https://');
        }
        imgs.add(str);
      }
    }

    return SearchArticleItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: cleanTitle,
      desc: cleanDesc,
      imageUrls: imgs,
      uname: json['uname']?.toString() ?? json['author_name']?.toString() ?? '',
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      view: json['view'] is int ? json['view'] : (json['stat']?['view'] is int ? json['stat']['view'] : 0),
      like: json['like'] is int ? json['like'] : (json['stat']?['like'] is int ? json['stat']['like'] : 0),
      reply: json['reply'] is int ? json['reply'] : (json['stat']?['reply'] is int ? json['stat']['reply'] : 0),
      pubTime: json['pub_time'] is int ? json['pub_time'] : (json['publish_time'] is int ? json['publish_time'] : 0),
    );
  }
}
