import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/play_url_model.dart';
import 'package:mobili/models/subtitle_model.dart';
import 'package:mobili/widgets/player/bili_video_player.dart';
import 'package:mobili/widgets/player/subtitle_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Subtitle Model Tests', () {
    test('SubtitleTrack parses AI and manual subtitles correctly', () {
      final aiJson = {
        'id': 123456789,
        'lan': 'ai-zh',
        'lan_doc': '中文（AI生成）',
        'is_lock': false,
        'subtitle_url': 'https://i0.hdslb.com/bfs/subtitle/test_ai.json',
        'type': 1,
        'id_str': '123456789',
        'ai_type': 0,
        'ai_status': 2,
      };

      final track = SubtitleTrack.fromJson(aiJson);
      expect(track.id, equals(123456789));
      expect(track.lan, equals('ai-zh'));
      expect(track.lanDoc, equals('中文（AI生成）'));
      expect(track.subtitleUrl, startsWith('https://'));
      expect(track.isAi, isTrue);
    });

    test('SubtitleTrack parses regular CC subtitle', () {
      final ccJson = {
        'id': 987654321,
        'lan': 'zh-CN',
        'lan_doc': '中文（简体）',
        'subtitle_url': '//i0.hdslb.com/bfs/subtitle/test_cc.json',
        'type': 0,
      };

      final track = SubtitleTrack.fromJson(ccJson);
      expect(track.id, equals(987654321));
      expect(track.lan, equals('zh-CN'));
      expect(track.lanDoc, equals('中文（简体）'));
      expect(track.subtitleUrl, equals('https://i0.hdslb.com/bfs/subtitle/test_cc.json'));
      expect(track.isAi, isFalse);
    });

    test('SubtitleData binary search retrieves active item accurately', () {
      final track = SubtitleTrack(
        id: 1,
        lan: 'zh-CN',
        lanDoc: '中文（简体）',
        isLock: false,
        subtitleUrl: 'https://example.com/sub.json',
        type: 0,
      );

      final dataJson = {
        'body': [
          {'from': 1.0, 'to': 3.5, 'content': '欢迎收看本期视频'},
          {'from': 4.0, 'to': 7.0, 'content': '今天我们聊聊架构优化'},
          {'from': 7.5, 'to': 10.0, 'content': '记得一键三连支持一下'},
        ],
      };

      final subtitleData = SubtitleData.fromJson(track, dataJson);
      expect(subtitleData.items.length, equals(3));

      // Before first subtitle
      expect(subtitleData.getActiveItem(0.5), isNull);

      // In the middle of first subtitle
      final item1 = subtitleData.getActiveItem(2.0);
      expect(item1, isNotNull);
      expect(item1!.content, equals('欢迎收看本期视频'));

      // In the gap between subtitle 1 and 2
      expect(subtitleData.getActiveItem(3.8), isNull);

      // In the second subtitle
      final item2 = subtitleData.getActiveItem(5.5);
      expect(item2, isNotNull);
      expect(item2!.content, equals('今天我们聊聊架构优化'));

      // In the third subtitle
      final item3 = subtitleData.getActiveItem(8.0);
      expect(item3, isNotNull);
      expect(item3!.content, equals('记得一键三连支持一下'));

      // After last subtitle
      expect(subtitleData.getActiveItem(15.0), isNull);
    });
  });

  group('SubtitleOverlay Widget Tests', () {
    final track = SubtitleTrack(
      id: 1,
      lan: 'zh-CN',
      lanDoc: '中文',
      isLock: false,
      subtitleUrl: 'https://example.com',
      type: 0,
    );

    final subtitleData = SubtitleData(
      track: track,
      items: [
        SubtitleItem(from: 1.0, to: 4.0, content: '你好，Flutter 世界！'),
      ],
    );

    testWidgets('Displays subtitle text when within active timestamp range', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SubtitleOverlay(
                  subtitleData: subtitleData,
                  currentPosition: const Duration(seconds: 2),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('你好，Flutter 世界！'), findsOneWidget);
    });

    testWidgets('Renders empty when outside subtitle timestamp range', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SubtitleOverlay(
                  subtitleData: subtitleData,
                  currentPosition: const Duration(seconds: 10),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('你好，Flutter 世界！'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('BiliVideoPlayer Subtitle Floating Panel Tests', () {
    final playInfo = PlayUrlInfo(
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
          url: 'https://example.com/test.mp4',
          backupUrls: const [],
        ),
      ],
      supportFormats: [],
      videoCodecid: 7,
    );

    final track1 = SubtitleTrack(
      id: 1,
      lan: 'zh-CN',
      lanDoc: '中文（简体）',
      subtitleUrl: 'https://example.com/zh.json',
      isAi: false,
    );

    final track2 = SubtitleTrack(
      id: 2,
      lan: 'ai-en',
      lanDoc: '英语（AI生成）',
      subtitleUrl: 'https://example.com/en.json',
      isAi: true,
    );

    testWidgets('Tapping CC button opens floating subtitle panel with options and handles disable', (tester) async {
      SubtitleTrack? selectedTrack;
      bool changedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiliVideoPlayer(
              playUrlInfo: playInfo,
              subtitleTracks: [track1, track2],
              currentSubtitleTrack: track1,
              isSubtitleEnabled: true,
              onSubtitleTrackChanged: (track) {
                changedCalled = true;
                selectedTrack = track;
              },
            ),
          ),
        ),
      );

      // Verify CC button exists
      final ccButton = find.byIcon(Icons.closed_caption_rounded);
      expect(ccButton, findsOneWidget);

      // Tap CC button to open floating panel
      await tester.tap(ccButton);
      await tester.pump(const Duration(milliseconds: 350));

      // Floating panel should show "关闭字幕", track1, track2, and "AI" badge
      expect(find.text('关闭字幕'), findsOneWidget);
      expect(find.text('中文（简体）'), findsOneWidget);
      expect(find.text('英语（AI生成）'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);

      // Tap "关闭字幕"
      await tester.tap(find.text('关闭字幕'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(changedCalled, isTrue);
      expect(selectedTrack, isNull);

      // Panel should now be dismissed
      expect(find.text('关闭字幕'), findsNothing);
    });

    testWidgets('Selecting a subtitle track calls onSubtitleTrackChanged with that track', (tester) async {
      SubtitleTrack? selectedTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiliVideoPlayer(
              playUrlInfo: playInfo,
              subtitleTracks: [track1, track2],
              currentSubtitleTrack: null,
              isSubtitleEnabled: false,
              onSubtitleTrackChanged: (track) {
                selectedTrack = track;
              },
            ),
          ),
        ),
      );

      // Tap CC button
      await tester.tap(find.byIcon(Icons.closed_caption_outlined));
      await tester.pump(const Duration(milliseconds: 350));

      // Tap track2
      await tester.tap(find.text('英语（AI生成）'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(selectedTrack, equals(track2));
      expect(find.text('英语（AI生成）'), findsNothing); // Panel dismissed
    });
  });
}
