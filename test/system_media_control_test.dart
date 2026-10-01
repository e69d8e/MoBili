import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/widgets/player/bili_video_player.dart';
import 'package:mobili/services/settings/player_settings_service.dart';
import 'package:mobili/services/player/system_media_control_service.dart';
import 'package:mobili/models/play_url_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyPlayUrl = PlayUrlInfo(
    currentQuality: 80,
    format: 'mp4',
    timelength: 60000,
    acceptQuality: [80],
    acceptDescription: ['1080P 高清'],
    durls: [
      PlayUrlDurl(
        order: 1,
        length: 60000,
        size: 1000,
        url: 'https://example.com/video.mp4',
        backupUrls: const [],
      ),
    ],
    supportFormats: [],
    videoCodecid: 7,
  );

  group('SystemMediaControlService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PlayerSettingsService.init();
      await PlayerSettingsService.setEnableVerticalPan(true);
      await SystemMediaControlService.instance.resetBrightness();
      await SystemMediaControlService.instance.setVolume(1.0);
    });

    test('SystemMediaControlService gets and sets brightness', () async {
      final service = SystemMediaControlService.instance;
      await service.setBrightness(0.65);
      expect(await service.getBrightness(), equals(0.65));

      await service.resetBrightness();
      expect(await service.getBrightness(), equals(1.0));
    });

    test('SystemMediaControlService gets and sets volume', () async {
      final service = SystemMediaControlService.instance;
      await service.setVolume(0.42);
      expect(await service.getVolume(), equals(0.42));
    });

    testWidgets('Hardware volume change updates player currentVolume and triggers HUD', (tester) async {
      final playerKey = GlobalKey<BiliVideoPlayerState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: BiliVideoPlayer(
                key: playerKey,
                playUrlInfo: dummyPlayUrl,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(playerKey.currentState, isNotNull);
      // Verify NO volume HUD is displayed on initial entrance
      expect(find.text('100%'), findsNothing);

      // Simulate hardware volume button pressed to 0.55
      SystemMediaControlService.instance.simulateVolumeChangedForTesting(0.55);
      await tester.pump();

      expect(playerKey.currentState!.currentVolume, equals(0.55));
      expect(find.text('55%'), findsOneWidget);

      // Advance clock to let HUD dismiss
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('55%'), findsNothing);
    });

    testWidgets('Disposing player resets brightness', (tester) async {
      final playerKey = GlobalKey<BiliVideoPlayerState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: BiliVideoPlayer(
                key: playerKey,
                playUrlInfo: dummyPlayUrl,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Change brightness to 0.3
      playerKey.currentState!.setScreenBrightness(0.3);
      expect(await SystemMediaControlService.instance.getBrightness(), equals(0.3));

      // Remove player from tree (trigger dispose)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );
      await tester.pump();

      // Brightness should be reset to 1.0 (system default)
      expect(await SystemMediaControlService.instance.getBrightness(), equals(1.0));
    });

    testWidgets('Session brightness memory is applied to next video in same session', (tester) async {
      SystemMediaControlService.instance.clearSessionBrightness();

      final playerKey1 = GlobalKey<BiliVideoPlayerState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: BiliVideoPlayer(
                key: playerKey1,
                playUrlInfo: dummyPlayUrl,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // User sets brightness in video 1 to 0.45
      playerKey1.currentState!.setScreenBrightness(0.45);
      expect(SystemMediaControlService.instance.sessionBrightness, equals(0.45));

      // Leave video 1 (dispose)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );
      await tester.pump();
      // Hardware brightness was reset on exit
      expect(await SystemMediaControlService.instance.getBrightness(), equals(1.0));
      // But session memory retained 0.45
      expect(SystemMediaControlService.instance.sessionBrightness, equals(0.45));

      // Enter video 2 in same session
      final playerKey2 = GlobalKey<BiliVideoPlayerState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: BiliVideoPlayer(
                key: playerKey2,
                playUrlInfo: dummyPlayUrl,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Video 2 automatically adopted remembered brightness 0.45
      expect(playerKey2.currentState!.screenBrightness, equals(0.45));
      expect(await SystemMediaControlService.instance.getBrightness(), equals(0.45));
    });
  });
}
