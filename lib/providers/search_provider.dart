import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_model.dart';
import '../models/video_model.dart';
import '../services/api/search_api_service.dart';

class SearchProvider extends ChangeNotifier {
  final SearchApiService _searchApiService;

  SearchProvider({SearchApiService? searchApiService})
      : _searchApiService = searchApiService ?? SearchApiService();

  List<SearchHotItem> _hotSearches = [];
  List<SearchSuggestItem> _suggestions = [];
  List<String> _history = [];

  // Search Results
  List<VideoItem> _searchResults = [];
  List<SearchUserItem> _searchUsers = [];
  List<SearchArticleItem> _searchArticles = [];

  String _currentKeyword = '';
  String _currentCategory = 'video'; // 'video', 'user', 'article'
  String _currentOrder = 'totalrank'; // totalrank, click, pubdate, dm
  int _videoPage = 1;
  int _userPage = 1;
  int _articlePage = 1;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  bool _hasMore = true;
  String? _errorMessage;

  /// 搜索代际令牌：每次新搜索/重置自增，旧请求落地前校验，慢响应不覆盖新结果
  int _searchToken = 0;
  bool _isDisposed = false;

  List<SearchHotItem> get hotSearches => _hotSearches;
  List<SearchSuggestItem> get suggestions => _suggestions;
  List<String> get history => _history;

  List<VideoItem> get searchResults => _searchResults;
  List<SearchUserItem> get searchUsers => _searchUsers;
  List<SearchArticleItem> get searchArticles => _searchArticles;

  String get currentKeyword => _currentKeyword;
  String get currentCategory => _currentCategory;
  String get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasSearched => _hasSearched;

  /// 是否还有更多结果（空页即视为到底）
  bool get hasMore => _hasMore;

  /// 最近一次搜索/加载失败的错误信息；null 表示无错误
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    await _loadHistory();
    await loadHotSearches();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _history = prefs.getStringList('search_history') ?? [];
    notifyListeners();
  }

  Future<void> addHistory(String kw) async {
    final clean = kw.trim();
    if (clean.isEmpty) return;
    _history.remove(clean);
    _history.insert(0, clean);
    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    notifyListeners();
  }

  Future<void> loadHotSearches() async {
    try {
      final list = await _searchApiService.getHotSearch();
      _hotSearches = list;
    } catch (_) {
    } finally {
      if (!_isDisposed) notifyListeners();
    }
  }

  Timer? _suggestDebounceTimer;
  int _suggestToken = 0;

  Future<void> fetchSuggestions(String query) async {
    final cleanQuery = query.trim();
    _suggestDebounceTimer?.cancel();

    if (cleanQuery.isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    final token = ++_suggestToken;
    _suggestDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final list = await _searchApiService.getSearchSuggest(cleanQuery);
        if (!_isDisposed && _suggestToken == token) {
          _suggestions = list;
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void clearSuggestions() {
    _suggestDebounceTimer?.cancel();
    _suggestToken++;
    _suggestions = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _suggestDebounceTimer?.cancel();
    super.dispose();
  }

  /// 执行搜索。返回是否成功；失败时设置 [errorMessage] 供 UI 呈现错误态
  Future<bool> search(String keyword, {String? order, String? category}) async {
    if (keyword.trim().isEmpty) return false;
    final newKeyword = keyword.trim();
    final keywordChanged = newKeyword != _currentKeyword;
    _currentKeyword = newKeyword;
    if (order != null) _currentOrder = order;
    if (category != null) _currentCategory = category;

    final token = ++_searchToken;

    _isLoading = true;
    _hasSearched = true;
    _errorMessage = null;
    _hasMore = true;
    _suggestions = [];
    // 新搜索开启后，在途的 loadMore 已无归属，解除其加载标记
    _isLoadingMore = false;
    // 换了关键词时清空旧结果，避免展示错位数据
    if (keywordChanged) {
      _searchResults = [];
      _searchUsers = [];
      _searchArticles = [];
    }
    notifyListeners();

    await addHistory(_currentKeyword);

    try {
      if (_currentCategory == 'video') {
        _videoPage = 1;
        final results = await _searchApiService.searchVideos(
          keyword: _currentKeyword,
          page: _videoPage,
          order: _currentOrder,
        );
        // 已被更新的搜索取代：静默丢弃本次响应，不覆盖新结果
        if (_searchToken != token) return true;
        _searchResults = results;
        if (results.isEmpty) _hasMore = false;
      } else if (_currentCategory == 'user') {
        _userPage = 1;
        final results = await _searchApiService.searchUsers(
          keyword: _currentKeyword,
          page: _userPage,
        );
        if (_searchToken != token) return true;
        _searchUsers = results;
        if (results.isEmpty) _hasMore = false;
      } else if (_currentCategory == 'article') {
        _articlePage = 1;
        final results = await _searchApiService.searchArticles(
          keyword: _currentKeyword,
          page: _articlePage,
        );
        if (_searchToken != token) return true;
        _searchArticles = results;
        if (results.isEmpty) _hasMore = false;
      }
      return true;
    } catch (_) {
      if (_searchToken == token) {
        _errorMessage = '搜索失败，请检查网络后重试';
      }
      return false;
    } finally {
      if (_searchToken == token) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setCategory(String cat) async {
    if (_currentCategory == cat) return;
    _currentCategory = cat;
    notifyListeners();

    if (_currentKeyword.isNotEmpty) {
      if (cat == 'video' && _searchResults.isEmpty) {
        await search(_currentKeyword, category: 'video');
      } else if (cat == 'user' && _searchUsers.isEmpty) {
        await search(_currentKeyword, category: 'user');
      } else if (cat == 'article' && _searchArticles.isEmpty) {
        await search(_currentKeyword, category: 'article');
      }
    }
  }

  Future<void> changeOrder(String order) async {
    if (_currentOrder == order) return;
    _currentOrder = order;
    await search(_currentKeyword, order: order);
  }

  /// 加载下一页。返回是否成功；失败时页码保持不变（可重试不跳页）。
  /// 守卫跳过（已在加载/到底）返回 true，避免调用方误报错误。
  Future<bool> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore || _currentKeyword.isEmpty) {
      return true;
    }
    _isLoadingMore = true;
    notifyListeners();
    final token = _searchToken;

    try {
      if (_currentCategory == 'video') {
        final nextPage = _videoPage + 1;
        final results = await _searchApiService.searchVideos(
          keyword: _currentKeyword,
          page: nextPage,
          order: _currentOrder,
        );
        // 翻页在途时发起了新搜索：本次追加作废
        if (_searchToken != token) return false;
        _videoPage = nextPage;
        if (results.isEmpty) _hasMore = false;
        _searchResults.addAll(results);
      } else if (_currentCategory == 'user') {
        final nextPage = _userPage + 1;
        final results = await _searchApiService.searchUsers(
          keyword: _currentKeyword,
          page: nextPage,
        );
        if (_searchToken != token) return false;
        _userPage = nextPage;
        if (results.isEmpty) _hasMore = false;
        _searchUsers.addAll(results);
      } else if (_currentCategory == 'article') {
        final nextPage = _articlePage + 1;
        final results = await _searchApiService.searchArticles(
          keyword: _currentKeyword,
          page: nextPage,
        );
        if (_searchToken != token) return false;
        _articlePage = nextPage;
        if (results.isEmpty) _hasMore = false;
        _searchArticles.addAll(results);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (_searchToken == token) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void resetSearch() {
    _searchToken++;
    _currentKeyword = '';
    _searchResults = [];
    _searchUsers = [];
    _searchArticles = [];
    _suggestions = [];
    _hasSearched = false;
    _hasMore = true;
    _errorMessage = null;
    _currentCategory = 'video';
    notifyListeners();
  }
}
