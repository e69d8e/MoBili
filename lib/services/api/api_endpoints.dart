class ApiEndpoints {
  static const String biliBase = 'https://api.bilibili.com';
  static const String passportBase = 'https://passport.bilibili.com';
  static const String searchBase = 'https://s.search.bilibili.com';

  // Device & Security
  static const String spiFinger = '$biliBase/x/frontend/finger/spi';
  static const String nav = '$biliBase/x/web-interface/nav';
  static const String navStat = '$biliBase/x/web-interface/nav/stat';

  // Video Feeds
  static const String feedRcmd = '$biliBase/x/web-interface/wbi/index/top/feed/rcmd';
  static const String popular = '$biliBase/x/web-interface/popular';
  static const String ranking = '$biliBase/x/web-interface/ranking/v2';

  // Video Detail & Playback
  static const String videoView = '$biliBase/x/web-interface/view';
  static const String playUrl = '$biliBase/x/player/wbi/playurl';
  static const String playUrlV2 = '$biliBase/x/player/playurl';
  static const String playerV2 = '$biliBase/x/player/wbi/v2';
  static const String playerInfo = '$biliBase/x/player/v2';
  static const String danmakuList = '$biliBase/x/v1/dm/list.so';
  static const String danmakuSeg = '$biliBase/x/v2/dm/web/seg.so';
  static const String relatedVideos = '$biliBase/x/web-interface/archive/related';

  // Video Comments
  static const String replyMain = '$biliBase/x/v2/reply/wbi/main';
  static const String replyList = '$biliBase/x/v2/reply';
  static const String replySub = '$biliBase/x/v2/reply/reply';
  static const String replyAction = '$biliBase/x/v2/reply/action';
  static const String replyAdd = '$biliBase/x/v2/reply/add';

  // Video Interactions
  static const String archiveRelation = '$biliBase/x/web-interface/archive/relation';
  static const String likeVideo = '$biliBase/x/web-interface/archive/like';
  static const String hasLike = '$biliBase/x/web-interface/archive/has/like';
  static const String coinVideo = '$biliBase/x/web-interface/coin/add';
  static const String favVideo = '$biliBase/x/v3/fav/resource/deal';
  static const String tripleCombo = '$biliBase/x/web-interface/archive/like/triple';

  // Search
  static const String searchAll = '$biliBase/x/web-interface/wbi/search/all/v2';
  static const String searchType = '$biliBase/x/web-interface/wbi/search/type';
  static const String searchSquare = '$biliBase/x/web-interface/wbi/search/square';
  static const String searchSuggest = '$searchBase/main/suggest';

  // User & Profile
  static const String userHistory = '$biliBase/x/v2/history';
  static const String historyReport = '$biliBase/x/v2/history/report';
  static const String heartbeat = '$biliBase/x/click-interface/web/heartbeat';
  static const String userFavFolders = '$biliBase/x/v3/fav/folder/created/list-all';
  static const String userFavList = '$biliBase/x/v3/fav/resource/list';
  static const String userDynamic = '$biliBase/x/polymer/web-dynamic/v1/feed/all';
  static const String dynamicDetail = '$biliBase/x/polymer/web-dynamic/v1/detail';
  static const String opusDetail = '$biliBase/x/polymer/web-dynamic/v1/opus/detail';
  static const String userFollowings = '$biliBase/x/relation/followings';
  static const String userFollowers = '$biliBase/x/relation/followers';
  static const String relationStat = '$biliBase/x/relation/stat';

  // Watch Later (稍后观看)
  static const String toViewList = '$biliBase/x/v2/history/toview/web';
  static const String toViewAdd = '$biliBase/x/v2/history/toview/add';
  static const String toViewDel = '$biliBase/x/v2/history/toview/del';
  static const String toViewClear = '$biliBase/x/v2/history/toview/clear';
  
  // UP Space
  static const String upSpaceInfo = '$biliBase/x/space/wbi/acc/info';
  static const String upSpaceVideos = '$biliBase/x/space/wbi/arc/search';
  static const String upRelationModify = '$biliBase/x/relation/modify';

  // Auth / QR Login
  static const String qrGenerate = '$passportBase/x/passport-login/web/qrcode/generate';
  static const String qrPoll = '$passportBase/x/passport-login/web/qrcode/poll';
}
