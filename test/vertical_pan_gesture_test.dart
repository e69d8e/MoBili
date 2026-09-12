import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/widgets/player/bili_video_player.dart';
import 'package:mobili/services/player_settings_service.dart';
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

  group('Vertical Pan Brightness & Volume Gesture Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PlayerSettingsService.init();
      await PlayerSettingsService.setEnableVerticalPan(true);
      SystemMediaControlService.instance.clearSessionBrightness();
      await SystemMediaControlService.instance.setBrightness(1.0);
      await SystemMediaControlService.instance.setVolume(1.0);
    });

    testWidgets('Swiping down on left half of screen decreases brightness and shows brightness HUD', (tester) async {
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
      expect(playerKey.currentState!.screenBrightness, equals(1.0));

      // Left half drag: start at (200, 200)
      final gesture = await tester.startGesture(const Offset(200, 200));
      await tester.pump();

      // Drag downwards across several move events to simulate real finger movement
      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }

      // Brightness should have decreased
      expect(playerKey.currentState!.screenBrightness, lessThan(1.0));

      // HUD with percentage should be displayed
      final percent = (playerKey.currentState!.screenBrightness * 100).round();
      expect(find.text('$percent%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      await gesture.up();
      // Pump past HUD dismiss timer and double tap timer
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('Swiping down on right half of screen decreases volume and shows volume HUD', (tester) async {
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
      expect(playerKey.currentState!.currentVolume, equals(1.0));

      // Right half drag: start at (600, 200)
      final gesture = await tester.startGesture(const Offset(600, 200));
      await tester.pump();

      // Drag downwards across several move events
      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }

      // Volume should have decreased
      expect(playerKey.currentState!.currentVolume, lessThan(1.0));

      // HUD with percentage should be displayed
      final percent = (playerKey.currentState!.currentVolume * 100).round();
      expect(find.text('$percent%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      await gesture.up();
      // Pump past HUD dismiss timer and double tap timer
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('Swiping up on left half increases brightness', (tester) async {
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

      // Set initial brightness lower
      playerKey.currentState!.setScreenBrightness(0.4);
      expect(playerKey.currentState!.screenBrightness, equals(0.4));

      // Drag upwards on left half
      final gesture = await tester.startGesture(const Offset(200, 300));
      await tester.pump();
      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
      }

      expect(playerKey.currentState!.screenBrightness, greaterThan(0.5));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('Swiping up on right half increases volume', (tester) async {
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

      // Set initial volume lower
      await playerKey.currentState!.setVolume(0.3);
      expect(playerKey.currentState!.currentVolume, equals(0.3));

      // Drag upwards on right half
      final gesture = await tester.startGesture(const Offset(600, 300));
      await tester.pump();
      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
      }

      expect(playerKey.currentState!.currentVolume, greaterThan(0.4));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('Vertical pan is ignored when PlayerSettingsService.enableVerticalPanVolumeBrightness is false', (tester) async {
      await PlayerSettingsService.setEnableVerticalPan(false);
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

      final gesture = await tester.startGesture(const Offset(200, 200));
      await tester.pump();
      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }

      // Brightness remains unchanged
      expect(playerKey.currentState!.screenBrightness, equals(1.0));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('Swiping down starting in top exclusion area (status bar region) does NOT change brightness or show HUD', (tester) async {
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
      expect(playerKey.currentState!.screenBrightness, equals(1.0));

      // Drag starting near top edge (status bar / top bar pull down zone: y = 20)
      final gesture = await tester.startGesture(const Offset(200, 20));
      await tester.pump();

      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }

      // Brightness must remain 1.0 (unaffected)
      expect(playerKey.currentState!.screenBrightness, equals(1.0));
      // No HUD should be displayed
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('Swiping down starting in top exclusion area on right side does NOT change volume or show HUD', (tester) async {
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
      expect(playerKey.currentState!.currentVolume, equals(1.0));

      // Drag starting near top edge on right side (y = 30)
      final gesture = await tester.startGesture(const Offset(600, 30));
      await tester.pump();

      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }

      // Volume must remain 1.0 (unaffected)
      expect(playerKey.currentState!.currentVolume, equals(1.0));
      // No HUD should be displayed
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1000));
    });
  });
}
