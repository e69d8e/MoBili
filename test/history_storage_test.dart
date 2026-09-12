import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/services/storage/history_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HistoryStorageService().resetForTesting();
  });

  group('HistoryStorageService Tests', () {
    test('Saves progress in-memory immediately and returns accurate progress', () async {
      final storage = HistoryStorageService();
      await storage.init();

      storage.saveProgress(
        bvid: 'BV1test123',
        progress: 120,
        duration: 300,
        title: '测试视频',
      );

      // In-memory progress is available with 0 delay
      expect(storage.getProgress('BV1test123'), equals(120));
      final record = storage.getRecord('BV1test123');
      expect(record, isNotNull);
      expect(record!['title'], equals('测试视频'));
      expect(record['duration'], equals(300));
    });

    test('Flush persists to SharedPreferences', () async {
      final storage = HistoryStorageService();
      await storage.init();

      storage.saveProgress(
        bvid: 'BV2flush456',
        progress: 45,
        duration: 200,
        title: '持久化测试',
      );

      await storage.flush();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_video_playback_history');
      expect(raw, isNotNull);
      expect(raw, contains('BV2flush456'));
      expect(raw, contains('45'));
    });

    test('Delete and clear history works correctly', () async {
      final storage = HistoryStorageService();
      await storage.init();

      storage.saveProgress(
        bvid: 'BV3delete789',
        progress: 10,
        immediate: true,
      );
      expect(storage.getProgress('BV3delete789'), equals(10));

      await storage.deleteProgress('BV3delete789');
      expect(storage.getProgress('BV3delete789'), equals(0));

      await storage.clearAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('local_video_playback_history'), isNull);
    });

    test('Isolates playback progress for different cids under the same bvid', () async {
      final storage = HistoryStorageService();
      await storage.init();

      const bvid = 'BV1MultiPart123';
      const cidPart1 = 10001;
      const cidPart2 = 10002;
      const cidPart3 = 10003;

      // Watch Part 1 up to 75 seconds
      storage.saveProgress(
        bvid: bvid,
        progress: 75,
        duration: 600,
        cid: cidPart1,
        title: '分P测试 - P1',
      );

      // Part 1 should have 75s
      expect(storage.getProgress(bvid, cid: cidPart1), equals(75));
      // Part 2 (unwatched) should have 0s
      expect(storage.getProgress(bvid, cid: cidPart2), equals(0));
      // Generic bvid query (no cid) returns latest progress
      expect(storage.getProgress(bvid), equals(75));

      // Now watch Part 2 up to 210 seconds
      storage.saveProgress(
        bvid: bvid,
        progress: 210,
        duration: 800,
        cid: cidPart2,
        title: '分P测试 - P2',
      );

      // Verify progress isolation
      expect(storage.getProgress(bvid, cid: cidPart1), equals(75));
      expect(storage.getProgress(bvid, cid: cidPart2), equals(210));
      expect(storage.getProgress(bvid, cid: cidPart3), equals(0));

      // Flush and reload from SharedPreferences to ensure cid_progress persistence
      await storage.flush();
      await storage.init();

      expect(storage.getProgress(bvid, cid: cidPart1), equals(75));
      expect(storage.getProgress(bvid, cid: cidPart2), equals(210));
      expect(storage.getProgress(bvid, cid: cidPart3), equals(0));

      final record = storage.getRecord(bvid);
      expect(record, isNotNull);
      expect(record!['cid_progress'], isA<Map>());
      expect(record['cid_progress']['$cidPart1'], equals(75));
      expect(record['cid_progress']['$cidPart2'], equals(210));
    });

    test('Handles legacy records without cid_progress gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      // Set legacy format where cid_progress does not exist
      await prefs.setString(
        'local_video_playback_history',
        '{"BV_Legacy":{"progress":150,"duration":500,"title":"老数据","timestamp":100000,"cid":8888}}',
      );

      final storage = HistoryStorageService();
      await storage.init();

      // Same cid matches legacy record['cid']
      expect(storage.getProgress('BV_Legacy', cid: 8888), equals(150));
      // Different cid should NOT match and should return 0
      expect(storage.getProgress('BV_Legacy', cid: 9999), equals(0));
      // Generic query without cid returns the overall progress
      expect(storage.getProgress('BV_Legacy'), equals(150));
    });

    test('Collection episodes with distinct bvids and cids maintain independent progress', () async {
      final storage = HistoryStorageService();
      await storage.init();

      // Episode 1
      const ep1Bvid = 'BV_Episode1';
      const ep1Cid = 11111;
      storage.saveProgress(
        bvid: ep1Bvid,
        progress: 180,
        duration: 900,
        cid: ep1Cid,
        title: '合集第1集',
      );

      // Episode 2 (unplayed initially)
      const ep2Bvid = 'BV_Episode2';
      const ep2Cid = 22222;

      expect(storage.getProgress(ep1Bvid, cid: ep1Cid), equals(180));
      expect(storage.getProgress(ep2Bvid, cid: ep2Cid), equals(0));

      // Now watch Episode 2 up to 45 seconds
      storage.saveProgress(
        bvid: ep2Bvid,
        progress: 45,
        duration: 850,
        cid: ep2Cid,
        title: '合集第2集',
      );

      expect(storage.getProgress(ep1Bvid, cid: ep1Cid), equals(180));
      expect(storage.getProgress(ep2Bvid, cid: ep2Cid), equals(45));
    });
  });
}

