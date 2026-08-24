class UserInfo {
  final bool isLogin;
  final int mid;
  final String uname;
  final String face;
  final int level;
  final double money;
  final int vipType; // 0: none, 1: month, 2: year
  final int vipStatus;
  final String vipLabel;
  final int following;
  final int follower;
  final int dynamicCount;

  UserInfo({
    this.isLogin = false,
    this.mid = 0,
    this.uname = '',
    this.face = '',
    this.level = 0,
    this.money = 0.0,
    this.vipType = 0,
    this.vipStatus = 0,
    this.vipLabel = '',
    this.following = 0,
    this.follower = 0,
    this.dynamicCount = 0,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? statJson}) {
    final bool loggedIn = json['isLogin'] == true;
    if (!loggedIn) {
      return UserInfo(isLogin: false);
    }

    String faceUrl = json['face']?.toString() ?? '';
    if (faceUrl.startsWith('http://')) {
      faceUrl = faceUrl.replaceFirst('http://', 'https://');
    }

    int lvl = 0;
    if (json['level_info'] != null && json['level_info']['current_level'] is int) {
      lvl = json['level_info']['current_level'];
    }

    String vipTxt = '';
    int vType = 0;
    int vStatus = 0;
    if (json['vip'] != null) {
      vType = json['vip']['type'] is int ? json['vip']['type'] : 0;
      vStatus = json['vip']['status'] is int ? json['vip']['status'] : 0;
      if (json['vip']['label'] != null) {
        vipTxt = json['vip']['label']['text']?.toString() ?? '';
      }
    }

    int followings = 0;
    int followers = 0;
    int dynamics = 0;
    if (statJson != null) {
      followings = statJson['following'] is int ? statJson['following'] : 0;
      followers = statJson['follower'] is int ? statJson['follower'] : 0;
      dynamics = statJson['dynamic_count'] is int ? statJson['dynamic_count'] : 0;
    }

    return UserInfo(
      isLogin: true,
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      uname: json['uname']?.toString() ?? '',
      face: faceUrl,
      level: lvl,
      money: json['money'] is num ? (json['money'] as num).toDouble() : 0.0,
      vipType: vType,
      vipStatus: vStatus,
      vipLabel: vipTxt,
      following: followings,
      follower: followers,
      dynamicCount: dynamics,
    );
  }
}

class UpSpaceInfo {
  final int mid;
  final String name;
  final String sex;
  final String face;
  final String sign;
  final int level;
  final String topPhoto;
  final int fans;
  final int attention;
  final bool isFollowing;

  UpSpaceInfo({
    required this.mid,
    required this.name,
    required this.sex,
    required this.face,
    required this.sign,
    required this.level,
    required this.topPhoto,
    this.fans = 0,
    this.attention = 0,
    this.isFollowing = false,
  });

  factory UpSpaceInfo.fromJson(Map<String, dynamic> json) {
    String faceUrl = json['face']?.toString() ?? '';
    if (faceUrl.startsWith('//')) {
      faceUrl = 'https:$faceUrl';
    } else if (faceUrl.startsWith('http://')) {
      faceUrl = faceUrl.replaceFirst('http://', 'https://');
    }

    String topPhotoUrl = json['top_photo']?.toString() ??
        json['top_photo_url']?.toString() ??
        json['banner']?.toString() ??
        json['top_photo_arc']?.toString() ??
        '';
    if (topPhotoUrl.startsWith('//')) {
      topPhotoUrl = 'https:$topPhotoUrl';
    } else if (topPhotoUrl.startsWith('http://')) {
      topPhotoUrl = topPhotoUrl.replaceFirst('http://', 'https://');
    }

    return UpSpaceInfo(
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      sex: json['sex']?.toString() ?? '',
      face: faceUrl,
      sign: json['sign']?.toString() ?? '',
      level: json['level'] is int ? json['level'] : 0,
      topPhoto: topPhotoUrl,
      fans: json['fans'] is int ? json['fans'] : (json['stat']?['fans'] is int ? json['stat']['fans'] : 0),
      attention: json['attention'] is int ? json['attention'] : (json['stat']?['attention'] is int ? json['stat']['attention'] : 0),
      isFollowing: json['following'] == true || json['is_followed'] == true,
    );
  }
}

class FavFolder {
  final int id;
  final int fid;
  final int mid;
  final String title;
  final String cover;
  final int mediaCount;
  final int viewCount;

  FavFolder({
    required this.id,
    required this.fid,
    required this.mid,
    required this.title,
    required this.cover,
    required this.mediaCount,
    required this.viewCount,
  });

  factory FavFolder.fromJson(Map<String, dynamic> json) {
    String coverUrl = json['cover']?.toString() ?? '';
    if (coverUrl.startsWith('http://')) {
      coverUrl = coverUrl.replaceFirst('http://', 'https://');
    }

    return FavFolder(
      id: json['id'] is int ? json['id'] : 0,
      fid: json['fid'] is int ? json['fid'] : 0,
      mid: json['mid'] is int ? json['mid'] : 0,
      title: json['title']?.toString() ?? '',
      cover: coverUrl,
      mediaCount: json['media_count'] is int ? json['media_count'] : 0,
      viewCount: json['view_count'] is int ? json['view_count'] : 0,
    );
  }
}

class HistoryItem {
  final int aid;
  final String bvid;
  final int cid;
  final String title;
  final String cover;
  final int viewAt;
  final int progress; // in seconds, -1 for finished
  final int duration;
  final String ownerName;
  final int ownerMid;

  HistoryItem({
    required this.aid,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.viewAt,
    required this.progress,
    required this.duration,
    required this.ownerName,
    required this.ownerMid,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final history = json['history'] is Map ? json['history'] as Map<String, dynamic> : {};
    
    // Support pic or cover from different history API variations
    String coverUrl = json['pic']?.toString() ?? json['cover']?.toString() ?? history['pic']?.toString() ?? '';
    if (coverUrl.startsWith('//')) {
      coverUrl = 'https:$coverUrl';
    } else if (coverUrl.startsWith('http://')) {
      coverUrl = coverUrl.replaceFirst('http://', 'https://');
    }

    final authorName = json['author_name']?.toString() ??
        (json['owner'] is Map ? json['owner']['name']?.toString() : null) ??
        json['author']?.toString() ??
        '';

    final authorMid = json['author_mid'] is int
        ? json['author_mid'] as int
        : (json['owner'] is Map && json['owner']['mid'] is int
            ? json['owner']['mid'] as int
            : 0);

    return HistoryItem(
      aid: history['oid'] is int
          ? history['oid'] as int
          : (json['oid'] is int
              ? json['oid'] as int
              : (json['aid'] is int ? json['aid'] as int : 0)),
      bvid: history['bvid']?.toString() ?? json['bvid']?.toString() ?? '',
      cid: history['cid'] is int
          ? history['cid'] as int
          : (json['cid'] is int ? json['cid'] as int : 0),
      title: json['title']?.toString() ?? '',
      cover: coverUrl,
      viewAt: json['view_at'] is int ? json['view_at'] as int : 0,
      progress: json['progress'] is int ? json['progress'] as int : 0,
      duration: json['duration'] is int ? json['duration'] as int : 0,
      ownerName: authorName,
      ownerMid: authorMid,
    );
  }
}

class RelationUser {
  final int mid;
  final String uname;
  final String face;
  final String sign;
  final int vipType;
  final String vipLabel;
  final int mtime;
  final int attribute;
  final bool isFollowing;

  RelationUser({
    required this.mid,
    required this.uname,
    required this.face,
    required this.sign,
    this.vipType = 0,
    this.vipLabel = '',
    this.mtime = 0,
    this.attribute = 0,
    this.isFollowing = true,
  });

  factory RelationUser.fromJson(Map<String, dynamic> json, {bool defaultFollowing = true}) {
    String faceUrl = json['face']?.toString() ?? '';
    if (faceUrl.startsWith('//')) {
      faceUrl = 'https:$faceUrl';
    } else if (faceUrl.startsWith('http://')) {
      faceUrl = faceUrl.replaceFirst('http://', 'https://');
    }

    int vType = 0;
    String vLabel = '';
    if (json['vip'] is Map) {
      final vip = json['vip'];
      vType = vip['vipType'] is int
          ? vip['vipType']
          : (vip['type'] is int ? vip['type'] : 0);
      if (vip['label'] is Map) {
        vLabel = vip['label']['text']?.toString() ?? '';
      }
    }

    // attribute: 0 = not following, 2 = following, 6 = mutual following
    final attr = json['attribute'] is int ? json['attribute'] as int : 0;
    final following = json.containsKey('attribute') ? (attr == 2 || attr == 6) : defaultFollowing;

    return RelationUser(
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      uname: json['uname']?.toString() ?? '',
      face: faceUrl,
      sign: json['sign']?.toString() ?? '',
      vipType: vType,
      vipLabel: vLabel,
      mtime: json['mtime'] is int ? json['mtime'] : 0,
      attribute: attr,
      isFollowing: following,
    );
  }
}

class WatchLaterItem {
  final int aid;
  final String bvid;
  final int cid;
  final String title;
  final String pic;
  final String ownerName;
  final String ownerFace;
  final int ownerMid;
  final int duration;
  final int pubdate;
  final int addAt;
  final int progress;

  WatchLaterItem({
    required this.aid,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.pic,
    required this.ownerName,
    required this.ownerFace,
    required this.ownerMid,
    required this.duration,
    required this.pubdate,
    required this.addAt,
    this.progress = 0,
  });

  factory WatchLaterItem.fromJson(Map<String, dynamic> json) {
    String picUrl = json['pic']?.toString() ?? json['cover']?.toString() ?? '';
    if (picUrl.startsWith('//')) {
      picUrl = 'https:$picUrl';
    } else if (picUrl.startsWith('http://')) {
      picUrl = picUrl.replaceFirst('http://', 'https://');
    }

    String uName = '';
    String uFace = '';
    int uMid = 0;
    if (json['owner'] is Map) {
      final owner = json['owner'];
      uName = owner['name']?.toString() ?? '';
      uFace = owner['face']?.toString() ?? '';
      uMid = owner['mid'] is int ? owner['mid'] : (int.tryParse(owner['mid']?.toString() ?? '0') ?? 0);
    } else {
      uName = json['author_name']?.toString() ?? json['author']?.toString() ?? '';
      uMid = json['author_mid'] is int ? json['author_mid'] : (int.tryParse(json['author_mid']?.toString() ?? '0') ?? 0);
    }

    if (uFace.startsWith('//')) {
      uFace = 'https:$uFace';
    } else if (uFace.startsWith('http://')) {
      uFace = uFace.replaceFirst('http://', 'https://');
    }

    return WatchLaterItem(
      aid: json['aid'] is int ? json['aid'] : (int.tryParse(json['aid']?.toString() ?? '0') ?? (json['id'] is int ? json['id'] : 0)),
      bvid: json['bvid']?.toString() ?? '',
      cid: json['cid'] is int ? json['cid'] : (int.tryParse(json['cid']?.toString() ?? '0') ?? 0),
      title: json['title']?.toString() ?? '',
      pic: picUrl,
      ownerName: uName,
      ownerFace: uFace,
      ownerMid: uMid,
      duration: json['duration'] is int ? json['duration'] : (int.tryParse(json['duration']?.toString() ?? '0') ?? 0),
      pubdate: json['pubdate'] is int ? json['pubdate'] : (json['ctime'] is int ? json['ctime'] : 0),
      addAt: json['add_at'] is int ? json['add_at'] : (json['view_at'] is int ? json['view_at'] : 0),
      progress: json['progress'] is int ? json['progress'] : 0,
    );
  }
}
