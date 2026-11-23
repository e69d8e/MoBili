import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../models/subtitle_model.dart';
import '../../../models/video_model.dart';
import '../../../theme/overlay_colors.dart';
import '../../../utils/formatters.dart';

/// 播放器内浮层通用包装：
/// - 全屏模式下作为贴合右侧的安全区侧滑抽屉
/// - 竖屏小窗模式下作为控制栏上方柔和浮出的半透明胶囊面板
class PlayerPanelFrame extends StatelessWidget {
  final bool isFull;
  final String? title;
  final IconData? titleIcon;
  final Color accent;
  final double? maxWidth;
  final Widget child;

  const PlayerPanelFrame({
    super.key,
    required this.isFull,
    this.title,
    this.titleIcon,
    required this.accent,
    this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isFull ? 10 : 6,
          horizontal: isFull ? 10 : 5,
        ),
        constraints: BoxConstraints(
          minWidth: isFull ? 180 : 88,
          maxWidth: maxWidth ?? (isFull ? 236 : 184),
          maxHeight: isFull ? double.infinity : 148,
        ),
        decoration: BoxDecoration(
          color: OverlayColors.panel,
          borderRadius: BorderRadius.circular(isFull ? 16 : 12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: isFull ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(6.0, 2, 6.0, 6),
                child: Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, size: 13, color: accent),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      title!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 4, thickness: 0.5, color: Colors.white12),
              const SizedBox(height: 4),
            ],
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating popup/drawer panel for selecting playback quality.
class PlayerQualityPanel extends StatelessWidget {
  final List<({int quality, String description, bool locked})> qualityItems;
  final int currentQuality;
  final Color accent;
  final bool isFull;
  final ValueChanged<int> onSelectQuality;

  const PlayerQualityPanel({
    super.key,
    required this.qualityItems,
    required this.currentQuality,
    required this.accent,
    required this.isFull,
    required this.onSelectQuality,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerPanelFrame(
      isFull: isFull,
      title: isFull ? '画质清晰度' : null,
      titleIcon: Icons.high_quality_outlined,
      accent: accent,
      maxWidth: isFull ? 210 : 136,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: qualityItems.map((item) {
          final isSelected = currentQuality == item.quality;

          return InkWell(
            onTap: () => onSelectQuality(item.quality),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: isFull ? 8.0 : 5.5,
              ),
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? accent.withValues(alpha: 0.55)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: isFull
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      item.description,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? accent
                            : Colors.white.withValues(
                                alpha: item.locked ? 0.55 : 0.88,
                              ),
                        fontSize: isFull ? 12 : 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (item.locked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Floating popup/drawer panel for selecting playback speed.
class PlayerSpeedPanel extends StatelessWidget {
  final List<double> speeds;
  final double currentSpeed;
  final Color accent;
  final bool isFull;
  final ValueChanged<double> onSelectSpeed;

  const PlayerSpeedPanel({
    super.key,
    this.speeds = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    required this.currentSpeed,
    required this.accent,
    required this.isFull,
    required this.onSelectSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerPanelFrame(
      isFull: isFull,
      title: isFull ? '播放倍速' : null,
      titleIcon: Icons.speed_rounded,
      accent: accent,
      maxWidth: isFull ? 186 : 108,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: speeds.map((s) {
          final isSelected = (currentSpeed - s).abs() < 0.01;
          return InkWell(
            onTap: () => onSelectSpeed(s),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: isFull ? 8.0 : 5.5,
              ),
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? accent.withValues(alpha: 0.55)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  '${s}x',
                  style: TextStyle(
                    color: isSelected
                        ? accent
                        : Colors.white.withValues(alpha: 0.88),
                    fontSize: isFull ? 12 : 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Floating popup/drawer panel for browsing and jumping to video chapters.
/// 支持传入 [positionListenable] 实时高亮当前播放章节。
class PlayerChapterPanel extends StatelessWidget {
  final List<VideoChapter> chapters;
  final int currentSec;
  final ValueListenable<VideoPlayerValue>? positionListenable;
  final Color accent;
  final bool isFull;
  final ValueChanged<VideoChapter> onSelectChapter;

  const PlayerChapterPanel({
    super.key,
    required this.chapters,
    required this.currentSec,
    this.positionListenable,
    required this.accent,
    required this.isFull,
    required this.onSelectChapter,
  });

  Widget _buildChapterList(int activeSec) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: chapters.map((ch) {
        final isCurrent =
            activeSec >= ch.from &&
            (ch.to > ch.from ? activeSec < ch.to : true);
        final timeStr = Formatters.formatDuration(ch.from);

        return InkWell(
          onTap: () => onSelectChapter(ch),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: isFull ? 7.0 : 5.0,
            ),
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: BoxDecoration(
              color: isCurrent
                  ? accent.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent
                    ? accent.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isCurrent ? accent : Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Text(
                    ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? accent
                          : Colors.white.withValues(alpha: 0.88),
                      fontSize: isFull ? 12 : 11,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlayerPanelFrame(
      isFull: isFull,
      title: '视频章节',
      titleIcon: Icons.bookmark_outline_rounded,
      accent: accent,
      maxWidth: isFull ? 250 : 184,
      child: positionListenable != null
          ? ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: positionListenable!,
              builder: (context, val, _) =>
                  _buildChapterList(val.position.inSeconds),
            )
          : _buildChapterList(currentSec),
    );
  }
}

/// Floating popup/drawer panel for subtitle track selection.
class PlayerSubtitlePanel extends StatelessWidget {
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? currentSubtitleTrack;
  final bool isSubtitleEnabled;
  final Color accent;
  final bool isFull;
  final ValueChanged<SubtitleTrack?> onSelectTrack;

  const PlayerSubtitlePanel({
    super.key,
    required this.subtitleTracks,
    required this.currentSubtitleTrack,
    required this.isSubtitleEnabled,
    required this.accent,
    required this.isFull,
    required this.onSelectTrack,
  });

  Widget _buildSubtitleOption({
    required String label,
    bool isAi = false,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 8.0,
          vertical: isFull ? 8.0 : 5.5,
        ),
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? accent
                      : Colors.white.withValues(alpha: 0.88),
                  fontSize: isFull ? 12 : 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAi) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlayerPanelFrame(
      isFull: isFull,
      title: isFull ? '字幕轨道' : null,
      titleIcon: Icons.closed_caption_outlined,
      accent: accent,
      maxWidth: isFull ? 220 : 170,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubtitleOption(
            label: '关闭字幕',
            isSelected: !isSubtitleEnabled,
            accent: accent,
            onTap: () => onSelectTrack(null),
          ),
          ...subtitleTracks.map((track) {
            final isSelected = isSubtitleEnabled &&
                (currentSubtitleTrack?.id == track.id ||
                    (currentSubtitleTrack != null &&
                        currentSubtitleTrack!.lan == track.lan));
            final label = track.lanDoc.isNotEmpty ? track.lanDoc : track.lan;
            return _buildSubtitleOption(
              label: label,
              isAi: track.isAi,
              isSelected: isSelected,
              accent: accent,
              onTap: () => onSelectTrack(track),
            );
          }),
        ],
      ),
    );
  }
}
