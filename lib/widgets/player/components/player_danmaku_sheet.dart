import 'package:flutter/material.dart';
import '../danmaku_overlay.dart';

/// Modal bottom sheet for configuring player danmaku opacity, font size, and area ratio.
class PlayerDanmakuSheet {
  static void show(
    BuildContext context, {
    required DanmakuController danmakuController,
    required Color accent,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        '弹幕设置',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Opacity
                    Row(
                      children: [
                        const Text('不透明度', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: danmakuController.opacity,
                            min: 0.2,
                            max: 1.0,
                            activeColor: accent,
                            inactiveColor: Colors.white24,
                            thumbColor: accent,
                            onChanged: (val) {
                              setSheetState(() {});
                              danmakuController.setOpacity(val);
                            },
                          ),
                        ),
                        Text(
                          '${(danmakuController.opacity * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    // Font Size
                    Row(
                      children: [
                        const Text('字体大小', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: danmakuController.fontSizeScale,
                            min: 0.6,
                            max: 1.6,
                            activeColor: accent,
                            inactiveColor: Colors.white24,
                            thumbColor: accent,
                            onChanged: (val) {
                              setSheetState(() {});
                              danmakuController.setFontSizeScale(val);
                            },
                          ),
                        ),
                        Text(
                          '${(danmakuController.fontSizeScale * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    // Area ratio
                    Row(
                      children: [
                        const Text('显示区域', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 14),
                        ...[0.25, 0.5, 0.75, 1.0].map((ratio) {
                          final selected = (danmakuController.areaRatio - ratio).abs() < 0.05;
                          final label = '${(ratio * 100).toInt()}%';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {});
                                danmakuController.setAreaRatio(ratio);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? accent.withValues(alpha: 0.22)
                                      : const Color(0xFF262630),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? accent
                                        : Colors.white.withValues(alpha: 0.15),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: selected ? accent : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
