import 'package:flutter/material.dart';
import '../../models/subtitle_model.dart';

class SubtitleOverlay extends StatelessWidget {
  final SubtitleData? subtitleData;
  final Duration currentPosition;
  final bool isFullScreen;
  final double bottomOffset;

  const SubtitleOverlay({
    super.key,
    required this.subtitleData,
    required this.currentPosition,
    this.isFullScreen = false,
    this.bottomOffset = 42.0,
  });

  @override
  Widget build(BuildContext context) {
    if (subtitleData == null || subtitleData!.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentSeconds = currentPosition.inMilliseconds / 1000.0;
    final item = subtitleData!.getActiveItem(currentSeconds);

    if (item == null || item.content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final fontSize = isFullScreen ? 18.0 : 14.5;

    return Positioned(
      left: 20,
      right: 20,
      bottom: bottomOffset,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              item.content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                height: 1.25,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
