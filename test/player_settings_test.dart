import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/services/settings/player_settings_service.dart';
import 'package:mobili/services/storage/history_storage_service.dart';
import 'package:mobili/services/api/user_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerSettingsService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PlayerSettingsService.init();
    });

    test('Default quality getter and setter', () async {
      expect(PlayerSettingsService.defaultQuality, equals(80)); // 1080P default
      await PlayerSettingsService.setDefaultQuality(116);
      expect(PlayerSettingsService.defaultQuality, equals(116));
    });

    test('Default playback speed getter and setter', () async {
      expect(PlayerSettingsService.defaultPlaybackSpeed, equals(1.0));
      await PlayerSettingsService.setDefaultPlaybackSpeed(1.25);
      expect(PlayerSettingsService.defaultPlaybackSpeed, equals(1.25));
    });

    test('Double-tap seek seconds getter and setter', () async {
      expect(PlayerSettingsService.doubleTapSeekSeconds, equals(10));
      await PlayerSettingsService.setDoubleTapSeekSeconds(15);
      expect(PlayerSettingsService.doubleTapSeekSeconds, equals(15));
    });

    test('Gesture toggle preferences', () async {
      expect(PlayerSettingsService.enableLongPressSpeed, isTrue);
      await PlayerSettingsService.setEnableLongPressSpeed(false);
      expect(PlayerSettingsService.enableLongPressSpeed, isFalse);

      expect(PlayerSettingsService.enableHorizontalPanSeek, isTrue);
      await PlayerSettingsService.setEnableHorizontalPan(false);
      expect(PlayerSettingsService.enableHorizontalPanSeek, isFalse);

      expect(PlayerSettingsService.enableVerticalPanVolumeBrightness, isTrue);
      await PlayerSettingsService.setEnableVerticalPan(false);
      expect(PlayerSettingsService.enableVerticalPanVolumeBrightness, isFalse);

      expect(PlayerSettingsService.autoPlayNextEpisode, isTrue);
      await PlayerSettingsService.setAutoPlayNextEpisode(false);
      expect(PlayerSettingsService.autoPlayNextEpisode, isFalse);
    });

    test('Incognito mode toggling and blocking history progress', () async {
      expect(PlayerSettingsService.incognitoMode, isFalse);
      await PlayerSettingsService.setIncognitoMode(true);
      expect(PlayerSettingsService.incognitoMode, isTrue);

      // Verify HistoryStorageService respects incognitoMode
      final historyService = HistoryStorageService();
      historyService.saveProgress(
        bvid: 'BV1IncognitoTest',
        progress: 120,
        duration: 300,
        aid: 12345,
        cid: 67890,
      );
      expect(historyService.getProgress('BV1IncognitoTest'), equals(0));

      // Verify UserApiService respects incognitoMode
      final userApi = UserApiService();
      final reported = await userApi.reportHistory(
        aid: 12345,
        cid: 67890,
        progress: 120,
        bvid: 'BV1IncognitoTest',
        duration: 300,
      );
      expect(reported, isFalse);

      // Turn off incognitoMode
      await PlayerSettingsService.setIncognitoMode(false);
      expect(PlayerSettingsService.incognitoMode, isFalse);
    });

    test('Quality memory: persisted selection is remembered on re-initialization', () async {
      int qualityNotified = 0;
      void onQualityChange() {
        qualityNotified = PlayerSettingsService.qualityListenable.value;
      }
      PlayerSettingsService.qualityListenable.addListener(onQualityChange);

      await PlayerSettingsService.setDefaultQuality(64); // User selected 720P
      expect(PlayerSettingsService.defaultQuality, equals(64));
      expect(qualityNotified, equals(64));

      // Simulate app restart by re-initializing PlayerSettingsService
      await PlayerSettingsService.init();
      expect(PlayerSettingsService.defaultQuality, equals(64));
      expect(PlayerSettingsService.qualityListenable.value, equals(64));

      // Switch to 1080P
      await PlayerSettingsService.setDefaultQuality(80);
      expect(PlayerSettingsService.defaultQuality, equals(80));
      expect(qualityNotified, equals(80));

      await PlayerSettingsService.init();
      expect(PlayerSettingsService.defaultQuality, equals(80));

      PlayerSettingsService.qualityListenable.removeListener(onQualityChange);
    });

    test('Subtitle toggle memory and preferred language persistence', () async {
      // Default should be true
      expect(PlayerSettingsService.subtitleEnabled, isTrue);
      expect(PlayerSettingsService.subtitleEnabledListenable.value, isTrue);
      expect(PlayerSettingsService.preferredSubtitleLanguage, isEmpty);

      bool? subtitleNotified;
      void onSubtitleChange() {
        subtitleNotified = PlayerSettingsService.subtitleEnabledListenable.value;
      }
      PlayerSettingsService.subtitleEnabledListenable.addListener(onSubtitleChange);

      // Disable subtitles
      await PlayerSettingsService.setSubtitleEnabled(false);
      expect(PlayerSettingsService.subtitleEnabled, isFalse);
      expect(subtitleNotified, isFalse);

      // Set preferred language
      await PlayerSettingsService.setPreferredSubtitleLanguage('zh-CN');
      expect(PlayerSettingsService.preferredSubtitleLanguage, equals('zh-CN'));

      // Simulate app restart
      await PlayerSettingsService.init();
      expect(PlayerSettingsService.subtitleEnabled, isFalse);
      expect(PlayerSettingsService.subtitleEnabledListenable.value, isFalse);
      expect(PlayerSettingsService.preferredSubtitleLanguage, equals('zh-CN'));

      // Re-enable subtitles
      await PlayerSettingsService.setSubtitleEnabled(true);
      expect(PlayerSettingsService.subtitleEnabled, isTrue);
      expect(subtitleNotified, isTrue);

      await PlayerSettingsService.init();
      expect(PlayerSettingsService.subtitleEnabled, isTrue);

      PlayerSettingsService.subtitleEnabledListenable.removeListener(onSubtitleChange);
    });
  });
}
