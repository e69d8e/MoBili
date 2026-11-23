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
  /// [hostMid]: 若传入关注 UP 主的 mid，则只拉取该 UP 主动态
  Future<DynamicFeedResponse?> getDynamicFeed({
    String type = 'all',
    String offset = '',
    int page = 1,
    int? hostMid,
  }) async {
    final result = await fetchDynamicFeed(
      type: type,
      offset: offset,
      page: page,
      hostMid: hostMid,
    );
    return result.data;
  }

  /// 获取动态流（区分网络/接口错误与真正的空结果）
  Future<({DynamicFeedResponse? data, String? error})> fetchDynamicFeed({
    String type = 'all',
    String offset = '',
    int page = 1,
    int? hostMid,
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
      if (hostMid != null && hostMid > 0) {
        query['host_mid'] = hostMid;
      }

      final res = await BiliHttpClient().get(
        ApiEndpoints.userDynamic,
        queryParameters: query,
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        return (
          data: DynamicFeedResponse.fromJson(res.data['data']),
          error: null,
        );
      }
      final msg = res.data is Map ? res.data['message']?.toString() : null;
      return (data: null, error: msg?.isNotEmpty == true ? msg : '动态加载失败');
    } catch (_) {
      return (data: null, error: '网络连接异常，请下拉刷新重试');
    }
  }

  /// Get dynamic or opus article detail by ID
  ///
  /// 图文动态在列表/动态详情接口里只返回被截断的 summary，
  /// 完整正文（含段落与图片）只在 opus 详情接口中提供，
  /// 因此这里并行请求两个接口再合并结果，避免详情页内容不完整。
  Future<DynamicItem?> getDynamicDetail(String dynamicId) async {
    if (dynamicId.startsWith('cv')) {
      final cvId = int.tryParse(dynamicId.substring(2)) ?? 0;
      return cvId > 0 ? getArticleDetail(cvId) : null;
    }

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
    if ((merged == null || merged.paragraphs.isEmpty) && webDetail.cvId > 0) {
      final articleDetail = await getArticleDetail(webDetail.cvId);
      if (articleDetail != null) {
        merged = DynamicItem.merge(articleDetail, merged);
      }
    }
    if (merged == null) return null;

    // 转发的图文动态同样只有摘要，尝试补全一层
    final orig = merged.orig;
    if (orig != null &&
        orig.id.isNotEmpty &&
        orig.video == null &&
        orig.paragraphs.isEmpty) {
      final origCv = orig.id.startsWith('cv')
          ? (int.tryParse(orig.id.substring(2)) ?? 0)
          : 0;
      final origDetail = origCv > 0
          ? await getArticleDetail(origCv)
          : await getOpusDetail(orig.id);
      if (origDetail != null &&
          (origDetail.paragraphs.isNotEmpty || origDetail.pictures.isNotEmpty)) {
        final enriched = DynamicItem.merge(origDetail, orig);
        if (enriched != null) {
          merged = merged.copyWith(orig: enriched);
        }
      }
    }

    return merged;
  }

  /// 获取专栏（cv 号）图文详情：先查 viewinfo 判断是否关联 opus，再兜底拉取正文 HTML。
  Future<DynamicItem?> getArticleDetail(int cvId) async {
    if (cvId <= 0) return null;

    DynamicItem? viewInfoItem;
    String dynIdStr = '';

    try {
      final infoRes = await BiliHttpClient().get(
        ApiEndpoints.articleViewInfo,
        queryParameters: {'id': cvId},
      );
      if (infoRes.data is Map &&
          infoRes.data['code'] == 0 &&
          infoRes.data['data'] is Map) {
        final data = Map<String, dynamic>.from(infoRes.data['data'] as Map);
        viewInfoItem = DynamicItem.fromArticleViewJson(
          data,
          fallbackCvId: cvId,
        );
        final rawDyn = data['dyn_id_str']?.toString().trim() ?? '';
        if (rawDyn.isNotEmpty && rawDyn != '0') {
          dynIdStr = rawDyn;
        }
        if (viewInfoItem.paragraphs.isNotEmpty) {
          return viewInfoItem;
        }
      }
    } catch (_) {}

    if (dynIdStr.isNotEmpty) {
      final opusItem = await getOpusDetail(dynIdStr);
      if (opusItem != null &&
          (opusItem.paragraphs.isNotEmpty || opusItem.pictures.isNotEmpty)) {
        return DynamicItem.merge(opusItem, viewInfoItem);
      }
    }

    try {
      final viewRes = await BiliHttpClient().get(
        ApiEndpoints.articleView,
        queryParameters: {'id': cvId},
      );
      if (viewRes.data is Map &&
          viewRes.data['code'] == 0 &&
          viewRes.data['data'] is Map) {
        final data = Map<String, dynamic>.from(viewRes.data['data'] as Map);
        final viewItem = DynamicItem.fromArticleViewJson(
          data,
          fallbackCvId: cvId,
        );
        return DynamicItem.merge(viewItem, viewInfoItem);
      }
    } catch (_) {}

    return viewInfoItem;
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
          final refs = _extractDetailRefs(itemData);
          return _WebDetailResult(
            DynamicItem.fromJson(itemData),
            refs.opusId,
            refs.cvId,
          );
        }
      }
    } catch (_) {}
    return const _WebDetailResult(null, '', 0);
  }

  /// 从 jump_url 与 article 节点中提取关联的 opus id 与专栏 cv id
  static ({String opusId, int cvId}) _extractDetailRefs(Map itemData) {
    final urls = <String>[];
    var cvId = 0;

    void collect(dynamic value) {
      if (value is String && value.isNotEmpty) urls.add(value);
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
          final article = major['article'];
          if (article is Map) {
            collect(article['jump_url']);
            final rawId = article['id'];
            cvId = rawId is int
                ? rawId
                : (int.tryParse(rawId?.toString() ?? '') ?? 0);
          }
        }
      }
    }

    var opusId = '';
    for (final url in urls) {
      if (opusId.isEmpty) opusId = extractOpusIdFromUrl(url);
      if (cvId <= 0) cvId = extractCvIdFromUrl(url);
    }
    return (opusId: opusId, cvId: cvId);
  }

  /// Like / Unlike dynamic (或 cv 专栏)
  Future<bool> likeDynamic(String dynamicId, {required bool like}) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null || csrf.isEmpty) return false;

    if (dynamicId.startsWith('cv')) {
      final cvId = int.tryParse(dynamicId.substring(2)) ?? 0;
      if (cvId <= 0) return false;
      try {
        final res = await BiliHttpClient().post(
          '${ApiEndpoints.biliBase}/x/article/like',
          data: FormData.fromMap({
            'id': cvId,
            'type': like ? 1 : 2,
            'csrf': csrf,
          }),
          options: Options(
            headers: {
              'Origin': 'https://www.bilibili.com',
              'Referer': 'https://www.bilibili.com/read/$dynamicId',
            },
          ),
        );
        return res.data is Map && res.data['code'] == 0;
      } catch (_) {
        return false;
      }
    }

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

/// 动态详情接口的解析结果：条目 + 可选的 opus id / cv id（来自 jump_url）
class _WebDetailResult {
  final DynamicItem? item;
  final String opusId;
  final int cvId;

  const _WebDetailResult(this.item, this.opusId, this.cvId);
}
