import 'package:dio/dio.dart';
import '../../models/dynamic_model.dart';
import 'api_endpoints.dart';
import 'bili_http_client.dart';

class DynamicApiService {
  static final DynamicApiService _instance = DynamicApiService._internal();
  factory DynamicApiService() => _instance;
  DynamicApiService._internal();

  /// Get user following dynamic feed (全部/视频/图文)
  /// [type]: 'all', 'video', 'article'
  Future<DynamicFeedResponse?> getDynamicFeed({
    String type = 'all',
    String offset = '',
    int page = 1,
  }) async {
    try {
      final query = <String, dynamic>{
        'timezone_offset': -480,
        'type': type,
        'features': 'itemOpusStyle',
      };
      if (offset.isNotEmpty) {
        query['offset'] = offset;
      }
      if (page > 1) {
        query['page'] = page;
      }

      final res = await BiliHttpClient().get(
        ApiEndpoints.userDynamic,
        queryParameters: query,
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        return DynamicFeedResponse.fromJson(res.data['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get dynamic or opus article detail by ID
  Future<DynamicItem?> getDynamicDetail(String dynamicId) async {
    // 1. Try WBI-signed dynamic detail API (standard web dynamic detail)
    try {
      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.dynamicDetail,
        queryParameters: {
          'timezone_offset': -480,
          'platform': 'web',
          'gaia_source': 'main_web',
          'features': 'itemOpusStyle',
          'id': dynamicId,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final itemData = res.data['data']['item'];
        if (itemData != null) {
          return DynamicItem.fromJson(itemData);
        }
      }
    } catch (_) {}

    // 2. Fallback to Opus Detail API
    try {
      final opusRes = await BiliHttpClient().get(
        ApiEndpoints.opusDetail,
        queryParameters: {
          'id': dynamicId,
          'timezone_offset': -480,
        },
      );

      if (opusRes.data != null && opusRes.data['code'] == 0 && opusRes.data['data'] != null) {
        final data = opusRes.data['data'];
        final itemData = data['item'] ?? data;
        if (itemData != null) {
          final item = DynamicItem.fromJson(itemData);
          if (item.paragraphs.isNotEmpty || item.pictures.isNotEmpty || item.text.isNotEmpty) {
            return item;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Like / Unlike dynamic
  Future<bool> likeDynamic(String dynamicId, {required bool like}) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null || csrf.isEmpty) return false;

    try {
      final res = await BiliHttpClient().post(
        '${ApiEndpoints.biliBase}/x/polymer/web-dynamic/v1/feed/like',
        data: {
          'dynamic_id': dynamicId,
          'up': like ? 1 : 2,
          'csrf': csrf,
        },
        queryParameters: {
          'csrf': csrf,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Origin': 'https://t.bilibili.com',
            'Referer': 'https://t.bilibili.com/',
          },
        ),
      );
      if (res.data != null && res.data['code'] == 0) {
        return true;
      }

      // Fallback to legacy thumb API if polymer returns error
      final legacyRes = await BiliHttpClient().post(
        'https://api.vc.bilibili.com/dynamic_like/v1/dynamic_like/thumb',
        data: FormData.fromMap({
          'dynamic_id': dynamicId,
          'up': like ? 1 : 2,
          'csrf': csrf,
          'csrf_token': csrf,
        }),
        options: Options(
          headers: {
            'Origin': 'https://t.bilibili.com',
            'Referer': 'https://t.bilibili.com/',
          },
        ),
      );
      return legacyRes.data != null && legacyRes.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }
}
