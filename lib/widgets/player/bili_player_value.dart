/// 播放器状态快照，供 UI 观察与测试。
class BiliPlayerValue {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isBuffering;
  final bool isInitialized;
  final double aspectRatio;

  const BiliPlayerValue({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isInitialized = false,
    this.aspectRatio = 16 / 9,
  });

  BiliPlayerValue copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isBuffering,
    bool? isInitialized,
    double? aspectRatio,
  }) {
    return BiliPlayerValue(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isInitialized: isInitialized ?? this.isInitialized,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}
