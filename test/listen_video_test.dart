import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/providers/listen_video_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ListenVideoProvider Tests', () {
    late ListenVideoProvider provider;

    setUp(() {
      provider = ListenVideoProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initial state is empty and not playing', () {
      expect(provider.hasAudio, isFalse);
      expect(provider.isPlaying, isFalse);
      expect(provider.position, Duration.zero);
      expect(provider.duration, Duration.zero);
      expect(provider.speed, 1.0);
      expect(provider.isSleepTimerActive, isFalse);
    });

    test('Sleep timer sets and cancels correctly', () {
      provider.setSleepTimer(const Duration(minutes: 15));
      expect(provider.isSleepTimerActive, isTrue);
      expect(provider.sleepTimerRemaining, const Duration(minutes: 15));
      expect(provider.isSleepEndOfTrack, isFalse);

      provider.cancelSleepTimer();
      expect(provider.isSleepTimerActive, isFalse);
      expect(provider.sleepTimerRemaining, isNull);
    });

    test('Sleep timer endOfTrack mode sets correctly', () {
      provider.setSleepTimer(null, endOfTrack: true);
      expect(provider.isSleepEndOfTrack, isTrue);

      provider.cancelSleepTimer();
      expect(provider.isSleepEndOfTrack, isFalse);
    });

    test('Stop and clear resets all metadata', () async {
      provider.setSleepTimer(const Duration(minutes: 30));
      await provider.stopAndClear();

      expect(provider.hasAudio, isFalse);
      expect(provider.bvid, isNull);
      expect(provider.title, isNull);
      expect(provider.isSleepTimerActive, isFalse);
    });
  });
}
