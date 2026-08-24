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

  /// Like / Unlike dynamic
  Future<bool> likeDynamic(String dynamicId, {required bool like}) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final res = await BiliHttpClient().post(
        '${ApiEndpoints.biliBase}/x/polymer/web-dynamic/v1/feed/like',
        data: FormData.fromMap({
          'dynamic_id': dynamicId,
          'up': like ? 1 : 2,
          'csrf': csrf,
        }),
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }
}
