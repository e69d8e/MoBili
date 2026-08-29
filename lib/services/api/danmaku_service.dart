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

  /// Fetches and parses Danmaku XML list for a given video CID (supports local cache file)
  Future<List<DanmakuItem>> getDanmakuList(int cid, {String? localFilePath}) async {
    if (cid <= 0) return [];
    
    // 1. Try local file if provided
    if (localFilePath != null && localFilePath.isNotEmpty) {
      try {
        final f = File(localFilePath);
        if (f.existsSync()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            return await compute(_decodeAndParseDanmakuBytes, bytes);
          }
        }
      } catch (_) {}
    }

    // 2. Fetch from network
    try {
      final Uint8List bytes = await BiliHttpClient().getBytes(
        ApiEndpoints.danmakuList,
        queryParameters: {'oid': cid},
      );

      if (bytes.isNotEmpty) {
        return await compute(_decodeAndParseDanmakuBytes, bytes);
      }
    } catch (_) {}

    return [];
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
