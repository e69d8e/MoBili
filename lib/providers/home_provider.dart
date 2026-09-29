import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../services/api/video_api_service.dart';

class HomeProvider extends ChangeNotifier {
  final VideoApiService _videoApiService;

  HomeProvider({VideoApiService? videoApiService})
      : _videoApiService = videoApiService ?? VideoApiService();

  int _currentTab = 0;

  // Recommend
  List<VideoItem> _recommendVideos = [];
  int _rcmdIdx = 1;
  bool _rcmdLoading = false;
  bool _rcmdLoadingMore = false;
  bool _rcmdHasMore = true;
  String? _rcmdError;

  /// Feed 代数：每次刷新自增；在途的加载更多落地时校验，旧页数据不得混入新 feed
  int _rcmdGen = 0;

  // Popular
  List<VideoItem> _popularVideos = [];
  int _popularPn = 1;
  bool _popularLoading = false;
  bool _popularLoadingMore = false;
  bool _popularHasMore = true;
  String? _popularError;
  int _popularGen = 0;

  // Ranking
  List<VideoItem> _rankingVideos = [];
  bool _rankingLoading = false;
  String? _rankingError;

  int get currentTab => _currentTab;
  List<VideoItem> get recommendVideos => _recommendVideos;
  bool get rcmdLoading => _rcmdLoading;
  bool get rcmdLoadingMore => _rcmdLoadingMore;
  bool get rcmdHasMore => _rcmdHasMore;
  String? get rcmdError => _rcmdError;

  List<VideoItem> get popularVideos => _popularVideos;
  bool get popularLoading => _popularLoading;
  bool get popularLoadingMore => _popularLoadingMore;
  bool get popularHasMore => _popularHasMore;
  String? get popularError => _popularError;

  List<VideoItem> get rankingVideos => _rankingVideos;
  bool get rankingLoading => _rankingLoading;
  String? get rankingError => _rankingError;

  void setTab(int tab) {
    if (_currentTab == tab) return;
    _currentTab = tab;

    if (tab == 0 && _recommendVideos.isEmpty && !_rcmdLoading) {
      loadRecommendFeed();
    } else if (tab == 1 && _popularVideos.isEmpty && !_popularLoading) {
      loadPopularVideos();
    } else if (tab == 2 && _rankingVideos.isEmpty && !_rankingLoading) {
      loadRankingVideos();
    }
  }

  // === Recommend ===
  Future<bool> loadRecommendFeed({bool isRefresh = false}) async {
    if (_rcmdLoading) return true;
    _rcmdLoading = true;
    _rcmdError = null;
    if (isRefresh) {
      _rcmdIdx = 1;
      // 作废可能已在途的加载更多，防止旧页数据被追加进新 feed
      _rcmdGen++;
      _rcmdLoadingMore = false;
    }
    notifyListeners();

    try {
      final list = await _videoApiService.getRecommendFeed(freshIdx: _rcmdIdx);
      if (isRefresh || _recommendVideos.isEmpty) {
        _recommendVideos = list;
      } else {
        _recommendVideos.addAll(list);
      }
      // 空页视为到底（过滤广告后单页可能少于请求量，不能以数量判断）
      _rcmdHasMore = list.isNotEmpty;
      _rcmdIdx++;
      return true;
    } catch (_) {
      _rcmdError = '加载失败，请检查网络后重试';
      return false;
    } finally {
      _rcmdLoading = false;
      notifyListeners();
    }
  }

  /// 加载更多。返回 false 仅表示失败（守卫跳过返回 true，避免调用方误报错误）
  Future<bool> loadMoreRecommend() async {
    if (_rcmdLoadingMore || _rcmdLoading || !_rcmdHasMore) return true;
    _rcmdLoadingMore = true;
    notifyListeners();
    final gen = _rcmdGen;

    try {
      final list = await _videoApiService.getRecommendFeed(freshIdx: _rcmdIdx);
      // 翻页在途时发生了刷新：本次追加作废
      if (gen != _rcmdGen) return true;
      _recommendVideos.addAll(list);
      _rcmdHasMore = list.isNotEmpty;
      _rcmdIdx++;
      return true;
    } catch (_) {
      return false;
    } finally {
      if (gen == _rcmdGen) {
        _rcmdLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // === Popular ===
  Future<bool> loadPopularVideos({bool isRefresh = false}) async {
    if (_popularLoading) return true;
    _popularLoading = true;
    _popularError = null;
    if (isRefresh) {
      _popularPn = 1;
      _popularGen++;
      _popularLoadingMore = false;
    }
    notifyListeners();

    try {
      final list = await _videoApiService.getPopularVideos(pn: _popularPn);
      if (isRefresh || _popularVideos.isEmpty) {
        _popularVideos = list;
      } else {
        _popularVideos.addAll(list);
      }
      _popularHasMore = list.isNotEmpty;
      _popularPn++;
      return true;
    } catch (_) {
      _popularError = '加载失败，请检查网络后重试';
      return false;
    } finally {
      _popularLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loadMorePopular() async {
    if (_popularLoadingMore || _popularLoading || !_popularHasMore) return true;
    _popularLoadingMore = true;
    notifyListeners();
    final gen = _popularGen;

    try {
      final list = await _videoApiService.getPopularVideos(pn: _popularPn);
      if (gen != _popularGen) return true;
      _popularVideos.addAll(list);
      _popularHasMore = list.isNotEmpty;
      _popularPn++;
      return true;
    } catch (_) {
      return false;
    } finally {
      if (gen == _popularGen) {
        _popularLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // === Ranking ===
  Future<bool> loadRankingVideos() async {
    if (_rankingLoading) return true;
    _rankingLoading = true;
    _rankingError = null;
    notifyListeners();

    try {
      final list = await _videoApiService.getRankingVideos();
      _rankingVideos = list;
      return true;
    } catch (_) {
      _rankingError = '加载失败，请检查网络后重试';
      return false;
    } finally {
      _rankingLoading = false;
      notifyListeners();
    }
  }
}
