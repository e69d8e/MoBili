class CommentMember {
  final int mid;
  final String uname;
  final String avatar;
  final int level;
  final String sign;

  CommentMember({
    required this.mid,
    required this.uname,
    required this.avatar,
    required this.level,
    this.sign = '',
  });

  factory CommentMember.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CommentMember(mid: 0, uname: '', avatar: '', level: 0);
    int lvl = 0;
    if (json['level_info'] != null && json['level_info']['current_level'] is int) {
      lvl = json['level_info']['current_level'];
    }

    String avatarUrl = json['avatar']?.toString() ?? '';
    if (avatarUrl.startsWith('http://')) {
      avatarUrl = avatarUrl.replaceFirst('http://', 'https://');
    }

    return CommentMember(
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      uname: json['uname']?.toString() ?? '',
      avatar: avatarUrl,
      level: lvl,
      sign: json['sign']?.toString() ?? '',
    );
  }
}

class CommentItem {
  final int rpid;
  final int oid;
  final int mid;
  final int root;
  final int parent;
  final int count;
  final int rcount;
  final int like;
  final int ctime;
  final String message;
  final CommentMember member;
  final List<CommentItem> replies;
  bool isLiked;

  CommentItem({
    required this.rpid,
    required this.oid,
    required this.mid,
    required this.root,
    required this.parent,
    required this.count,
    required this.rcount,
    required this.like,
    required this.ctime,
    required this.message,
    required this.member,
    this.replies = const [],
    this.isLiked = false,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    String msg = '';
    if (json['content'] != null) {
      msg = json['content']['message']?.toString() ?? '';
    }

    final List<CommentItem> subReplies = [];
    if (json['replies'] is List) {
      for (final r in json['replies']) {
        subReplies.add(CommentItem.fromJson(r));
      }
    }

    return CommentItem(
      rpid: json['rpid'] is int ? json['rpid'] : int.tryParse(json['rpid']?.toString() ?? '0') ?? 0,
      oid: json['oid'] is int ? json['oid'] : int.tryParse(json['oid']?.toString() ?? '0') ?? 0,
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      root: json['root'] is int ? json['root'] : 0,
      parent: json['parent'] is int ? json['parent'] : 0,
      count: json['count'] is int ? json['count'] : 0,
      rcount: json['rcount'] is int ? json['rcount'] : 0,
      like: json['like'] is int ? json['like'] : 0,
      ctime: json['ctime'] is int ? json['ctime'] : 0,
      message: msg,
      member: CommentMember.fromJson(json['member']),
      replies: subReplies,
      isLiked: (json['action'] == 1),
    );
  }
}

class CommentResult {
  final List<CommentItem> replies;
  final int nextCursor;
  final String nextOffset;
  final bool isEnd;
  final int totalCount;

  CommentResult({
    this.replies = const [],
    this.nextCursor = 0,
    this.nextOffset = '',
    this.isEnd = true,
    this.totalCount = 0,
  });
}
