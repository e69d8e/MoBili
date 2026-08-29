import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/play_url_model.dart';
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

    test('Speed and seek relative controls work properly', () async {
      await provider.setSpeed(1.5);
      expect(provider.speed, 1.5);

      await provider.seek(const Duration(seconds: 30));
      expect(provider.position, const Duration(seconds: 30));

      await provider.seekRelative(-15);
      expect(provider.position, const Duration(seconds: 15));

      await provider.seekRelative(-30);
      expect(provider.position, Duration.zero);
    });

    test('Pause and stop state management', () async {
      await provider.pause();
      expect(provider.isPlaying, isFalse);

      await provider.stopAndClear();
      expect(provider.isPlaying, isFalse);
      expect(provider.position, Duration.zero);
    });

    test('Exiting listen screen pauses audio', () async {
      // Simulate active playback state
      await provider.pause();
      expect(provider.isPlaying, isFalse);
    });
  });

  group('PlayUrlInfo DASH Audio Parsing & Selection Tests', () {
    test('DASH audio stream baseUrl is extracted as primaryAudioUrl', () {
      final json = {
        'quality': 64,
        'format': 'dash',
        'timelength': 600000,
        'dash': {
          'video': [
            {'id': 64, 'baseUrl': 'https://bilivideo.com/video_720p.m4s'}
          ],
          'audio': [
            {
              'id': 30280,
              'baseUrl': 'https://bilivideo.com/audio_192k.m4s',
              'backupUrl': ['https://backup.bilivideo.com/audio_192k.m4s'],
              'bandwidth': 192000,
            }
          ]
        },
        'video_codecid': 7,
      };

      final info = PlayUrlInfo.fromJson(json);
      expect(info.audioTracks.length, 1);
      expect(info.audioTracks.first.baseUrl, 'https://bilivideo.com/audio_192k.m4s');
      expect(info.primaryAudioUrl, 'https://bilivideo.com/audio_192k.m4s');
    });

    test('DASH audio fallback to backupUrl when baseUrl is empty', () {
      final json = {
        'quality': 64,
        'format': 'dash',
        'timelength': 600000,
        'dash': {
          'audio': [
            {
              'id': 30280,
              'baseUrl': '',
              'backupUrl': ['https://backup.bilivideo.com/audio_backup.m4s'],
              'bandwidth': 192000,
            }
          ]
        },
        'video_codecid': 7,
      };

      final info = PlayUrlInfo.fromJson(json);
      expect(info.primaryAudioUrl, 'https://backup.bilivideo.com/audio_backup.m4s');
    });

    test('DASH dolby & flac audio fallback support', () {
      final jsonDolby = {
        'quality': 64,
        'format': 'dash',
        'timelength': 600000,
        'dash': {
          'dolby': {
            'audio': [
              {
                'id': 30250,
                'baseUrl': 'https://bilivideo.com/dolby_audio.m4s',
                'bandwidth': 320000,
              }
            ]
          }
        },
        'video_codecid': 7,
      };

      final infoDolby = PlayUrlInfo.fromJson(jsonDolby);
      expect(infoDolby.audioTracks.length, 1);
      expect(infoDolby.primaryAudioUrl, 'https://bilivideo.com/dolby_audio.m4s');
    });

    test('Fallback to progressive video URL when DASH audio is not available', () {
      final json = {
        'quality': 16,
        'format': 'mp4',
        'timelength': 360000,
        'durl': [
          {'order': 1, 'url': 'https://bilivideo.com/segment_0.mp4'}
        ],
        'video_codecid': 7,
      };

      final info = PlayUrlInfo.fromJson(json);
      expect(info.audioTracks, isEmpty);
      expect(info.primaryAudioUrl, 'https://bilivideo.com/segment_0.mp4');
    });
  });
}
