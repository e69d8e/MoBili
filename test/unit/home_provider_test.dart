import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/providers/home_provider.dart';
import 'package:mobili/services/api/video_api_service.dart';

class FakeVideoApiService implements VideoApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;
  bool emptyRecommendPage = false;
  bool emptyPopularPage = false;
  int recommendCallCount = 0;
  int popularCallCount = 0;
  int rankingCallCount = 0;

  VideoItem _createItem(String bvid, String title) {
    return VideoItem(
      aid: 123,
      bvid: bvid,
      cid: 456,
      title: title,
      pic: 'https://i0.hdslb.com/cover.jpg',
      desc: '测试简介',
      duration: 120,
      pubdate: 1700000000,
      ctime: 1700000000,
      owner: Owner(mid: 100, name: 'UP1', face: ''),
      stat: Stat(view: 1000, danmaku: 50),
    );
  }

  @override
  Future<List<VideoItem>> getRecommendFeed({int ps = 20, int freshIdx = 1}) async {
    recommendCallCount++;
    if (shouldThrow) {
      throw Exception('Network error');
    }
    if (emptyRecommendPage) {
      return [];
    }
    return [
      _createItem('BVrcmd_$freshIdx', '推荐视频 $freshIdx'),
    ];
  }

  @override
  Future<List<VideoItem>> getPopularVideos({int pn = 1, int ps = 20}) async {
    popularCallCount++;
    if (shouldThrow) {
      throw Exception('Network error');
    }
    if (emptyPopularPage) {
      return [];
    }
    return [
      _createItem('BVpopular_$pn', '热门视频 $pn'),
    ];
  }

  @override
  Future<List<VideoItem>> getRankingVideos({int rid = 0, String type = 'all'}) async {
    rankingCallCount++;
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return [
      _createItem('BVranking_1', '排行榜第1'),
      _createItem('BVranking_2', '排行榜第2'),
    ];
  }
}

void main() {
  group('HomeProvider Unit Tests', () {
    late FakeVideoApiService fakeService;
    late HomeProvider provider;

    setUp(() {
      fakeService = FakeVideoApiService();
      provider = HomeProvider(videoApiService: fakeService);
    });

    test('initial state has default values', () {
      expect(provider.currentTab, equals(0));
      expect(provider.recommendVideos, isEmpty);
      expect(provider.popularVideos, isEmpty);
      expect(provider.rankingVideos, isEmpty);
      expect(provider.rcmdLoading, isFalse);
      expect(provider.rcmdLoadingMore, isFalse);
      expect(provider.popularLoading, isFalse);
      expect(provider.popularLoadingMore, isFalse);
      expect(provider.rankingLoading, isFalse);
    });

    test('loadRecommendFeed populates recommendVideos and increments freshIdx', () async {
      await provider.loadRecommendFeed();

      expect(provider.recommendVideos.length, equals(1));
      expect(provider.recommendVideos.first.bvid, equals('BVrcmd_1'));
      expect(provider.rcmdLoading, isFalse);
      expect(fakeService.recommendCallCount, equals(1));

      // Load more
      await provider.loadMoreRecommend();
      expect(provider.recommendVideos.length, equals(2));
      expect(provider.recommendVideos.last.bvid, equals('BVrcmd_2'));
      expect(provider.rcmdLoadingMore, isFalse);
      expect(fakeService.recommendCallCount, equals(2));

      // Refresh resets
      await provider.loadRecommendFeed(isRefresh: true);
      expect(provider.recommendVideos.length, equals(1));
      expect(provider.recommendVideos.first.bvid, equals('BVrcmd_1'));
    });

    test('loadPopularVideos and loadMorePopular manage popular videos list', () async {
      await provider.loadPopularVideos();

      expect(provider.popularVideos.length, equals(1));
      expect(provider.popularVideos.first.bvid, equals('BVpopular_1'));
      expect(provider.popularLoading, isFalse);

      await provider.loadMorePopular();
      expect(provider.popularVideos.length, equals(2));
      expect(provider.popularVideos.last.bvid, equals('BVpopular_2'));
      expect(provider.popularLoadingMore, isFalse);

      // Refresh resets
      await provider.loadPopularVideos(isRefresh: true);
      expect(provider.popularVideos.length, equals(1));
      expect(provider.popularVideos.first.bvid, equals('BVpopular_1'));
    });

    test('loadRankingVideos loads ranking list', () async {
      await provider.loadRankingVideos();

      expect(provider.rankingVideos.length, equals(2));
      expect(provider.rankingVideos.first.bvid, equals('BVranking_1'));
      expect(provider.rankingLoading, isFalse);
    });

    test('setTab switches tab and lazily loads corresponding data', () async {
      expect(provider.currentTab, equals(0));

      // Switch to popular (tab 1)
      provider.setTab(1);
      expect(provider.currentTab, equals(1));
      await Future.delayed(Duration.zero);
      expect(provider.popularVideos.isNotEmpty, isTrue);

      // Switch to ranking (tab 2)
      provider.setTab(2);
      expect(provider.currentTab, equals(2));
      await Future.delayed(Duration.zero);
      expect(provider.rankingVideos.isNotEmpty, isTrue);

      // Switching to same tab is no-op
      provider.setTab(2);
      expect(provider.currentTab, equals(2));
    });

    test('errors set error state and return false without throwing', () async {
      fakeService.shouldThrow = true;

      // 1. Recommend loading error
      final okRcmd = await provider.loadRecommendFeed();
      expect(okRcmd, isFalse);
      expect(provider.rcmdError, isNotNull);
      expect(provider.rcmdLoading, isFalse);

      // 2. Recommend load more error
      expect(await provider.loadMoreRecommend(), isFalse);
      expect(provider.rcmdLoadingMore, isFalse);

      // 3. Popular loading error
      final okPopular = await provider.loadPopularVideos();
      expect(okPopular, isFalse);
      expect(provider.popularError, isNotNull);
      expect(provider.popularLoading, isFalse);

      // 4. Popular load more error
      expect(await provider.loadMorePopular(), isFalse);
      expect(provider.popularLoadingMore, isFalse);

      // 5. Ranking loading error
      final okRanking = await provider.loadRankingVideos();
      expect(okRanking, isFalse);
      expect(provider.rankingError, isNotNull);
      expect(provider.rankingLoading, isFalse);

      // 6. 重试成功后错误被清除
      fakeService.shouldThrow = false;
      final okRetry = await provider.loadRecommendFeed();
      expect(okRetry, isTrue);
      expect(provider.rcmdError, isNull);
      expect(provider.recommendVideos, isNotEmpty);
    });

    test('hasMore flips false when a page returns empty', () async {
      await provider.loadRecommendFeed();
      expect(provider.rcmdHasMore, isTrue);
      expect(provider.recommendVideos.length, equals(1));

      // 模拟推荐流到底（空页）
      fakeService.emptyRecommendPage = true;
      await provider.loadMoreRecommend();
      expect(provider.rcmdHasMore, isFalse);

      // 到底后 loadMore 不再发起请求
      final calls = fakeService.recommendCallCount;
      await provider.loadMoreRecommend();
      expect(fakeService.recommendCallCount, equals(calls));
    });

    test('popular hasMore follows the same empty-page rule', () async {
      await provider.loadPopularVideos();
      expect(provider.popularHasMore, isTrue);

      fakeService.emptyPopularPage = true;
      await provider.loadMorePopular();
      expect(provider.popularHasMore, isFalse);
    });
  });
}
