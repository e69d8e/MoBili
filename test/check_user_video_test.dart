// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/services/api/bili_http_client.dart';
import 'package:mobili/services/api/video_api_service.dart';
import 'package:mobili/services/player/bili_stream_proxy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BiliHttpClient().clearUserCookies();
  });

  tearDown(() {
    BiliStreamProxy().dispose();
  });

  test('Guest user gets fnval=0 merged stream (720P) with audio', () async {
    const testBvid = 'BV1GJ411x7h7';
    final detail = await VideoApiService().getVideoDetail(testBvid);
    expect(detail, isNotNull);
    final cid = detail!.videoItem.cid;

    // Guest mode: should use fnval=0 by default
    final playInfo = await VideoApiService().getVideoPlayUrl(bvid: testBvid, cid: cid, qn: 80);
    expect(playInfo, isNotNull);
    print('PRIMARY VIDEO URL: ${playInfo!.primaryVideoUrl}');
    expect(playInfo.primaryVideoUrl, isNotNull);
    expect(playInfo.primaryVideoUrl!.isNotEmpty, isTrue);

    // fnval=0 returns single stream mp4 (isDash is false, audio embedded in mp4)
    expect(playInfo.isDash, isFalse);
    expect(playInfo.durls.isNotEmpty, isTrue);

    // Verify proxy can wrap this single stream URL
    final proxy = BiliStreamProxy();
    final proxyUrl = await proxy.getProxyUrl(playInfo.primaryVideoUrl!);
    expect(proxyUrl.startsWith('http://127.0.0.1:'), isTrue);
    expect(proxyUrl.endsWith('.mp4'), isTrue);
  });

  test('Explicit DASH fnval=4048 returns separate video and audio tracks', () async {
    const testBvid = 'BV1GJ411x7h7';
    final detail = await VideoApiService().getVideoDetail(testBvid);
    expect(detail, isNotNull);
    final cid = detail!.videoItem.cid;

    // Explicit fnval=4048 for DASH
    final playInfo = await VideoApiService().getVideoPlayUrl(bvid: testBvid, cid: cid, qn: 80, fnval: 4048);
    expect(playInfo, isNotNull);
    expect(playInfo!.isDash, isTrue);
    expect(playInfo.primaryVideoUrl, isNotNull);
    expect(playInfo.primaryAudioUrl, isNotNull);

    // Verify both can be proxied
    final proxy = BiliStreamProxy();
    final videoProxyUrl = await proxy.getProxyUrl(playInfo.primaryVideoUrl!, isAudio: false);
    final audioProxyUrl = await proxy.getProxyUrl(playInfo.primaryAudioUrl!, isAudio: true);

    expect(videoProxyUrl.startsWith('http://127.0.0.1:'), isTrue);
    expect(videoProxyUrl.contains('video_'), isTrue);

    expect(audioProxyUrl.startsWith('http://127.0.0.1:'), isTrue);
    expect(audioProxyUrl.contains('audio_'), isTrue);
  });
}
