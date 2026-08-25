class Owner {
  final int mid;
  final String name;
  final String face;

  Owner({
    required this.mid,
    required this.name,
    required this.face,
  });

  factory Owner.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Owner(mid: 0, name: '', face: '');
    return Owner(
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      face: json['face']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'mid': mid,
    'name': name,
    'face': face,
  };
}

class Stat {
  final int view;
  final int danmaku;
  final int reply;
  final int favorite;
  final int coin;
  final int share;
  final int like;
  final int hisRank;

  Stat({
    this.view = 0,
    this.danmaku = 0,
    this.reply = 0,
    this.favorite = 0,
    this.coin = 0,
    this.share = 0,
    this.like = 0,
    this.hisRank = 0,
  });

  factory Stat.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Stat();
    return Stat(
      view: json['view'] is int ? json['view'] : int.tryParse(json['view']?.toString() ?? '0') ?? 0,
      danmaku: json['danmaku'] is int ? json['danmaku'] : int.tryParse(json['danmaku']?.toString() ?? '0') ?? 0,
      reply: json['reply'] is int ? json['reply'] : int.tryParse(json['reply']?.toString() ?? '0') ?? 0,
      favorite: json['favorite'] is int ? json['favorite'] : int.tryParse(json['favorite']?.toString() ?? '0') ?? 0,
      coin: json['coin'] is int ? json['coin'] : int.tryParse(json['coin']?.toString() ?? '0') ?? 0,
      share: json['share'] is int ? json['share'] : int.tryParse(json['share']?.toString() ?? '0') ?? 0,
      like: json['like'] is int ? json['like'] : int.tryParse(json['like']?.toString() ?? '0') ?? 0,
      hisRank: json['his_rank'] is int ? json['his_rank'] : 0,
    );
  }
}

class VideoPage {
  final int cid;
  final int page;
  final String from;
  final String part;
  final int duration;
  final String? vid;

  VideoPage({
    required this.cid,
    required this.page,
    required this.from,
    required this.part,
    required this.duration,
    this.vid,
  });

  factory VideoPage.fromJson(Map<String, dynamic> json) {
    return VideoPage(
      cid: json['cid'] is int ? json['cid'] : int.tryParse(json['cid']?.toString() ?? '0') ?? 0,
      page: json['page'] is int ? json['page'] : 1,
      from: json['from']?.toString() ?? '',
      part: json['part']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] : 0,
      vid: json['vid']?.toString(),
    );
  }
}

class VideoItem {
  final int aid;
  final String bvid;
  final int cid;
  final String title;
  final String pic;
  final String desc;
  final int duration;
  final int pubdate;
  final int ctime;
  final Owner owner;
  final Stat stat;
  final String? rcmdReason;

  VideoItem({
    required this.aid,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.pic,
    required this.desc,
    required this.duration,
    required this.pubdate,
    required this.ctime,
    required this.owner,
    required this.stat,
    this.rcmdReason,
  });

  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    // Clean html tags from title (search API returns <em class="keyword">)
    String cleanTitle = json['title']?.toString() ?? '';
    cleanTitle = cleanTitle.replaceAll(_htmlTagRegex, '');

    String picUrl = json['pic']?.toString() ??
        json['cover']?.toString() ??
        json['cover_url']?.toString() ??
        json['first_frame']?.toString() ??
        json['pic_url']?.toString() ??
        json['archive']?['pic']?.toString() ??
        '';
    if (picUrl.startsWith('//')) {
      picUrl = 'https:$picUrl';
    } else if (picUrl.startsWith('http://')) {
      picUrl = picUrl.replaceFirst('http://', 'https://');
    }

    String rcmd = '';
    if (json['rcmd_reason'] != null) {
      if (json['rcmd_reason'] is Map) {
        rcmd = json['rcmd_reason']['content']?.toString() ?? '';
      } else if (json['rcmd_reason'] is String) {
        rcmd = json['rcmd_reason'];
      }
    }

    Owner ownerObj;
    if (json['owner'] != null) {
      ownerObj = Owner.fromJson(json['owner']);
    } else {
      // Search API format or top format
      ownerObj = Owner(
        mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
        name: json['author']?.toString() ?? json['up_name']?.toString() ?? json['name']?.toString() ?? '',
        face: json['up_face']?.toString() ?? json['face']?.toString() ?? '',
      );
    }

    Stat statObj;
    if (json['stat'] != null) {
      statObj = Stat.fromJson(json['stat']);
    } else {
      statObj = Stat(
        view: json['play'] is int ? json['play'] : int.tryParse(json['play']?.toString() ?? '0') ?? 0,
        danmaku: json['video_review'] is int ? json['video_review'] : int.tryParse(json['video_review']?.toString() ?? '0') ?? 0,
        like: json['like'] is int ? json['like'] : int.tryParse(json['like']?.toString() ?? '0') ?? 0,
        favorite: json['favorites'] is int ? json['favorites'] : int.tryParse(json['favorites']?.toString() ?? '0') ?? 0,
      );
    }

    // Parse duration (can be "03:45" string or seconds int)
    int durationSec = 0;
    final rawDur = json['duration'];
    if (rawDur is int) {
      durationSec = rawDur;
    } else if (rawDur is String) {
      if (rawDur.contains(':')) {
        final parts = rawDur.split(':');
        if (parts.length == 2) {
          durationSec = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        } else if (parts.length == 3) {
          durationSec = (int.tryParse(parts[0]) ?? 0) * 3600 + (int.tryParse(parts[1]) ?? 0) * 60 + (int.tryParse(parts[2]) ?? 0);
        }
      } else {
        durationSec = int.tryParse(rawDur) ?? 0;
      }
    }

    return VideoItem(
      aid: json['aid'] is int ? json['aid'] : int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
      bvid: json['bvid']?.toString() ?? '',
      cid: json['cid'] is int ? json['cid'] : int.tryParse(json['cid']?.toString() ?? '0') ?? 0,
      title: cleanTitle,
      pic: picUrl,
      desc: json['desc']?.toString() ?? '',
      duration: durationSec,
      pubdate: json['pubdate'] is int ? json['pubdate'] : (json['senddate'] is int ? json['senddate'] : 0),
      ctime: json['ctime'] is int ? json['ctime'] : 0,
      owner: ownerObj,
      stat: statObj,
      rcmdReason: rcmd.isNotEmpty ? rcmd : null,
    );
  }
}

class UgcEpisode {
  final int id;
  final int aid;
  final String bvid;
  final int cid;
  final String title;
  final String cover;
  final int duration;
  final int page;

  UgcEpisode({
    required this.id,
    required this.aid,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.duration,
    required this.page,
  });

  factory UgcEpisode.fromJson(Map<String, dynamic> json) {
    String coverUrl = json['arc']?['pic']?.toString() ?? json['cover']?.toString() ?? '';
    if (coverUrl.startsWith('//')) {
      coverUrl = 'https:$coverUrl';
    } else if (coverUrl.startsWith('http://')) {
      coverUrl = coverUrl.replaceFirst('http://', 'https://');
    }

    String epTitle = json['title']?.toString() ?? json['arc']?['title']?.toString() ?? '';
    epTitle = epTitle.replaceAll(VideoItem._htmlTagRegex, '');

    return UgcEpisode(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      aid: json['aid'] is int ? json['aid'] : int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
      bvid: json['bvid']?.toString() ?? '',
      cid: json['cid'] is int ? json['cid'] : int.tryParse(json['cid']?.toString() ?? '0') ?? 0,
      title: epTitle,
      cover: coverUrl,
      duration: json['arc']?['duration'] is int ? json['arc']['duration'] : (json['page']?['duration'] is int ? json['page']['duration'] : 0),
      page: json['page']?['page'] is int ? json['page']['page'] : 1,
    );
  }
}

class UgcSection {
  final int seasonId;
  final int id;
  final String title;
  final List<UgcEpisode> episodes;

  UgcSection({
    required this.seasonId,
    required this.id,
    required this.title,
    required this.episodes,
  });

  factory UgcSection.fromJson(Map<String, dynamic> json) {
    final List<UgcEpisode> epList = [];
    if (json['episodes'] is List) {
      for (final e in json['episodes']) {
        epList.add(UgcEpisode.fromJson(e));
      }
    }
    return UgcSection(
      seasonId: json['season_id'] is int ? json['season_id'] : 0,
      id: json['id'] is int ? json['id'] : 0,
      title: json['title']?.toString() ?? '',
      episodes: epList,
    );
  }
}

class UgcSeason {
  final int id;
  final String title;
  final String cover;
  final int mid;
  final String intro;
  final int epCount;
  final List<UgcSection> sections;

  UgcSeason({
    required this.id,
    required this.title,
    required this.cover,
    required this.mid,
    required this.intro,
    required this.epCount,
    required this.sections,
  });

  factory UgcSeason.fromJson(Map<String, dynamic> json) {
    String coverUrl = json['cover']?.toString() ?? '';
    if (coverUrl.startsWith('//')) {
      coverUrl = 'https:$coverUrl';
    } else if (coverUrl.startsWith('http://')) {
      coverUrl = coverUrl.replaceFirst('http://', 'https://');
    }

    final List<UgcSection> secList = [];
    if (json['sections'] is List) {
      for (final s in json['sections']) {
        secList.add(UgcSection.fromJson(s));
      }
    }

    return UgcSeason(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      cover: coverUrl,
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      intro: json['intro']?.toString() ?? '',
      epCount: json['ep_count'] is int ? json['ep_count'] : 0,
      sections: secList,
    );
  }
}

class VideoChapter {
  final int from; // in seconds
  final int to;   // in seconds
  final String title;
  final String? imgUrl;

  VideoChapter({
    required this.from,
    required this.to,
    required this.title,
    this.imgUrl,
  });

  factory VideoChapter.fromJson(Map<String, dynamic> json) {
    return VideoChapter(
      from: json['from'] is int ? json['from'] : int.tryParse(json['from']?.toString() ?? '0') ?? 0,
      to: json['to'] is int ? json['to'] : int.tryParse(json['to']?.toString() ?? '0') ?? 0,
      title: json['content']?.toString() ?? json['title']?.toString() ?? '',
      imgUrl: json['imgUrl']?.toString(),
    );
  }
}

class VideoDetail {
  final VideoItem videoItem;
  final List<VideoPage> pages;
  final UgcSeason? ugcSeason;
  final List<VideoChapter> chapters;
  final List<String> tags;
  final bool isLiked;
  final bool isCoin;
  final bool isFav;

  VideoDetail({
    required this.videoItem,
    required this.pages,
    this.ugcSeason,
    this.chapters = const [],
    this.tags = const [],
    this.isLiked = false,
    this.isCoin = false,
    this.isFav = false,
  });

  static final RegExp _chapterTimeRegex = RegExp(r'(?:^|[\r\n])\s*(?:(?:(\d{1,2}):)?(\d{1,2}):(\d{2}))\s*[-—–~:：\s]?\s*([^\r\n]+)');

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    final videoItem = VideoItem.fromJson(json);
    final List<VideoPage> pages = [];
    if (json['pages'] is List) {
      for (final p in json['pages']) {
        pages.add(VideoPage.fromJson(p));
      }
    }

    UgcSeason? season;
    if (json['ugc_season'] != null && json['ugc_season'] is Map<String, dynamic>) {
      season = UgcSeason.fromJson(json['ugc_season']);
    }

    final List<VideoChapter> chapters = [];
    if (json['view_points'] is List) {
      for (final vp in json['view_points']) {
        if (vp is Map<String, dynamic>) {
          chapters.add(VideoChapter.fromJson(vp));
        }
      }
    }

    // Fallback: Parse timestamps from video description if no official view_points
    if (chapters.isEmpty && videoItem.desc.isNotEmpty) {
      final matches = _chapterTimeRegex.allMatches(videoItem.desc).toList();
      if (matches.length >= 2) {
        for (int i = 0; i < matches.length; i++) {
          final m = matches[i];
          final hours = m.group(1) != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
          final mins = int.tryParse(m.group(2)!) ?? 0;
          final secs = int.tryParse(m.group(3)!) ?? 0;
          final totalSec = hours * 3600 + mins * 60 + secs;
          final title = (m.group(4) ?? '').trim();
          if (title.isNotEmpty) {
            int toSec = videoItem.duration;
            if (i + 1 < matches.length) {
              final nextM = matches[i + 1];
              final nextH = nextM.group(1) != null ? int.tryParse(nextM.group(1)!) ?? 0 : 0;
              final nextMin = int.tryParse(nextM.group(2)!) ?? 0;
              final nextS = int.tryParse(nextM.group(3)!) ?? 0;
              toSec = nextH * 3600 + nextMin * 60 + nextS;
            }
            chapters.add(VideoChapter(
              from: totalSec,
              to: toSec > totalSec ? toSec : (totalSec + 60),
              title: title,
            ));
          }
        }
      }
    }

    return VideoDetail(
      videoItem: videoItem,
      pages: pages,
      ugcSeason: season,
      chapters: chapters,
    );
  }
}

class VideoRelation {
  final bool attention;
  final bool favorite;
  final bool seasonFav;
  final bool like;
  final bool dislike;
  final int coin;

  VideoRelation({
    this.attention = false,
    this.favorite = false,
    this.seasonFav = false,
    this.like = false,
    this.dislike = false,
    this.coin = 0,
  });

  factory VideoRelation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VideoRelation();
    return VideoRelation(
      attention: json['attention'] == true || json['attention'] == 1,
      favorite: json['favorite'] == true || json['favorite'] == 1,
      seasonFav: json['season_fav'] == true || json['season_fav'] == 1,
      like: json['like'] == true || json['like'] == 1,
      dislike: json['dislike'] == true || json['dislike'] == 1,
      coin: json['coin'] is int ? json['coin'] : int.tryParse(json['coin']?.toString() ?? '0') ?? 0,
    );
  }
}

