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
  ///
  /// 图文动态在列表/动态详情接口里只返回被截断的 summary，
  /// 完整正文（含段落与图片）只在 opus 详情接口中提供，
  /// 因此这里并行请求两个接口再合并结果，避免详情页内容不完整。
  Future<DynamicItem?> getDynamicDetail(String dynamicId) async {
    final webDetailFuture = _getWebDynamicDetail(dynamicId);
    final opusDetailFuture = getOpusDetail(dynamicId);

    final webDetail = await webDetailFuture;
    var opusDetail = await opusDetailFuture;

    // 动态 id 与 opus id 不一致时，用详情里的 jump_url 再尝试一次
    if (opusDetail == null &&
        webDetail.opusId.isNotEmpty &&
        webDetail.opusId != dynamicId) {
      opusDetail = await getOpusDetail(webDetail.opusId);
    }

    var merged = DynamicItem.merge(opusDetail, webDetail.item);
    if (merged == null) return null;

    // 转发的图文动态同样只有摘要，尝试补全一层
    final orig = merged.orig;
    if (orig != null &&
        orig.id.isNotEmpty &&
        orig.video == null &&
        orig.paragraphs.isEmpty) {
      final origOpus = await getOpusDetail(orig.id);
      if (origOpus != null &&
          (origOpus.paragraphs.isNotEmpty || origOpus.pictures.isNotEmpty)) {
        final enriched = DynamicItem.merge(origOpus, orig);
        if (enriched != null) {
          merged = merged.copyWith(orig: enriched);
        }
      }
    }

    return merged;
  }

  /// Get opus (图文) detail: full paragraphs, pictures, author and stat.
  ///
  /// 该接口无需登录，是非登录状态下获取图文完整正文的唯一来源。
  Future<DynamicItem?> getOpusDetail(String opusId) async {
    if (opusId.isEmpty) return null;

    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.opusDetail,
        queryParameters: {
          'id': opusId,
          'timezone_offset': -480,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] is Map) {
        final data = Map<String, dynamic>.from(res.data['data'] as Map);
        Map<String, dynamic>? itemData;
        if (data['item'] is Map) {
          itemData = Map<String, dynamic>.from(data['item'] as Map);
        } else if (data['id_str'] != null || data['modules'] != null) {
          itemData = data;
        }

        if (itemData != null) {
          final item = DynamicItem.fromJson(itemData);
          if (item.paragraphs.isNotEmpty ||
              item.pictures.isNotEmpty ||
              item.text.isNotEmpty) {
            return item;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// 动态详情接口（需要 WBI 签名）
  Future<_WebDetailResult> _getWebDynamicDetail(String dynamicId) async {
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
        if (itemData is Map) {
          return _WebDetailResult(
            DynamicItem.fromJson(itemData),
            _extractOpusId(itemData),
          );
        }
      }
    } catch (_) {}
    return const _WebDetailResult(null, '');
  }

  /// 从 jump_url（形如 //www.bilibili.com/opus/123456）中提取 opus id
  static String _extractOpusId(Map itemData) {
    final urls = <String>[];

    void collect(dynamic value) {
      if (value is String && value.contains('/opus/')) urls.add(value);
    }

    final basic = itemData['basic'];
    if (basic is Map) collect(basic['jump_url']);

    final modules = itemData['modules'];
    if (modules is Map) {
      final dynamicModule = modules['module_dynamic'];
      if (dynamicModule is Map) {
        final major = dynamicModule['major'];
        if (major is Map) {
          final opus = major['opus'];
          if (opus is Map) collect(opus['jump_url']);
        }
      }
    }

    for (final url in urls) {
      final match = RegExp(r'/opus/(\d+)').firstMatch(url);
      if (match != null) return match.group(1)!;
    }
    return '';
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

/// 动态详情接口的解析结果：条目 + 可选的 opus id（来自 jump_url）
class _WebDetailResult {
  final DynamicItem? item;
  final String opusId;

  const _WebDetailResult(this.item, this.opusId);
}
