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
      notifyListeners();
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
        if (_suggestToken == token) {
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
    _suggestDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> search(String keyword, {String? order, String? category}) async {
    if (keyword.trim().isEmpty) return;
    _currentKeyword = keyword.trim();
    if (order != null) _currentOrder = order;
    if (category != null) _currentCategory = category;

    _isLoading = true;
    _hasSearched = true;
    _suggestions = [];
    notifyListeners();

    await addHistory(_currentKeyword);

    try {
      if (_currentCategory == 'video') {
        _videoPage = 1;
        _searchResults = await _searchApiService.searchVideos(
          keyword: _currentKeyword,
          page: _videoPage,
          order: _currentOrder,
        );
      } else if (_currentCategory == 'user') {
        _userPage = 1;
        _searchUsers = await _searchApiService.searchUsers(
          keyword: _currentKeyword,
          page: _userPage,
        );
      } else if (_currentCategory == 'article') {
        _articlePage = 1;
        _searchArticles = await _searchApiService.searchArticles(
          keyword: _currentKeyword,
          page: _articlePage,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || _currentKeyword.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      if (_currentCategory == 'video') {
        _videoPage++;
        final results = await _searchApiService.searchVideos(
          keyword: _currentKeyword,
          page: _videoPage,
          order: _currentOrder,
        );
        _searchResults.addAll(results);
      } else if (_currentCategory == 'user') {
        _userPage++;
        final results = await _searchApiService.searchUsers(
          keyword: _currentKeyword,
          page: _userPage,
        );
        _searchUsers.addAll(results);
      } else if (_currentCategory == 'article') {
        _articlePage++;
        final results = await _searchApiService.searchArticles(
          keyword: _currentKeyword,
          page: _articlePage,
        );
        _searchArticles.addAll(results);
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void resetSearch() {
    _currentKeyword = '';
    _searchResults = [];
    _searchUsers = [];
    _searchArticles = [];
    _suggestions = [];
    _hasSearched = false;
    _currentCategory = 'video';
    notifyListeners();
  }
}
