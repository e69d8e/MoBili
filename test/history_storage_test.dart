import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/services/storage/history_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
  });
}
