import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/models/search_model.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/providers/search_provider.dart';
import 'package:mobili/services/api/search_api_service.dart';

class FakeSearchApiService implements SearchApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;
  bool returnEmptyVideos = false;
  final List<int> requestedVideoPages = [];

  @override
  Future<List<SearchHotItem>> getHotSearch({int limit = 10}) async {
    if (shouldThrow) throw Exception('API Error');
    return [
      SearchHotItem(keyword: '热搜词1', showName: '热搜词1', icon: '', position: 1),
      SearchHotItem(keyword: '热搜词2', showName: '热搜词2', icon: '', position: 2),
    ];
  }

  @override
  Future<List<SearchSuggestItem>> getSearchSuggest(String term) async {
    if (shouldThrow) throw Exception('API Error');
    return [
      SearchSuggestItem(value: '$term 结果1', term: term),
      SearchSuggestItem(value: '$term 结果2', term: term),
    ];
  }

  @override
  Future<List<VideoItem>> searchVideos({
    required String keyword,
    int page = 1,
    String order = 'totalrank',
    int duration = 0,
    int tid = 0,
  }) async {
    requestedVideoPages.add(page);
    if (shouldThrow) throw Exception('API Error');
    if (returnEmptyVideos) return [];
    return [
      VideoItem(
        aid: page * 100,
        bvid: 'BVsearch_${keyword}_$page',
        cid: page * 100 + 1,
        title: '$keyword 视频第$page页',
        pic: 'https://i0.hdslb.com/cover.jpg',
        desc: '描述',
        duration: 100,
        pubdate: 1700000000,
        ctime: 1700000000,
        owner: Owner(mid: 1, name: 'UP1', face: ''),
        stat: Stat(view: 100),
      ),
    ];
  }

  @override
  Future<List<SearchUserItem>> searchUsers({
    required String keyword,
    int page = 1,
    String order = '',
    String orderSort = '0',
    int userType = 0,
  }) async {
    if (shouldThrow) throw Exception('API Error');
    return [
      SearchUserItem(
        mid: page * 10,
        uname: '$keyword 用户$page',
        upic: 'https://i0.hdslb.com/user.jpg',
        usign: '个性签名',
        fans: 1000,
        videos: 50,
        level: 6,
      ),
    ];
  }

  @override
  Future<List<SearchArticleItem>> searchArticles({
    required String keyword,
    int page = 1,
    String order = 'totalrank',
  }) async {
    if (shouldThrow) throw Exception('API Error');
    return [
      SearchArticleItem(
        id: page * 5,
        title: '$keyword 图文专栏$page',
        desc: '专栏描述',
        imageUrls: [],
        uname: '专栏作者',
        mid: 10,
        view: 500,
        like: 20,
        reply: 5,
        pubTime: 1700000000,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchProvider Unit Tests', () {
    late FakeSearchApiService fakeService;
    late SearchProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'search_history': ['历史词1', '历史词2'],
      });
      fakeService = FakeSearchApiService();
      provider = SearchProvider(searchApiService: fakeService);
    });

    test('init loads history from SharedPreferences and fetches hot searches', () async {
      await provider.init();
      expect(provider.history, equals(['历史词1', '历史词2']));
      expect(provider.hotSearches.length, equals(2));
      expect(provider.hotSearches.first.keyword, equals('热搜词1'));
    });

    test('addHistory deduplicates, trims, moves to front, and caps at 20', () async {
      await provider.init();

      // Add a new keyword
      await provider.addHistory('  Flutter  ');
      expect(provider.history.first, equals('Flutter'));
      expect(provider.history.length, equals(3));

      // Re-add an existing keyword: should move to front
      await provider.addHistory('历史词2');
      expect(provider.history.first, equals('历史词2'));
      expect(provider.history.length, equals(3));

      // Cap at 20 items
      for (int i = 0; i < 25; i++) {
        await provider.addHistory('词条$i');
      }
      expect(provider.history.length, equals(20));
      expect(provider.history.first, equals('词条24'));

      // Clear history
      await provider.clearHistory();
      expect(provider.history, isEmpty);
    });

    test('search and loadMore for video category', () async {
      await provider.search('Flutter');

      expect(provider.hasSearched, isTrue);
      expect(provider.currentKeyword, equals('Flutter'));
      expect(provider.searchResults.length, equals(1));
      expect(provider.searchResults.first.bvid, equals('BVsearch_Flutter_1'));
      expect(provider.isLoading, isFalse);

      // Load more
      await provider.loadMore();
      expect(provider.searchResults.length, equals(2));
      expect(provider.searchResults.last.bvid, equals('BVsearch_Flutter_2'));
      expect(provider.isLoadingMore, isFalse);
    });

    test('category switching searches users and articles', () async {
      await provider.search('科技');
      expect(provider.searchResults.isNotEmpty, isTrue);

      // Switch to user
      await provider.setCategory('user');
      expect(provider.currentCategory, equals('user'));
      expect(provider.searchUsers.isNotEmpty, isTrue);
      expect(provider.searchUsers.first.uname, contains('科技'));

      // Switch to article
      await provider.setCategory('article');
      expect(provider.currentCategory, equals('article'));
      expect(provider.searchArticles.isNotEmpty, isTrue);
      expect(provider.searchArticles.first.title, contains('科技'));
    });

    test('suggestions debouncing and clearing', () async {
      provider.fetchSuggestions('Dart');
      // Wait for debounce timer (250ms)
      await Future.delayed(const Duration(milliseconds: 300));
      expect(provider.suggestions.length, equals(2));
      expect(provider.suggestions.first.value, contains('Dart'));

      // Clear suggestions
      provider.clearSuggestions();
      expect(provider.suggestions, isEmpty);
    });

    test('resetSearch clears state and results', () async {
      await provider.search('Flutter');
      expect(provider.hasSearched, isTrue);
      expect(provider.searchResults.isNotEmpty, isTrue);

      provider.resetSearch();
      expect(provider.hasSearched, isFalse);
      expect(provider.currentKeyword, isEmpty);
      expect(provider.searchResults, isEmpty);
      expect(provider.searchUsers, isEmpty);
      expect(provider.searchArticles, isEmpty);
      expect(provider.currentCategory, equals('video'));
    });

    test('search failure sets errorMessage and returns false without throwing', () async {
      fakeService.shouldThrow = true;

      final ok = await provider.search('ErrorKeyword');
      expect(ok, isFalse);
      expect(provider.errorMessage, isNotNull);
      expect(provider.isLoading, isFalse);
      expect(provider.hasSearched, isTrue);

      // 重试成功后错误被清除
      fakeService.shouldThrow = false;
      final okRetry = await provider.search('ErrorKeyword');
      expect(okRetry, isTrue);
      expect(provider.errorMessage, isNull);
      expect(provider.searchResults, isNotEmpty);
    });

    test('loadMore failure does not skip pages (page-skip regression)', () async {
      await provider.search('Flutter');
      expect(provider.searchResults.length, equals(1));
      expect(fakeService.requestedVideoPages, equals([1]));

      fakeService.shouldThrow = true;
      final ok = await provider.loadMore();
      expect(ok, isFalse);
      expect(provider.searchResults.length, equals(1));

      // 重试必须仍请求第 2 页，而不是跳到第 3 页
      fakeService.shouldThrow = false;
      final okRetry = await provider.loadMore();
      expect(okRetry, isTrue);
      expect(fakeService.requestedVideoPages, equals([1, 2, 2]));
      expect(provider.searchResults.length, equals(2));
      expect(provider.searchResults.last.bvid, equals('BVsearch_Flutter_2'));
    });

    test('hasMore flips false when a page returns empty', () async {
      await provider.search('Flutter');
      expect(provider.hasMore, isTrue);

      fakeService.returnEmptyVideos = true;
      await provider.loadMore();
      expect(provider.hasMore, isFalse);
      expect(provider.searchResults.length, equals(1));

      // 到底后 loadMore 直接跳过，不再发请求
      final pages = List<int>.from(fakeService.requestedVideoPages);
      await provider.loadMore();
      expect(fakeService.requestedVideoPages, equals(pages));
    });
  });
}
