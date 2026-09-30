import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/player/bili_stream_proxy.dart';

/// BiliStreamProxy 磁盘缓存（边播边缓存 / 回拖命中 / LRU 淘汰）行为测试。
///
/// 块大小为 2MiB，测试数据统一用 5MiB（块 0/1 完整 + 块 2 半块），
/// 便于构造「部分命中 + 回源填充」的场景。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  const blockSize = 2 * 1024 * 1024;
  final data = List<int>.generate(5 * 1024 * 1024, (i) => i % 251);

  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('mobili_stream_cache_test');
    BiliStreamProxy().debugSetCacheDirectory(cacheDir.path);
  });

  tearDown(() async {
    BiliStreamProxy().dispose();
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
    }
  });

  /// 可响应 Range 的上游测试服务器，并记录收到的每次 Range 请求。
  Future<(HttpServer, List<String?>)> startRangeServer(List<int> body) async {
    final seen = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain();
      final range = req.headers.value(HttpHeaders.rangeHeader);
      seen.add(range);
      if (range == null) {
        req.response.statusCode = HttpStatus.ok;
        req.response.contentLength = body.length;
        req.response.add(body);
        await req.response.close();
        return;
      }
      final spec = range.substring('bytes='.length).split(',').first.trim();
      final parts = spec.split('-');
      final start = int.parse(parts[0].trim());
      final rawEnd = parts.length > 1 ? parts[1].trim() : '';
      final end = rawEnd.isEmpty ? body.length - 1 : int.parse(rawEnd);
      if (start >= body.length) {
        req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        req.response.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes */${body.length}');
        await req.response.close();
        return;
      }
      final clampedEnd = math.min(end, body.length - 1);
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$clampedEnd/${body.length}',
      );
      req.response.contentLength = clampedEnd - start + 1;
      req.response.add(body.sublist(start, clampedEnd + 1));
      await req.response.close();
    });
    return (server, seen);
  }

  /// 发起一次 Range 请求并读完响应体。
  Future<(HttpClientResponse, List<int>)> getRange(
    String url,
    String? range,
  ) async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    if (range != null) {
      req.headers.set(HttpHeaders.rangeHeader, range);
    }
    final res = await req.close();
    final body = await res.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
    client.close(force: true);
    return (res, body);
  }

  test('完整播放一遍后，重播与任意区间直接命中磁盘缓存', () async {
    final (upstream, seen) = await startRangeServer(data);
    final proxy = BiliStreamProxy();
    final proxyUrl =
        await proxy.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');

    // 第一遍：开放区间顺序播放（总长未知 → 透传 + 边播边缓存）
    final (first, firstBody) = await getRange(proxyUrl, 'bytes=0-');
    expect(first.statusCode, HttpStatus.partialContent);
    expect(firstBody, equals(data));
    expect(seen.length, 1);
    await proxy.debugFlushPendingWrites();

    // 重播：全部命中缓存，上游不再被请求
    final (replay, replayBody) = await getRange(proxyUrl, 'bytes=0-');
    expect(replayBody, equals(data));
    expect(seen.length, 1);

    // 任意区间回拖：直接从磁盘块出流
    final (mid, midBody) = await getRange(proxyUrl, 'bytes=2097152-3145727');
    expect(mid.statusCode, HttpStatus.partialContent);
    expect(
      mid.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 2097152-3145727/5242880',
    );
    expect(midBody, equals(data.sublist(2097152, 3145728)));
    expect(seen.length, 1, reason: '命中缓存后不应再回源');

    // 后缀区间
    final (_, tailBody) = await getRange(proxyUrl, 'bytes=-10');
    expect(tailBody, equals(data.sublist(data.length - 10)));
    expect(seen.length, 1);

    await upstream.close(force: true);
  });

  test('未缓存的区间回源填充到块边界，多取部分进缓存', () async {
    final (upstream, seen) = await startRangeServer(data);
    final proxy = BiliStreamProxy();
    final proxyUrl =
        await proxy.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');

    // 先只取最后一块（块 2）
    final (_, tailBody) = await getRange(proxyUrl, 'bytes=4194304-5242879');
    expect(tailBody, equals(data.sublist(4194304)));
    expect(seen, ['bytes=4194304-5242879']);
    await proxy.debugFlushPendingWrites();

    // 再取开头 1MiB：块 0 缺失，回源按块对齐取 0..2MiB，多出部分进缓存
    final (_, headBody) = await getRange(proxyUrl, 'bytes=0-1048575');
    expect(headBody, equals(data.sublist(0, 1048576)));
    expect(seen.last, 'bytes=0-2097151', reason: '回源应扩展到块边界');
    await proxy.debugFlushPendingWrites();

    // 块 0 后半段：已随上次填充进缓存，不再回源
    final (_, restBody) = await getRange(proxyUrl, 'bytes=1048576-2097151');
    expect(restBody, equals(data.sublist(1048576, 2097152)));
    expect(seen.length, 2, reason: '块 0 已完整缓存，不应回源');

    await upstream.close(force: true);
  });

  test('稳定缓存键：CDN 地址变化仍命中同一份缓存', () async {
    final (upstream1, seen1) = await startRangeServer(data);
    final (upstream2, seen2) = await startRangeServer(data);
    final proxy = BiliStreamProxy();
    const cacheKey = 'BV1xx411c7mD_100|v80';

    final url1 = await proxy.getProxyUrl(
      'http://127.0.0.1:${upstream1.port}/a.m4s?e=1',
      cacheKey: cacheKey,
    );
    final (_, firstBody) = await getRange(url1, 'bytes=0-');
    expect(firstBody, equals(data));
    await proxy.debugFlushPendingWrites();

    // CDN 签名地址变了，但稳定键相同 → 代理 token 相同 → 缓存命中
    final url2 = await proxy.getProxyUrl(
      'http://127.0.0.1:${upstream2.port}/b.m4s?e=2',
      cacheKey: cacheKey,
    );
    expect(url2, url1, reason: '稳定键应映射到同一个本地 token');
    final (_, secondBody) = await getRange(url2, 'bytes=0-');
    expect(secondBody, equals(data));
    expect(seen2, isEmpty, reason: '内容命中磁盘缓存，不应请求新 CDN 地址');
    expect(seen1.length, 1);

    await upstream1.close(force: true);
    await upstream2.close(force: true);
  });

  test('元数据持久化：重启代理（模拟重启 App）后缓存仍命中', () async {
    final (upstream, seen) = await startRangeServer(data);
    final proxy = BiliStreamProxy();
    final proxyUrl =
        await proxy.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');

    final (_, firstBody) = await getRange(proxyUrl, 'bytes=0-');
    expect(firstBody, equals(data));
    await proxy.debugFlushPendingWrites();
    proxy.dispose();

    // 重建代理（保留磁盘缓存目录），同一稳定键应直接命中
    final reborn = BiliStreamProxy();
    reborn.debugSetCacheDirectory(cacheDir.path);
    final rebornUrl =
        await reborn.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');
    final (_, secondBody) = await getRange(rebornUrl, 'bytes=0-');
    expect(secondBody, equals(data));
    expect(seen.length, 1, reason: '重启后应从磁盘缓存出流');
    reborn.dispose();

    await upstream.close(force: true);
  });

  test('缓存文件被系统清空（如 iOS 清 tmp）后自动回源重建', () async {
    final (upstream, seen) = await startRangeServer(data);
    final proxy = BiliStreamProxy();
    final proxyUrl =
        await proxy.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');

    final (_, firstBody) = await getRange(proxyUrl, 'bytes=0-');
    expect(firstBody, equals(data));
    await proxy.debugFlushPendingWrites();
    proxy.dispose();

    // 模拟系统清空缓存数据文件，但 meta.json 残留
    final entryDir = cacheDir.listSync().whereType<Directory>().first;
    entryDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.blk'))
        .forEach((f) => f.deleteSync());

    final reborn = BiliStreamProxy();
    reborn.debugSetCacheDirectory(cacheDir.path);
    final rebornUrl =
        await reborn.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');
    final (_, secondBody) = await getRange(rebornUrl, 'bytes=0-');
    expect(secondBody, equals(data), reason: '块文件缺失应回源并重建缓存');
    expect(seen.length, 2);
    reborn.dispose();

    await upstream.close(force: true);
  });

  /// 等待上游请求停稳（预取循环在出流结束后异步触发，需轮询收敛）。
  Future<void> waitForUpstreamSettle(List<String?> seen) async {
    var last = -1;
    var stableChecks = 0;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (seen.length == last) {
        stableChecks++;
        if (stableChecks >= 8) return; // 连续 400ms 无新增上游请求
      } else {
        last = seen.length;
        stableChecks = 0;
      }
    }
  }

  test('预测预取：出流结束后把播放位置前方补到预取深度', () async {
    final (upstream, seen) = await startRangeServer(data);
    final proxy = BiliStreamProxy();
    final proxyUrl =
        await proxy.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');

    // 播放器只取开头 1MiB（有界请求），随后停止拉流
    final (_, body) = await getRange(proxyUrl, 'bytes=0-1048575');
    expect(body, data.sublist(0, 1048576));
    await waitForUpstreamSettle(seen);

    // 预取把整段补齐（总长 5MiB < 预取深度 16MiB）
    expect(seen[0], 'bytes=0-1048575');
    expect(seen[1], 'bytes=0-5242879', reason: '预取应从首个缺失块补到深度/EOF');
    expect(seen.length, 2, reason: '预取完成后不应继续回源');

    // 预取区间的任意回拖直接命中缓存
    final (_, midBody) = await getRange(proxyUrl, 'bytes=2097152-3145727');
    expect(midBody, data.sublist(2097152, 3145728));
    expect(seen.length, 2);

    await upstream.close(force: true);
  });

  test('预测预取深度封顶：水位前方最多缓存 16MiB，深度之外仍回源', () async {
    // 40MiB 数据：预取 16MiB 深度无法覆盖全部
    final big = List<int>.generate(40 * 1024 * 1024, (i) => i % 251);
    final (upstream, seen) = await startRangeServer(big);
    final proxy = BiliStreamProxy();
    final proxyUrl =
        await proxy.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');

    // 播放器取开头 1MiB；预取到 水位(1MiB) + 16MiB = 17MiB 为止
    final (_, body) = await getRange(proxyUrl, 'bytes=0-1048575');
    expect(body, big.sublist(0, 1048576));
    await waitForUpstreamSettle(seen);
    expect(seen, [
      'bytes=0-1048575',
      'bytes=0-8388607',
      'bytes=8388608-16777215',
      'bytes=16777216-17825791',
    ], reason: '预取应在 17MiB 处封顶，不继续取 17MiB 之后的内容');

    // 跳到 30MiB（预取深度之外）：回源填充该区间，并从新水位预取到 EOF
    final (_, beyond) = await getRange(proxyUrl, 'bytes=31457280-32505855');
    expect(beyond, big.sublist(31457280, 32505856));
    await waitForUpstreamSettle(seen);
    expect(seen, [
      'bytes=0-1048575',
      'bytes=0-8388607',
      'bytes=8388608-16777215',
      'bytes=16777216-17825791',
      'bytes=31457280-33554431',
      'bytes=33554432-41943039',
    ]);

    await upstream.close(force: true);
  });

  test('向后 seek 超过阈值时重置预取锚点，从新位置向前预取', () async {
    final big = List<int>.generate(40 * 1024 * 1024, (i) => i % 251);
    final (upstream, seen) = await startRangeServer(big);
    final proxy = BiliStreamProxy();
    final proxyUrl =
        await proxy.getProxyUrl('http://127.0.0.1:${upstream.port}/v.m4s');

    // 先播 30MiB 处：首次请求总长未知走精确区间，预取从缺失块对齐补到 EOF
    final (_, body) = await getRange(proxyUrl, 'bytes=31457280-32505855');
    expect(body, big.sublist(31457280, 32505856));
    await waitForUpstreamSettle(seen);
    expect(seen, [
      'bytes=31457280-32505855',
      'bytes=31457280-39845887',
      'bytes=39845888-41943039',
    ]);

    // 回跳到开头（远超 8MiB 阈值）：预取放弃旧位置，改为向前补到 17MiB
    final (_, backBody) = await getRange(proxyUrl, 'bytes=0-1048575');
    expect(backBody, big.sublist(0, 1048576));
    await waitForUpstreamSettle(seen);
    expect(seen, [
      'bytes=31457280-32505855',
      'bytes=31457280-39845887',
      'bytes=39845888-41943039',
      'bytes=0-2097151',
      'bytes=2097152-10485759',
      'bytes=10485760-17825791',
    ]);

    await upstream.close(force: true);
  });

  test('超出总量上限时按 LRU 淘汰最旧条目', () async {
    final proxy = BiliStreamProxy();
    proxy.debugSetMaxCacheBytes(3 * 1024 * 1024);

    final (upA, seenA) = await startRangeServer(data.sublist(0, blockSize));
    final (upB, _) = await startRangeServer(data.sublist(0, blockSize));
    final (upC, _) = await startRangeServer(data.sublist(0, blockSize));

    final urlA = await proxy.getProxyUrl('http://127.0.0.1:${upA.port}/a.m4s');
    final urlB = await proxy.getProxyUrl('http://127.0.0.1:${upB.port}/b.m4s');
    final urlC = await proxy.getProxyUrl('http://127.0.0.1:${upC.port}/c.m4s');

    final (_, bodyA1) = await getRange(urlA, 'bytes=0-');
    expect(bodyA1, data.sublist(0, blockSize));
    final (_, bodyB1) = await getRange(urlB, 'bytes=0-');
    expect(bodyB1, data.sublist(0, blockSize));
    // A + B = 4MiB > 3MiB：写 C 的块触发淘汰时最旧的 A 被删，B 也被挤出
    final (_, bodyC1) = await getRange(urlC, 'bytes=0-');
    expect(bodyC1, data.sublist(0, blockSize));
    await proxy.debugFlushPendingWrites();

    final dirs = cacheDir.listSync().whereType<Directory>().length;
    expect(dirs, 1, reason: '上限 3MiB 只应留下最后访问的 C');

    // A 的缓存已被淘汰；再次播放 A 需要重新回源
    final (_, bodyA2) = await getRange(urlA, 'bytes=0-');
    expect(bodyA2, data.sublist(0, blockSize));
    expect(seenA.length, 2, reason: '被淘汰的条目应重新回源');

    await upA.close(force: true);
    await upB.close(force: true);
    await upC.close(force: true);
  });
}
