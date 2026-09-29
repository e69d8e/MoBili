import '../../models/search_model.dart';
import '../../models/video_model.dart';
import 'api_endpoints.dart';
import 'bili_http_client.dart';

class SearchApiService {
  static final SearchApiService _instance = SearchApiService._internal();
  factory SearchApiService() => _instance;
  SearchApiService._internal();

  /// Get hot search keywords / trending list
  Future<List<SearchHotItem>> getHotSearch({int limit = 10}) async {
    try {
      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.searchSquare,
        queryParameters: {'limit': limit},
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final trending = res.data['data']['trending'];
        if (trending != null && trending['list'] is List) {
          return (trending['list'] as List)
              .map((item) => SearchHotItem.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get auto-complete search suggestions
  Future<List<SearchSuggestItem>> getSearchSuggest(String term) async {
    if (term.trim().isEmpty) return [];
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.searchSuggest,
        queryParameters: {
          'term': term,
          'main_ver': 'v1',
          'highlight': 'term',
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['result'] != null) {
        final tag = res.data['result']['tag'] as List?;
        if (tag != null) {
          return tag.map((item) => SearchSuggestItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Search videos using WBI signature
  /// order options: totalrank (综合), click (最多播放), pubdate (最新发布), dm (最多弹幕), stow (最多收藏)
  /// 失败时抛出异常（而非返回空列表），让 Provider 呈现错误态
  Future<List<VideoItem>> searchVideos({
    required String keyword,
    int page = 1,
    String order = 'totalrank',
  }) async {
    if (keyword.trim().isEmpty) return [];
    final res = await BiliHttpClient().getWbi(
      ApiEndpoints.searchAll,
      queryParameters: {
        'keyword': keyword,
        'page': page,
        'order': order,
        'search_type': 'video',
      },
    );

    if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
      final result = res.data['data']['result'];
      if (result is List) {
        // Bilibili search result has multiple categories: find video category
        for (final section in result) {
          if (section is Map && section['result_type'] == 'video' && section['data'] is List) {
            return (section['data'] as List)
                .map((item) => VideoItem.fromJson(item))
                .toList();
          }
        }
      }
      return [];
    }
    throw Exception(res.data?['message'] ?? '搜索请求失败');
  }

  /// Search users / UP creators
  /// order options: 0 (默认), fans (粉丝数), level (等级)
  Future<List<SearchUserItem>> searchUsers({
    required String keyword,
    int page = 1,
    String order = '0',
  }) async {
    if (keyword.trim().isEmpty) return [];
    final res = await BiliHttpClient().getWbi(
      ApiEndpoints.searchType,
      queryParameters: {
        'keyword': keyword,
        'page': page,
        'order': order,
        'search_type': 'bili_user',
      },
    );

    if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
      final result = res.data['data']['result'];
      if (result is List) {
        return result.map((item) => SearchUserItem.fromJson(item)).toList();
      }
      return [];
    }
    throw Exception(res.data?['message'] ?? '搜索请求失败');
  }

  /// Search articles / Opus / pictures
  /// order options: totalrank (综合), pubdate (最新发布), click (最多阅读)
  Future<List<SearchArticleItem>> searchArticles({
    required String keyword,
    int page = 1,
    String order = 'totalrank',
  }) async {
    if (keyword.trim().isEmpty) return [];
    final res = await BiliHttpClient().getWbi(
      ApiEndpoints.searchType,
      queryParameters: {
        'keyword': keyword,
        'page': page,
        'order': order,
        'search_type': 'article',
      },
    );

    if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
      final result = res.data['data']['result'];
      if (result is List) {
        return result.map((item) => SearchArticleItem.fromJson(item)).toList();
      }
      return [];
    }
    throw Exception(res.data?['message'] ?? '搜索请求失败');
  }
}
