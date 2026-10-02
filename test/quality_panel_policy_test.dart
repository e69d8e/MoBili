import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/play_url_model.dart';
import 'package:mobili/services/player/quality_panel_policy.dart';

/// 实测样本：BV1aza76HERk（4K30 视频）大会员请求 qn=116 的真实响应。
/// 视频只提供 [120, 112, 80, 64, 32, 16]，**没有 116（1080P 60帧）**。
PlayUrlInfo fourK30Video() => PlayUrlInfo(
  currentQuality: 112,
  format: 'dash',
  timelength: 202000,
  acceptQuality: const [120, 112, 80, 64, 32, 16],
  acceptDescription: const [
    '高清 4K',
    '高清 1080P+',
    '高清 1080P',
    '高清 720P',
    '清晰 480P',
    '流畅 360P',
  ],
  durls: const [],
  supportFormats: [
    for (final e in <(int, String)>[
      (120, '高清 4K'),
      (112, '高清 1080P+'),
      (80, '高清 1080P'),
      (64, '高清 720P'),
      (32, '清晰 480P'),
      (16, '流畅 360P'),
    ])
      SupportFormat(quality: e.$1, format: 'dash', newDescription: e.$2, displayDesc: e.$2),
  ],
  videoTracks: [
    for (final id in [16, 32, 64, 80, 112, 120])
      DashVideoItem(
        id: id,
        baseUrl: 'https://upos.bilibili.com/v_$id.m4s',
        mimeType: 'video/mp4',
        codecs: 'avc1.640032',
        width: id >= 112 ? 1920 : 1280,
        height: id >= 112 ? 1080 : 720,
        bandwidth: id * 100000,
        backupUrls: const [],
      ),
  ],
  audioTracks: const [],
  videoCodecid: 7,
  requestedQuality: 112,
);

/// 实测样本：BV1Q8ae6aED9（60帧视频）大会员请求 qn=116 的真实响应。
PlayUrlInfo sixtyFpsVideo() => PlayUrlInfo(
  currentQuality: 116,
  format: 'dash',
  timelength: 2486000,
  acceptQuality: const [120, 116, 80, 64, 32, 16],
  acceptDescription: const [],
  durls: const [],
  supportFormats: [
    for (final e in <(int, String)>[
      (120, '高清 4K'),
      (116, '高清 1080P60'),
      (80, '高清 1080P'),
      (64, '高清 720P'),
      (32, '清晰 480P'),
      (16, '流畅 360P'),
    ])
      SupportFormat(quality: e.$1, format: 'dash', newDescription: e.$2, displayDesc: e.$2),
  ],
  videoTracks: [
    for (final id in [16, 32, 64, 80, 116, 120])
      DashVideoItem(
        id: id,
        baseUrl: 'https://upos.bilibili.com/v_$id.m4s',
        mimeType: 'video/mp4',
        codecs: 'avc1.640032',
        width: 1920,
        height: 1080,
        bandwidth: id * 100000,
        backupUrls: const [],
      ),
  ],
  audioTracks: const [],
  videoCodecid: 7,
  requestedQuality: 116,
);

String fakeLabel(int q) => switch (q) {
  127 => '8K',
  120 => '4K',
  116 => '1080P 60帧',
  112 => '1080P 高码率',
  80 => '1080P 高清',
  74 => '720P 60帧',
  64 => '720P 高清',
  32 => '480P 清晰',
  16 => '360P 流畅',
  _ => '$q P',
};

void main() {
  group('buildQualityPanelItems', () {
    test('60帧视频列出含 1080P 60帧 的全部真实档位', () {
      final items = buildQualityPanelItems(sixtyFpsVideo(), isLoggedIn: true, labelOf: fakeLabel);
      expect(items.map((i) => i.quality), equals(const [120, 116, 80, 64, 32, 16]));
      expect(items.firstWhere((i) => i.quality == 116).description, equals('高清 1080P60'));
    });

    test('4K30 视频不得虚构 1080P 60帧 选项（回归：大会员误报需大会员）', () {
      final items = buildQualityPanelItems(fourK30Video(), isLoggedIn: true, labelOf: fakeLabel);
      expect(items.map((i) => i.quality), equals(const [120, 112, 80, 64, 32, 16]));
      expect(items.any((i) => i.quality == 116), isFalse,
          reason: '视频没有 60 帧轨，面板不能显示"1080P 60帧"诱导用户点击');
    });

    test('完全无声明时回退到 DASH 实际视频轨画质', () {
      final info = PlayUrlInfo(
        currentQuality: 80,
        format: 'dash',
        timelength: 1000,
        acceptQuality: const [],
        acceptDescription: const [],
        durls: const [],
        supportFormats: const [],
        videoTracks: [
          for (final id in [16, 32, 64, 80])
            DashVideoItem(
              id: id,
              baseUrl: 'https://upos.bilibili.com/v_$id.m4s',
              mimeType: 'video/mp4',
              codecs: 'avc1.640028',
              width: 1280,
              height: 720,
              bandwidth: id * 10000,
              backupUrls: const [],
            ),
        ],
        audioTracks: const [],
        videoCodecid: 7,
      );
      final items = buildQualityPanelItems(info, isLoggedIn: true, labelOf: fakeLabel);
      expect(items.map((i) => i.quality), equals(const [80, 64, 32, 16]));
    });

    test('渐进式且无任何声明时只给当前画质及其下常规档，不虚构高阶档', () {
      final info = PlayUrlInfo(
        currentQuality: 64,
        format: 'mp4',
        timelength: 1000,
        acceptQuality: const [],
        acceptDescription: const [],
        durls: [
          PlayUrlDurl(
            order: 1,
            length: 1000,
            size: 1,
            url: 'https://upos.bilibili.com/v.mp4',
            backupUrls: const [],
          ),
        ],
        supportFormats: const [],
        videoTracks: const [],
        audioTracks: const [],
        videoCodecid: 7,
      );
      final items = buildQualityPanelItems(info, isLoggedIn: true, labelOf: fakeLabel);
      expect(items.map((i) => i.quality), equals(const [64, 32, 16]));
      expect(items.any((i) => i.quality >= 80), isFalse);
    });

    test('未登录时 1080P 及以上档位标记锁定', () {
      final items = buildQualityPanelItems(sixtyFpsVideo(), isLoggedIn: false, labelOf: fakeLabel);
      expect(items.firstWhere((i) => i.quality == 120).locked, isTrue);
      expect(items.firstWhere((i) => i.quality == 116).locked, isTrue);
      expect(items.firstWhere((i) => i.quality == 64).locked, isFalse);
    });
  });

  group('qualityDowngradeMessage', () {
    test('视频没有该画质时不得提示需大会员（回归）', () {
      final msg = qualityDowngradeMessage(
        requested: 116,
        granted: 112,
        isLogin: true,
        videoOffersQuality: false,
        labelOf: fakeLabel,
      );
      expect(msg, equals('该视频未提供1080P 60帧画质，已切换至1080P 高码率'));
      expect(msg, isNot(contains('大会员')));
    });

    test('视频有该画质且已登录高阶档 → 提示需大会员', () {
      final msg = qualityDowngradeMessage(
        requested: 116,
        granted: 80,
        isLogin: true,
        videoOffersQuality: true,
        labelOf: fakeLabel,
      );
      expect(msg, equals('1080P 60帧需大会员，已切换至1080P 高清'));
    });

    test('视频有该画质但未登录 → 提示需登录', () {
      final msg = qualityDowngradeMessage(
        requested: 80,
        granted: 64,
        isLogin: false,
        videoOffersQuality: true,
        labelOf: fakeLabel,
      );
      expect(msg, equals('1080P 高清需登录后观看，已切换至720P 高清'));
    });

    test('低阶档降级 → 中性文案', () {
      final msg = qualityDowngradeMessage(
        requested: 64,
        granted: 32,
        isLogin: true,
        videoOffersQuality: true,
        labelOf: fakeLabel,
      );
      expect(msg, equals('已为当前流适配最高可用画质480P 清晰'));
    });

    test('未降级（granted >= requested）不提示', () {
      expect(
        qualityDowngradeMessage(
          requested: 80,
          granted: 112,
          isLogin: true,
          videoOffersQuality: false,
          labelOf: fakeLabel,
        ),
        isNull,
      );
    });
  });

  group('declaredQualities', () {
    test('取 support_formats 与 accept_quality 的并集', () {
      final info = fourK30Video();
      expect(declaredQualities(info), equals(<int>{120, 112, 80, 64, 32, 16}));
    });
  });
}
