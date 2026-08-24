import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../services/api/video_api_service.dart';

class HomeProvider extends ChangeNotifier {
  int _currentTab = 0;

  // Recommend
  List<VideoItem> _recommendVideos = [];
  int _rcmdIdx = 1;
  bool _rcmdLoading = false;
  bool _rcmdLoadingMore = false;

  // Popular
  List<VideoItem> _popularVideos = [];
  int _popularPn = 1;
  bool _popularLoading = false;
  bool _popularLoadingMore = false;

  // Ranking
  List<VideoItem> _rankingVideos = [];
  bool _rankingLoading = false;

  int get currentTab => _currentTab;
  List<VideoItem> get recommendVideos => _recommendVideos;
  bool get rcmdLoading => _rcmdLoading;
  bool get rcmdLoadingMore => _rcmdLoadingMore;

  List<VideoItem> get popularVideos => _popularVideos;
  bool get popularLoading => _popularLoading;
  bool get popularLoadingMore => _popularLoadingMore;

  List<VideoItem> get rankingVideos => _rankingVideos;
  bool get rankingLoading => _rankingLoading;

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
  Future<void> loadRecommendFeed({bool isRefresh = false}) async {
    if (_rcmdLoading) return;
    _rcmdLoading = true;
    if (isRefresh) {
      _rcmdIdx = 1;
    }
    notifyListeners();

    final list = await VideoApiService().getRecommendFeed(freshIdx: _rcmdIdx);
    if (isRefresh || _recommendVideos.isEmpty) {
      _recommendVideos = list;
    } else {
      _recommendVideos.addAll(list);
    }
    _rcmdIdx++;
    _rcmdLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreRecommend() async {
    if (_rcmdLoadingMore || _rcmdLoading) return;
    _rcmdLoadingMore = true;
    notifyListeners();

    final list = await VideoApiService().getRecommendFeed(freshIdx: _rcmdIdx);
    _recommendVideos.addAll(list);
    _rcmdIdx++;
    _rcmdLoadingMore = false;
    notifyListeners();
  }

  // === Popular ===
  Future<void> loadPopularVideos({bool isRefresh = false}) async {
    if (_popularLoading) return;
    _popularLoading = true;
    if (isRefresh) {
      _popularPn = 1;
    }
    notifyListeners();

    final list = await VideoApiService().getPopularVideos(pn: _popularPn);
    if (isRefresh || _popularVideos.isEmpty) {
      _popularVideos = list;
    } else {
      _popularVideos.addAll(list);
    }
    _popularPn++;
    _popularLoading = false;
    notifyListeners();
  }

  Future<void> loadMorePopular() async {
    if (_popularLoadingMore || _popularLoading) return;
    _popularLoadingMore = true;
    notifyListeners();

    final list = await VideoApiService().getPopularVideos(pn: _popularPn);
    _popularVideos.addAll(list);
    _popularPn++;
    _popularLoadingMore = false;
    notifyListeners();
  }

  // === Ranking ===
  Future<void> loadRankingVideos() async {
    if (_rankingLoading) return;
    _rankingLoading = true;
    notifyListeners();

    final list = await VideoApiService().getRankingVideos();
    _rankingVideos = list;
    _rankingLoading = false;
    notifyListeners();
  }
}
