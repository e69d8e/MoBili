import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/comment_model.dart';
import 'api_endpoints.dart';
import 'bili_http_client.dart';

class CommentApiService {
  static final CommentApiService _instance = CommentApiService._internal();
  factory CommentApiService() => _instance;
  CommentApiService._internal();

  /// Get comments list with WBI signature and cursor pagination
  /// mode: 3 (Hot/Popular), 2 (Latest/Time)
  /// next: cursor next page integer
  /// nextOffset: cursor pagination_reply next_offset string
  Future<CommentResult> getComments({
    required int oid,
    int type = 1,
    int mode = 3,
    int next = 0,
    String nextOffset = '',
    int ps = 20,
    int pn = 1,
  }) async {
    if (oid <= 0) return CommentResult();
    try {
      final Map<String, dynamic> params = {
        'oid': oid,
        'type': type,
        'mode': mode,
        'ps': ps,
      };

      if (nextOffset.isNotEmpty) {
        params['pagination_str'] = nextOffset.startsWith('{')
            ? nextOffset
            : jsonEncode({'offset': nextOffset});
      }
      if (next > 0) {
        params['next'] = next;
      } else if (nextOffset.isEmpty) {
        params['next'] = 0;
      }

      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.replyMain,
        queryParameters: params,
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final data = res.data['data'];
        final List<CommentItem> list = [];

        // Parse top replies on first page
        if (next == 0 && nextOffset.isEmpty && data['top_replies'] is List) {
          for (final t in data['top_replies']) {
            list.add(CommentItem.fromJson(t));
          }
        }

        // Parse normal replies
        if (data['replies'] is List) {
          for (final r in data['replies']) {
            list.add(CommentItem.fromJson(r));
          }
        }

        final cursor = data['cursor'] ?? {};
        final int nextCursor = cursor['next'] is int
            ? cursor['next']
            : int.tryParse(cursor['next']?.toString() ?? '0') ?? 0;
        final String parsedOffset = cursor['pagination_reply']?['next_offset']?.toString() ?? '';
        final int allCount = cursor['all_count'] is int
            ? cursor['all_count']
            : int.tryParse(cursor['all_count']?.toString() ?? '0') ?? 0;

        // If hot comments preview (name == '热门评论') and more comments exist, do not set isEnd
        final bool isHotPreview = cursor['name'] == '热门评论';
        final bool isEnd = (!isHotPreview && cursor['is_end'] == true) ||
            (list.isEmpty && (next != 0 || nextOffset.isNotEmpty));

        return CommentResult(
          replies: list,
          nextCursor: nextCursor,
          nextOffset: parsedOffset,
          isEnd: isEnd,
          totalCount: allCount,
        );
      }

      // Fallback to legacy reply endpoint if wbi reply fails
      return await _getLegacyComments(oid: oid, type: type, pn: pn, ps: ps);
    } catch (_) {
      return await _getLegacyComments(oid: oid, type: type, pn: pn, ps: ps);
    }
  }

  Future<CommentResult> _getLegacyComments({
    required int oid,
    int type = 1,
    int pn = 1,
    int ps = 20,
  }) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.replyList,
        queryParameters: {
          'oid': oid,
          'type': type,
          'sort': 2,
          'pn': pn,
          'ps': ps,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final data = res.data['data'];
        final List<CommentItem> list = [];
        if (data['replies'] is List) {
          for (final r in data['replies']) {
            list.add(CommentItem.fromJson(r));
          }
        }
        final page = data['page'] ?? {};
        final int count = page['count'] is int ? page['count'] : 0;
        final int totalPages = (count / ps).ceil();
        return CommentResult(
          replies: list,
          nextCursor: pn + 1,
          nextOffset: '',
          isEnd: pn >= totalPages || list.isEmpty,
          totalCount: count,
        );
      }
      return CommentResult();
    } catch (_) {
      return CommentResult();
    }
  }

  /// Get sub-replies for a root comment
  Future<List<CommentItem>> getSubComments({
    required int oid,
    required int rootRpid,
    int type = 1,
    int pn = 1,
    int ps = 10,
  }) async {
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.replySub,
        queryParameters: {
          'oid': oid,
          'type': type,
          'root': rootRpid,
          'pn': pn,
          'ps': ps,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final replies = res.data['data']['replies'] as List?;
        if (replies != null) {
          return replies.map((r) => CommentItem.fromJson(r)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Like / Cancel like on a comment
  Future<bool> likeComment({
    required int oid,
    required int rpid,
    required int action, // 1: like, 0: cancel like
    int type = 1,
  }) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) return false;

    try {
      final res = await BiliHttpClient().post(
        ApiEndpoints.replyAction,
        data: FormData.fromMap({
          'oid': oid,
          'type': type,
          'rpid': rpid,
          'action': action,
          'csrf': csrf,
        }),
      );
      return res.data != null && res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  /// Post a new comment or reply to an existing comment
  Future<({bool success, String message, CommentItem? reply})> sendComment({
    required int oid,
    required String message,
    int root = 0,
    int parent = 0,
    int type = 1,
  }) async {
    final csrf = BiliHttpClient().biliJct;
    if (csrf == null) {
      return (success: false, message: '请先登录', reply: null);
    }

    try {
      final map = <String, dynamic>{
        'oid': oid,
        'type': type,
        'message': message,
        'csrf': csrf,
      };
      if (root > 0) map['root'] = root;
      if (parent > 0) map['parent'] = parent;

      final res = await BiliHttpClient().post(
        ApiEndpoints.replyAdd,
        data: FormData.fromMap(map),
      );

      if (res.data != null && res.data['code'] == 0) {
        CommentItem? replyItem;
        if (res.data['data'] != null && res.data['data']['reply'] != null) {
          replyItem = CommentItem.fromJson(res.data['data']['reply']);
        }
        return (success: true, message: '发表成功', reply: replyItem);
      }
      final msg = res.data?['message']?.toString() ?? '发表失败，请重试';
      return (success: false, message: msg, reply: null);
    } catch (_) {
      return (success: false, message: '网络错误，请稍后重试', reply: null);
    }
  }
}

