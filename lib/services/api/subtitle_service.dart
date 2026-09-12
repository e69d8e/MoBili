import '../../models/subtitle_model.dart';
import 'api_endpoints.dart';
import 'bili_http_client.dart';

class SubtitleService {
  static final SubtitleService _instance = SubtitleService._internal();
  factory SubtitleService() => _instance;
  SubtitleService._internal();

  final Map<String, SubtitleData> _contentCache = {};

  /// Fetch list of subtitle tracks (CC and AI subtitles) for given video and episode
  Future<List<SubtitleTrack>> getSubtitleTracks({
    required String bvid,
    required int cid,
  }) async {
    if (cid <= 0) return [];

    try {
      // 1. Try player/wbi/v2 with WBI signature
      final res = await BiliHttpClient().getWbi(
        ApiEndpoints.playerV2,
        queryParameters: {
          'bvid': bvid,
          'cid': cid,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final subMap = res.data['data']['subtitle'];
        if (subMap is Map && subMap['subtitles'] is List) {
          final List<SubtitleTrack> tracks = [];
          for (final s in subMap['subtitles']) {
            if (s is Map<String, dynamic>) {
              final track = SubtitleTrack.fromJson(s);
              if (track.subtitleUrl.isNotEmpty) {
                tracks.add(track);
              }
            }
          }
          return tracks;
        }
      }
    } catch (_) {}

    // Fallback: Try player/v2 without WBI
    try {
      final res = await BiliHttpClient().get(
        ApiEndpoints.playerInfo,
        queryParameters: {
          'bvid': bvid,
          'cid': cid,
        },
      );

      if (res.data != null && res.data['code'] == 0 && res.data['data'] != null) {
        final subMap = res.data['data']['subtitle'];
        if (subMap is Map && subMap['subtitles'] is List) {
          final List<SubtitleTrack> tracks = [];
          for (final s in subMap['subtitles']) {
            if (s is Map<String, dynamic>) {
              final track = SubtitleTrack.fromJson(s);
              if (track.subtitleUrl.isNotEmpty) {
                tracks.add(track);
              }
            }
          }
          return tracks;
        }
      }
    } catch (_) {}

    return [];
  }

  /// Fetch full subtitle entries from a track's subtitle_url
  Future<SubtitleData?> getSubtitleData(SubtitleTrack track) async {
    final url = track.subtitleUrl;
    if (url.isEmpty) return null;

    if (_contentCache.containsKey(url)) {
      return _contentCache[url];
    }

    try {
      final res = await BiliHttpClient().get(url);
      if (res.data != null && res.data is Map) {
        final map = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : Map<String, dynamic>.from(res.data as Map);
        final data = SubtitleData.fromJson(track, map);
        _contentCache[url] = data;
        return data;
      }
    } catch (_) {}

    return null;
  }

  void clearCache() {
    _contentCache.clear();
  }
}
