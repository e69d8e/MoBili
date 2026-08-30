import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/storage/app_cache_service.dart';
import 'package:mobili/screens/profile/cache_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCacheService Unit Tests', () {
    test('formatBytes formats bytes correctly across all magnitudes', () {
      expect(AppCacheService.formatBytes(0), '0 B');
      expect(AppCacheService.formatBytes(-50), '0 B');
      expect(AppCacheService.formatBytes(512), '512 B');
      expect(AppCacheService.formatBytes(1024), '1.0 KB');
      expect(AppCacheService.formatBytes(1024 * 512), '512.0 KB');
      expect(AppCacheService.formatBytes(1024 * 1024 * 128), '128.0 MB');
      expect(AppCacheService.formatBytes((1024 * 1024 * 1024 * 1.5).toInt()), '1.50 GB');
    });

    test('CacheSizeInfo calculates cleanable and total bytes accurately', () {
      const info = CacheSizeInfo(
        imageCacheBytes: 1000,
        tempDirBytes: 2000,
        videoCacheBytes: 5000,
        videoCacheCount: 3,
        historyCount: 15,
        searchHistoryCount: 8,
      );

      expect(info.cleanableBytes, 3000);
      expect(info.totalAppStorageBytes, 8000);
      expect(info.videoCacheCount, 3);
      expect(info.historyCount, 15);
      expect(info.searchHistoryCount, 8);

      final updated = info.copyWith(imageCacheBytes: 0);
      expect(updated.imageCacheBytes, 0);
      expect(updated.cleanableBytes, 2000);
      expect(updated.totalAppStorageBytes, 7000);
    });

    test('AutoCleanInterval and AutoCleanTarget parsing and duration checks', () {
      expect(AutoCleanInterval.fromKey('launch'), AutoCleanInterval.launch);
      expect(AutoCleanInterval.fromKey('days1').duration, const Duration(days: 1));
      expect(AutoCleanInterval.fromKey('days7').duration, const Duration(days: 7));
      expect(AutoCleanInterval.fromKey('days30').duration, const Duration(days: 30));
      expect(AutoCleanInterval.fromKey('unknown'), AutoCleanInterval.days7);

      expect(AutoCleanTarget.fromKey('images')?.key, 'images');
      expect(AutoCleanTarget.fromKey('temp')?.key, 'temp');
      expect(AutoCleanTarget.fromKey('searchHistory')?.key, 'searchHistory');
      expect(AutoCleanTarget.fromKey('playbackHistory')?.key, 'playbackHistory');
      expect(AutoCleanTarget.fromKey('invalid'), isNull);
    });

    test('AppCacheService toggles auto clean settings correctly', () async {
      final service = AppCacheService();
      await service.setAutoCleanEnabled(true);
      expect(service.autoCleanEnabled, isTrue);

      await service.setAutoCleanInterval(AutoCleanInterval.days3);
      expect(service.autoCleanInterval, AutoCleanInterval.days3);

      await service.toggleAutoCleanTarget('searchHistory', true);
      expect(service.autoCleanTargets.contains('searchHistory'), isTrue);

      await service.toggleAutoCleanTarget('searchHistory', false);
      expect(service.autoCleanTargets.contains('searchHistory'), isFalse);
    });
  });

  group('CacheManagementScreen Widget Smoke Test', () {
    testWidgets('Renders overview card, category items, auto clean and bottom bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CacheManagementScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('缓存管理'), findsOneWidget);
      expect(find.text('可深度释放空间'), findsOneWidget);
      expect(find.text('网络图片缓存'), findsAtLeastNWidgets(1));
      expect(find.text('系统临时与播放缓冲'), findsAtLeastNWidgets(1));
      expect(find.text('离线视频与本地弹幕'), findsOneWidget);
      expect(find.text('本地播放历史与进度'), findsAtLeastNWidgets(1));
      expect(find.text('搜索关键词历史'), findsAtLeastNWidgets(1));
      expect(find.text('自动清理策略'), findsOneWidget);
      expect(find.text('定时自动清理缓存'), findsOneWidget);
      expect(find.text('一键深度清理'), findsOneWidget);
    });
  });
}
