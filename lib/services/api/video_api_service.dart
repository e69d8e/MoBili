import 'package:dio/dio.dart';
import '../../models/video_model.dart';
import '../../models/play_url_model.dart';
import 'api_endpoints.dart';
import 'bili_http_client.dart';

class VideoApiService {
  static final VideoApiService _instance = VideoApiService._internal();
  factory VideoApiService() => _instance;
  VideoApiService._internal();

  /// Get Popular (热门) videos
  Future<List<VideoItem>> getPopularVideos({int pn = 1, int ps = 20}) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.popular,
        queryParameters: {'pn': pn, 'ps': ps},
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final list = res.data['data']['list'] as List?;
        if (list != null) {
          return list
              .map((item) => VideoItem.fromJson(item))
              .where((v) => v.bvid.isNotEmpty && v.title.isNotEmpty && v.pic.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get Recommend (推荐) feed with WBI signature
  Future<List<VideoItem>> getRecommendFeed({int ps = 20, int freshIdx = 1}) async {
    try {
      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.feedRcmd,
        queryParameters: {
          'ps': ps,
          'fresh_type': 4,
          'feed_version': 'V8',
          'brush': 1,
          'fresh_idx': freshIdx,
          'fresh_idx_1hr': freshIdx,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final items = res.data['data']['item'] as List?;
        if (items != null) {
          return items
              .where((item) {
                // Must be normal video (not ad / cm / live / banner)
                if (item['goto'] != null && item['goto'] != 'av') return false;
                final bvid = item['bvid']?.toString() ?? '';
                final title = item['title']?.toString() ?? '';
                final pic = item['pic']?.toString() ?? item['cover']?.toString() ?? '';
                return bvid.isNotEmpty && title.isNotEmpty && pic.isNotEmpty;
              })
              .map((item) => VideoItem.fromJson(item))
              .where((v) => v.bvid.isNotEmpty && v.title.isNotEmpty && v.pic.isNotEmpty)
              .toList();
        }
      }
      // Fallback to popular videos if feed rcmd fails
      return await getPopularVideos(pn: freshIdx, ps: ps);
    } catch (_) {
      return await getPopularVideos(pn: freshIdx, ps: ps);
    }
  }

  /// Get Ranking (排行榜) videos
  Future<List<VideoItem>> getRankingVideos({int rid = 0, String type = 'all'}) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.ranking,
        queryParameters: {'rid': rid, 'type': type},
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final list = res.data['data']['list'] as List?;
        if (list != null) {
          return list
              .map((item) => VideoItem.fromJson(item))
              .where((v) => v.bvid.isNotEmpty && v.title.isNotEmpty && v.pic.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get Video Detail & metadata
  Future<VideoDetail?> getVideoDetail(String bvid) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.videoView,
        queryParameters: {'bvid': bvid},
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        return VideoDetail.fromJson(res.data['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get Video Stream Play URL (qn: 16=360P, 32=480P, 64=720P, 80=1080P, 112=1080P+, 116=1080P60, 120=4K)
  /// fnval=0 requests progressive stream with full resolution unlocked for logged-in accounts
  Future<PlayUrlInfo?> getVideoPlayUrl({
    required String bvid,
    required int cid,
    int qn = 80, // Default 1080P (server auto-downgrades if guest or lower resolution)
    int fnval = 0, // 0 = Progressive stream with video+audio (zero delay, instant load)
  }) async {
    try {
      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.playUrl,
        queryParameters: {
          'bvid': bvid,
          'cid': cid,
          'qn': qn,
          'fnval': fnval,
          'fnver': 0,
          'fourk': 1,
          'high_quality': 1,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        return PlayUrlInfo.fromJson(res.data['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get Dedicated Audio Stream Play URL (fnval=16 DASH audio stream)
  Future<String?> getVideoAudioUrl({
    required String bvid,
    required int cid,
  }) async {
    try {
      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.playUrl,
        queryParameters: {
          'bvid': bvid,
          'cid': cid,
          'qn': 64,
          'fnval': 16, // DASH format for pure audio streams
          'fnver': 0,
          'fourk': 1,
          'high_quality': 1,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final info = PlayUrlInfo.fromJson(res.data['data']);
        if (info.primaryAudioUrl != null && info.primaryAudioUrl!.isNotEmpty) {
          return info.primaryAudioUrl;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get Related Videos for recommendations
  Future<List<VideoItem>> getRelatedVideos(String bvid) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.relatedVideos,
        queryParameters: {'bvid': bvid},
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] is List) {
        return (res.data['data'] as List)
            .map((item) => VideoItem.fromJson(item))
            .where((v) => v.bvid.isNotEmpty && v.title.isNotEmpty && v.pic.isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Like / Dislike Video
  Future<bool> likeVideo(String bvid, {required bool like}) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final res = await BiliHttpClient().post(
        ApiEndpoints.likeVideo,
        queryParameters: {
          'bvid': bvid,
          'like': like ? 1 : 2,
          'csrf': csrf,
        },
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  /// Triple combo (Like + Coin + Fav)
  Future<bool> tripleCombo(String bvid) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final res = await BiliHttpClient().post(
        ApiEndpoints.tripleCombo,
        queryParameters: {
          'bvid': bvid,
          'csrf': csrf,
        },
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  /// Add Coin to video (multiply: 1 or 2, selectLike: true to like simultaneously)
  Future<({bool success, String message, bool liked})> addCoin({
    required String bvid,
    int multiply = 1,
    bool selectLike = true,
  }) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) {
      return (success: false, message: '请先登录', liked: false);
    }

    try {
      final res = await BiliHttpClient().post(
        ApiEndpoints.coinVideo,
        data: FormData.fromMap({
          'bvid': bvid,
          'multiply': multiply,
          'select_like': selectLike ? 1 : 0,
          'csrf': csrf,
        }),
      );

      if (res.data != null) {
        final code = res.data['code'] as int? ?? -1;
        final msg = res.data['message']?.toString() ?? '';
        final likeStatus = res.data['data']?['like'] == true;
        if (code == 0) {
          return (success: true, message: '投币成功', liked: likeStatus);
        } else {
          return (success: false, message: msg.isNotEmpty ? msg : '投币失败', liked: false);
        }
      }
      return (success: false, message: '投币失败', liked: false);
    } catch (_) {
      return (success: false, message: '网络错误，请稍后重试', liked: false);
    }
  }

  /// Get Video Relation (attention/follow, like, coin, favorite)
  Future<VideoRelation?> getVideoRelation({required String bvid, int? aid}) async {
    try {
      final query = <String, dynamic>{'bvid': bvid};
      if (aid != null && aid > 0) query['aid'] = aid;

      final res = await BiliHttpClient().get(
        ApiEndpoints.archiveRelation,
        queryParameters: query,
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        return VideoRelation.fromJson(res.data['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

