import 'package:dio/dio.dart';
import '../../models/user_model.dart';
import '../../models/video_model.dart';
import 'api_endpoints.dart';
import 'bili_http_client.dart';

class UserApiService {
  static final UserApiService _instance = UserApiService._internal();
  factory UserApiService() => _instance;
  UserApiService._internal();

  /// Get currently logged-in user info and statistics
  Future<UserInfo> getUserNav() async {
    try {
      final navRes = await BiliHttpClient().get(ApiEndpoints.nav);
      if (navRes.data != null && navRes.data['data'] != null) {
        final navData = navRes.data['data'];
        if (navData['isLogin'] == true) {
          // Fetch stat
          Map<String, dynamic>? statData;
          try {
            final statRes = await BiliHttpClient().get(ApiEndpoints.navStat);
            if (statRes.data != null && statRes.data['data'] != null) {
              statData = statRes.data['data'];
            }
          } catch (_) {}

          return UserInfo.fromJson(navData, statJson: statData);
        }
      }
      return UserInfo(isLogin: false);
    } catch (_) {
      return UserInfo(isLogin: false);
    }
  }

  /// Get user watch history
  Future<List<HistoryItem>> getUserHistory({int pn = 1, int ps = 20}) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.userHistory,
        queryParameters: {'pn': pn, 'ps': ps},
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final rawData = res.data['data'];
        final list = rawData is List
            ? rawData
            : (rawData is Map && rawData['list'] is List ? rawData['list'] as List : null);
        if (list != null) {
          return list.map((item) => HistoryItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Report video playback progress to Bilibili Cloud History
  Future<bool> reportHistory({
    required int aid,
    required int cid,
    required int progress,
    String bvid = '',
    int duration = 0,
  }) async {
    if (aid <= 0 || cid <= 0) return false;
    try {
      final csrf = BiliHttpClient().biliJct;
      final body = <String, dynamic>{
        'aid': aid,
        'cid': cid,
        'progress': progress,
        'type': 3,
        'sub_type': 0,
      };
      if (csrf != null) {
        body['csrf'] = csrf;
      }

      final res = await BiliHttpClient().post(
        ApiEndpoints.historyReport,
        data: FormData.fromMap(body),
      );

      if (res.data != null && res.data['code'] == 0) {
        return true;
      }

      // Also send heartbeat for reliability
      if (csrf != null) {
        final hbBody = <String, dynamic>{
          'aid': aid,
          'bvid': bvid,
          'cid': cid,
          'played_time': progress,
          'real_played_time': progress,
          'start_ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'type': 3,
          'dt': 2,
          'csrf': csrf,
        };
        await BiliHttpClient().post(
          ApiEndpoints.heartbeat,
          data: FormData.fromMap(hbBody),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get user followings (关注列表)
  Future<List<RelationUser>> getUserFollowings({required int vmid, int pn = 1, int ps = 20, String order = 'desc'}) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.userFollowings,
        queryParameters: {
          'vmid': vmid,
          'pn': pn,
          'ps': ps,
          'order': order,
          'order_type': 'attention',
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final list = res.data['data']['list'] as List?;
        if (list != null) {
          return list.map((item) => RelationUser.fromJson(item, defaultFollowing: true)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get user followers (粉丝列表)
  Future<List<RelationUser>> getUserFollowers({required int vmid, int pn = 1, int ps = 20}) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.userFollowers,
        queryParameters: {
          'vmid': vmid,
          'pn': pn,
          'ps': ps,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final list = res.data['data']['list'] as List?;
        if (list != null) {
          return list.map((item) => RelationUser.fromJson(item, defaultFollowing: false)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get Watch Later list (稍后观看列表)
  Future<List<WatchLaterItem>> getWatchLaterList({int pn = 1, int ps = 30}) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.toViewList,
        queryParameters: {
          'pn': pn,
          'ps': ps,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final list = res.data['data']['list'] as List?;
        if (list != null) {
          return list.map((item) => WatchLaterItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check if video is in Watch Later
  Future<bool> isInWatchLater(int aid) async {
    try {
      final list = await getWatchLaterList(pn: 1, ps: 100);
      return list.any((item) => item.aid == aid);
    } catch (_) {
      return false;
    }
  }

  /// Add video to Watch Later (添加稍后观看)
  Future<bool> addToWatchLater({required int aid, String? bvid}) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final mapData = <String, dynamic>{
        'aid': aid,
        'csrf': csrf,
      };
      if (bvid != null && bvid.isNotEmpty) {
        mapData['bvid'] = bvid;
      }

      final res = await BiliHttpClient().post(
        ApiEndpoints.toViewAdd,
        data: FormData.fromMap(mapData),
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  /// Delete video from Watch Later (从稍后观看删除)
  Future<bool> deleteFromWatchLater({required int aid}) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final res = await BiliHttpClient().post(
        ApiEndpoints.toViewDel,
        data: FormData.fromMap({
          'aid': aid,
          'csrf': csrf,
        }),
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  /// Clear all Watch Later videos (清空稍后观看)
  Future<bool> clearWatchLater() async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final res = await BiliHttpClient().post(
        ApiEndpoints.toViewClear,
        data: FormData.fromMap({
          'clean': true,
          'csrf': csrf,
        }),
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  /// Get user favorite folder list
  Future<List<FavFolder>> getUserFavFolders(int upMid) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.userFavFolders,
        queryParameters: {'up_mid': upMid},
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final list = res.data['data']['list'] as List?;
        if (list != null) {
          return list.map((item) => FavFolder.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get video list inside a favorite folder
  Future<List<VideoItem>> getFavFolderVideos(int mediaId, {int pn = 1, int ps = 20}) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.userFavList,
        queryParameters: {
          'media_id': mediaId,
          'pn': pn,
          'ps': ps,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final medias = res.data['data']['medias'] as List?;
        if (medias != null) {
          return medias.map((item) => VideoItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get relation statistics (粉丝数、关注数)
  Future<({int follower, int following})?> getUserRelationStat(int vmid) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.relationStat,
        queryParameters: {'vmid': vmid},
      );
      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final data = res.data['data'];
        final follower = data['follower'] is int
            ? data['follower'] as int
            : (int.tryParse(data['follower']?.toString() ?? '0') ?? 0);
        final following = data['following'] is int
            ? data['following'] as int
            : (int.tryParse(data['following']?.toString() ?? '0') ?? 0);
        return (follower: follower, following: following);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get UP space profile info (with merged follower / following stats)
  Future<UpSpaceInfo?> getUpSpaceInfo(int mid) async {
    try {
      final results = await Future.wait([
        BiliHttpClient().getWbi(
          ApiEndpoints.upSpaceInfo,
          queryParameters: {'mid': mid},
        ),
        getUserRelationStat(mid),
      ]);

      final res = results[0] as Response;
      final stat = results[1] as ({int follower, int following})?;

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(res.data['data']);
        if (stat != null) {
          data['fans'] = stat.follower;
          data['follower'] = stat.follower;
          data['attention'] = stat.following;
          data['following_count'] = stat.following;
        }
        return UpSpaceInfo.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get UP uploaded videos
  Future<List<VideoItem>> getUpSpaceVideos(int mid, {int pn = 1, int ps = 30}) async {
    try {
      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.upSpaceVideos,
        queryParameters: {
          'mid': mid,
          'pn': pn,
          'ps': ps,
          'order': 'pubdate',
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final list = res.data['data']['list'];
        if (list != null && list['vlist'] is List) {
          return (list['vlist'] as List)
              .map((item) => VideoItem.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Follow / Unfollow UP
  Future<bool> modifyRelation(int mid, {required int act}) async {
    // act: 1: follow, 2: unfollow
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final res = await BiliHttpClient().post(
        ApiEndpoints.upRelationModify,
        data: FormData.fromMap({
          'fid': mid,
          'act': act,
          're_src': 11,
          'csrf': csrf,
        }),
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }
}
