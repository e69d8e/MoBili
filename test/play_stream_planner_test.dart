import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/player/play_stream_planner.dart';

void main() {
  group('planFirstRequest', () {
    test('guest always uses progressive single stream (DASH would only grant 480P)', () {
      final low = planFirstRequest(isLoggedIn: false, qn: 64);
      expect(low.kind, equals(PlayStreamKind.progressive));
      expect(low.fnval, equals(kProgressiveFnval));
      expect(low.qn, equals(64));

      final high = planFirstRequest(isLoggedIn: false, qn: 80);
      expect(high.kind, equals(PlayStreamKind.progressive));
      expect(high.fnval, equals(kProgressiveFnval));
      expect(high.qn, equals(80));
    });

    test('logged-in below 1080P keeps progressive single stream', () {
      final plan = planFirstRequest(isLoggedIn: true, qn: 64);
      expect(plan.kind, equals(PlayStreamKind.progressive));
      expect(plan.fnval, equals(kProgressiveFnval));
    });

    test('logged-in at 1080P and above requests DASH with fnval=4048', () {
      for (final qn in [80, 112, 116, 120]) {
        final plan = planFirstRequest(isLoggedIn: true, qn: qn);
        expect(plan.kind, equals(PlayStreamKind.dash), reason: 'qn=$qn');
        expect(plan.fnval, equals(kDashFnvalAll), reason: 'qn=$qn');
        expect(plan.qn, equals(qn), reason: 'qn=$qn');
      }
    });

    test('invalid target quality falls back to 1080P', () {
      final plan = planFirstRequest(isLoggedIn: true, qn: 0);
      expect(plan.qn, equals(kMinDashQuality));
      expect(plan.kind, equals(PlayStreamKind.dash));
    });
  });

  group('planProgressiveFallback', () {
    test('DASH grant below 1080P triggers a progressive second request', () {
      final fallback = planProgressiveFallback(
        currentKind: PlayStreamKind.dash,
        grantedQuality: 64,
        requestedQn: 80,
      );
      expect(fallback, isNotNull);
      expect(fallback!.kind, equals(PlayStreamKind.progressive));
      expect(fallback.fnval, equals(kProgressiveFnval));
      expect(fallback.qn, equals(80));
    });

    test('DASH grant of 1080P or above needs no fallback', () {
      expect(
        planProgressiveFallback(
          currentKind: PlayStreamKind.dash,
          grantedQuality: 80,
          requestedQn: 80,
        ),
        isNull,
      );
      expect(
        planProgressiveFallback(
          currentKind: PlayStreamKind.dash,
          grantedQuality: 112,
          requestedQn: 80,
        ),
        isNull,
      );
    });

    test('progressive first request never triggers a second request', () {
      expect(
        planProgressiveFallback(
          currentKind: PlayStreamKind.progressive,
          grantedQuality: 64,
          requestedQn: 80,
        ),
        isNull,
      );
    });
  });

  group('isDashStreamUrl', () {
    test('detects .m4s DASH tracks with query strings', () {
      expect(
        isDashStreamUrl('https://upos-sz-mirrorali.bilivideo.com/x/video.m4s?deadline=1'),
        isTrue,
      );
      expect(isDashStreamUrl('https://upos.bilibili.com/audio.M4S'), isTrue);
    });

    test('progressive mp4 files are not DASH tracks', () {
      expect(isDashStreamUrl('https://upos.bilibili.com/video.mp4?x=1'), isFalse);
      expect(isDashStreamUrl('file:///tmp/video_BV1_cid.mp4'), isFalse);
      expect(isDashStreamUrl(''), isFalse);
    });
  });

  group('shouldCorrectDrift', () {
    final base = DateTime(2026, 1, 1, 12, 0, 0);

    test('small drift is ignored', () {
      expect(
        shouldCorrectDrift(
          videoPosition: const Duration(seconds: 10),
          audioPosition: const Duration(milliseconds: 10300),
          isSeeking: false,
          now: base,
        ),
        isFalse,
      );
    });

    test('drift beyond threshold triggers correction', () {
      expect(
        shouldCorrectDrift(
          videoPosition: const Duration(seconds: 10),
          audioPosition: const Duration(milliseconds: 9400),
          isSeeking: false,
          now: base,
        ),
        isTrue,
      );
    });

    test('never corrects while the user is dragging the progress bar', () {
      expect(
        shouldCorrectDrift(
          videoPosition: const Duration(seconds: 10),
          audioPosition: const Duration(seconds: 2),
          isSeeking: true,
          now: base,
        ),
        isFalse,
      );
    });

    test('corrections are rate limited to the resync interval', () {
      final lastSync = base.subtract(kDashAudioResyncInterval - const Duration(milliseconds: 500));
      expect(
        shouldCorrectDrift(
          videoPosition: const Duration(seconds: 10),
          audioPosition: const Duration(seconds: 5),
          isSeeking: false,
          lastSyncAt: lastSync,
          now: base,
        ),
        isFalse,
      );

      final oldSync = base.subtract(kDashAudioResyncInterval + const Duration(milliseconds: 500));
      expect(
        shouldCorrectDrift(
          videoPosition: const Duration(seconds: 10),
          audioPosition: const Duration(seconds: 5),
          isSeeking: false,
          lastSyncAt: oldSync,
          now: base,
        ),
        isTrue,
      );
    });
  });

  group('evaluateDualStreamSync', () {
    test('video buffering pauses playing audio to prevent frozen picture with continuing sound', () {
      final decision = evaluateDualStreamSync(
        isExplicitlyPaused: false,
        isRecovering: false,
        videoInitialized: true,
        videoPlaying: false,
        videoBuffering: true,
        videoCompleted: false,
        videoHasError: false,
        audioInitialized: true,
        audioPlaying: true,
        audioBuffering: false,
        audioCompleted: false,
        audioHasError: false,
        isSyncPausedAudio: false,
        isSyncPausedVideo: false,
      );

      expect(decision.pauseAudio, isTrue);
      expect(decision.nextSyncPausedAudio, isTrue);
      expect(decision.pauseVideo, isFalse);
    });

    test('audio resumes once video buffering finishes', () {
      final decision = evaluateDualStreamSync(
        isExplicitlyPaused: false,
        isRecovering: false,
        videoInitialized: true,
        videoPlaying: true,
        videoBuffering: false,
        videoCompleted: false,
        videoHasError: false,
        audioInitialized: true,
        audioPlaying: false,
        audioBuffering: false,
        audioCompleted: false,
        audioHasError: false,
        isSyncPausedAudio: true,
        isSyncPausedVideo: false,
      );

      expect(decision.resumeAudio, isTrue);
      expect(decision.nextSyncPausedAudio, isFalse);
    });

    test('audio buffering pauses playing video and resumes both when ready', () {
      final pauseVideo = evaluateDualStreamSync(
        isExplicitlyPaused: false,
        isRecovering: false,
        videoInitialized: true,
        videoPlaying: true,
        videoBuffering: false,
        videoCompleted: false,
        videoHasError: false,
        audioInitialized: true,
        audioPlaying: false,
        audioBuffering: true,
        audioCompleted: false,
        audioHasError: false,
        isSyncPausedAudio: false,
        isSyncPausedVideo: false,
      );
      expect(pauseVideo.pauseVideo, isTrue);
      expect(pauseVideo.nextSyncPausedVideo, isTrue);

      final resumeBoth = evaluateDualStreamSync(
        isExplicitlyPaused: false,
        isRecovering: false,
        videoInitialized: true,
        videoPlaying: false,
        videoBuffering: false,
        videoCompleted: false,
        videoHasError: false,
        audioInitialized: true,
        audioPlaying: false,
        audioBuffering: false,
        audioCompleted: false,
        audioHasError: false,
        isSyncPausedAudio: false,
        isSyncPausedVideo: true,
      );
      expect(resumeBoth.resumeVideo, isTrue);
      expect(resumeBoth.resumeAudio, isTrue);
      expect(resumeBoth.nextSyncPausedVideo, isFalse);
    });

    test('simultaneous buffering clearing audio first unpauses video without deadlock', () {
      final decision = evaluateDualStreamSync(
        isExplicitlyPaused: false,
        isRecovering: false,
        videoInitialized: true,
        videoPlaying: false,
        videoBuffering: true,
        videoCompleted: false,
        videoHasError: false,
        audioInitialized: true,
        audioPlaying: false,
        audioBuffering: false,
        audioCompleted: false,
        audioHasError: false,
        isSyncPausedAudio: true,
        isSyncPausedVideo: true,
      );

      expect(decision.resumeVideo, isTrue);
      expect(decision.nextSyncPausedVideo, isFalse);
      expect(decision.resumeAudio, isFalse);
      expect(decision.nextSyncPausedAudio, isTrue);
    });

    test('explicit pause suppresses all automatic resume/pause actions', () {
      final decision = evaluateDualStreamSync(
        isExplicitlyPaused: true,
        isRecovering: false,
        videoInitialized: true,
        videoPlaying: false,
        videoBuffering: false,
        videoCompleted: false,
        videoHasError: false,
        audioInitialized: true,
        audioPlaying: false,
        audioBuffering: false,
        audioCompleted: false,
        audioHasError: false,
        isSyncPausedAudio: true,
        isSyncPausedVideo: false,
      );

      expect(decision.hasAction, isFalse);
    });

    test('video error or completion pauses continuing audio', () {
      final errDecision = evaluateDualStreamSync(
        isExplicitlyPaused: false,
        isRecovering: false,
        videoInitialized: true,
        videoPlaying: false,
        videoBuffering: false,
        videoCompleted: false,
        videoHasError: true,
        audioInitialized: true,
        audioPlaying: true,
        audioBuffering: false,
        audioCompleted: false,
        audioHasError: false,
        isSyncPausedAudio: false,
        isSyncPausedVideo: false,
      );
      expect(errDecision.pauseAudio, isTrue);
    });
  });

  group('evaluateVideoStall', () {
    test('detects silent freeze quickly when audio keeps advancing ahead of stuck video', () {
      final stall = evaluateVideoStall(
        isInitialized: true,
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        hasError: false,
        isExplicitlyPaused: false,
        isSyncPausedVideo: false,
        isSeeking: false,
        isRecovering: false,
        videoPosition: const Duration(seconds: 20),
        videoDuration: const Duration(minutes: 3),
        stalledFor: const Duration(milliseconds: 1600),
        audioPlaying: true,
        audioPosition: const Duration(seconds: 21),
      );
      expect(stall, equals(VideoStallKind.silentFreeze));
    });

    test('detects silent freeze on single-stream when position stalls past threshold', () {
      final before = evaluateVideoStall(
        isInitialized: true,
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        hasError: false,
        isExplicitlyPaused: false,
        isSyncPausedVideo: false,
        isSeeking: false,
        isRecovering: false,
        videoPosition: const Duration(seconds: 20),
        videoDuration: const Duration(minutes: 3),
        stalledFor: const Duration(seconds: 2),
      );
      expect(before, equals(VideoStallKind.none));

      final after = evaluateVideoStall(
        isInitialized: true,
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        hasError: false,
        isExplicitlyPaused: false,
        isSyncPausedVideo: false,
        isSeeking: false,
        isRecovering: false,
        videoPosition: const Duration(seconds: 20),
        videoDuration: const Duration(minutes: 3),
        stalledFor: kVideoSilentFreezeTimeout,
      );
      expect(after, equals(VideoStallKind.silentFreeze));
    });

    test('detects buffering timeout and unexpected stop but ignores near-EOF', () {
      expect(
        evaluateVideoStall(
          isInitialized: true,
          isPlaying: false,
          isBuffering: true,
          isCompleted: false,
          hasError: false,
          isExplicitlyPaused: false,
          isSyncPausedVideo: false,
          isSeeking: false,
          isRecovering: false,
          videoPosition: const Duration(seconds: 20),
          videoDuration: const Duration(minutes: 3),
          stalledFor: kVideoBufferingStallTimeout,
        ),
        equals(VideoStallKind.bufferTimeout),
      );

      expect(
        evaluateVideoStall(
          isInitialized: true,
          isPlaying: false,
          isBuffering: false,
          isCompleted: false,
          hasError: false,
          isExplicitlyPaused: false,
          isSyncPausedVideo: false,
          isSeeking: false,
          isRecovering: false,
          videoPosition: const Duration(seconds: 20),
          videoDuration: const Duration(minutes: 3),
          stalledFor: kVideoUnexpectedStopTimeout,
        ),
        equals(VideoStallKind.unexpectedStop),
      );

      expect(
        evaluateVideoStall(
          isInitialized: true,
          isPlaying: true,
          isBuffering: false,
          isCompleted: false,
          hasError: false,
          isExplicitlyPaused: false,
          isSyncPausedVideo: false,
          isSeeking: false,
          isRecovering: false,
          videoPosition: const Duration(milliseconds: 179800),
          videoDuration: const Duration(minutes: 3),
          stalledFor: const Duration(seconds: 10),
        ),
        equals(VideoStallKind.none),
      );
    });
  });
}
