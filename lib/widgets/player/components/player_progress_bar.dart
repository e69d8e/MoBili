import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../models/video_model.dart';
import '../../../theme/overlay_colors.dart';
import '../../../utils/formatters.dart';

/// 国际版 B 站风格自定义视频进度条：
/// - 展示已播放进度、缓冲进度与章节节点刻度
/// - 按下拖动时轨道加粗、滑块放大，并在指尖上方浮现时间 + 章节预览气泡
/// - 联动水平泛滑手势的 [dragPositionMs]
class PlayerProgressBar extends StatefulWidget {
  final ValueListenable<VideoPlayerValue> controller;
  final ValueNotifier<double?> dragPositionMs;
  final List<VideoChapter> chapters;
  final Color accent;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;

  const PlayerProgressBar({
    super.key,
    required this.controller,
    required this.dragPositionMs,
    required this.chapters,
    required this.accent,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _isDragging = false;

  String? _findChapterTitle(int sec) {
    if (widget.chapters.isEmpty) return null;
    for (final ch in widget.chapters) {
      if (sec >= ch.from && (ch.to <= ch.from || sec < ch.to)) {
        return ch.title;
      }
    }
    return null;
  }

  double _fractionFromLocalDx(double dx, double width) {
    if (width <= 0) return 0.0;
    return (dx / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: widget.dragPositionMs,
      builder: (context, dragVal, _) {
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: widget.controller,
          builder: (context, val, _) {
            final totalMs = val.duration.inMilliseconds;
            final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
            final curMs =
                (dragVal ?? val.position.inMilliseconds.toDouble()).clamp(
                  0.0,
                  maxMs,
                );
            final fraction = (curMs / maxMs).clamp(0.0, 1.0);

            double bufferedFraction = 0.0;
            if (totalMs > 0 && val.buffered.isNotEmpty) {
              final endMs = val.buffered.last.end.inMilliseconds;
              bufferedFraction = (endMs / totalMs).clamp(0.0, 1.0);
            }

            final activeDrag = _isDragging || dragVal != null;
            final currentSec = (curMs / 1000.0).floor();
            final chapterTitle = activeDrag ? _findChapterTitle(currentSec) : null;

            return LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final thumbX = trackWidth * fraction;
                final previewLeft = (thumbX - 64.0).clamp(
                  0.0,
                  (trackWidth - 128.0).clamp(0.0, double.infinity),
                );

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: totalMs <= 0
                      ? null
                      : (details) {
                          setState(() => _isDragging = true);
                          final f = _fractionFromLocalDx(
                            details.localPosition.dx,
                            trackWidth,
                          );
                          HapticFeedback.selectionClick();
                          widget.onSeekStart(f * maxMs);
                        },
                  onHorizontalDragUpdate: totalMs <= 0
                      ? null
                      : (details) {
                          final f = _fractionFromLocalDx(
                            details.localPosition.dx,
                            trackWidth,
                          );
                          widget.onSeekUpdate(f * maxMs);
                        },
                  onHorizontalDragEnd: totalMs <= 0
                      ? null
                      : (_) {
                          final target = widget.dragPositionMs.value ?? curMs;
                          setState(() => _isDragging = false);
                          HapticFeedback.lightImpact();
                          widget.onSeekEnd(target);
                        },
                  onHorizontalDragCancel: () {
                    if (_isDragging) {
                      final target = widget.dragPositionMs.value ?? curMs;
                      setState(() => _isDragging = false);
                      widget.onSeekEnd(target);
                    }
                  },
                  onTapDown: totalMs <= 0
                      ? null
                      : (details) {
                          final f = _fractionFromLocalDx(
                            details.localPosition.dx,
                            trackWidth,
                          );
                          HapticFeedback.selectionClick();
                          widget.onSeekEnd(f * maxMs);
                        },
                  child: SizedBox(
                    height: 32,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // 拖动指尖预览气泡
                        if (_isDragging && totalMs > 0)
                          Positioned(
                            bottom: 34,
                            left: previewLeft,
                            child: IgnorePointer(
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 96,
                                  maxWidth: 168,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: OverlayColors.bubble,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${Formatters.formatDuration(currentSec)} / ${Formatters.formatDuration(val.duration.inSeconds)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (chapterTitle != null &&
                                        chapterTitle.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        chapterTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: widget.accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // 背景轨道 / 缓冲轨道 / 播放轨道 + 章节刻度
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          height: activeDrag ? 4.5 : 2.5,
                          width: trackWidth,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CustomPaint(
                              painter: _ProgressTrackPainter(
                                playedFraction: fraction,
                                bufferedFraction: bufferedFraction,
                                accent: widget.accent,
                                chapters: widget.chapters,
                                totalDurationSeconds: val.duration.inSeconds,
                              ),
                            ),
                          ),
                        ),

                        // 滑块圆点（拖动时放大 + 柔和光晕）
                        Positioned(
                          left: (thumbX - (activeDrag ? 8.0 : 5.0)).clamp(
                            0.0,
                            (trackWidth - (activeDrag ? 16.0 : 10.0)).clamp(
                              0.0,
                              double.infinity,
                            ),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: activeDrag ? 16.0 : 10.0,
                            height: activeDrag ? 16.0 : 10.0,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                              boxShadow: activeDrag
                                  ? [
                                      BoxShadow(
                                        color: widget.accent.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProgressTrackPainter extends CustomPainter {
  final double playedFraction;
  final double bufferedFraction;
  final Color accent;
  final List<VideoChapter> chapters;
  final int totalDurationSeconds;

  const _ProgressTrackPainter({
    required this.playedFraction,
    required this.bufferedFraction,
    required this.accent,
    required this.chapters,
    required this.totalDurationSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 缓冲条
    if (bufferedFraction > 0) {
      final bufPaint = Paint()..color = Colors.white38;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * bufferedFraction, size.height),
        bufPaint,
      );
    }

    // 已播放进度条
    if (playedFraction > 0) {
      final playPaint = Paint()..color = accent;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * playedFraction, size.height),
        playPaint,
      );
    }

    // 章节分割刻度
    if (chapters.length > 1 && totalDurationSeconds > 0) {
      final notchPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
      for (int i = 1; i < chapters.length; i++) {
        final f = (chapters[i].from / totalDurationSeconds).clamp(0.0, 1.0);
        if (f > 0.01 && f < 0.99) {
          canvas.drawRect(
            Rect.fromLTWH(size.width * f - 1.0, 0, 2.0, size.height),
            notchPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressTrackPainter oldDelegate) {
    return oldDelegate.playedFraction != playedFraction ||
        oldDelegate.bufferedFraction != bufferedFraction ||
        oldDelegate.accent != accent ||
        oldDelegate.totalDurationSeconds != totalDurationSeconds ||
        oldDelegate.chapters.length != chapters.length;
  }
}
