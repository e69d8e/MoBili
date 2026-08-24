import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/listen_video_provider.dart';
import '../../screens/video/listen_video_screen.dart';
import '../../theme/app_theme.dart';
import '../network_image_view.dart';

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListenVideoProvider>();
    if (!provider.hasAudio) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final title = provider.title ?? '正在播放音频';
    final cover = provider.coverUrl ?? '';
    final upName = provider.upName ?? '';

    final pos = provider.position.inMilliseconds;
    final dur = provider.duration.inMilliseconds;
    final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

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
          // Top mini progress line
          LinearProgressIndicator(
            value: progress,
            minHeight: 2.0,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(primary),
          ),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => ListenVideoScreen(
                    bvid: provider.bvid ?? '',
                    cid: provider.cid ?? 0,
                    title: title,
                    coverUrl: cover,
                    upName: upName,
                    totalDuration: provider.duration,
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
                            url: cover,
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
                          title,
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
                              upName.isNotEmpty ? upName : '听视频模式',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                              ),
                            ),
                            if (provider.isSleepTimerActive && provider.sleepTimerRemaining != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '🌙 ${provider.sleepTimerRemaining!.inMinutes}m',
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
                    icon: provider.isBuffering
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primary),
                            ),
                          )
                        : Icon(
                            provider.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: primary,
                            size: 32,
                          ),
                    onPressed: provider.togglePlayPause,
                  ),

                  // Close Button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                    onPressed: provider.stopAndClear,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
