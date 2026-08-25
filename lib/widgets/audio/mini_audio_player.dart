import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/listen_video_provider.dart';
import '../../screens/video/listen_video_screen.dart';
import '../../theme/app_theme.dart';
import '../network_image_view.dart';

class _MiniPlayerMetadata {
  final bool hasAudio;
  final bool isPlaying;
  final bool isBuffering;
  final String title;
  final String cover;
  final String upName;
  final String bvid;
  final int cid;
  final Duration duration;
  final bool isSleepTimerActive;
  final int? sleepTimerMinutes;

  const _MiniPlayerMetadata({
    required this.hasAudio,
    required this.isPlaying,
    required this.isBuffering,
    required this.title,
    required this.cover,
    required this.upName,
    required this.bvid,
    required this.cid,
    required this.duration,
    required this.isSleepTimerActive,
    this.sleepTimerMinutes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MiniPlayerMetadata &&
          runtimeType == other.runtimeType &&
          hasAudio == other.hasAudio &&
          isPlaying == other.isPlaying &&
          isBuffering == other.isBuffering &&
          title == other.title &&
          cover == other.cover &&
          upName == other.upName &&
          bvid == other.bvid &&
          cid == other.cid &&
          duration == other.duration &&
          isSleepTimerActive == other.isSleepTimerActive &&
          sleepTimerMinutes == other.sleepTimerMinutes;

  @override
  int get hashCode => Object.hash(
        hasAudio,
        isPlaying,
        isBuffering,
        title,
        cover,
        upName,
        bvid,
        cid,
        duration,
        isSleepTimerActive,
        sleepTimerMinutes,
      );
}

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ListenVideoProvider, _MiniPlayerMetadata>(
      selector: (_, provider) => _MiniPlayerMetadata(
        hasAudio: provider.hasAudio,
        isPlaying: provider.isPlaying,
        isBuffering: provider.isBuffering,
        title: provider.title ?? '正在播放音频',
        cover: provider.coverUrl ?? '',
        upName: provider.upName ?? '',
        bvid: provider.bvid ?? '',
        cid: provider.cid ?? 0,
        duration: provider.duration,
        isSleepTimerActive: provider.isSleepTimerActive,
        sleepTimerMinutes: provider.sleepTimerRemaining?.inMinutes,
      ),
      builder: (context, meta, _) {
        if (!meta.hasAudio) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;

        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFEBECEF),
                width: 0.8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top mini progress line (isolated high-frequency redraw)
                _MiniAudioProgressBar(primary: primary, isDark: isDark),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ListenVideoScreen(
                          bvid: meta.bvid,
                          cid: meta.cid,
                          title: meta.title,
                          coverUrl: meta.cover,
                          upName: meta.upName,
                          totalDuration: meta.duration,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        // Album Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                NetworkImageView(
                                  url: meta.cover,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 100,
                                  memCacheHeight: 100,
                                ),
                                Container(
                                  color: Colors.black26,
                                  child: const Center(
                                    child: Icon(
                                      Icons.headphones_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & UP
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                meta.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    meta.upName.isNotEmpty ? meta.upName : '听视频模式',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                                    ),
                                  ),
                                  if (meta.isSleepTimerActive && meta.sleepTimerMinutes != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '🌙 ${meta.sleepTimerMinutes}m',
                                      style: TextStyle(fontSize: 10, color: primary),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Play / Pause Button
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: meta.isBuffering
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                                  ),
                                )
                              : Icon(
                                  meta.isPlaying
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: primary,
                                  size: 32,
                                ),
                          onPressed: () => context.read<ListenVideoProvider>().togglePlayPause(),
                        ),

                        // Close Button
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                          ),
                          onPressed: () => context.read<ListenVideoProvider>().stopAndClear(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniAudioProgressBar extends StatelessWidget {
  final Color primary;
  final bool isDark;

  const _MiniAudioProgressBar({
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ListenVideoProvider, double>(
      selector: (_, provider) {
        final pos = provider.position.inMilliseconds;
        final dur = provider.duration.inMilliseconds;
        return dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
      },
      builder: (_, progress, _) {
        return LinearProgressIndicator(
          value: progress,
          minHeight: 2.0,
          backgroundColor: isDark ? Colors.white10 : Colors.black12,
          valueColor: AlwaysStoppedAnimation<Color>(primary),
        );
      },
    );
  }
}
