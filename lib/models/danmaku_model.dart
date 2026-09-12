import 'package:flutter/material.dart';

enum DanmakuMode {
  scroll, // 1, 2, 3
  bottom, // 4
  top,    // 5
  reverse,// 6
  other,
}

class DanmakuItem {
  final double timePoint; // in seconds
  final DanmakuMode mode;
  final double fontSize;
  final Color color;
  final int timestamp;
  final String senderHash;
  final String text;
  final String dmid;

  DanmakuItem({
    required this.timePoint,
    required this.mode,
    required this.fontSize,
    required this.color,
    required this.timestamp,
    required this.senderHash,
    required this.text,
    this.dmid = '',
  });

  /// Parse from Bilibili XML `<d p="...">text</d>` parameter string
  static DanmakuItem? fromXml(String pAttr, String content) {
    if (content.trim().isEmpty) return null;
    final parts = pAttr.split(',');
    if (parts.length < 5) return null;

    final time = double.tryParse(parts[0]) ?? 0.0;
    final modeInt = int.tryParse(parts[1]) ?? 1;
    final fontSz = (double.tryParse(parts[2]) ?? 25.0) * 0.6; // scale font size for mobile
    final colorInt = int.tryParse(parts[3]) ?? 16777215;
    final ts = int.tryParse(parts[4]) ?? 0;
    final hash = parts.length > 6 ? parts[6] : '';
    final id = parts.length > 7 ? parts[7] : '';

    DanmakuMode dMode = DanmakuMode.scroll;
    if (modeInt == 4) {
      dMode = DanmakuMode.bottom;
    } else if (modeInt == 5) {
      dMode = DanmakuMode.top;
    } else if (modeInt == 6) {
      dMode = DanmakuMode.reverse;
    }

    final Color c = Color(0xFF000000 | (colorInt & 0xFFFFFF));

    return DanmakuItem(
      timePoint: time,
      mode: dMode,
      fontSize: fontSz.clamp(12.0, 24.0),
      color: c,
      timestamp: ts,
      senderHash: hash,
      text: content,
      dmid: id,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DanmakuItem) return false;
    if (dmid.isNotEmpty && other.dmid.isNotEmpty) {
      return dmid == other.dmid;
    }
    return other.timePoint == timePoint &&
        other.mode == mode &&
        other.color.toARGB32() == color.toARGB32() &&
        other.text == text &&
        other.fontSize == fontSize;
  }

  @override
  int get hashCode {
    if (dmid.isNotEmpty) return dmid.hashCode;
    return Object.hash(timePoint, mode, color.toARGB32(), text, fontSize);
  }
}
