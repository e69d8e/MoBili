import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/video_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';

/// Modal dialog/bottom sheet for browsing and selecting UGC collection/season episodes.
class VideoSeasonSheet {
  static void show(
    BuildContext context, {
    required UgcSeason season,
    required String currentBvid,
    required void Function(UgcEpisode ep) onSelectEpisode,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEpisodes = season.sections.expand((s) => s.episodes).toList();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '合集选集',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final screenHeight = MediaQuery.of(ctx).size.height;
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        final dialogWidth = math.min(screenWidth - 32, 480.0);

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.52),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xE6181820) : const Color(0xF2FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.video_library_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '合集选集',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${season.title} · 共${season.epCount}集',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                        ),
                        const SizedBox(height: 8),

                        // Episode List
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: allEpisodes.length,
                            separatorBuilder: (c, _) => const SizedBox(height: 6),
                            itemBuilder: (c, idx) {
                              final ep = allEpisodes[idx];
                              final isPlaying = ep.bvid == currentBvid;
                              final primaryColor = Theme.of(context).colorScheme.primary;
                              return InkWell(
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  onSelectEpisode(ep);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isPlaying
                                        ? primaryColor.withValues(alpha: 0.14)
                                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isPlaying ? primaryColor : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (isPlaying)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6.0),
                                          child: Icon(Icons.play_circle_fill_rounded, color: primaryColor, size: 14),
                                        ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${idx + 1}. ${ep.title}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                                color: isPlaying
                                                    ? primaryColor
                                                    : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
                                              ),
                                            ),
                                            if (ep.duration > 0) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                Formatters.formatDuration(ep.duration),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
