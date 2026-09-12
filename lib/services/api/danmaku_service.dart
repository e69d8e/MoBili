import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/danmaku_model.dart';
import 'api_endpoints.dart';
import 'bili_http_client.dart';

class DanmakuService {
  static final DanmakuService _instance = DanmakuService._internal();
  factory DanmakuService() => _instance;
  DanmakuService._internal();

  final Map<int, List<DanmakuItem>> _sessionCache = {};

  /// Fetches and parses Danmaku XML list for a given video CID (supports local cache file, deduplication and memory cache)
  Future<List<DanmakuItem>> getDanmakuList(int cid, {String? localFilePath}) async {
    if (cid <= 0) return [];

    // 1. Try local file if provided
    if (localFilePath != null && localFilePath.isNotEmpty) {
      try {
        final f = File(localFilePath);
        if (f.existsSync()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            final parsed = await compute(_decodeAndParseDanmakuBytes, bytes);
            final deduplicated = deduplicateDanmakus(parsed);
            _sessionCache[cid] = deduplicated;
            return deduplicated;
          }
        }
      } catch (_) {}
    }

    // 2. Check in-memory session cache
    if (_sessionCache.containsKey(cid) && _sessionCache[cid]!.isNotEmpty) {
      return _sessionCache[cid]!;
    }

    // 3. Fetch from primary network endpoint (list.so)
    try {
      final Uint8List bytes = await BiliHttpClient().getBytes(
        ApiEndpoints.danmakuList,
        queryParameters: {'oid': cid},
      );

      if (bytes.isNotEmpty) {
        final parsed = await compute(_decodeAndParseDanmakuBytes, bytes);
        final deduplicated = deduplicateDanmakus(parsed);
        _sessionCache[cid] = deduplicated;
        return deduplicated;
      }
    } catch (_) {}

    return [];
  }

  /// Deduplicate danmakus by dmid or (timePoint + text), maintaining chronological order
  static List<DanmakuItem> deduplicateDanmakus(List<DanmakuItem> list) {
    if (list.isEmpty) return [];

    final Map<String, DanmakuItem> uniqueMap = {};
    for (final item in list) {
      final key = item.dmid.isNotEmpty
          ? 'id_${item.dmid}'
          : 't_${item.timePoint.toStringAsFixed(1)}_${item.text.trim()}';
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = item;
      }
    }

    final result = uniqueMap.values.toList()
      ..sort((a, b) => a.timePoint.compareTo(b.timePoint));
    return result;
  }

  void clearCache() {
    _sessionCache.clear();
  }
}

/// Top-level isolate worker for decompressing and parsing Danmaku XML bytes
List<DanmakuItem> _decodeAndParseDanmakuBytes(Uint8List bytes) {
  if (bytes.isEmpty) return [];

  String xmlString = '';
  try {
    // Try decompressing deflate stream with raw zlib decoder
    final decodedBytes = zlib.decode(bytes);
    xmlString = utf8.decode(decodedBytes, allowMalformed: true);
  } catch (_) {
    try {
      // If raw zlib fails, try raw deflate decode
      final decodedBytes = ZLibDecoder(raw: true).convert(bytes);
      xmlString = utf8.decode(decodedBytes, allowMalformed: true);
    } catch (_) {
      // If not compressed, decode directly
      xmlString = utf8.decode(bytes, allowMalformed: true);
    }
  }

  if (xmlString.isEmpty) return [];

  final List<DanmakuItem> list = [];
  final RegExp danmakuExp = RegExp(r'<d\s+p="([^"]+)">([^<]*)</d>');
  final matches = danmakuExp.allMatches(xmlString);

  for (final match in matches) {
    final pAttr = match.group(1);
    final text = match.group(2);
    if (pAttr != null && text != null && text.trim().isNotEmpty) {
      final item = DanmakuItem.fromXml(pAttr, text.trim());
      if (item != null) {
        list.add(item);
      }
    }
  }

  // Sort by timeline ascending
  list.sort((a, b) => a.timePoint.compareTo(b.timePoint));
  return list;
}
