import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mobili/utils/formatters.dart';

void main() {
  group('Formatters Unit Tests', () {
    group('formatCount Tests', () {
      test('handles null and negative numbers gracefully', () {
        expect(Formatters.formatCount(null), equals('0'));
        expect(Formatters.formatCount(-1), equals('0'));
        expect(Formatters.formatCount(-999), equals('0'));
      });

      test('formats small numbers (< 10000) directly as strings', () {
        expect(Formatters.formatCount(0), equals('0'));
        expect(Formatters.formatCount(1), equals('1'));
        expect(Formatters.formatCount(999), equals('999'));
        expect(Formatters.formatCount(9999), equals('9999'));
      });

      test('formats numbers in wan (10,000 to 99,999,999)', () {
        expect(Formatters.formatCount(10000), equals('1.0万'));
        expect(Formatters.formatCount(12345), equals('1.2万'));
        expect(Formatters.formatCount(99000), equals('9.9万'));
        expect(Formatters.formatCount(100000), equals('10.0万'));
        expect(Formatters.formatCount(99990000), equals('9999.0万'));
      });

      test('formats large numbers in yi (>= 100,000,000)', () {
        expect(Formatters.formatCount(100000000), equals('1.0亿'));
        expect(Formatters.formatCount(123456789), equals('1.2亿'));
        expect(Formatters.formatCount(5000000000), equals('50.0亿'));
      });
    });

    group('formatDuration Tests', () {
      test('handles null and zero/negative durations', () {
        expect(Formatters.formatDuration(null), equals('00:00'));
        expect(Formatters.formatDuration(0), equals('00:00'));
        expect(Formatters.formatDuration(-10), equals('00:00'));
      });

      test('formats durations under one hour (mm:ss)', () {
        expect(Formatters.formatDuration(1), equals('00:01'));
        expect(Formatters.formatDuration(9), equals('00:09'));
        expect(Formatters.formatDuration(59), equals('00:59'));
        expect(Formatters.formatDuration(60), equals('01:00'));
        expect(Formatters.formatDuration(125), equals('02:05'));
        expect(Formatters.formatDuration(3599), equals('59:59'));
      });

      test('formats durations over one hour (hh:mm:ss)', () {
        expect(Formatters.formatDuration(3600), equals('01:00:00'));
        expect(Formatters.formatDuration(3665), equals('01:01:05'));
        expect(Formatters.formatDuration(7322), equals('02:02:02'));
        expect(Formatters.formatDuration(86400), equals('24:00:00'));
      });
    });

    group('formatDurationFromMs Tests', () {
      test('handles null and millisecond conversions', () {
        expect(Formatters.formatDurationFromMs(null), equals('00:00'));
        expect(Formatters.formatDurationFromMs(0), equals('00:00'));
        expect(Formatters.formatDurationFromMs(1500), equals('00:01'));
        expect(Formatters.formatDurationFromMs(65000), equals('01:05'));
        expect(Formatters.formatDurationFromMs(3665000), equals('01:01:05'));
      });
    });

    group('formatTime Tests', () {
      test('handles null and non-positive timestamps', () {
        expect(Formatters.formatTime(null), equals(''));
        expect(Formatters.formatTime(0), equals(''));
        expect(Formatters.formatTime(-100), equals(''));
      });

      test('formats relative time within 60 seconds as 刚刚', () {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(Formatters.formatTime(nowSec - 10), equals('刚刚'));
        expect(Formatters.formatTime(nowSec), equals('刚刚'));
      });

      test('formats relative time in minutes (< 60 minutes)', () {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(Formatters.formatTime(nowSec - 120), equals('2分钟前'));
        expect(Formatters.formatTime(nowSec - 3500), equals('58分钟前'));
      });

      test('formats relative time in hours (< 24 hours)', () {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(Formatters.formatTime(nowSec - 3600 * 2), equals('2小时前'));
        expect(Formatters.formatTime(nowSec - 3600 * 23), equals('23小时前'));
      });

      test('formats relative time in days (< 7 days)', () {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(Formatters.formatTime(nowSec - 86400 * 3), equals('3天前'));
        expect(Formatters.formatTime(nowSec - 86400 * 6), equals('6天前'));
      });

      test('formats dates earlier in the current year or across years', () {
        final now = DateTime.now();
        // 30 days ago
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        final formatted30 = Formatters.formatTime(thirtyDaysAgo.millisecondsSinceEpoch ~/ 1000);
        if (thirtyDaysAgo.year == now.year) {
          expect(formatted30, equals(DateFormat('MM-dd').format(thirtyDaysAgo)));
        } else {
          expect(formatted30, equals(DateFormat('yyyy-MM-dd').format(thirtyDaysAgo)));
        }

        // Two years ago
        final twoYearsAgo = DateTime(now.year - 2, 5, 20, 10, 0);
        final formattedPast = Formatters.formatTime(twoYearsAgo.millisecondsSinceEpoch ~/ 1000);
        expect(formattedPast, equals(DateFormat('yyyy-MM-dd').format(twoYearsAgo)));
      });
    });
  });
}
