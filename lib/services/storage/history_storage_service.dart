import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryStorageService {
  static final HistoryStorageService _instance = HistoryStorageService._internal();
  factory HistoryStorageService() => _instance;
  HistoryStorageService._internal();

  static const String _storageKey = 'local_video_playback_history';
  static const int _maxRecords = 500;

  final Map<String, Map<String, dynamic>> _cache = {};
  bool _initialized = false;
  bool _dirty = false;
  Timer? _debounceTimer;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Initialize local history cache
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, val) {
            if (val is Map) {
              _cache[key.toString()] = Map<String, dynamic>.from(val);
            }
          });
        }
      }
      _initialized = true;
    } catch (_) {
      _initialized = true;
    }
  }

  /// Get recorded playback progress in seconds for a specific bvid
  int getProgress(String bvid) {
    if (bvid.isEmpty) return 0;
    final record = _cache[bvid];
    if (record == null) return 0;
    final progress = record['progress'];
    if (progress is int) return progress;
    if (progress is num) return progress.toInt();
    return 0;
  }

  /// Get the full playback record for a bvid
  Map<String, dynamic>? getRecord(String bvid) {
    if (bvid.isEmpty) return null;
    return _cache[bvid];
  }

  /// Total number of stored playback history records
  int get totalRecordCount => _cache.length;

  /// Save playback progress with in-memory instant update and debounced disk persistence
  void saveProgress({
    required String bvid,
    required int progress,
    int duration = 0,
    int aid = 0,
    int cid = 0,
    String? title,
    String? cover,
    bool immediate = false,
  }) {
    if (bvid.isEmpty) return;

    final existing = _cache[bvid] ?? {};
    final record = <String, dynamic>{
      'bvid': bvid,
      'progress': progress,
      'duration': duration > 0 ? duration : (existing['duration'] ?? 0),
      'aid': aid > 0 ? aid : (existing['aid'] ?? 0),
      'cid': cid > 0 ? cid : (existing['cid'] ?? 0),
      'title': title ?? existing['title'] ?? '',
      'cover': cover ?? existing['cover'] ?? '',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    _cache[bvid] = record;
    _dirty = true;

    if (immediate) {
      flush();
    } else {
      _schedulePersist();
    }
  }

  void _schedulePersist() {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      flush();
    });
  }

  /// Flush pending dirty history records to disk immediately
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (!_dirty) return;
    _dirty = false;
    await _persist();
  }

  /// Delete a record
  Future<void> deleteProgress(String bvid) async {
    if (_cache.remove(bvid) != null) {
      _dirty = true;
      await flush();
    }
  }

  /// Clear all local playback history
  Future<void> clearAll() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _dirty = false;
    _cache.clear();
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await _getPrefs();
      // If cache exceeds max records, trim oldest
      if (_cache.length > _maxRecords) {
        final entries = _cache.entries.toList()
          ..sort((a, b) {
            final timeA = a.value['updatedAt'] as int? ?? 0;
            final timeB = b.value['updatedAt'] as int? ?? 0;
            return timeB.compareTo(timeA);
          });
        _cache.clear();
        for (final e in entries.take(_maxRecords)) {
          _cache[e.key] = e.value;
        }
      }
      await prefs.setString(_storageKey, jsonEncode(_cache));
    } catch (_) {}
  }
}
