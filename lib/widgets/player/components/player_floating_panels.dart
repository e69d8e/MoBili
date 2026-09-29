import 'package:flutter/material.dart';
import '../../../models/subtitle_model.dart';
import '../../../models/video_model.dart';
import '../../../utils/formatters.dart';

/// Floating popup panel for selecting playback quality.
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
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        constraints: BoxConstraints(maxHeight: isFull ? 240 : 120),
        decoration: BoxDecoration(
          color: const Color(0xF0181820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: qualityItems.map((item) {
              final isSelected = currentQuality == item.quality;

              return InkWell(
                onTap: () => onSelectQuality(item.quality),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.55) : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            item.description,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? accent
                                  : Colors.white.withValues(
                                      alpha: item.locked ? 0.55 : 0.85,
                                    ),
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        // 未登录时 1080P 及以上标记锁定（点击仍会触发登录引导）
                        if (item.locked) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Floating popup panel for selecting playback speed.
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
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        constraints: BoxConstraints(maxHeight: isFull ? 240 : 120),
        decoration: BoxDecoration(
          color: const Color(0xF0181820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: speeds.map((s) {
              final isSelected = currentSpeed == s;
              return InkWell(
                onTap: () => onSelectSpeed(s),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.55) : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${s}x',
                      style: TextStyle(
                        color: isSelected ? accent : Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Floating popup panel for browsing and jumping to video chapters.
class PlayerChapterPanel extends StatelessWidget {
  final List<VideoChapter> chapters;
  final int currentSec;
  final Color accent;
  final bool isFull;
  final ValueChanged<VideoChapter> onSelectChapter;

  const PlayerChapterPanel({
    super.key,
    required this.chapters,
    required this.currentSec,
    required this.accent,
    required this.isFull,
    required this.onSelectChapter,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        constraints: BoxConstraints(
          maxHeight: isFull ? 240 : 130,
          maxWidth: isFull ? 220 : 170,
        ),
        decoration: BoxDecoration(
          color: const Color(0xF0181820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.bookmark_outline_rounded, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    '视频章节',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 6, thickness: 0.5, color: Colors.white12),
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: chapters.map((ch) {
                    final isCurrent = currentSec >= ch.from && (ch.to > ch.from ? currentSec < ch.to : true);
                    final timeStr = Formatters.formatDuration(ch.from);

                    return InkWell(
                      onTap: () => onSelectChapter(ch),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        decoration: BoxDecoration(
                          color: isCurrent ? accent.withValues(alpha: 0.22) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCurrent ? accent.withValues(alpha: 0.55) : Colors.transparent,
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
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ch.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? accent : Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating popup panel for subtitle track selection.
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accent.withValues(alpha: 0.55) : Colors.transparent,
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
                  color: isSelected ? accent : Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAi) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
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
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        constraints: BoxConstraints(
          maxHeight: isFull ? 240 : 130,
          maxWidth: isFull ? 200 : 160,
        ),
        decoration: BoxDecoration(
          color: const Color(0xF0181820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
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
        ),
      ),
    );
  }
}
