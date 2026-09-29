import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/player/bili_stream_proxy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('BiliStreamProxy Tests', () {
    tearDown(() {
      BiliStreamProxy().dispose();
    });

    test('getProxyUrl returns valid local loopback URL with .mp4 extension', () async {
      final proxy = BiliStreamProxy();
      const testRemoteUrl = 'https://upos-sz-mirrorali.bilivideo.com/test_video.m4s?param=123';
      final proxyUrl = await proxy.getProxyUrl(testRemoteUrl);

      expect(proxyUrl.startsWith('http://127.0.0.1:'), isTrue);
      expect(proxyUrl.endsWith('.mp4'), isTrue);
      expect(proxyUrl.contains('video_'), isTrue);
      expect(proxy.isRunning, isTrue);
    });

    test('getProxyUrl with isAudio returns audio_ prefix in path', () async {
      final proxy = BiliStreamProxy();
      const testRemoteAudioUrl = 'https://upos-sz-mirrorali.bilivideo.com/test_audio.m4s?param=456';
      final proxyUrl = await proxy.getProxyUrl(testRemoteAudioUrl, isAudio: true);

      expect(proxyUrl.startsWith('http://127.0.0.1:'), isTrue);
      expect(proxyUrl.endsWith('.mp4'), isTrue);
      expect(proxyUrl.contains('audio_'), isTrue);
    });

    test('Local proxy handles dummy upstream server and serves standard mp4 content type', () async {
      // 1. Create a dummy upstream server
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      upstream.listen((req) async {
        await req.drain();
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
        req.response.write('dummy_stream_content');
        await req.response.close();
      });

      final upstreamUrl = 'http://127.0.0.1:${upstream.port}/upstream.m4s';

      // 2. Get proxy URL
      final proxy = BiliStreamProxy();
      final proxyUrl = await proxy.getProxyUrl(upstreamUrl, isAudio: true);

      // 3. Fetch from proxy
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.value(HttpHeaders.contentTypeHeader), equals('audio/mp4'));
      expect(res.headers.value(HttpHeaders.acceptRangesHeader), equals('bytes'));

      final body = await res.transform(const SystemEncoding().decoder).join();
      expect(body, equals('dummy_stream_content'));

      client.close(force: true);
      await upstream.close(force: true);
    });

    test('Local proxy supports HEAD requests without body', () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      upstream.listen((req) async {
        expect(req.method, equals('HEAD'));
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.set(HttpHeaders.contentLengthHeader, 1024);
        await req.response.close();
      });

      final upstreamUrl = 'http://127.0.0.1:${upstream.port}/upstream_video.m4s';
      final proxy = BiliStreamProxy();
      final proxyUrl = await proxy.getProxyUrl(upstreamUrl, isAudio: false);

      final client = HttpClient();
      final req = await client.headUrl(Uri.parse(proxyUrl));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.value(HttpHeaders.contentTypeHeader), equals('video/mp4'));
      expect(res.headers.value(HttpHeaders.contentLengthHeader), equals('1024'));

      final body = await res.toList();
      expect(body, isEmpty);

      client.close(force: true);
      await upstream.close(force: true);
    });

    test('Local proxy injects Referer and forwards Range header to upstream', () async {
      String? receivedReferer;
      String? receivedUserAgent;
      String? receivedRange;

      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      upstream.listen((req) async {
        receivedReferer = req.headers.value(HttpHeaders.refererHeader);
        receivedUserAgent = req.headers.value(HttpHeaders.userAgentHeader);
        receivedRange = req.headers.value(HttpHeaders.rangeHeader);

        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-100/1000');
        req.response.write('partial_bytes');
        await req.response.close();
      });

      final upstreamUrl = 'http://127.0.0.1:${upstream.port}/upstream_range.m4s';
      final proxy = BiliStreamProxy();
      final proxyUrl = await proxy.getProxyUrl(upstreamUrl);

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-100');
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.partialContent));
      expect(receivedReferer, equals('https://www.bilibili.com'));
      expect(receivedUserAgent, contains('Mozilla/5.0'));
      expect(receivedRange, equals('bytes=0-100'));
      expect(res.headers.value(HttpHeaders.contentRangeHeader), equals('bytes 0-100/1000'));

      client.close(force: true);
      await upstream.close(force: true);
    });

    test('getLocalFileProxyUrl returns loopback url with audio_ local prefix', () async {
      final dir = await Directory.systemTemp.createTemp('mobili_proxy_test');
      final file = File('${dir.path}/audio_BV1_test_123.m4s');
      await file.writeAsBytes(List<int>.filled(10, 7));

      final proxy = BiliStreamProxy();
      final proxyUrl = await proxy.getLocalFileProxyUrl(file.path, isAudio: true);

      expect(proxyUrl.startsWith('http://127.0.0.1:'), isTrue);
      expect(proxyUrl.endsWith('.mp4'), isTrue);
      expect(proxyUrl.contains('locala_'), isTrue);

      await dir.delete(recursive: true);
    });

    test('local file proxy honours Range and serves audio/mp4', () async {
      final dir = await Directory.systemTemp.createTemp('mobili_proxy_test');
      final bytes = List<int>.generate(100, (i) => i);
      final file = File('${dir.path}/audio_BV1_range_1.m4s');
      await file.writeAsBytes(bytes);

      final proxy = BiliStreamProxy();
      final proxyUrl = await proxy.getLocalFileProxyUrl(file.path, isAudio: true);

      final client = HttpClient();

      // 全量请求：200 + audio/mp4 + 完整字节
      final fullReq = await client.getUrl(Uri.parse(proxyUrl));
      final fullRes = await fullReq.close();
      expect(fullRes.statusCode, equals(HttpStatus.ok));
      expect(fullRes.headers.value(HttpHeaders.contentTypeHeader), equals('audio/mp4'));
      expect(fullRes.headers.value(HttpHeaders.acceptRangesHeader), equals('bytes'));
      expect(fullRes.headers.value(HttpHeaders.contentLengthHeader), equals('100'));
      final fullBody = await fullRes.fold<List<int>>([], (p, e) => p..addAll(e));
      expect(fullBody, equals(bytes));

      // 区间请求：206 + Content-Range + 指定字节
      final rangeReq = await client.getUrl(Uri.parse(proxyUrl));
      rangeReq.headers.set(HttpHeaders.rangeHeader, 'bytes=0-3');
      final rangeRes = await rangeReq.close();
      expect(rangeRes.statusCode, equals(HttpStatus.partialContent));
      expect(rangeRes.headers.value(HttpHeaders.contentRangeHeader), equals('bytes 0-3/100'));
      expect(rangeRes.headers.value(HttpHeaders.contentLengthHeader), equals('4'));
      final rangeBody = await rangeRes.fold<List<int>>([], (p, e) => p..addAll(e));
      expect(rangeBody, equals([0, 1, 2, 3]));

      // 越界区间：416
      final badReq = await client.getUrl(Uri.parse(proxyUrl));
      badReq.headers.set(HttpHeaders.rangeHeader, 'bytes=500-600');
      final badRes = await badReq.close();
      expect(badRes.statusCode, equals(HttpStatus.requestedRangeNotSatisfiable));
      await badRes.drain<void>();

      client.close(force: true);
      await dir.delete(recursive: true);
    });

    test('local file proxy returns 404 for a missing file', () async {
      final dir = await Directory.systemTemp.createTemp('mobili_proxy_test');
      final missing = '${dir.path}/video_missing_1.m4s';

      final proxy = BiliStreamProxy();
      final proxyUrl = await proxy.getLocalFileProxyUrl(missing);

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.notFound));

      client.close(force: true);
      await dir.delete(recursive: true);
    });
  });
}
