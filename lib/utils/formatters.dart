import 'package:intl/intl.dart';

class Formatters {
  /// Format view/danmaku count: 12345 -> 1.2万, 123456789 -> 1.2亿
  static String formatCount(int? count) {
    if (count == null || count < 0) return '0';
    if (count < 10000) {
      return count.toString();
    } else if (count < 100000000) {
      final double wan = count / 10000.0;
      return '${wan.toStringAsFixed(1)}万';
    } else {
      final double yi = count / 100000000.0;
      return '${yi.toStringAsFixed(1)}亿';
    }
  }

  /// Format duration in seconds to mm:ss or hh:mm:ss
  static String formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;

    final String mm = m.toString().padLeft(2, '0');
    final String ss = s.toString().padLeft(2, '0');

    if (h > 0) {
      final String hh = h.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Format duration from milliseconds
  static String formatDurationFromMs(int? milliseconds) {
    if (milliseconds == null) return '00:00';
    return formatDuration(milliseconds ~/ 1000);
  }

  static final DateFormat _monthDayFormat = DateFormat('MM-dd');
  static final DateFormat _yearMonthDayFormat = DateFormat('yyyy-MM-dd');

  /// Format timestamp (seconds since epoch) to relative or absolute date
  static String formatTime(int? timestamp) {
    if (timestamp == null || timestamp <= 0) return '';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else if (date.year == now.year) {
      return _monthDayFormat.format(date);
    } else {
      return _yearMonthDayFormat.format(date);
    }
  }
}
